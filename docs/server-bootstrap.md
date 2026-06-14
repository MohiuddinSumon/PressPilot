# Server Bootstrap Guide

Everything you need to do after first SSH login to prepare the Oracle VM for PressPilot.

**Prerequisites:** You have completed [oracle-setup.md](oracle-setup.md) and can SSH into your VM.

---

## Overview

By the end of this guide, your server will have:

- Docker Engine and Docker Compose v2 installed
- Ports 80 and 443 open at the OS firewall level
- The PressPilot repository cloned
- The full stack running (`docker compose up -d`)

Estimated time: 20–30 minutes on a fresh server.

---

## 1. Update the System

The very first thing to do on any fresh Ubuntu server is update all packages to their latest versions.

```bash
sudo apt update && sudo apt upgrade -y
```

This may take 2–5 minutes. If prompted about restarting services, press **Enter** to accept the defaults (or type `y`).

After the upgrade finishes, reboot to apply any kernel updates:

```bash
sudo reboot
```

Wait about 30 seconds, then SSH back in:

```powershell
ssh presspilot
```

---

## 2. Install Docker Engine (Official Method)

> **Warning:** Do NOT install Docker via `snap` (`sudo snap install docker`). The snap version has known permission issues with volume mounts and runs as a confined process. Always use the official Docker repository.

### 2.1 Install Required Packages

```bash
sudo apt install -y ca-certificates curl gnupg lsb-release
```

### 2.2 Add Docker's Official GPG Key

```bash
sudo install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

### 2.3 Add Docker's Repository

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

> **Note:** The `$(dpkg --print-architecture)` part will automatically resolve to `arm64` on your Oracle VM. This ensures you get the correct ARM64 Docker packages.

### 2.4 Install Docker Engine and Compose Plugin

```bash
sudo apt update

sudo apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin
```

### 2.5 Verify the Installation

```bash
sudo docker run hello-world
```

You should see:

```
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

Check the installed version:

```bash
docker --version
docker compose version
```

Expected output (versions will be newer than these):

```
Docker version 27.x.x, build xxxxx
Docker Compose version v2.x.x
```

> **Note:** The command is `docker compose` (with a space), not `docker-compose` (with a hyphen). The v2 Compose plugin is built into the Docker CLI.

---

## 3. Add the `ubuntu` User to the Docker Group

By default, Docker requires `sudo` for every command. Adding your user to the `docker` group lets you run Docker commands without `sudo`.

```bash
sudo usermod -aG docker ubuntu
```

Apply the group change without logging out:

```bash
newgrp docker
```

Verify you can run Docker without sudo:

```bash
docker ps
```

You should see an empty table (no containers yet), not a permission error.

> **Note:** If you log out and back in via SSH, the group change will apply automatically. The `newgrp docker` command only applies it to your current terminal session.

---

## 4. Configure the OS Firewall (iptables)

Oracle's Ubuntu images ship with `iptables` rules that block all inbound traffic on ports 80 and 443 at the **operating system level**, separate from Oracle's VCN Security List. You must open these ports in both places.

### 4.1 Install iptables-persistent

This package saves your iptables rules across reboots so they are not lost when the server restarts:

```bash
sudo apt install -y iptables-persistent
```

During installation you will be asked:

```
Save current IPv4 rules? [yes/no]
Save current IPv6 rules? [yes/no]
```

Answer **yes** to both.

### 4.2 Open Ports 80 and 443

Insert rules to allow HTTP and HTTPS traffic:

```bash
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
```

> **Note:** The `-I INPUT 6` inserts the rule at position 6 in the INPUT chain. This places it after Oracle's required management rules (positions 1–5) but before the default REJECT/DROP rule at the bottom. Do not use `-A` (append) — it would add the rule after the DROP, making it ineffective.

### 4.3 Save the Rules Permanently

```bash
sudo netfilter-persistent save
```

You should see:

```
run-parts: executing /usr/share/netfilter-persistent/plugins.d/15-ip4tables save
run-parts: executing /usr/share/netfilter-persistent/plugins.d/25-ip6tables save
```

### 4.4 Verify the Rules

```bash
sudo iptables -L INPUT --line-numbers -n
```

Look for lines showing `ACCEPT` for `dpt:80` and `dpt:443`.

> **Warning:** If you skip this step, Caddy will start and obtain SSL certificates, but all browser traffic will be blocked by iptables before it ever reaches your containers. The site will appear completely unreachable.

---

## 5. Install Git

Git is likely already installed on Ubuntu 24.04, but verify:

```bash
git --version
```

If not installed:

```bash
sudo apt install -y git
```

---

## 6. Clone the PressPilot Repository

Navigate to a suitable directory and clone the repository:

```bash
cd /opt
sudo mkdir presspilot
sudo chown ubuntu:ubuntu presspilot
cd presspilot
git clone https://github.com/YOUR_USERNAME/presspilot.git .
```

Replace `YOUR_USERNAME` with your GitHub username. The `.` at the end clones into the current directory instead of creating a subfolder.

> **Note:** If your repository is private, you will need to authenticate. The recommended method is a GitHub Personal Access Token (PAT). Go to GitHub → Settings → Developer Settings → Personal access tokens → Generate new token. Use the token as your password when prompted.

Alternatively, use SSH-based cloning if you have added an SSH key to your GitHub account:

```bash
git clone git@github.com:YOUR_USERNAME/presspilot.git .
```

---

## 7. Configure Environment Variables

PressPilot uses a `.env` file to store secrets and configuration. Never commit this file to Git.

### 7.1 Copy the Example File

```bash
cp .env.example .env
```

### 7.2 Edit the File

```bash
nano .env
```

Fill in the required values. The `.env.example` file contains descriptions for each variable. Key values you need immediately:

