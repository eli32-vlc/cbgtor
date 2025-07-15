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

# Create directory structure with correct permissions
RUN mkdir -p /var/lib/tor && \
    mkdir -p /etc/webtunnel
    # DO NOT create hidden_service directory here - let Tor create it with correct permissions

# Set up WebTunnel bridges file
COPY bridges.txt /etc/webtunnel/bridges.txt

# Clone and build WebTunnel
WORKDIR /opt/webtunnel
RUN git clone https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/webtunnel.git . \
    && go build -o /usr/local/bin/webtunnel

# Configure Nginx - we'll use a template first and generate the actual config during startup
COPY nginx.conf.template /etc/nginx/nginx.conf.template
RUN rm -f /etc/nginx/sites-enabled/default

# Configure Tor
COPY torrc /etc/tor/torrc

# Set up the simple HTML page
COPY index.html /var/www/html/index.html

# Create SSL certificates and ensure proper startup sequence
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Configure supervisord
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose ports
EXPOSE 443 80

# Start supervisord
ENTRYPOINT ["/start.sh"]
