#!/usr/bin/env bash
# PressPilot — Add a new Ghost domain
# Usage: bash add-domain.sh <domain> <service-name>
# Example: bash add-domain.sh mpmohi.com ghost-mpmohi
#
# This script automates steps 2-6 of docs/add-new-domain.md.
# You still need to: update DNS in Cloudflare, complete Ghost wizard, add API key.

set -euo pipefail

DOMAIN="${1:-}"
SERVICE="${2:-}"
INSTALL_DIR="${INSTALL_DIR:-/opt/presspilot}"

if [[ -z "$DOMAIN" || -z "$SERVICE" ]]; then
    echo "Usage: bash add-domain.sh <domain> <service-name>"
    echo "Example: bash add-domain.sh mpmohi.com ghost-mpmohi"
    exit 1
fi

DB_NAME="ghost_$(echo "$SERVICE" | tr '-' '_' | sed 's/ghost_//')"
echo "=== Adding domain: $DOMAIN (service: $SERVICE, db: $DB_NAME) ==="

# ---------------------------------------------------------------------------
# 1. Add Caddyfile entry
# ---------------------------------------------------------------------------
CADDY_BLOCK="
# $DOMAIN
$DOMAIN, www.$DOMAIN {
    reverse_proxy $SERVICE:2368
}"

if grep -q "$DOMAIN" "$INSTALL_DIR/Caddyfile"; then
    echo "[Caddy] Entry for $DOMAIN already exists, skipping."
else
    echo "$CADDY_BLOCK" >> "$INSTALL_DIR/Caddyfile"
    echo "[Caddy] Added entry for $DOMAIN"
fi

# ---------------------------------------------------------------------------
# 2. Add docker-compose service block
# ---------------------------------------------------------------------------
COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"

if grep -q "$SERVICE:" "$COMPOSE_FILE"; then
    echo "[Docker] Service $SERVICE already exists in docker-compose.yml, skipping."
else
    # Read current .env to get shared mail config
    source "$INSTALL_DIR/.env" 2>/dev/null || true

    cat >> "$COMPOSE_FILE" << EOF

  # Auto-added by add-domain.sh on $(date +%Y-%m-%d)
  $SERVICE:
    image: ghost:5-alpine
    restart: unless-stopped
    networks:
      - presspilot
    depends_on:
      mysql:
        condition: service_healthy
    environment:
      url: https://$DOMAIN
      database__client: mysql
      database__connection__host: mysql
      database__connection__port: 3306
      database__connection__user: \${MYSQL_USER}
      database__connection__password: \${MYSQL_PASSWORD}
      database__connection__database: $DB_NAME
      mail__transport: \${GHOST_MAIL_TRANSPORT:-SMTP}
      mail__options__host: \${GHOST_MAIL_HOST:-smtp.mailgun.org}
      mail__options__port: \${GHOST_MAIL_PORT:-587}
      mail__options__auth__user: \${GHOST_MAIL_USER:-}
      mail__options__auth__pass: \${GHOST_MAIL_PASSWORD:-}
      mail__from: noreply@$DOMAIN
      NODE_ENV: production
    volumes:
      - ${SERVICE}_content:/var/lib/ghost/content
EOF

    # Add volume declaration
    sed -i "/^volumes:/a\\  ${SERVICE}_content:" "$COMPOSE_FILE"
    echo "[Docker] Added service $SERVICE to docker-compose.yml"
fi

# ---------------------------------------------------------------------------
# 3. Create MySQL database
# ---------------------------------------------------------------------------
echo "[MySQL] Creating database $DB_NAME..."
source "$INSTALL_DIR/.env"
docker compose -f "$COMPOSE_FILE" exec mysql \
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" \
    -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; GRANT ALL PRIVILEGES ON $DB_NAME.* TO '${MYSQL_USER}'@'%'; FLUSH PRIVILEGES;" \
    && echo "[MySQL] Database $DB_NAME ready." \
    || echo "[MySQL] Warning: could not create database automatically. Create it manually."

# ---------------------------------------------------------------------------
# 4. Start the new Ghost container
# ---------------------------------------------------------------------------
echo "[Docker] Starting $SERVICE..."
docker compose -f "$COMPOSE_FILE" up -d "$SERVICE"

# ---------------------------------------------------------------------------
# 5. Reload Caddy
# ---------------------------------------------------------------------------
echo "[Caddy] Reloading configuration..."
docker compose -f "$COMPOSE_FILE" exec caddy caddy reload --config /etc/caddy/Caddyfile
echo "[Caddy] Reloaded."

echo ""
echo "=== Domain $DOMAIN added! ==="
echo ""
echo "Remaining manual steps:"
echo "  1. Cloudflare: Add A record → $DOMAIN → [ORACLE_VM_IP], proxied"
echo "  2. Wait for DNS propagation (~2 min with Cloudflare)"
echo "  3. Visit https://$DOMAIN/ghost to complete Ghost setup wizard"
echo "  4. Ghost Admin → Settings → Integrations → Add custom integration → copy Admin API Key"
echo "  5. Add to .env: GHOST_$(echo "$DOMAIN" | tr '.' '_' | tr '[:lower:]' '[:upper:]')_ADMIN_API_KEY=<key>"
echo "  6. Add keywords for $DOMAIN in your keyword store (Google Sheets / NocoDB)"
echo "  7. Update n8n workflow config to include $DOMAIN"
