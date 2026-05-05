# cbgtor - Tor Hidden Service with Reverse Proxy

A Docker-based Tor hidden service setup with nginx reverse proxy, WebTunnel bridges for censorship circumvention, and stealth/security hardening.

## Features

- **Tor Hidden Service** - Automatically generates `.onion` address on startup
- **Reverse Proxy** - Proxy target website through Tor or direct HTTP/HTTPS
- **WebTunnel Bridges** - Built-in pluggable transport for censorship circumvention
- **Stealth Mode** - Server identity hidden, fingerprinting minimized
- **Rate Limiting** - Protection against abuse (10r/s general, 30r/s proxy)
- **Discord Notifications** - Webhook alerts when service comes online
- **Health Checks** - Docker HEALTHCHECK and `/health` endpoint
- **Auto-Recovery** - Supervisor manages process restarts

## Quick Start

### Build and Run

```bash
# Default build
docker build -t cbgtor .
docker run -d -p 80:80 -p 443:443 cbgtor

# With custom target URL
docker build -t cbgtor --build-arg TARGET_URL=https://your-target.com .
docker run -d -p 80:80 -p 443:443 \
  -e TARGET_URL=https://your-target.com \
  -e DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/... \
  cbgtor
```

### Docker Compose

```yaml
services:
  cbgtor:
    build: .
    ports:
      - "80:80"
      - "443:443"
    environment:
      - TARGET_URL=https://your-target.com
      - DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/your-webhook
    restart: unless-stopped
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TARGET_URL` | Backend URL to proxy | `https://2305878273.7844380499.cfd` |
| `DISCORD_WEBHOOK_URL` | Discord webhook for notifications | (none) |

### Build Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `TARGET_URL` | Backend URL baked into image | `https://2305878273.7844380499.cfd` |

### Adding Bridges

Edit `torrc` and add more bridges:

```
Bridge webtunnel [ipv6]:port fingerprint url=https://... ver=0.0.1
```

Then rebuild the image.

## Architecture

```
Client -> nginx (80/443) -> Tor Hidden Service -> nginx (8080) -> Target URL
```

- **Public ports** (80/443): Serve status page and `/proxy/` endpoint
- **Tor access**: All traffic proxied to target via hidden service on port 8080
- **WebTunnel**: Pluggable transport bypasses censorship

## File Structure

```
├── Dockerfile              # Container build
├── nginx.conf              # Main nginx config (rate limiting, SSL)
├── nginx-headers.conf      # Security headers
├── nginx-proxy.conf        # Proxy stealth settings
├── site.conf               # Public-facing nginx server block
├── tor-site.conf           # Tor-only nginx server block
├── torrc                   # Tor configuration with bridges
├── start.sh                # Startup script (hostname, webhook)
├── supervisord.conf        # Process management
├── index.html.template     # Status page template
├── bridges.txt             # Bridge reference
└── webtunnel_bridges.txt   # WebTunnel bridge reference
```

## Endpoints

| Path | Description |
|------|-------------|
| `/` | Status page with onion address |
| `/health` | Health check (returns `OK`) |
| `/proxy/` | Reverse proxy to target URL |

## Security Features

- Server version hidden (`server_tokens off`)
- Identifying headers stripped (`X-Powered-By`, `Server`, etc.)
- Client IP not forwarded to upstream
- Strong TLS ciphers only (ECDHE)
- Rate limiting and connection limits
- Tor statistics disabled
- Client-only mode (no relay)
