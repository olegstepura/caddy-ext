# Custom Caddy Docker Proxy

This repository provides a custom build of the [Caddy](https://caddyserver.com/) web server, pre-configured with [caddy-docker-proxy](https://github.com/lucaslorentz/caddy-docker-proxy) and a selection of highly useful plugins. 

The image is built automatically and published to the GitHub Container Registry (GHCR).

## Features & Plugins

This custom image is built from `caddy:alpine` and includes the following plugins:

* **[Caddy Docker Proxy](https://github.com/lucaslorentz/caddy-docker-proxy):** Automatically generates Caddyfile configurations based on Docker container labels.
* **[Cloudflare DNS](https://github.com/caddy-dns/cloudflare):** Enables automated ACME DNS-01 challenges using Cloudflare, perfect for internal services or wildcards.
* **[Caddy L4](https://github.com/mholt/caddy-l4):** Adds Layer 4 (TCP/UDP) proxying capabilities.
* **[Caddy RateLimit](https://github.com/mholt/caddy-ratelimit):** Provides HTTP rate limiting functionality to protect your services.
* **[Sablier](https://github.com/sablierapp/sablier)**: Integrates scale-to-zero capabilities. Intercepts requests to sleeping containers, wakes them up on-demand, and proxies the traffic once healthy.

Note on Sablier: To ensure Caddy discovers offline containers and allows Sablier to wake them up, this image hardcodes `CADDY_DOCKER_SCAN_STOPPED_CONTAINERS=true` by default.

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

  # Sablier daemon that actually starts/stops the containers
  sablier:
    image: sablierapp/sablier:latest
    command: start --provider.name=docker --provider.auto-stop-on-startup=true
    networks:
      - caddy
    volumes:
      # Requires read/write access to control container states
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped

  # Example service routed by Caddy
  whoami:
    image: traefik/whoami
    networks:
      - caddy
    labels:
      # -- Sablier Docker Provider config --
      # Allows the Sablier daemon to manage this container
      sablier.enable: "true"
      sablier.group: whoami

      # -- Caddy Routing & TLS --
      caddy: whoami.yourdomain.com
      caddy.tls.dns: cloudflare {env.CLOUDFLARE_API_TOKEN}

      # Use a route block to ensure Sablier checks run before proxying
      caddy.route: "/*"
      caddy.route.0_sablier: ""
      caddy.route.0_sablier.group: whoami
      caddy.route.0_sablier.dynamic: "" # Serves a loading screen while waking
      caddy.route.1_reverse_proxy: "http://whoami:80"

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
