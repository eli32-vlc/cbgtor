#!/bin/bash
set -e

echo "Starting setup..."

# Generate SSL certificate first
if [ ! -f /etc/ssl/certs/ssl-cert-snakeoil.pem ]; then
    echo "Generating self-signed SSL certificate..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout /etc/ssl/private/ssl-cert-snakeoil.key \
      -out /etc/ssl/certs/ssl-cert-snakeoil.pem \
      -subj "/CN=localhost"
fi

# Setup Nginx config from template
echo "Configuring Nginx..."
cp /etc/nginx/nginx.conf.template /etc/nginx/sites-enabled/proxy.conf

# Set proper permissions for Tor
echo "Setting up Tor directories with correct permissions..."
mkdir -p /var/lib/tor/hidden_service/
chown -R debian-tor:debian-tor /var/lib/tor/
chmod 700 /var/lib/tor/hidden_service/

# Show the bridges for debugging
echo "WebTunnel bridges configured:"
cat /etc/tor/torrc | grep "Bridge webtunnel"

# Start supervisord
echo "Starting services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
