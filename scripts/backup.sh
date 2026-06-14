#!/usr/bin/env bash
# PressPilot — Backup script
# Dumps all MySQL databases + Ghost content volumes → Oracle Object Storage
# Set up as daily cron: 0 3 * * * /opt/presspilot/scripts/backup.sh >> /var/log/presspilot-backup.log 2>&1

set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/presspilot}"
BACKUP_DIR="/tmp/presspilot-backup-$(date +%Y%m%d-%H%M%S)"
RETENTION_DAYS=30

source "$INSTALL_DIR/.env"

echo "[$(date)] Starting PressPilot backup..."
mkdir -p "$BACKUP_DIR"

# ---------------------------------------------------------------------------
# 1. MySQL dump
# ---------------------------------------------------------------------------
echo "[$(date)] Dumping MySQL databases..."
for DB in ghost_mostlyprompt ghost_fellowcoder ghost_aimovi; do
    docker compose -f "$INSTALL_DIR/docker-compose.yml" exec -T mysql \
        mysqldump -u root -p"${MYSQL_ROOT_PASSWORD}" \
        --single-transaction --routines --triggers \
        "$DB" 2>/dev/null \
        | gzip > "$BACKUP_DIR/${DB}.sql.gz" \
        && echo "  → $DB dumped" \
        || echo "  → $DB: skipped (may not exist yet)"
done

# ---------------------------------------------------------------------------
# 2. Ghost content volumes
# ---------------------------------------------------------------------------
echo "[$(date)] Backing up Ghost content..."
for SITE in mostlyprompt fellowcoder aimovi; do
    VOLUME="presspilot_ghost_${SITE}_content"
    if docker volume inspect "$VOLUME" &>/dev/null; then
        docker run --rm \
            -v "${VOLUME}:/data:ro" \
            -v "${BACKUP_DIR}:/backup" \
            alpine tar czf "/backup/ghost_${SITE}_content.tar.gz" -C /data . \
            && echo "  → $SITE content backed up"
    fi
done

# ---------------------------------------------------------------------------
# 3. n8n data
# ---------------------------------------------------------------------------
echo "[$(date)] Backing up n8n data..."
docker run --rm \
    -v presspilot_n8n_data:/data:ro \
    -v "${BACKUP_DIR}:/backup" \
    alpine tar czf /backup/n8n_data.tar.gz -C /data . 2>/dev/null \
    && echo "  → n8n data backed up" \
    || echo "  → n8n data: skipped"

# ---------------------------------------------------------------------------
# 4. Config files
# ---------------------------------------------------------------------------
echo "[$(date)] Backing up config files..."
tar czf "$BACKUP_DIR/config.tar.gz" \
    -C "$INSTALL_DIR" \
    --exclude='.git' \
    --exclude='node_modules' \
    Caddyfile docker-compose.yml scripts/ n8n-workflows/ provider-layer/ \
    && echo "  → Config files backed up"

# ---------------------------------------------------------------------------
# 5. Upload to Oracle Object Storage (using s3-compatible API)
# ---------------------------------------------------------------------------
if [[ -n "${OCI_ACCESS_KEY:-}" && -n "${OCI_SECRET_KEY:-}" ]]; then
    echo "[$(date)] Uploading to Oracle Object Storage..."

    # Install AWS CLI (s3-compatible) if not present
    if ! command -v aws &>/dev/null; then
        pip3 install awscli -q
    fi

    ENDPOINT="https://${OCI_NAMESPACE}.compat.objectstorage.${OCI_REGION}.oraclecloud.com"
    ARCHIVE_NAME="backup-$(date +%Y%m%d-%H%M%S).tar.gz"

    # Bundle everything
    tar czf "/tmp/$ARCHIVE_NAME" -C "$BACKUP_DIR" .

    AWS_ACCESS_KEY_ID="${OCI_ACCESS_KEY}" \
    AWS_SECRET_ACCESS_KEY="${OCI_SECRET_KEY}" \
    aws s3 cp "/tmp/$ARCHIVE_NAME" \
        "s3://${OCI_BUCKET_NAME}/$ARCHIVE_NAME" \
        --endpoint-url "$ENDPOINT" \
        --region "${OCI_REGION}" \
        && echo "  → Uploaded to s3://${OCI_BUCKET_NAME}/$ARCHIVE_NAME"

    rm -f "/tmp/$ARCHIVE_NAME"
else
    echo "[$(date)] OCI credentials not set — backup saved locally at $BACKUP_DIR (not uploaded)"
fi

# ---------------------------------------------------------------------------
# 6. Cleanup old local backups
# ---------------------------------------------------------------------------
find /tmp -maxdepth 1 -name "presspilot-backup-*" -mtime +"$RETENTION_DAYS" -exec rm -rf {} + 2>/dev/null || true

echo "[$(date)] Backup complete."
