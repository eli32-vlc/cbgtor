FROM ubuntu:22.04

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

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
    mkdir -p /etc/nginx/ssl

# Generate SSL certificate for Nginx
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/nginx.key \
    -out /etc/nginx/ssl/nginx.crt \
    -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost"

# Create the simple HTML page template
COPY index.html.template /var/www/html/index.html.template

# Configure Nginx
COPY nginx.conf /etc/nginx/nginx.conf
COPY site.conf /etc/nginx/sites-available/default
# Using -f to force the symlink creation even if it already exists
RUN rm -f /etc/nginx/sites-enabled/default && ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Configure Tor
COPY torrc /etc/tor/torrc

# Set up the startup script
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Set up supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose ports
EXPOSE 80 443

# Start services using supervisord
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
