FROM ubuntu:latest

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set environment variables for bridges (to be provided at runtime)
ENV TOR_BRIDGE1=""
ENV TOR_BRIDGE2=""
ENV DISCORD_WEBHOOK_URL=""

# Install minimal required packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    tor \
    obfs4proxy \
    ca-certificates \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure Nginx
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

# Configure Tor
COPY torrc /etc/tor/torrc

# Create a simple HTML page
RUN mkdir -p /var/www/html
COPY index.html /var/www/html/index.html

# Create startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Expose ports
EXPOSE 443 80

# Start services
CMD ["/start.sh"]
