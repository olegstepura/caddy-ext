# Custom Caddy Docker Proxy

This repository provides a custom build of the [Caddy](https://caddyserver.com/) web server, pre-configured with [caddy-docker-proxy](https://github.com/lucaslorentz/caddy-docker-proxy) and a selection of highly useful plugins. 

The image is built automatically and published to the GitHub Container Registry (GHCR).

## Features & Plugins

This custom image is built from `caddy:alpine` and includes the following plugins:

* **[Caddy Docker Proxy](https://github.com/lucaslorentz/caddy-docker-proxy/v2):** Automatically generates Caddyfile configurations based on Docker container labels.
* **[Cloudflare DNS](https://github.com/caddy-dns/cloudflare):** Enables automated ACME DNS-01 challenges using Cloudflare, perfect for internal services or wildcards.
* **[Caddy L4](https://github.com/mholt/caddy-l4):** Adds Layer 4 (TCP/UDP) proxying capabilities.
* **[Caddy RateLimit](https://github.com/mholt/caddy-ratelimit):** Provides HTTP rate limiting functionality to protect your services.

## Image Registry

You can pull the pre-built image directly from GHCR:

```bash
docker pull ghcr.io/olegstepura/caddy-ext:latest
```

## Usage Example

Since this image acts as a Docker proxy, you need to mount the Docker socket. Here is a basic `docker-compose.yml` example showing how to deploy this custom Caddy image and use the Cloudflare DNS plugin.

```yaml
version: "3.9"

services:
  caddy:
    image: ghcr.io/olegstepura/caddy-ext:latest
    ports:
      - "80:80"
      - "443:443"
    environment:
      - CADDY_INGRESS_NETWORKS=caddy
      # Required for the Cloudflare DNS plugin
      - CLOUDFLARE_API_TOKEN=${CLOUDFLARE_API_TOKEN}
    networks:
      - caddy
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - caddy_data:/data
    restart: unless-stopped

  # Example service routed by Caddy
  whoami:
    image: traefik/whoami
    networks:
      - caddy
    labels:
      caddy: whoami.yourdomain.com
      caddy.reverse_proxy: "{{upstreams 80}}"
      # Using Cloudflare DNS for TLS
      caddy.tls.dns: cloudflare {env.CLOUDFLARE_API_TOKEN}

networks:
  caddy:
    name: caddy

volumes:
  caddy_data:
```

## Building Locally

If you want to build the image manually:

1. Clone the repository.
2. Run the Docker build command:

```bash
docker build -t custom-caddy .
```

---
**Note:** Ensure that your Cloudflare API token has `Zone:Zone:Read` and `Zone:DNS:Edit` permissions.
