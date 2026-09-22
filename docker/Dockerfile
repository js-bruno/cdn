# OPTIONAL: run the CDN with Docker instead of the native systemd setup.
# Build from the repo root:
#   docker build -f docker/Dockerfile -t cdn-caddy:local .
FROM caddy:2.11-builder AS builder
ARG CADDY_WEBDAV_REF=fa2f366b0d75e54c2e381c0aefc3a8df8bf5794b
RUN xcaddy build --with github.com/mholt/caddy-webdav@${CADDY_WEBDAV_REF}

FROM caddy:2.11
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
COPY Caddyfile /etc/caddy/Caddyfile
