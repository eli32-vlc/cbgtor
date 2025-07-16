#!/bin/bash

# Wait for Tor to generate the hidden service
while [ ! -f /var/lib/tor_data/hidden_service/hostname ]; do
  echo "Waiting for Tor hidden service to be created..."
  sleep 5
  # If Tor has been waiting for more than 60 seconds, something is wrong
  if [ $SECONDS -gt 60 ]; then
    echo "Timed out waiting for Tor hidden service. Checking Tor status..."
    ps aux | grep tor
    cat /var/log/tor/log || echo "No tor log found"
    # Continue anyway after logging debug info
    break
  fi
done

# If hostname file exists, get the onion address
if [ -f /var/lib/tor_data/hidden_service/hostname ]; then
  ONION_ADDR=$(cat /var/lib/tor_data/hidden_service/hostname)
  echo "Onion address: $ONION_ADDR"

  # Create the HTML page with the onion address
  sed "s|ONION_ADDRESS|$ONION_ADDR|g" /var/www/html/index.html.template > /var/www/html/index.html

  # Send Discord webhook (only once)
  if [ -n "$DISCORD_WEBHOOK_URL" ] && [ ! -f "/tmp/webhook_sent" ]; then
    curl -H "Content-Type: application/json" -X POST -d "{\"content\":\"Tor Hidden Service is now available at: $ONION_ADDR\"}" $DISCORD_WEBHOOK_URL
    touch /tmp/webhook_sent
    echo "Discord notification sent"
  fi
else
  # Fallback if the hidden service wasn't created
  echo "Failed to get onion address. Creating fallback page."
  sed "s|ONION_ADDRESS|Service unavailable|g" /var/www/html/index.html.template > /var/www/html/index.html
fi
