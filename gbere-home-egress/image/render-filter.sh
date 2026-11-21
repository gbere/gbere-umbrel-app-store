#!/bin/sh
# Turns /data/domains (one per line or space-separated) into tinyproxy's filter
# file. An empty list leaves an empty filter, and with FilterDefaultDeny that
# means the proxy forwards nothing at all.
set -eu
OUT=/tmp/egress/filter
: > "${OUT}.new"
for domain in $(cat /data/domains 2>/dev/null); do
    # A domain also covers its subdomains.
    printf '(^|\\.)%s$\n' "$(printf '%s' "${domain}" | sed 's/\./\\./g')" >> "${OUT}.new"
done
mv "${OUT}.new" "${OUT}"