```env
# Ghost database passwords — generate random strings
MYSQL_ROOT_PASSWORD=change_me_use_a_strong_random_password
MYSQL_PASSWORD=change_me_use_a_strong_random_password

# Ghost site URL — must match your domain exactly
GHOST_URL=https://mostlyprompt.com

# n8n configuration
N8N_HOST=n8n.yourdomain.com
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=change_me_strong_password

# LLM API keys — add whichever you have
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
```

Save with `Ctrl+O`, then `Enter`, then exit with `Ctrl+X`.

> **Warning:** Use strong, randomly generated passwords. You can generate them with:
> ```bash
> openssl rand -base64 32
> ```
> Run this once for each password you need.

---

## 8. Run the Setup Script

If the repository includes `scripts/setup-server.sh`, make it executable and run it:

```bash
chmod +x scripts/setup-server.sh
./scripts/setup-server.sh
```

This script automates any remaining server preparation steps (directory creation, permissions, etc.).

If the script does not exist yet or you prefer manual setup, the remaining steps are covered below.

---

## 9. Start the Stack

### 9.1 Pull Docker Images

Before starting, pull all required images. This can take a few minutes on first run as it downloads Ghost, MySQL, n8n, and Caddy:

```bash
docker compose pull
```

> **Note:** All images in PressPilot's `docker-compose.yml` are ARM64-compatible. If you ever add a new service, verify that the image has an `arm64` or `linux/arm64` manifest before adding it. You can check with:
> ```bash
> docker manifest inspect IMAGE_NAME | grep -i arm64
> ```

### 9.2 Start All Services

```bash
docker compose up -d
```

The `-d` flag runs containers in detached mode (in the background). You will see output like:

```
[+] Running 6/6
 ✔ Network presspilot_default   Created
 ✔ Container presspilot-mysql   Started
 ✔ Container presspilot-ghost1  Started
 ✔ Container presspilot-n8n     Started
 ✔ Container presspilot-caddy   Started
```

### 9.3 Verify Containers Are Running

```bash
docker compose ps
```

All services should show `running` status. If any show `exited`, check their logs (next section).

---

## 10. Checking Logs

### View All Logs (live stream)

```bash
docker compose logs -f
```

Press `Ctrl+C` to stop streaming.

### View Logs for a Specific Service

```bash
docker compose logs -f caddy
docker compose logs -f ghost1
docker compose logs -f n8n
docker compose logs -f mysql
```

### Common Log Messages to Watch For

**Caddy** — Look for lines like:

```
{"level":"info","msg":"certificate obtained successfully","identifier":"mostlyprompt.com"}
```

This means Caddy successfully obtained an SSL certificate from Let's Encrypt. If you see errors about ACME challenges failing, check that ports 80/443 are open (both VCN Security List and iptables).

**Ghost** — Look for:

```
Ghost boot 1.xxx seconds
Your admin interface is located at: https://mostlyprompt.com/ghost/
```

**MySQL** — If Ghost fails to start, check MySQL logs first. Ghost will crash if it cannot connect to the database.

---

## 11. Useful Docker Commands

Keep these handy for day-to-day management:

```bash
# Start the stack
docker compose up -d

# Stop the stack
docker compose down

# Restart a single service
docker compose restart ghost1

# Rebuild and restart after config changes
docker compose up -d --force-recreate

# Pull latest images and restart
docker compose pull && docker compose up -d

# View real-time resource usage
docker stats

# Enter a running container's shell
docker compose exec ghost1 bash
docker compose exec mysql bash

# Run a one-off command inside a container
docker compose exec mysql mysql -u root -p

# Remove stopped containers and unused images (free disk space)
docker system prune -f
```

---

## 12. Enable Docker to Start on Boot

Docker's systemd service should be enabled automatically, but verify:

```bash
sudo systemctl is-enabled docker
```

Should output `enabled`. If not:

```bash
sudo systemctl enable docker
```

To confirm the entire stack restarts automatically after a server reboot, all services in `docker-compose.yml` should have `restart: unless-stopped` (or `restart: always`). Check with:

```bash
grep restart docker-compose.yml
```

---

## 13. What's Next

With Docker running and the stack deployed:

- **[dns-cloudflare.md](dns-cloudflare.md)** — Point your domains to this server via Cloudflare so traffic reaches Caddy
- **ghost-instance.md** — Complete Ghost setup wizard and configure each site
- **n8n-setup.md** — Set up n8n credentials and import PressPilot workflows

---

## Troubleshooting

### "Permission denied" when running docker commands

You forgot to add your user to the docker group, or the group change has not taken effect:

```bash
sudo usermod -aG docker ubuntu
newgrp docker
```

### Container keeps restarting

Check its logs:

```bash
docker compose logs --tail=50 SERVICE_NAME
```

Common causes: wrong password in `.env`, database not ready yet (Ghost starts before MySQL is fully up — it will retry automatically, give it 30 seconds), missing environment variable.

### "Port is already allocated" error

Something else is listening on port 80 or 443. Check:

```bash
sudo ss -tlnp | grep -E ':80|:443'
```

If Apache or Nginx is installed, stop it:

```bash
sudo systemctl stop apache2
sudo systemctl disable apache2
```

### Caddy can't get SSL certificates

1. Verify DNS is pointing to your server's public IP (see dns-cloudflare.md)
2. Verify port 80 is open in both the VCN Security List (oracle-setup.md §5) and iptables (this guide §4)
3. Check Caddy logs: `docker compose logs -f caddy`
4. Let's Encrypt has rate limits — if you've requested certificates many times for the same domain, you may be rate-limited for up to 1 hour

### I see the site but it shows a certificate warning

Your Cloudflare SSL mode may be set to "Flexible". Set it to "Full (strict)" — see dns-cloudflare.md §4.
