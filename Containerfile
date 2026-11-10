# Build custom Caddy with caddy-docker-proxy and Cloudflare DNS plugin
# Based on: https://github.com/lucaslorentz/caddy-docker-proxy

ARG CADDY_VERSION=2.11.7

# caddy-l4 is pinned to a master commit: v0.1.1 and v0.1.2 hand a pooled prefetch buffer to
# Caddy's `tls` listener wrapper and then reuse it, so under concurrent load a fall-through
# connection can be handshaked with another client's ClientHello (Go clients fail with
# "tls: server did not echo the legacy session ID"). Fixed by mholt/caddy-l4#483, which is not
# in a release yet. Switch back to a release tag once v0.1.3 is out. This commit requires
# Caddy >= 2.11.7.
ARG CADDY_L4_VERSION=4ad6aec1ccc6

FROM golang:alpine AS builder

# ARGs declared before FROM are not visible inside a stage unless re-declared here. Before this
# line `xcaddy build ${CADDY_VERSION}` got an empty version and always built Caddy's latest.
ARG CADDY_VERSION
ARG CADDY_L4_VERSION

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
RUN xcaddy build v${CADDY_VERSION} \
    --with github.com/lucaslorentz/caddy-docker-proxy/v2 \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/mholt/caddy-l4@${CADDY_L4_VERSION} \
    --with github.com/mholt/caddy-ratelimit \
    --with github.com/sablierapp/sablier-caddy-plugin

FROM caddy:${CADDY_VERSION}-alpine

# Enable scanning of stopped containers by default so Sablier functions out-of-the-box
ENV CADDY_DOCKER_SCAN_STOPPED_CONTAINERS=true

# Copy the built binary from builder
COPY --from=builder /build/caddy /usr/bin/caddy

CMD ["caddy", "docker-proxy"]

