# Custom Caddy Docker Proxy

This repository provides a custom build of the [Caddy](https://caddyserver.com/) web server, pre-configured with [caddy-docker-proxy](https://github.com/lucaslorentz/caddy-docker-proxy) and a selection of highly useful plugins. 

The image is built automatically and published to the GitHub Container Registry (GHCR).

## Features & Plugins

This custom image is built from `caddy:alpine` and includes the following plugins:

* **[Caddy Docker Proxy](https://github.com/lucaslorentz/caddy-docker-proxy/v2):** Automatically generates Caddyfile configurations based on Docker container labels.
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

The Cloudflare API token is passed via a [Docker secret](https://docs.docker.com/compose/how-tos/use-secrets/) and read directly from the mounted file using Caddy's `{file.*}` placeholder — the token never lands in the environment or in `docker inspect` output.

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
    networks:
      - caddy
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - caddy_data:/data
    secrets:
      - caddy_cloudflare_api_token
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
      # Token is read from the mounted secret file at request time
      caddy.tls.dns: cloudflare {file./run/secrets/caddy_cloudflare_api_token}

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

secrets:
  caddy_cloudflare_api_token:
    # Provide the token via a file on the host (recommended for Swarm/Compose)
    file: ./secrets/caddy_cloudflare_api_token
    # ...or source it from an existing external Docker secret:
    # external: true
```

### Reusing the secret across sites

If you maintain a base Caddyfile alongside the docker-proxy (e.g. mounted at `/etc/caddy/Caddyfile`), you can wrap the DNS config in a snippet and import it per site. This keeps the secret path in one place:

```caddyfile
(cloudflare_tls) {
  tls {
    dns cloudflare {file./run/secrets/caddy_cloudflare_api_token}
  }
}
```

Then from container labels:

```yaml
labels:
  caddy: whoami.yourdomain.com
  caddy.import: cloudflare_tls
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
