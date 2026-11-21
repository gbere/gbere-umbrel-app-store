#!/bin/sh
# Three processes, all unprivileged:
#   1. tinyproxy  - HTTP proxy that only forwards to ALLOWED_DOMAINS
#   2. httpd      - status page (shows the public key, sets the destination)
#   3. ssh -N -R  - publishes the proxy on the remote server, reconnecting forever
set -eu

DATA=/data
RUN=/tmp/egress
KEY="${DATA}/id_ed25519"
TARGET_FILE="${DATA}/target"

# Where the proxy shows up on the remote side. The remote sshd must allow
# exactly this with permitlisten="..." on the key.
REMOTE_BIND="${REMOTE_BIND:-127.0.0.1:1080}"
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

cat > "${RUN}/tinyproxy.conf" <<CONF
Port 8888
Listen ${PROXY_LISTEN}
Timeout 600
MaxClients 20
# Default deny: anything not in the filter file is refused, which includes
# every IP literal - so the LAN this container sits on is out of reach.
Filter "${RUN}/filter"
FilterDefaultDeny Yes
FilterType ere
FilterCaseSensitive Off
ConnectPort 443
DisableViaHeader Yes
LogLevel Connect
PidFile "${RUN}/tinyproxy.pid"
CONF

tinyproxy -d -c "${RUN}/tinyproxy.conf" &
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

    echo "Connecting to ${hostpart}" > "${RUN}/status"
    # accept-new pins the server's host key on the first connection and refuses
    # a changed one afterwards.
    ssh -N \
        -R "${REMOTE_BIND}:127.0.0.1:8888" \
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
