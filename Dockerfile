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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set up working directory
WORKDIR /app

# Clone and build WebTunnel
RUN git clone https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/webtunnel.git /app/webtunnel \
    && cd /app/webtunnel \
    && go build -o /app/webtunnel/client

# Create the simple HTML page showing the onion address
RUN mkdir -p /var/www/html
COPY index.html.template /var/www/html/index.html.template

# Configure Nginx with reverse proxy settings
COPY nginx.conf /etc/nginx/nginx.conf
COPY reverse-proxy.conf /etc/nginx/sites-available/reverse-proxy.conf
RUN ln -s /etc/nginx/sites-available/reverse-proxy.conf /etc/nginx/sites-enabled/ \
    && rm -f /etc/nginx/sites-enabled/default

# Configure Tor
COPY torrc /etc/tor/torrc

# Set up the startup script
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Set up supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose ports
EXPOSE 443

# Start services using supervisord
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
