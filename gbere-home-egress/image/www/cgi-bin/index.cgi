#!/bin/sh
# Status page. Shows the public key to authorise on the remote server and lets
# the owner set where the tunnel connects. Sits behind umbrelOS authentication.
DATA=/data
RUN=/tmp/egress

esc() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'; }

message=''
if [ "${REQUEST_METHOD:-GET}" = "POST" ]; then
    # Same-origin only: a page on another site must not be able to repoint the
    # tunnel by submitting this form on the owner's behalf.
    origin_host="$(printf '%s' "${HTTP_ORIGIN:-}" | sed -e 's#^[a-z]*://##' -e 's#/.*$##')"
    if [ -z "${origin_host}" ] || [ "${origin_host}" != "${HTTP_HOST:-}" ]; then
        message='Request refused (different origin).'
    else
        body="$(head -c "${CONTENT_LENGTH:-0}")"
        field() { printf '%s' "${body}" | tr '&' '\n' | sed -n "s/^$1=//p" | head -n 1; }
        case "${body}" in
        *domains=*)
            # Form encoding: spaces arrive as "+", line breaks as %0D%0A.
            list="$(field domains | sed -e 's/%0D%0A/ /g' -e 's/%0A/ /g' -e 's/%0D/ /g' -e 's/+/ /g' -e 's/%20/ /g')"
            bad=''
            for domain in ${list}; do
                # A real public name: at least two labels ending in letters. That
                # leaves out IP addresses, "localhost" and bare names such as
                # "router", which only mean something on the local network.
                printf '%s' "${domain}" | grep -Eq '^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$' || bad="${domain}"
                case "${domain}" in *.local|*.lan|*.home|*.internal|*.localhost|*.home.arpa) bad="${domain}" ;; esac
            done
            if [ -n "${bad}" ]; then
                message='Invalid domain. Public names like example.com only, one per line.'
            else
                printf '%s\n' ${list} > "${DATA}/domains"
                /app/render-filter.sh
                squid -k reconfigure -f "${RUN}/squid.conf" 2>/dev/null
                message='Domains saved.'
            fi
            ;;
        *bind=*)
            bind="$(field bind | sed -e 's/%3A/:/g' -e 's/%3a/:/g' -e 's/%2A/*/g' -e 's/%2a/*/g')"
            if printf '%s' "${bind}" | grep -Eq '^(([0-9]{1,3}\.){3}[0-9]{1,3}|localhost):[0-9]{1,5}$'; then
                printf '%s' "${bind}" > "${DATA}/bind"
                message='Listen address saved.'
                [ -f "${RUN}/ssh.pid" ] && kill "$(cat "${RUN}/ssh.pid")" 2>/dev/null
            else
                message='Invalid listen address. Format: address:port, e.g. 127.0.0.1:1080'
            fi
            ;;
        *)
            target="$(field target | sed -e 's/%40/@/g' -e 's/%3A/:/g' -e 's/%3a/:/g')"
            if [ -z "${target}" ]; then
                rm -f "${DATA}/target"
                message='Destination cleared.'
            elif printf '%s' "${target}" | grep -Eq '^[a-z_][a-z0-9_-]{0,31}@[A-Za-z0-9.-]{1,253}(:[0-9]{1,5})?$'; then
                printf '%s' "${target}" > "${DATA}/target"
                message='Destination saved.'
            else
                message='Invalid destination. Format: user@server or user@server:port'
            fi
            # Drop the current connection so the loop picks the new destination up.
            [ -f "${RUN}/ssh.pid" ] && kill "$(cat "${RUN}/ssh.pid")" 2>/dev/null
            ;;
        esac
    fi
fi

if [ -f "${RUN}/ssh.pid" ] && kill -0 "$(cat "${RUN}/ssh.pid")" 2>/dev/null; then
    state="Tunnel open"
else
    state="$(cat "${RUN}/status" 2>/dev/null)"
fi

printf 'Content-Type: text/html; charset=utf-8\r\n\r\n'
cat <<HTML
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Home Egress</title>
<style>
body{font:16px/1.5 system-ui,sans-serif;max-width:44rem;margin:2rem auto;padding:0 1rem;color:#1c1c1c;background:#fafafa}
@media (prefers-color-scheme:dark){body{color:#eee;background:#161616}pre,input,textarea{background:#222;color:#eee;border-color:#444}}
pre{padding:.75rem;border:1px solid #ccc;border-radius:6px;white-space:pre-wrap;word-break:break-all}
input,textarea{font:inherit;padding:.4rem .6rem;border:1px solid #ccc;border-radius:6px;width:100%;box-sizing:border-box}
button{font:inherit;padding:.4rem 1rem;margin-top:.5rem}
</style></head><body>
<h1>Home Egress</h1>
<p><b>Status:</b> $(printf '%s' "${state}" | esc)</p>
$( [ -n "${message}" ] && printf '<p><b>%s</b></p>' "$(printf '%s' "${message}" | esc)" )
<h2>Destination</h2>
<form method="post">
<input name="target" placeholder="user@server:22" value="$(cat "${DATA}/target" 2>/dev/null | esc)">
<button type="submit">Save</button>
</form>
<h2>Listen address on the server</h2>
<p>Where the proxy appears on the destination server. Keep it on <code>127.0.0.1</code> unless the address you
choose is private to that server: the proxy has no password of its own.</p>
<form method="post">
<input name="bind" value="$(esc < "${DATA}/bind")">
<button type="submit">Save</button>
</form>
<h2>Public key</h2>
<p>Authorise it on the destination server, restricted to opening the tunnel port.</p>
<pre>$(esc < "${DATA}/id_ed25519.pub")</pre>
<h2>Allowed domains</h2>
<p>One per line; each covers its subdomains. Everything else is refused, and so is any name that resolves to a private address.</p>
<form method="post">
<textarea name="domains" rows="5">$(esc < "${DATA}/domains")</textarea>
<button type="submit">Save</button>
</form>
</body></html>
HTML
