# Build custom Caddy with caddy-docker-proxy and Cloudflare DNS plugin
# Based on: https://github.com/lucaslorentz/caddy-docker-proxy

ARG CADDY_VERSION=2.11.2

FROM golang:alpine AS builder

# Install git and ca-certificates (required for xcaddy)
RUN apk add --no-cache git ca-certificates curl

# Set GOTOOLCHAIN to auto to allow automatic toolchain upgrades
ENV GOTOOLCHAIN=auto

# Install xcaddy
RUN go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

# Set working directory
WORKDIR /build

# Build Caddy with plugins
# xcaddy outputs to current directory by default
RUN xcaddy build ${CADDY_VERSION} \
    --with github.com/lucaslorentz/caddy-docker-proxy/v2 \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/mholt/caddy-l4 \
    --with github.com/mholt/caddy-ratelimit \
    --with github.com/sablierapp/sablier-caddy-plugin

FROM caddy:${CADDY_VERSION}-alpine

# Enable scanning of stopped containers by default so Sablier functions out-of-the-box
ENV CADDY_DOCKER_SCAN_STOPPED_CONTAINERS=true

# Copy the built binary from builder
COPY --from=builder /build/caddy /usr/bin/caddy

CMD ["caddy", "docker-proxy"]

