#!/bin/bash

# Wait for Tor to generate the hidden service
while [ ! -f /var/lib/tor/hidden_service/hostname ]; do
  echo "Waiting for Tor hidden service to be ready..."
  sleep 5
done

# Get the onion address
ONION_ADDRESS=$(cat /var/lib/tor/hidden_service/hostname)

# Update the HTML file with the onion address
sed -i "s/Loading.../$ONION_ADDRESS/g" /var/www/html/index.html

# Send the onion address to the Discord webhook
if [ ! -z "$DISCORD_WEBHOOK_URL" ]; then
  echo "Sending onion address to Discord webhook..."
  curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"Tor Hidden Service is online: $ONION_ADDRESS\"}" $DISCORD_WEBHOOK_URL
else
  echo "DISCORD_WEBHOOK_URL not set, skipping webhook notification."
fi

# Create SSL certificate if needed
if [ ! -f /etc/ssl/certs/ssl-cert-snakeoil.pem ]; then
  echo "Generating self-signed SSL certificate..."
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/ssl-cert-snakeoil.key \
    -out /etc/ssl/certs/ssl-cert-snakeoil.pem \
    -subj "/CN=localhost"
fi

echo "Setup complete!"
exit 0
