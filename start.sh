#!/bin/bash

# Generate SSL certificate for Nginx
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/nginx.key \
  -out /etc/nginx/ssl/nginx.crt \
  -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost"

# Wait for Tor to generate the hidden service
while [ ! -f /var/lib/tor/hidden_service/hostname ]; do
  echo "Waiting for Tor hidden service to be created..."
  sleep 5
done

# Get the onion address
ONION_ADDR=$(cat /var/lib/tor/hidden_service/hostname)
echo "Onion address: $ONION_ADDR"

# Create the HTML page with the onion address
cat /var/www/html/index.html.template | sed "s|ONION_ADDRESS|$ONION_ADDR|g" > /var/www/html/index.html

# Send Discord webhook (only once)
if [ -n "$DISCORD_WEBHOOK_URL" ] && [ ! -f "/tmp/webhook_sent" ]; then
  curl -H "Content-Type: application/json" -X POST -d "{\"content\":\"Tor Hidden Service is now available at: $ONION_ADDR\"}" $DISCORD_WEBHOOK_URL
  touch /tmp/webhook_sent
  echo "Discord notification sent"
fi
