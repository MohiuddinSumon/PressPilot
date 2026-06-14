#!/usr/bin/env bash
# PressPilot — Fresh Ubuntu 24.04 ARM64 server bootstrap
# Run as: bash setup-server.sh
# Tested on Oracle VM.Standard.A1.Flex (Ubuntu 24.04 aarch64)

set -euo pipefail

REPO_URL="https://github.com/YOUR_USERNAME/presspilot.git"  # update before running
INSTALL_DIR="/opt/presspilot"

echo "=== PressPilot Server Bootstrap ==="
echo "Running on: $(uname -m) / $(lsb_release -ds 2>/dev/null || echo 'Ubuntu')"
echo ""

# ---------------------------------------------------------------------------
# 1. System update
# ---------------------------------------------------------------------------
echo "[1/7] Updating system packages..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq
sudo apt-get install -y -qq curl git ufw iptables-persistent netfilter-persistent

# ---------------------------------------------------------------------------
# 2. Docker (official method — NOT snap)
# ---------------------------------------------------------------------------
echo "[2/7] Installing Docker..."
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sudo bash
    sudo usermod -aG docker "$USER"
    echo "  → Docker installed. NOTE: You may need to log out and back in for group to apply."
else
    echo "  → Docker already installed, skipping."
fi

# Docker Compose v2 (included with modern Docker, verify)
docker compose version &>/dev/null && echo "  → Docker Compose v2 available." || {
    echo "  → Installing Docker Compose plugin..."
    sudo apt-get install -y docker-compose-plugin
}

# ---------------------------------------------------------------------------
# 3. Firewall — Oracle Ubuntu images come with restrictive iptables
# ---------------------------------------------------------------------------
echo "[3/7] Configuring firewall (iptables for Oracle Cloud)..."

# Allow SSH (port 22) — should already be open, but be safe
sudo iptables -I INPUT 1 -p tcp --dport 22 -j ACCEPT 2>/dev/null || true

# Allow HTTP and HTTPS
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT

# Persist rules across reboots
sudo netfilter-persistent save
echo "  → Firewall rules saved."

# ---------------------------------------------------------------------------
# 4. Clone repo
# ---------------------------------------------------------------------------
echo "[4/7] Cloning PressPilot repository..."
if [ -d "$INSTALL_DIR" ]; then
    echo "  → $INSTALL_DIR already exists, pulling latest..."
    cd "$INSTALL_DIR" && git pull
else
    sudo git clone "$REPO_URL" "$INSTALL_DIR"
    sudo chown -R "$USER:$USER" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# ---------------------------------------------------------------------------
# 5. Environment setup
# ---------------------------------------------------------------------------
echo "[5/7] Setting up environment..."
cd "$INSTALL_DIR"
if [ ! -f .env ]; then
    cp .env.example .env
    echo "  → .env created from .env.example"
    echo "  !! IMPORTANT: Edit $INSTALL_DIR/.env before running docker compose up"
    echo "     Fill in: MYSQL passwords, Ghost API keys, LLM provider keys, Telegram tokens"
else
    echo "  → .env already exists, not overwriting."
fi

# Generate N8N_ENCRYPTION_KEY if missing
if grep -q "^N8N_ENCRYPTION_KEY=$" .env; then
    ENCRYPTION_KEY=$(openssl rand -hex 32)
    sed -i "s|^N8N_ENCRYPTION_KEY=.*|N8N_ENCRYPTION_KEY=${ENCRYPTION_KEY}|" .env
    echo "  → Generated N8N_ENCRYPTION_KEY"
fi

# ---------------------------------------------------------------------------
# 6. Build provider-layer
# ---------------------------------------------------------------------------
echo "[6/7] Building provider-layer image..."
cd "$INSTALL_DIR"
docker compose build provider-layer

# ---------------------------------------------------------------------------
# 7. Start stack
# ---------------------------------------------------------------------------
echo "[7/7] Starting PressPilot stack..."
docker compose up -d mysql caddy ghost-mostlyprompt n8n provider-layer

echo ""
echo "=== Bootstrap complete! ==="
echo ""
echo "Next steps:"
echo "  1. Edit /opt/presspilot/.env with your actual credentials"
echo "  2. Restart the stack: docker compose -f $INSTALL_DIR/docker-compose.yml up -d"
echo "  3. Visit https://mostlyprompt.com/ghost to complete Ghost setup"
echo "  4. Visit https://n8n.mostlyprompt.com to set up n8n workflows"
echo "  5. Import n8n workflows from $INSTALL_DIR/n8n-workflows/"
echo ""
echo "Logs: docker compose -C $INSTALL_DIR logs -f"
