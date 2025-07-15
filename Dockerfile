# Use Ubuntu as the base image
FROM ubuntu:latest

# Set non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

# Update package lists and install necessary packages
# curl for sending webhook, tor for hidden service, caddy for reverse proxy, sudo for user switching
# obfs4proxy is included (if needed), jq for JSON, ca-certificates for SSL
# golang and git are required to build webtunnel from source
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl tor caddy sudo obfs4proxy jq ca-certificates golang git && \
    rm -rf /var/lib/apt/lists/*

# Create directory for Tor hidden service data and set permissions
RUN mkdir -p /var/lib/tor/hidden_service && \
    chown -R debian-tor:debian-tor /var/lib/tor/hidden_service && \
    chmod 700 /var/lib/tor/hidden_service

# --- Build WebTunnel Client from Source ---
# Create a temporary directory for building
RUN mkdir -p /tmp/build_webtunnel
WORKDIR /tmp/build_webtunnel

# Clone the webtunnel repository
RUN git clone https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/webtunnel.git .

# Navigate to the client directory and build the client executable
# The output binary will be named 'client' by default
RUN cd main/client && go build -o webtunnel-client

# Copy the compiled client to a standard binary path
RUN cp main/client/webtunnel-client /usr/local/bin/webtunnel-client

# Clean up build artifacts
WORKDIR /
RUN rm -rf /tmp/build_webtunnel

# --- End WebTunnel Build ---

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
