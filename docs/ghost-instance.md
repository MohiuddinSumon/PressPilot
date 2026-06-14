# Ghost Instance Setup

This guide walks you through adding a Ghost blog instance to the PressPilot stack, configuring it with a real domain, setting up email, and connecting it to the n8n automation pipeline via the Admin API.

> **Note:** This guide assumes you have already completed `server-bootstrap.md` (Docker running, repo cloned) and `dns-cloudflare.md` (domain pointing to your Oracle VM).

---

## Table of Contents

1. [How Ghost Instances Are Structured](#1-how-ghost-instances-are-structured)
2. [Docker Compose Definition](#2-docker-compose-definition)
3. [Environment Variables Reference](#3-environment-variables-reference)
4. [Running Your First Ghost (mostlyprompt.com)](#4-running-your-first-ghost-mostlypromptcom)
5. [Ghost Initial Setup Wizard](#5-ghost-initial-setup-wizard)
6. [Mailgun SMTP Configuration](#6-mailgun-smtp-configuration)
7. [Installing Themes](#7-installing-themes)
8. [Getting the Ghost Admin API Key](#8-getting-the-ghost-admin-api-key)
9. [Verifying the API Key with curl](#9-verifying-the-api-key-with-curl)
10. [Ghost Content Structure](#10-ghost-content-structure)
11. [Adding a Second Ghost Instance](#11-adding-a-second-ghost-instance)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. How Ghost Instances Are Structured

PressPilot runs **one Ghost container per domain**, but shares a **single MySQL 8 container** across all instances. This approach keeps RAM usage low on the 24 GB Oracle Always Free VM.

```
┌─────────────────────────────────────────────────┐
│ Docker Compose Stack                             │
│                                                 │
│  ┌───────────────────┐   ┌───────────────────┐  │
│  │  ghost_mostlyprompt│   │  ghost_fellowcoder │  │
│  │  (port 2368)       │   │  (port 2369)       │  │
│  └────────┬──────────┘   └────────┬──────────┘  │
│           │                       │             │
│           ▼                       ▼             │
│  ┌─────────────────────────────────────────┐    │
│  │         MySQL 8 Container               │    │
│  │  DB: ghost_mostlyprompt                 │    │
│  │  DB: ghost_fellowcoder                  │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

**Key facts:**
- Each Ghost container binds to a unique internal port (2368, 2369, 2370, …)
- Caddy reverse-proxies the public domain to the correct internal port
- MySQL holds separate databases (one per Ghost site) — data never mixes
- Ghost content files (images, themes) are stored in named Docker volumes per instance

---

## 2. Docker Compose Definition

Here is the relevant section of `docker-compose.yml` for Ghost and MySQL. The full file is in the repo root.

```yaml
version: "3.9"

services:

  # ── Shared database ──────────────────────────────────────────────────────
  mysql:
    image: mysql:8.0
    platform: linux/arm64          # Required — Oracle VM is ARM64
    container_name: presspilot_mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - presspilot

  # ── Ghost #1: mostlyprompt.com ────────────────────────────────────────────
  ghost_mostlyprompt:
    image: ghost:5-alpine          # Alpine builds support arm64
    platform: linux/arm64
    container_name: ghost_mostlyprompt
    restart: unless-stopped
    depends_on:
      - mysql
    ports:
      - "127.0.0.1:2368:2368"     # Bind to localhost only — Caddy proxies externally
    environment:
      url: https://mostlyprompt.com
      database__client: mysql
      database__connection__host: mysql
      database__connection__port: 3306
      database__connection__user: root
      database__connection__password: ${MYSQL_ROOT_PASSWORD}
      database__connection__database: ghost_mostlyprompt
      mail__transport: SMTP
      mail__options__host: ${MAILGUN_SMTP_HOST}
      mail__options__port: 587
      mail__options__auth__user: ${MAILGUN_SMTP_USER}
      mail__options__auth__pass: ${MAILGUN_SMTP_PASS}
      mail__from: '"MostlyPrompt" <noreply@mostlyprompt.com>'
      NODE_ENV: production
    volumes:
      - ghost_mostlyprompt_data:/var/lib/ghost/content
    networks:
      - presspilot

volumes:
  mysql_data:
  ghost_mostlyprompt_data:

networks:
  presspilot:
    driver: bridge
```

> **Note:** The `platform: linux/arm64` line is mandatory. Without it, Docker on ARM may pull an x86 image and attempt emulation, which is slow and unreliable.

---

## 3. Environment Variables Reference

All secrets live in `.env` (never committed to git). Copy `.env.example` and fill in values:

```bash
cp .env.example .env
nano .env
```

### MySQL

| Variable | Description | Example |
|---|---|---|
| `MYSQL_ROOT_PASSWORD` | Root password for the shared MySQL container | `s3cur3P@ssw0rd!` |

### Ghost (per instance)

Each Ghost container reads its own set of environment variables. They follow a double-underscore `__` notation because Ghost uses a hierarchical config system.

| Variable | Description | Example |
|---|---|---|
| `url` | Full public URL of this Ghost site (must match your domain + HTTPS) | `https://mostlyprompt.com` |
| `database__client` | Always `mysql` for production | `mysql` |
| `database__connection__host` | Docker service name of MySQL | `mysql` |
| `database__connection__port` | MySQL port (default 3306) | `3306` |
| `database__connection__user` | MySQL user | `root` |
| `database__connection__password` | MySQL password | same as `MYSQL_ROOT_PASSWORD` |
| `database__connection__database` | Database name for this Ghost instance | `ghost_mostlyprompt` |
| `mail__transport` | Always `SMTP` | `SMTP` |
| `mail__options__host` | SMTP server hostname | `smtp.mailgun.org` |
| `mail__options__port` | SMTP port (587 for TLS, 465 for SSL) | `587` |
| `mail__options__auth__user` | SMTP username from Mailgun | `postmaster@mg.mostlyprompt.com` |
| `mail__options__auth__pass` | SMTP password from Mailgun | `key-abc123...` |
| `mail__from` | Sender address shown on emails | `"MostlyPrompt" <noreply@mostlyprompt.com>` |
| `NODE_ENV` | Always `production` | `production` |

> **Warning:** The `url` variable must exactly match the public URL including `https://`. If it says `http://` or has a trailing slash, Ghost will generate broken links and OAuth redirects will fail.

---

## 4. Running Your First Ghost (mostlyprompt.com)

### Step 1 — Create the MySQL database

Before starting Ghost, the database must exist in MySQL. Run this once:

```bash
# Start only MySQL first
docker compose up -d mysql

# Wait ~10 seconds for MySQL to initialize, then create the database
docker compose exec mysql mysql -u root -p${MYSQL_ROOT_PASSWORD} \
  -e "CREATE DATABASE IF NOT EXISTS ghost_mostlyprompt CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

> **Note:** Ghost can auto-create its database if the MySQL user has `CREATE DATABASE` privileges. Using `root` (as in this setup) is fine since MySQL is on the internal Docker network and never exposed externally.

### Step 2 — Start the Ghost container

```bash
docker compose up -d ghost_mostlyprompt
```

Check that it started correctly:

```bash
docker compose logs -f ghost_mostlyprompt
```

You should see lines like:

```
Ghost is running in production...
Your blog is now available on https://mostlyprompt.com
```

> **Warning:** If you see `Error: connect ECONNREFUSED` in the logs, MySQL is not ready yet. Wait 15–20 seconds and Ghost will retry automatically. Ghost has a built-in connection retry loop.

### Step 3 — Verify Caddy is routing correctly

Your `Caddyfile` should have an entry like:

```
mostlyprompt.com {
    reverse_proxy ghost_mostlyprompt:2368
}
```

Check Caddy logs:

```bash
docker compose logs caddy
```

You should see `certificate obtained successfully` and no errors.

### Step 4 — Open the site

Navigate to `https://mostlyprompt.com` in your browser. You should see the default Ghost Casper theme with a "Welcome to Ghost" message.

---

## 5. Ghost Initial Setup Wizard

The first time you visit `https://mostlyprompt.com/ghost`, Ghost will run a setup wizard.

### Step 1 — Create your admin account

Go to: `https://mostlyprompt.com/ghost`

You will be prompted to fill in:

| Field | What to enter |
|---|---|
| **Blog title** | E.g. `MostlyPrompt — AI Prompting Tips` |
| **Full name** | Your name |
| **Email address** | Your admin email (e.g. `bosontobouri@gmail.com`) |
| **Password** | A strong password — store in a password manager |

> **Warning:** This email and password become your Ghost admin login. Do **not** use a throwaway email — Ghost sends important system emails to this address (new member notifications, failed payments, etc.).

### Step 2 — Skip optional setup screens

Ghost will offer to invite staff members and explore the editor. You can skip these for now — click through to finish.

### Step 3 — Confirm you are in the Admin UI

After setup, you are inside the Ghost Admin dashboard at `https://mostlyprompt.com/ghost/#/dashboard`. From here you can manage posts, settings, themes, and integrations.

---

## 6. Mailgun SMTP Configuration

Ghost requires SMTP to send emails for:
- Member newsletter subscriptions
- Password reset emails
- New member welcome emails
- Staff invitation emails

Mailgun's free tier gives 100 emails/day, which is sufficient to start.

> **Note:** You can skip SMTP for initial launch if you do not need member features. Ghost will log warnings but will still run. Come back to this section when you are ready to enable newsletters.

### Step 1 — Create a Mailgun account

1. Go to [mailgun.com](https://www.mailgun.com) and sign up for the free plan.
2. You will need to verify your email and add a credit card (for identity verification — you will not be charged on the free tier).

> **Note:** Mailgun's Flex (free) plan allows sending to verified email addresses only, which is fine for personal testing. To send to anyone, you need a paid plan. Budget ~$3–5/month when you are ready to go live with newsletters.

### Step 2 — Add your sending domain

1. In Mailgun dashboard → **Sending** → **Domains** → **Add New Domain**
2. Enter: `mg.mostlyprompt.com` (use a subdomain, not the root domain)
3. Mailgun will show you DNS records to add in Cloudflare:
   - Two TXT records (SPF and DKIM)
   - One CNAME record (for tracking)
4. Add these records in Cloudflare DNS → **DNS** tab for `mostlyprompt.com`

> **Warning:** Set the DKIM and SPF TXT records with **DNS only** mode (grey cloud) in Cloudflare, not proxied (orange cloud). Mail authentication records must resolve directly.

5. Back in Mailgun, click **Verify DNS Records**. It may take up to 48 hours for DNS to propagate, but usually works in under 1 hour.

### Step 3 — Get SMTP credentials

1. In Mailgun → **Sending** → **Domains** → click your domain (`mg.mostlyprompt.com`)
2. Scroll to **SMTP credentials**
3. Note down:
   - **SMTP hostname:** `smtp.mailgun.org`
   - **Port:** `587` (TLS) or `465` (SSL)
   - **Username:** `postmaster@mg.mostlyprompt.com`
   - **Password:** Click **Reset password** to generate one

### Step 4 — Add SMTP credentials to .env

```bash
# In your .env file on the server:
MAILGUN_SMTP_HOST=smtp.mailgun.org
MAILGUN_SMTP_USER=postmaster@mg.mostlyprompt.com
MAILGUN_SMTP_PASS=your-mailgun-smtp-password-here
```

### Step 5 — Restart Ghost to pick up new env vars

```bash
docker compose up -d ghost_mostlyprompt
```

### Step 6 — Test email sending from Ghost Admin

1. Go to `https://mostlyprompt.com/ghost/#/settings/email`
2. Scroll to **Send test email**
3. Enter your email address and click Send
4. Check your inbox — the email should arrive within a minute

> **Warning:** If the test email does not arrive, check `docker compose logs ghost_mostlyprompt` for SMTP errors. Common issues: wrong password, wrong SMTP host, or firewall blocking port 587 outbound. Oracle's VCN egress rules allow outbound by default, but verify if needed.

---

## 7. Installing Themes

Ghost ships with the **Casper** theme by default. You can install a free or paid theme to customize the look.

### Finding themes

- **Free themes:** [ghost.org/themes](https://ghost.org/themes) (filter by Free)
- **Marketplace:** Same URL, paid options available
- **GitHub:** Many community themes are free on GitHub (search `ghost theme`)

Recommended free themes for content blogs:
- **Casper** (default, clean, solid)
- **London** — good for publications
- **Liebling** — magazine-style

### Installing a theme via Ghost Admin

1. Download the theme as a `.zip` file from the theme's website or GitHub releases page
2. Go to Ghost Admin → **Settings** (gear icon) → **Design**
3. Click the **Change theme** button
4. Click **Upload theme** in the top right
5. Select the `.zip` file you downloaded
6. Ghost will validate and install the theme
7. Click **Activate** to apply it to your live site

> **Note:** Ghost requires themes to follow its Handlebars templating spec. Themes downloaded from the official marketplace are guaranteed compatible. Community themes may need version checking — verify the theme supports Ghost 5.x.

### Customizing your theme

After activating a theme, Ghost Admin → **Design** shows customization options:
- **Brand colors** — primary and secondary
- **Typography** — font choices (varies by theme)
- **Homepage layout** — grid, list, featured posts
- **Navigation** — add/remove menu links

---

## 8. Getting the Ghost Admin API Key

The n8n automation pipeline creates draft posts by calling the Ghost Admin API. You need an Admin API key to authenticate these calls.

### Step 1 — Create a custom integration

1. Go to Ghost Admin → **Settings** → **Integrations**
2. Scroll to the bottom — click **+ Add custom integration**
3. Name it: `PressPilot n8n`
4. Click **Create**

### Step 2 — Copy the Admin API Key

After creation, Ghost shows:
- **Content API Key** — read-only, for public content queries
- **Admin API Key** — full read/write access

Copy the **Admin API Key**. It looks like:

```
67a3b5c1d2e4f5a6b7c8d9e0:1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2
```

The format is `{id}:{secret}` — both are hex strings separated by a colon.

### Step 3 — Add the API key to .env

```bash
# In .env
GHOST_MOSTLYPROMPT_ADMIN_API_KEY=67a3b5c1d2e4f5a6b7c8d9e0:1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2
GHOST_MOSTLYPROMPT_URL=https://mostlyprompt.com
```

> **Warning:** The Admin API key grants full access to your Ghost site — it can create, edit, and delete all content. Never expose it in public code, logs, or client-side JavaScript. Store only in `.env`.

---

## 9. Verifying the API Key with curl

Before wiring up n8n, confirm the API key works by creating a test draft post from the command line.

### How Ghost Admin API authentication works

Ghost uses JWT (JSON Web Token) for Admin API auth. You must:
1. Split the API key into `id` and `secret`
2. Generate a JWT signed with the secret (HS256, expiry 5 minutes)
3. Include it as `Authorization: Ghost <token>` header

For quick testing, you can use the Ghost Admin API directly with a tool like [this JWT generator](https://ghost.org/docs/admin-api/#token-authentication) — but for a fast curl test, use the simpler approach with a pre-generated token.

Here is a **self-contained bash script** to create a draft post:

```bash
#!/bin/bash
# test-ghost-api.sh
# Usage: ./test-ghost-api.sh

GHOST_URL="https://mostlyprompt.com"
ADMIN_API_KEY="67a3b5c1d2e4f5a6b7c8d9e0:1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2"

# Split key into id and secret
KEY_ID=$(echo $ADMIN_API_KEY | cut -d: -f1)
KEY_SECRET=$(echo $ADMIN_API_KEY | cut -d: -f2)

# Generate JWT (requires: apt install python3)
TOKEN=$(python3 - <<EOF
import jwt, time, binascii

key_id = "$KEY_ID"
key_secret = binascii.unhexlify("$KEY_SECRET")

now = int(time.time())
payload = {
    "iat": now,
    "exp": now + 300,
    "aud": "/admin/"
}

token = jwt.encode(payload, key_secret, algorithm="HS256", headers={"kid": key_id})
print(token)
EOF
)

# Create a draft post
curl -s -X POST \
  "$GHOST_URL/ghost/api/admin/posts/" \
  -H "Authorization: Ghost $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "posts": [{
      "title": "Test Draft from PressPilot",
      "status": "draft",
      "tags": [{"name": "test"}],
      "html": "<p>This is a test post created via the Ghost Admin API.</p>"
    }]
  }' | python3 -m json.tool
```

> **Note:** This script requires Python 3 and the `PyJWT` library (`pip3 install PyJWT`). For production, n8n handles JWT generation automatically using the Ghost node.

A successful response looks like:

```json
{
  "posts": [
    {
      "id": "63d8f4b2c5e1a3d9f2b1c4e7",
      "title": "Test Draft from PressPilot",
      "status": "draft",
      "url": "https://mostlyprompt.com/test-draft-from-presspilot/",
      ...
    }
  ]
}
```

Confirm the draft appears at `https://mostlyprompt.com/ghost/#/posts` — you should see it at the top of the list with a "Draft" badge.

---

## 10. Ghost Content Structure

Understanding Ghost's content model helps when configuring n8n workflows to create properly structured posts.

### Posts

The primary content type. Each post has:

| Field | Description |
|---|---|
| `title` | Post headline |
| `slug` | URL-friendly version of title, auto-generated |
| `status` | `draft`, `published`, `scheduled`, or `sent` (newsletters) |
| `html` | Post body in HTML |
| `lexical` | Post body in Ghost's Lexical JSON format (preferred for programmatic creation) |
| `custom_excerpt` | Manual meta description / teaser text |
| `tags` | Array of tag objects — used for categorization and SEO |
| `authors` | Array of author objects |
| `featured` | Boolean — pins post to top of listings |
| `published_at` | ISO 8601 timestamp — schedule future publication |
| `meta_title` | SEO title override |
| `meta_description` | SEO meta description override |
| `og_title`, `og_description`, `og_image` | Open Graph overrides for social sharing |

### Pages

Static pages (About, Contact, etc.) — same fields as posts but `type: page`. Not included in feeds or RSS by default.

### Tags

Two types:
- **Regular tags** — e.g. `#ai-prompting`, `#chatgpt` — displayed publicly, used for navigation
- **Internal tags** — prefixed with `#` in Ghost — hidden from public but useful for n8n workflow tracking (e.g. `#auto-generated`, `#needs-review`)

> **Tip:** Have n8n add an internal tag like `#presspilot-draft` to every AI-generated post. This lets you filter them in Ghost Admin and build Workflow C (the publish scheduler) to query only posts with this tag.

### Authors

Each Ghost site has at least one staff author (your admin account). You can add additional authors in **Settings → Staff**. The n8n pipeline can attribute posts to a dedicated "AI Author" account if you want to distinguish human and AI content.

---

## 11. Adding a Second Ghost Instance

When you are ready to add `fellowcoder.com` or another domain:

### Step 1 — Create the database

```bash
docker compose exec mysql mysql -u root -p${MYSQL_ROOT_PASSWORD} \
  -e "CREATE DATABASE IF NOT EXISTS ghost_fellowcoder CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

### Step 2 — Add a new Ghost service to docker-compose.yml

Copy the `ghost_mostlyprompt` block, increment the internal port, and change all references:

```yaml
  ghost_fellowcoder:
    image: ghost:5-alpine
    platform: linux/arm64
    container_name: ghost_fellowcoder
    restart: unless-stopped
    depends_on:
      - mysql
    ports:
      - "127.0.0.1:2369:2368"    # <-- incremented port
    environment:
      url: https://fellowcoder.com
      database__client: mysql
      database__connection__host: mysql
      database__connection__port: 3306
      database__connection__user: root
      database__connection__password: ${MYSQL_ROOT_PASSWORD}
      database__connection__database: ghost_fellowcoder
      # ... mail settings ...
    volumes:
      - ghost_fellowcoder_data:/var/lib/ghost/content
    networks:
      - presspilot

volumes:
  ghost_fellowcoder_data:    # <-- add this too
```

### Step 3 — Add a Caddy block

```
fellowcoder.com {
    reverse_proxy ghost_fellowcoder:2368
}
```

### Step 4 — Start the new instance

```bash
docker compose up -d ghost_fellowcoder
docker compose up -d caddy   # Reload Caddy to pick up new Caddyfile entry
```

> **Note:** The `add-domain.sh` script in `scripts/` automates steps 1–4. See `add-new-domain.md` for the full runbook.

---

## 12. Troubleshooting

### Ghost container exits immediately

```bash
docker compose logs ghost_mostlyprompt
```

Common causes:
- **MySQL not ready:** Wait 20 seconds and restart: `docker compose restart ghost_mostlyprompt`
- **Wrong database name:** The database must exist in MySQL before Ghost starts
- **`url` mismatch:** The `url` env var must exactly match your public domain with `https://`

### "Your blog is available on http://..." instead of https://

The `url` env var is set to `http://` instead of `https://`. Update `.env`, then:
```bash
docker compose up -d ghost_mostlyprompt
```

### Site shows Caddy error page instead of Ghost

Check that:
1. The Ghost container is running: `docker compose ps`
2. The internal port in Caddy matches the one in docker-compose (`2368` for Ghost #1)
3. Both containers are on the same Docker network (`presspilot`)

### Admin API returns 401 Unauthorized

- Regenerate the Admin API key in Ghost Admin → Integrations
- Check that the JWT is not expired (token has 5-minute expiry)
- Confirm the API key format: `{hex_id}:{hex_secret}` with exactly one colon

### Emails not sending

```bash
docker compose logs ghost_mostlyprompt | grep -i mail
```

Common causes:
- Wrong SMTP password (Mailgun resets passwords — check Mailgun dashboard)
- Port 587 blocked outbound (unlikely on Oracle, but check VCN egress rules)
- Mailgun domain not verified (check Mailgun DNS verification status)
