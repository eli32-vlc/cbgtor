FROM ubuntu:22.04

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Build arguments for configurable target
ARG TARGET_URL=https://2305878273.7844380499.cfd
ENV TARGET_URL=${TARGET_URL}

# Install minimal required packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    golang \
    nginx \
    tor \
    ca-certificates \
    curl \
    supervisor \
    openssl \
    jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set up working directory
WORKDIR /app

# Clone and build WebTunnel
RUN git clone https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/webtunnel.git /app/webtunnel \
    && cd /app/webtunnel \
    && go build -o /app/webtunnel/client

# Create directories with proper permissions
RUN mkdir -p /var/lib/tor_data && \
    chmod 700 /var/lib/tor_data && \
    mkdir -p /var/www/html && \
    mkdir -p /etc/nginx/ssl && \
    mkdir -p /var/log/nginx && \
    mkdir -p /var/log/tor && \
    mkdir -p /var/log/supervisor && \
    mkdir -p /etc/nginx/includes

# Generate SSL certificate for Nginx
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/nginx.key \
    -out /etc/nginx/ssl/nginx.crt \
    -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost"

# Create the simple HTML page template
COPY index.html.template /var/www/html/index.html.template

# Copy nginx include files for stealth/security
COPY nginx.conf /etc/nginx/nginx.conf
COPY nginx-headers.conf /etc/nginx/includes/headers.conf
COPY nginx-proxy.conf /etc/nginx/includes/proxy.conf
COPY site.conf /etc/nginx/sites-available/default
COPY tor-site.conf /etc/nginx/sites-available/tor-site
RUN rm -f /etc/nginx/sites-enabled/default && \
    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default && \
    ln -sf /etc/nginx/sites-available/tor-site /etc/nginx/sites-enabled/tor-site

# Configure Tor
COPY torrc /etc/tor/torrc

# Set up the startup script
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Set up supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://127.0.0.1:80/health || exit 1

# Start services using supervisord
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
