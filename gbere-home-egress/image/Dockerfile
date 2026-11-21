# Outbound-only egress proxy: a domain-allowlisted HTTP proxy (tinyproxy) that
# is published on a remote server through a reverse SSH tunnel. Nothing in this
# image accepts connections from outside the container except the status page.
FROM alpine:3.22

RUN apk add --no-cache openssh-client tinyproxy busybox-extras \
    && adduser -D -u 1000 egress \
    && mkdir /data && chown egress:egress /data

COPY entrypoint.sh render-filter.sh /app/
COPY www /app/www
RUN chmod +x /app/entrypoint.sh /app/render-filter.sh /app/www/cgi-bin/index.cgi

USER egress
VOLUME /data
EXPOSE 8080
ENTRYPOINT ["/app/entrypoint.sh"]
