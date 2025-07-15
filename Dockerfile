FROM ubuntu:latest

# Avoid interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Install minimal required packages
RUN apt-get update && apt-get install -y \
    curl \
    git \
    golang \
    nginx \
    tor \
    jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set up working directory
WORKDIR /opt

# Clone and build WebTunnel
RUN git clone https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/webtunnel.git \
    && cd webtunnel \
    && go build -o /usr/local/bin/webtunnel-client ./main

# Create directory for Tor hidden service
RUN mkdir -p /var/lib/tor/hidden_service/ \
    && chown -R debian-tor:debian-tor /var/lib/tor/hidden_service/ \
    && chmod 700 /var/lib/tor/hidden_service/

# Set up Nginx configuration for reverse proxy with header spoofing
RUN rm /etc/nginx/sites-enabled/default
COPY nginx.conf /etc/nginx/sites-enabled/proxy.conf

# Set up Tor configuration
COPY torrc /etc/tor/torrc

# Create simple HTML page
COPY index.html /var/www/html/index.html

# Create startup script
COPY start.sh /opt/start.sh
RUN chmod +x /opt/start.sh

# Expose port 443
EXPOSE 443

# Set environment variables for bridges (will be overridden at runtime)
ENV TOR_BRIDGE1=""
ENV TOR_BRIDGE2=""
ENV DISCORD_WEBHOOK_URL=""

# Start services
CMD ["/opt/start.sh"]
