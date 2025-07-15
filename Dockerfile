FROM ubuntu:latest

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg2 \
    apt-transport-https \
    ca-certificates \
    git \
    build-essential \
    golang \
    tor \
    nginx \
    supervisor \
    python3 \
    python3-pip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Discord webhook tool
RUN pip3 install discord-webhook

# Set up WebTunnel
WORKDIR /opt
RUN git clone https://gitlab.torproject.org/anti-censorship/pluggable-transports/webtunnel.git
WORKDIR /opt/webtunnel
RUN go build -o /usr/local/bin/webtunnel

# Set up Tor configuration directory
RUN mkdir -p /etc/tor/hidden_service

# Create the Tor configuration file
RUN echo "UseBridges 1" > /etc/tor/torrc && \
    echo "ClientTransportPlugin webtunnel exec /usr/local/bin/webtunnel" >> /etc/tor/torrc && \
    echo "SocksPort 9050" >> /etc/tor/torrc && \
    echo "Log notice stdout" >> /etc/tor/torrc && \
    echo "DataDirectory /var/lib/tor" >> /etc/tor/torrc && \
    echo "HiddenServiceDir /etc/tor/hidden_service/" >> /etc/tor/torrc && \
    echo "HiddenServicePort 80 127.0.0.1:8080" >> /etc/tor/torrc && \
    echo "# Bridge lines will be added at runtime" >> /etc/tor/torrc

# Set up Nginx configuration
RUN rm /etc/nginx/sites-enabled/default
COPY nginx.conf /etc/nginx/sites-available/proxy
RUN ln -s /etc/nginx/sites-available/proxy /etc/nginx/sites-enabled/

# Create script to update Tor configuration with bridges from environment variables
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Create the keep-alive HTML page template
COPY index.html.template /var/www/html/index.html.template

# Set up Supervisor configuration
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose port 443
EXPOSE 443

# Start services using Supervisor
CMD ["/start.sh"]
