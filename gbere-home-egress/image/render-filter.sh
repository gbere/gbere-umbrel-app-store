#!/bin/sh
# Turns /data/domains (one per line or space-separated) into squid's allowlist.
# An empty list leaves an empty file, and squid then forwards nothing at all.
set -eu
OUT=/tmp/egress/allowed-domains
: > "${OUT}.new"
for domain in $(cat /data/domains 2>/dev/null); do
    # The leading dot is squid's "this domain and its subdomains".
    printf '.%s\n' "${domain}" >> "${OUT}.new"
done
mv "${OUT}.new" "${OUT}"
