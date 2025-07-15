#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Starting setup script..."

# Generate a self-signed SSL certificate for Nginx to serve the public 443 page.
# This certificate is for the container's internal Nginx, not for the hidden service.
echo "Generating self-signed SSL certificate for Nginx..."
mkdir -p /etc/nginx/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/certs/nginx.key \
    -out /etc/nginx/certs/nginx.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" > /dev/null 2>&1
echo "SSL certificate generated."

# Ensure Tor's hidden service directory has the correct permissions.
# This is crucial for Tor to start and create the hidden service.
echo "Setting permissions for Tor hidden service directory..."
chown -R debian-tor:debian-tor /var/lib/tor/hidden_service
chmod 700 /var/lib/tor/hidden_service
echo "Permissions set."

# Start Tor in the background.
# Tor will read its configuration from /etc/tor/torrc and attempt to connect
# to the network via the specified WebTunnel bridges.
echo "Starting Tor..."
tor -f /etc/tor/torrc &
TOR_PID=$! # Store Tor's process ID
echo "Tor started with PID: $TOR_PID"

# Wait for the Tor Hidden Service to become active and extract its .onion address.
# Tor writes the hostname to /var/lib/tor/hidden_service/hostname once active.
echo "Waiting for Tor Hidden Service to become active..."
ONION_ADDRESS=""
# Loop for up to 90 seconds, checking for the hostname file.
for i in $(seq 1 90); do
    if [ -f /var/lib/tor/hidden_service/hostname ]; then
        ONION_ADDRESS=$(cat /var/lib/tor/hidden_service/hostname)
        echo "Tor Hidden Service is active. Onion address: $ONION_ADDRESS"
        break
    fi
    echo "Still waiting for onion address... ($i/90)"
    sleep 1
done

# If the onion address was not found after the timeout, exit with an error.
if [ -z "$ONION_ADDRESS" ]; then
    echo "Error: Tor Hidden Service did not become active in time. Check Tor logs for issues."
    exit 1
fi

# Update the public-facing keep-alive HTML page with the discovered onion address.
echo "Updating keep-alive HTML page with onion address..."
# Use sed to replace the placeholder text with the actual onion address.
# The temporary file approach avoids potential issues with in-place editing.
sed "s|<span id=\"onion-address\">Loading...</span>|<span id=\"onion-address\">$ONION_ADDRESS</span>|g" /var/www/html/index.html > /tmp/index.html && mv /tmp/index.html /var/www/html/index.html
echo "HTML page updated."

# Send the onion address to the Discord webhook if the URL is provided.
# This ensures the webhook is sent only once after the service is ready.
if [ -n "$DISCORD_WEBHOOK_URL" ]; then
    echo "Sending onion address to Discord webhook..."
    # Use curl to send a POST request with JSON payload.
    # -s: silent mode, -o /dev/null: discard output, -w "%{http_code}": print HTTP status code.
    WEBHOOK_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Content-Type: application/json" \
        -X POST \
        -d "{\"content\":\"New Tor Hidden Service URL: $ONION_ADDRESS\"}" \
        "$DISCORD_WEBHOOK_URL")

    if [ "$WEBHOOK_STATUS" -ge 200 ] && [ "$WEBHOOK_STATUS" -lt 300 ]; then
        echo "Discord webhook sent successfully (HTTP $WEBHOOK_STATUS)."
    else
        echo "Failed to send Discord webhook (HTTP $WEBHOOK_STATUS). Check webhook URL and Discord settings."
    fi
else
    echo "DISCORD_WEBHOOK_URL environment variable not set. Skipping Discord webhook."
fi

echo "Attempting to start Nginx..."

# Create Nginx log and run directories if they don't exist (minimal Ubuntu might not have them by default)
mkdir -p /var/log/nginx
mkdir -p /var/run/nginx

# Test Nginx configuration before starting
echo "Testing Nginx configuration..."
nginx -t
if [ $? -ne 0 ]; then
    echo "Error: Nginx configuration test failed. Check nginx.conf for syntax errors."
    exit 1
fi
echo "Nginx configuration test passed."

echo "Setup complete. Starting Nginx in foreground to keep container alive."
# Start Nginx in the foreground. This command will replace the current shell
# process, ensuring Nginx is the primary process of the Docker container.
# Nginx will listen on port 443 for the public keep-alive page and on 127.0.0.1:8080
# for traffic coming from the Tor hidden service.
exec nginx -g 'daemon off;'
