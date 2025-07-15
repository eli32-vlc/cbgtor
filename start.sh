#!/bin/bash

# Generate self-signed SSL certificate for Nginx
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Configure Tor bridges from environment variables
echo "UseBridges 1" > /etc/tor/torrc
echo "ClientTransportPlugin obfs4 exec /usr/bin/obfs4proxy" >> /etc/tor/torrc

if [ -n "$TOR_BRIDGE1" ]; then
    echo "Bridge $TOR_BRIDGE1" >> /etc/tor/torrc
fi

if [ -n "$TOR_BRIDGE2" ]; then
    echo "Bridge $TOR_BRIDGE2" >> /etc/tor/torrc
fi

# Add hidden service configuration
cat >> /etc/tor/torrc << EOL
HiddenServiceDir /var/lib/tor/hidden_service/
HiddenServicePort 80 127.0.0.1:80
EOL

# Start Tor in background
tor &

# Wait for the hidden service to be created
while [ ! -f /var/lib/tor/hidden_service/hostname ]; do
    echo "Waiting for hidden service to be created..."
    sleep 5
done

# Get onion address
ONION_ADDRESS=$(cat /var/lib/tor/hidden_service/hostname)

# Save onion address to file for the HTML page
echo "$ONION_ADDRESS" > /var/www/html/onion-address.txt

# Send onion address to Discord webhook if URL is provided
if [ -n "$DISCORD_WEBHOOK_URL" ]; then
    curl -H "Content-Type: application/json" \
         -d "{\"content\":\"Tor Hidden Service is online. Onion address: $ONION_ADDRESS\"}" \
         $DISCORD_WEBHOOK_URL
fi

# Start Nginx in foreground
echo "Starting Nginx..."
nginx -g 'daemon off;'
