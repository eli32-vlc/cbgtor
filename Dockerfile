FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install minimal required packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    tor \
    curl \
    ca-certificates \
    git \
    golang-go \
    make \
    supervisor \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Create directory structure
RUN mkdir -p /var/lib/tor/hidden_service/ \
    && mkdir -p /opt/webtunnel \
    && mkdir -p /etc/webtunnel

# Set up WebTunnel bridges file
COPY bridges.txt /etc/webtunnel/bridges.txt

# Clone and build WebTunnel
WORKDIR /opt/webtunnel
RUN git clone https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/webtunnel.git . \
    && go build -o /usr/local/bin/webtunnel

# Configure Nginx
RUN rm -f /etc/nginx/sites-enabled/default
COPY nginx.conf /etc/nginx/sites-enabled/proxy.conf

# Configure Tor
COPY torrc /etc/tor/torrc

# Set up the simple HTML page
COPY index.html /var/www/html/index.html

# Startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Configure supervisord
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose ports
EXPOSE 443

# Set entrypoint
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
