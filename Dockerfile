# Use Ubuntu as the base image
FROM ubuntu:latest

# Set non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

# Update package lists and install necessary packages
# curl for sending webhook, tor for hidden service, caddy for reverse proxy, sudo for user switching
# obfs4proxy is required for obfs4 bridges, jq for JSON processing in entrypoint.sh
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl tor caddy sudo obfs4proxy jq && \
    rm -rf /var/lib/apt/lists/*

# Create directory for Tor hidden service data and set permissions
RUN mkdir -p /var/lib/tor/hidden_service && \
    chown -R debian-tor:debian-tor /var/lib/tor/hidden_service && \
    chmod 700 /var/lib/tor/hidden_service

# Create directory for the HTML page
RUN mkdir -p /usr/share/caddy/html

# Copy Tor configuration
COPY torrc /etc/tor/torrc

# Copy Caddyfile configuration
COPY Caddyfile /etc/caddy/Caddyfile

# Copy the entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Make the entrypoint script executable
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose ports 80 (for internal Caddy, used by Tor) and 443 (for the public HTML page)
EXPOSE 80
EXPOSE 443

# Set the entrypoint for the container
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
