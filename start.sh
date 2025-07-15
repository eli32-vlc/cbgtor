#!/bin/bash
set -e

# Create self-signed SSL certificate for Nginx
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/server.key \
    -out /etc/nginx/ssl/server.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=example.com"

# Update torrc with bridges from environment variables
if [ -n "$TOR_BRIDGE1" ]; then
    echo "Bridge $TOR_BRIDGE1" >> /etc/tor/torrc
fi

if [ -n "$TOR_BRIDGE2" ]; then
    echo "Bridge $TOR_BRIDGE2" >> /etc/tor/torrc
fi

# Start Nginx
service nginx start

# Start Tor
service tor start

# Wait for hidden service to be created
while [ ! -f /var/lib/tor/hidden_service/hostname ]; do
    echo "Waiting for Tor hidden service to be created..."
    sleep 5
done

# Get onion address
ONION_ADDRESS=$(cat /var/lib/tor/hidden_service/hostname)
echo "Onion address: $ONION_ADDRESS"

# Write onion address to file for the web page
echo "$ONION_ADDRESS" > /var/www/html/onion-address.txt

# Send onion address to Discord webhook if URL is provided
if [ -n "$DISCORD_WEBHOOK_URL" ]; then
    curl -H "Content-Type: application/json" \
         -d "{\"content\": \"Tor hidden service is now available at: $ONION_ADDRESS\"}" \
         "$DISCORD_WEBHOOK_URL"
fi

# Keep container running
tail -f /dev/null
