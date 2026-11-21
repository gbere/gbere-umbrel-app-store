#!/bin/sh
# Three processes, all unprivileged:
#   1. squid      - HTTP proxy that only forwards to the allowed domains
#   2. httpd      - status page (shows the public key, sets the destination)
#   3. ssh -N -R  - publishes the proxy on the remote server, reconnecting forever
set -eu

DATA=/data
RUN=/tmp/egress
KEY="${DATA}/id_ed25519"
TARGET_FILE="${DATA}/target"

# Only loopback by default: the tunnel is the one intended client.
PROXY_LISTEN="${PROXY_LISTEN:-127.0.0.1}"

mkdir -p "${RUN}"

if [ ! -f "${KEY}" ]; then
    ssh-keygen -q -t ed25519 -N '' -C 'home-egress' -f "${KEY}"
fi

# Nothing is allowed until the owner lists domains on the status page.
# ALLOWED_DOMAINS only seeds a fresh install.
if [ ! -f "${DATA}/domains" ]; then
    printf '%s\n' ${ALLOWED_DOMAINS:-} > "${DATA}/domains"
fi
/app/render-filter.sh

# Where the proxy shows up on the destination server. Loopback unless the owner
# says otherwise on the status page: the proxy has no password, so a wider
# address is only right when that address is itself private.
if [ ! -f "${DATA}/bind" ]; then
    printf '%s' "${REMOTE_BIND:-127.0.0.1:1080}" > "${DATA}/bind"
fi

cat > "${RUN}/squid.conf" <<CONF
http_port ${PROXY_LISTEN}:8888
pid_filename ${RUN}/squid.pid
cache deny all
cache_log /dev/null
access_log stdio:/dev/stdout
coredump_dir /tmp
shutdown_lifetime 1 seconds
via off
forwarded_for delete

acl allowed dstdomain "${RUN}/allowed-domains"
# Checked against the address a name RESOLVES to, not against its text: an
# allowed domain whose DNS answers with a private address is still refused, so
# neither a typo nor a hostile DNS record can turn the allowlist into a way
# onto the network this container sits on.
acl private dst 0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.0.0.0/24 192.168.0.0/16 198.18.0.0/15 224.0.0.0/4 240.0.0.0/4
acl private dst ::/128 ::1/128 ::ffff:0:0/96 64:ff9b::/96 fc00::/7 fe80::/10 ff00::/8
acl web_ports port 80 443
acl tls_port port 443
acl CONNECT method CONNECT

http_access deny !web_ports
http_access deny CONNECT !tls_port
http_access deny !allowed
http_access deny private
http_access allow allowed
http_access deny all
CONF

squid -N -f "${RUN}/squid.conf" &
httpd -f -p 8080 -h /app/www &

echo 'Waiting for a destination' > "${RUN}/status"

while true; do
    if [ ! -s "${TARGET_FILE}" ]; then
        echo 'Waiting for a destination' > "${RUN}/status"
        sleep 5
        continue
    fi

    target="$(cat "${TARGET_FILE}")"
    hostpart="${target%%:*}"
    port=22
    case "${target}" in *:*) port="${target##*:}" ;; esac

    bind="$(cat "${DATA}/bind")"
    echo "Connecting to ${hostpart}" > "${RUN}/status"
    # accept-new pins the server's host key on the first connection and refuses
    # a changed one afterwards.
    ssh -N \
        -R "${bind}:127.0.0.1:8888" \
        -i "${KEY}" -p "${port}" \
        -o IdentitiesOnly=yes \
        -o ExitOnForwardFailure=yes \
        -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
        -o ConnectTimeout=20 \
        -o StrictHostKeyChecking=accept-new \
        -o UserKnownHostsFile="${DATA}/known_hosts" \
        -o BatchMode=yes \
        "${hostpart}" 2> "${RUN}/ssh.err" &
    ssh_pid=$!
    echo "${ssh_pid}" > "${RUN}/ssh.pid"
    wait "${ssh_pid}" || true
    rm -f "${RUN}/ssh.pid"
    echo "Disconnected: $(tail -n 1 "${RUN}/ssh.err" 2>/dev/null)" > "${RUN}/status"
    cat "${RUN}/ssh.err" >&2 || true
    sleep 10
done
