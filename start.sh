#!/bin/bash

# Generate self-signed SSL certificate if it doesn't exist
if [ ! -f /etc/nginx/ssl/nginx.crt ]; then
    mkdir -p /etc/nginx/ssl
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt -subj "/CN=localhost"
fi

# Add the bridge to the Tor configuration
if [ -n "$TOR_BRIDGES" ]; then
    echo "Bridge $TOR_BRIDGES" >> /etc/tor/torrc
    echo "Added bridge to configuration"
fi

# Start Tor and wait for the hidden service to be ready
supervisorctl start tor

# Wait for the onion address to be created
while [ ! -f /etc/tor/hidden_service/hostname ]; do
    echo "Waiting for onion address..."
    sleep 5
done

# Get the onion address
ONION_ADDRESS=$(cat /etc/tor/hidden_service/hostname)
echo "Onion address: $ONION_ADDRESS"

# Create the index.html file from template
sed "s/ONION_ADDRESS/$ONION_ADDRESS/g" /var/www/html/index.html.template > /var/www/html/index.html

# Send the onion address to Discord webhook if the webhook URL is provided
if [ -n "$DISCORD_WEBHOOK_URL" ]; then
    # Using curl to send the Discord webhook
    curl -H "Content-Type: application/json" \
         -d "{\"content\":\"Tor Hidden Service is ready. Onion address: $ONION_ADDRESS\"}" \
         "$DISCORD_WEBHOOK_URL"
    echo "Sent onion address to Discord webhook using curl"
fi

# Start nginx
supervisorctl start nginx

# Keep the container running
supervisorctl start all
tail -f /var/log/supervisor/supervisord.log
