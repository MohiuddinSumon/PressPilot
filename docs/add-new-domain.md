# Adding a New Domain — The 15-Minute Runbook

This guide walks you through adding a new Ghost blog to PressPilot. The process takes about 15 minutes if you have your domain's DNS access and your Oracle VM's IP address ready.

**Prerequisites before starting:**
- PressPilot stack is already running (`docker compose up -d` succeeded)
- You have SSH access to the Oracle VM
- The new domain is registered and you have access to Cloudflare (or wherever DNS is managed)
- You know the Oracle VM's public IP address (find it in Oracle Cloud Console → Instances → your VM → Public IP)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Step 1 — DNS in Cloudflare (5 min)](#2-step-1--dns-in-cloudflare-5-min)
3. [Step 2 — Update Caddyfile (2 min)](#3-step-2--update-caddyfile-2-min)
4. [Step 3 — Add Ghost Service to docker-compose.yml (3 min)](#4-step-3--add-ghost-service-to-docker-composeyml-3-min)
5. [Step 4 — Create the MySQL Database (1 min)](#5-step-4--create-the-mysql-database-1-min)
6. [Step 5 — Start the New Ghost Container](#6-step-5--start-the-new-ghost-container)
7. [Step 6 — Reload Caddy](#7-step-6--reload-caddy)
8. [Step 7 — Complete Ghost Setup Wizard](#8-step-7--complete-ghost-setup-wizard)
9. [Step 8 — Create a Ghost API Integration Key](#9-step-8--create-a-ghost-api-integration-key)
10. [Step 9 — Add the New Domain to the Keyword Sheet](#10-step-9--add-the-new-domain-to-the-keyword-sheet)
11. [Step 10 — Update n8n Workflows](#11-step-10--update-n8n-workflows)
12. [Step 11 — Verify Everything Works](#12-step-11--verify-everything-works)
13. [Using the add-domain.sh Script (Automates Steps 2–6)](#13-using-the-add-domainsh-script-automates-steps-26)
14. [Troubleshooting](#14-troubleshooting)
15. [Checklist Summary](#15-checklist-summary)

---

## 1. Overview

Each Ghost blog in PressPilot is an isolated Docker container with:
- Its own Ghost container (e.g. `ghost-fellowcoder`)
- Its own MySQL database (e.g. `ghost_fellowcoder`) — shared MySQL server, separate database
- Its own Caddy reverse proxy entry
- Its own Ghost Admin API key (for n8n to post drafts)

Adding a new domain means repeating this pattern. The steps below use `newdomain.com` as the example — replace it everywhere with your actual domain name.

---

## 2. Step 1 — DNS in Cloudflare (5 min)

DNS propagation can take a few minutes to hours, so do this step **first** while you work on the rest.

1. Log in to [dash.cloudflare.com](https://dash.cloudflare.com).
2. Select your domain (or click **Add a Site** if this domain isn't in Cloudflare yet).
3. Go to **DNS → Records**.
4. Click **Add record** and fill in:

   | Type | Name | Content | Proxy status | TTL |
   |---|---|---|---|---|
   | A | `@` (or leave blank for root) | `YOUR_ORACLE_VM_IP` | Proxied (orange cloud) | Auto |
   | A | `www` | `YOUR_ORACLE_VM_IP` | Proxied (orange cloud) | Auto |

5. Click **Save**.

> **Note:** The "Proxied" (orange cloud) setting routes traffic through Cloudflare's CDN and hides your server's real IP. This is recommended — it gives you DDoS protection and caching for free.

> **Warning:** If you already have A records pointing elsewhere (e.g. old hosting), delete or replace them. Two A records pointing to different IPs will cause random failures.

**To find your Oracle VM's public IP:**
```
Oracle Cloud Console → Compute → Instances → [your VM name] → Instance information → Public IP address
```

---

## 3. Step 2 — Update Caddyfile (2 min)

The Caddyfile tells Caddy which domain to serve and where to forward requests.

1. SSH into your Oracle VM:
   ```bash
   ssh -i ~/.ssh/oracle_key ubuntu@YOUR_ORACLE_VM_IP
   ```

2. Navigate to the PressPilot project directory:
   ```bash
   cd ~/presspilot
   ```

3. Open the Caddyfile:
   ```bash
   nano Caddyfile
   ```

4. Add a new block at the bottom of the file. Use the pattern of existing entries:
   ```
   newdomain.com, www.newdomain.com {
       reverse_proxy ghost-newdomain:2368
   }
   ```

   A full example Caddyfile with multiple domains:
   ```
   mostlyprompt.com, www.mostlyprompt.com {
       reverse_proxy ghost-mostlyprompt:2368
   }

   fellowcoder.com, www.fellowcoder.com {
       reverse_proxy ghost-fellowcoder:2368
   }

   newdomain.com, www.newdomain.com {
       reverse_proxy ghost-newdomain:2368
   }

   n8n.yourdomain.com {
       reverse_proxy n8n:5678
   }
   ```

5. Save and close: `Ctrl+O`, `Enter`, `Ctrl+X`.

> **Note:** The container name in `reverse_proxy` (e.g. `ghost-newdomain`) must exactly match the `container_name` you will set in `docker-compose.yml` in the next step. Docker's internal DNS resolves container names automatically within the same Compose network.

---

## 4. Step 3 — Add Ghost Service to docker-compose.yml (3 min)

1. Open `docker-compose.yml`:
   ```bash
   nano docker-compose.yml
   ```

2. Find an existing Ghost service block (e.g. `ghost-mostlyprompt`). Copy it.

3. Paste the copied block and edit it for your new domain. Change every occurrence of the old domain's name to the new domain's name:

   ```yaml
   ghost-newdomain:
     image: ghost:5-alpine
     container_name: ghost-newdomain
     restart: unless-stopped
     environment:
       url: https://newdomain.com
       database__client: mysql
       database__connection__host: mysql
       database__connection__user: root
       database__connection__password: ${MYSQL_ROOT_PASSWORD}
       database__connection__database: ghost_newdomain
       mail__transport: SMTP
       mail__options__host: ${MAILGUN_SMTP_HOST}
       mail__options__port: 587
       mail__options__auth__user: ${MAILGUN_SMTP_USER}
       mail__options__auth__pass: ${MAILGUN_SMTP_PASS}
     volumes:
       - ghost-newdomain-content:/var/lib/ghost/content
     networks:
       - presspilot
     depends_on:
       - mysql
   ```

4. Add the volume to the `volumes:` section at the bottom of `docker-compose.yml`:
   ```yaml
   volumes:
     ghost-mostlyprompt-content:
     ghost-fellowcoder-content:
     ghost-newdomain-content:    # Add this line
     mysql-data:
   ```

5. Save and close.

**Key things to change per new domain:**

| Field | What to change |
|---|---|
| Service name (top-level key) | `ghost-newdomain` |
| `container_name` | `ghost-newdomain` |
| `url` | `https://newdomain.com` |
| `database__connection__database` | `ghost_newdomain` |
| Volume name | `ghost-newdomain-content` |

> **Warning:** Ghost is strict about the `url` environment variable. It must be the exact public URL including `https://` and no trailing slash. Ghost will refuse to serve correctly if this doesn't match the domain Caddy is proxying.

---

## 5. Step 4 — Create the MySQL Database (1 min)

Ghost cannot create its own database — you must create it in MySQL first.

Run this command on your Oracle VM:

```bash
docker exec -it presspilot-mysql-1 mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "CREATE DATABASE ghost_newdomain CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

Replace `ghost_newdomain` with your actual database name (must match what you put in `docker-compose.yml`).

To verify the database was created:

```bash
docker exec -it presspilot-mysql-1 mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SHOW DATABASES;"
```

You should see `ghost_newdomain` in the list.

> **Note:** The container name `presspilot-mysql-1` follows Docker Compose's default naming: `{project_name}-{service_name}-{replica_number}`. Your project name is the directory name where `docker-compose.yml` lives. If your directory is called `presspilot`, the MySQL container is `presspilot-mysql-1`. Run `docker ps` to confirm the exact name.

> **Note:** The `CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci` specification is important — Ghost requires full Unicode support (including emoji in posts). Omitting it may cause database errors when Ghost tries to write content.

---

## 6. Step 5 — Start the New Ghost Container

Bring up only the new Ghost service without restarting everything else:

```bash
docker compose up -d ghost-newdomain
```

Check that the container started:

```bash
docker ps | grep ghost-newdomain
```

You should see it listed as `Up` (not `Restarting` or `Exit`).

If it shows `Restarting`, check the logs:

```bash
docker compose logs ghost-newdomain --tail=50
```

Common errors at this stage:
- `Database connection failed` — database doesn't exist yet (go back to Step 4)
- `ECONNREFUSED` to MySQL — MySQL container isn't running (`docker compose up -d mysql`)
- `url must be set` — missing `url` environment variable in `docker-compose.yml`

---

## 7. Step 6 — Reload Caddy

Tell Caddy to pick up the new Caddyfile entry without downtime:

```bash
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

Caddy will:
1. Parse the updated Caddyfile
2. Request a Let's Encrypt SSL certificate for `newdomain.com`
3. Start proxying traffic to `ghost-newdomain:2368`

This usually takes 10–30 seconds. Let's Encrypt certificate issuance requires the domain to be reachable over HTTP — which is why you set DNS first.

To check Caddy's logs:

```bash
docker compose logs caddy --tail=30
```

A successful reload looks like:
```
{"level":"info","ts":"...","msg":"config loaded from file","file":"/etc/caddy/Caddyfile"}
```

A successful certificate looks like:
```
{"level":"info","ts":"...","logger":"tls","msg":"obtained certificate","identifier":"newdomain.com"}
```

> **Warning:** Let's Encrypt rate limits apply: 5 failed certificate attempts per domain per hour, and 50 certificates per registered domain per week. If certificate issuance keeps failing, wait an hour before retrying and fix the root cause (usually DNS not propagated yet, or port 80/443 blocked). Check Oracle's VCN Security List and Ubuntu `iptables` if ports are blocked.

---

## 8. Step 7 — Complete Ghost Setup Wizard

1. Open your browser and go to `https://newdomain.com/ghost`.
2. You should see the Ghost setup wizard.
3. Fill in:
   - **Site title**: Your blog's name
   - **Full name**: Your name
   - **Email address**: Your email (this becomes the admin account)
   - **Password**: A strong password — save it in your password manager
4. Click **Last step: Invite your team** — you can skip this and click **I'll do this later**.
5. You are now in the Ghost Admin dashboard.

> **Note:** If you see a "Cannot connect to server" or blank page instead of the setup wizard, Ghost may still be initializing. Wait 30–60 seconds and refresh. Ghost runs database migrations on first start, which takes a moment.

> **Warning:** The email address you enter during setup is your Ghost admin login. Make sure it's an email address you actually own and can receive mail at. Ghost sends admin notifications to this address.

---

## 9. Step 8 — Create a Ghost API Integration Key

n8n needs an Admin API key to create posts programmatically on this Ghost instance.

1. In Ghost Admin, go to **Settings** (gear icon, bottom left).
2. Click **Integrations**.
3. Scroll down to **Custom integrations** → click **Add custom integration**.
4. Name it `n8n-presspilot` and click **Create**.
5. You will see an **Admin API key** — it looks like:
   ```
   1234abcd5678efgh:90123456789abcdef0123456789abcdef0123456789abcdef0123456789ab
   ```
   (A hex string with a colon separating the ID and the secret key.)
6. Copy the entire key.

7. Add it to your `.env` file on the server:
   ```bash
   nano ~/presspilot/.env
   ```
   Add:
   ```env
   GHOST_NEWDOMAIN_ADMIN_API_KEY=1234abcd5678efgh:90123456789abcdef...
   GHOST_NEWDOMAIN_ADMIN_API_URL=https://newdomain.com
   ```
   Save and close.

> **Warning:** Ghost Admin API keys have full write access to your Ghost installation. Treat them like passwords. Never commit them to Git — they must only live in `.env` (which is in `.gitignore`).

---

## 10. Step 9 — Add the New Domain to the Keyword Sheet

Open your keyword store (Google Sheets or NocoDB) and add at least 5–10 seed keywords for the new domain:

```
domain          | keyword                              | status  | score | last_used | notes
newdomain.com   | [your first keyword here]            | pending |       |           |
newdomain.com   | [your second keyword here]           | pending |       |           |
newdomain.com   | [your third keyword here]            | pending |       |           |
```

The daily scoring workflow will pick these up on its next run.

See [keyword-sheet.md](keyword-sheet.md) for the full schema reference and tips on choosing good keywords.

---

## 11. Step 10 — Update n8n Workflows

The n8n workflows need to know about the new Ghost instance.

1. Open n8n at `https://n8n.yourdomain.com`.
2. Open the **Research & Draft** workflow.
3. Find the node that builds the Ghost API URL. It usually has a variable like `$env.GHOST_ADMIN_API_URL` or a list of domain-to-key mappings.
4. Add your new domain:
   ```javascript
   // Example: domain → API key mapping object
   const ghostInstances = {
     "mostlyprompt.com": {
       url: $env.GHOST_MOSTLYPROMPT_ADMIN_API_URL,
       key: $env.GHOST_MOSTLYPROMPT_ADMIN_API_KEY,
     },
     "newdomain.com": {
       url: $env.GHOST_NEWDOMAIN_ADMIN_API_URL,
       key: $env.GHOST_NEWDOMAIN_ADMIN_API_KEY,
     }
   };
   ```
5. Save and activate the workflow.

> **Note:** After editing `.env`, you may need to restart n8n for it to pick up the new environment variables:
> ```bash
> docker compose restart n8n
> ```

---

## 12. Step 11 — Verify Everything Works

Run through this checklist to confirm the new domain is fully operational:

**DNS and SSL:**
```bash
# Check DNS resolution (run from your local machine)
nslookup newdomain.com
# Should return your Oracle VM's IP (or Cloudflare's IP if proxied)

# Check SSL
curl -I https://newdomain.com
# Should return HTTP/2 200 (or 301 redirect to /ghost for a fresh install)
```

**Ghost is running:**
- Visit `https://newdomain.com` — should show the Ghost default theme
- Visit `https://newdomain.com/ghost` — should show the Ghost admin dashboard

**n8n can post to Ghost:**
1. In n8n, open the Research & Draft workflow.
2. Manually trigger it with `newdomain.com` as the target domain and a test keyword.
3. Check Ghost Admin → Posts — you should see a new draft appear.
4. Check Telegram — you should receive a notification with the draft link.

**Keyword sheet:**
- Confirm rows with `domain = newdomain.com` and `status = pending` exist.
- After a scoring workflow run, some rows should change to `selected`.

---

## 13. Using the add-domain.sh Script (Automates Steps 2–6)

The `scripts/add-domain.sh` script automates the repetitive parts of this process. Instead of manually editing files, run:

```bash
cd ~/presspilot
bash scripts/add-domain.sh newdomain.com
```

The script will:
1. Append the Caddyfile entry for `newdomain.com` → `ghost-newdomain:2368`
2. Append the Ghost service block to `docker-compose.yml`
3. Add the volume entry to `docker-compose.yml`
4. Create the MySQL database `ghost_newdomain`
5. Run `docker compose up -d ghost-newdomain`
6. Reload Caddy

You still need to complete steps 1, 7, 8, 9, 10, and 11 manually (DNS, Ghost setup wizard, API key, keyword sheet, n8n update, verification).

> **Note:** Review the script output for errors before proceeding. If any step fails, the script will print the error and stop. Fix the issue and re-run — the script is idempotent (safe to run multiple times).

---

## 14. Troubleshooting

### Ghost container keeps restarting

```bash
docker compose logs ghost-newdomain --tail=100
```

Common causes:
- **Database `ghost_newdomain` doesn't exist** — run Step 4
- **Wrong MySQL password** — check `MYSQL_ROOT_PASSWORD` in `.env`
- **`url` not set or wrong format** — must be `https://newdomain.com` (no trailing slash)
- **MySQL isn't ready yet** — add `depends_on: mysql` with a health check, or wait 30s and try again

### SSL certificate not being issued

```bash
docker compose logs caddy --tail=50
```

Common causes:
- **DNS not propagated yet** — wait 5–15 minutes and check with `nslookup newdomain.com`
- **Port 80 blocked** — Let's Encrypt needs port 80 for HTTP challenge. Check Oracle VCN Security List ingress rules (80/tcp, 0.0.0.0/0) and Ubuntu iptables (`sudo iptables -L INPUT -n -v | grep 80`)
- **Rate limited** — wait an hour if you've had multiple failed attempts

### Ghost setup wizard shows "Cannot connect to server"

- Ghost is still initializing — wait 60 seconds and refresh
- Check container is actually up: `docker ps | grep ghost-newdomain`
- Check Caddy is routing correctly: `docker compose logs caddy | grep newdomain`

### n8n posts fail with 401 Unauthorized

- The Ghost Admin API key is wrong or has been revoked
- Re-copy the key from Ghost Admin → Settings → Integrations
- Make sure `.env` was updated and n8n was restarted

### Cloudflare shows "Error 521: Web server is down"

- Your Ghost container or Caddy is not running — `docker ps`
- Port 443 is blocked on Oracle — check both VCN Security List AND Ubuntu iptables:
  ```bash
  sudo iptables -L INPUT -n -v | grep 443
  # If nothing shows, add:
  sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT
  ```

---

## 15. Checklist Summary

Print or bookmark this as your quick reference:

- [ ] **DNS**: A records added in Cloudflare pointing `newdomain.com` and `www.newdomain.com` to Oracle VM IP
- [ ] **Caddyfile**: New site block added (`newdomain.com { reverse_proxy ghost-newdomain:2368 }`)
- [ ] **docker-compose.yml**: New Ghost service block added with correct `url`, `database`, `container_name`, and volume
- [ ] **MySQL**: `ghost_newdomain` database created with utf8mb4 charset
- [ ] **Container**: `docker compose up -d ghost-newdomain` succeeded and container shows `Up`
- [ ] **Caddy reload**: `caddy reload` succeeded, SSL certificate issued
- [ ] **Ghost wizard**: Visited `https://newdomain.com/ghost`, created admin account
- [ ] **API key**: Ghost Admin → Integrations → Created `n8n-presspilot` integration, copied Admin API key to `.env`
- [ ] **n8n restarted**: `docker compose restart n8n` to load new env vars
- [ ] **Keyword sheet**: At least 5–10 `pending` keywords added for `newdomain.com`
- [ ] **n8n workflow**: Domain and API key added to the Ghost instance mapping
- [ ] **Verified**: Test post created via n8n, appeared in Ghost drafts, Telegram notification received
