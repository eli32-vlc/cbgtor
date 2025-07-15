# Stage 1: Build WebTunnel client
FROM ubuntu:latest AS build
ARG DEBIAN_FRONTEND=noninteractive

# Install build dependencies for Go and Git
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    build-essential \
    golang-go \
    ca-certificates \
    && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# Clone the WebTunnel repository and build the client binary
WORKDIR /app/webtunnel
RUN git clone https://gitlab.torproject.org/tpo/anti-censorship/webtunnel.git .
RUN go mod tidy
# Build the client binary and place it in /usr/local/bin
RUN go build -o /usr/local/bin/client ./webtunnel.go

# Stage 2: Final image
FROM ubuntu:latest
ARG DEBIAN_FRONTEND=noninteractive

# Copy the built webtunnel client from the build stage
COPY --from=build /usr/local/bin/client /usr/local/bin/client

# Install runtime dependencies: Nginx, Tor, Curl, OpenSSL (for certs)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    nginx \
    tor \
    curl \
    openssl \
    && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# Create Tor user and directory with correct permissions
# The 'tor' package on Ubuntu typically creates a 'debian-tor' user/group.
# Ensure the hidden service directory exists and has correct permissions.
RUN groupadd -r debian-tor || true && useradd -r -g debian-tor -s /bin/false debian-tor || true && \
    mkdir -p /var/lib/tor/hidden_service && \
    chown -R debian-tor:debian-tor /var/lib/tor/hidden_service && \
    chmod 700 /var/lib/tor/hidden_service

# Copy configuration files and scripts into the image
COPY nginx.conf /etc/nginx/nginx.conf
COPY torrc /etc/tor/torrc
COPY start.sh /start.sh
COPY keep_alive.html /var/www/html/index.html
COPY webtunnel_bridges.txt /etc/tor/webtunnel_bridges.txt

# Make the start script executable
RUN chmod +x /start.sh

# Expose port 443 for the public keep-alive page
EXPOSE 443

# Set the entrypoint to the start script
CMD ["/bin/bash", "/start.sh"]
