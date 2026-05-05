#!/bin/bash
set -e

# Configuration
TOR_HOSTNAME_FILE="/var/lib/tor_data/hidden_service/hostname"
HTML_TEMPLATE="/var/www/html/index.html.template"
HTML_OUTPUT="/var/www/html/index.html"
MAX_WAIT_TIME=120
START_TIME=$(date +%s)

echo "=== Service Startup ==="
echo "Target URL: ${TARGET_URL:-not set}"
echo "Discord webhook: ${DISCORD_WEBHOOK_URL:+configured}"

# Substitute TARGET_URL in nginx configs
if [ -n "$TARGET_URL" ]; then
    echo "Substituting TARGET_URL in nginx configs..."
    for conf in /etc/nginx/sites-available/default /etc/nginx/sites-available/tor-site; do
        if [ -f "$conf" ]; then
            sed -i "s|__TARGET_URL__|${TARGET_URL}|g" "$conf"
            echo "  Updated: $conf"
        fi
    done
else
    echo "WARNING: TARGET_URL not set, using defaults in configs"
fi

# Validate bridge files exist
if [ -f "/app/bridges.txt" ]; then
    BRIDGE_COUNT=$(wc -l < /app/bridges.txt)
    echo "Loaded $BRIDGE_COUNT bridge(s) from bridges.txt"
else
    echo "WARNING: bridges.txt not found"
fi

# Wait for Tor to generate the hidden service
echo "Waiting for Tor hidden service hostname..."
while [ ! -f "$TOR_HOSTNAME_FILE" ]; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    if [ "$ELAPSED" -gt "$MAX_WAIT_TIME" ]; then
        echo "WARNING: Timed out after ${MAX_WAIT_TIME}s waiting for Tor hidden service"
        echo "Checking Tor process..."
        ps aux | grep -v grep | grep tor || echo "  Tor process not found!"

        # Check if torrc has issues
        if [ -f "/var/log/tor/notices.log" ]; then
            echo "Recent Tor notices:"
            tail -20 /var/log/tor/notices.log 2>/dev/null || true
        fi

        echo "Continuing with fallback..."
        break
    fi

    echo "  Waiting... (${ELAPSED}s/${MAX_WAIT_TIME}s)"
    sleep 5
done

# Generate HTML page
if [ -f "$TOR_HOSTNAME_FILE" ]; then
    ONION_ADDR=$(cat "$TOR_HOSTNAME_FILE" | tr -d '[:space:]')
    echo "Onion address: $ONION_ADDR"

    # Create the HTML page with the onion address
    sed "s|ONION_ADDRESS|${ONION_ADDR}|g; s|TARGET_URL_PLACEHOLDER|${TARGET_URL:-N/A}|g" "$HTML_TEMPLATE" > "$HTML_OUTPUT"

    # Send Discord webhook (only once per container lifecycle)
    if [ -n "$DISCORD_WEBHOOK_URL" ] && [ ! -f "/tmp/webhook_sent" ]; then
        PAYLOAD=$(cat <<PAYEOF
{
    "content": "Tor Hidden Service Online",
    "embeds": [{
        "title": "Service Status",
        "fields": [
            {"name": "Onion Address", "value": "\`${ONION_ADDR}\`", "inline": false},
            {"name": "Target URL", "value": "${TARGET_URL:-N/A}", "inline": true},
            {"name": "Startup Time", "value": "${ELAPSED:-0}s", "inline": true}
        ],
        "color": 3066993,
        "timestamp": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"
    }]
}
PAYEOF
)
        curl -s -H "Content-Type: application/json" -X POST -d "$PAYLOAD" "$DISCORD_WEBHOOK_URL" && \
            touch /tmp/webhook_sent && \
            echo "Discord notification sent" || \
            echo "Failed to send Discord notification"
    fi
else
    echo "Failed to get onion address. Creating fallback page."
    sed "s|ONION_ADDRESS|Service initializing...|g; s|TARGET_URL_PLACEHOLDER|${TARGET_URL:-N/A}|g" "$HTML_TEMPLATE" > "$HTML_OUTPUT"
fi

echo "=== Startup Complete ==="
