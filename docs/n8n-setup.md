# n8n Setup Guide

This guide covers installing and configuring n8n as the automation backbone of PressPilot. n8n orchestrates the content pipeline: scoring keywords, calling the LLM provider layer, creating Ghost draft posts, and sending Telegram notifications.

> **Note:** This guide assumes you have completed `server-bootstrap.md` and have Docker Compose running. It also assumes at least one Ghost instance is live with an Admin API key (see `ghost-instance.md`).

---

## Table of Contents

1. [n8n in the PressPilot Stack](#1-n8n-in-the-presspilot-stack)
2. [n8n Container Configuration](#2-n8n-container-configuration)
3. [First Run — Accessing the Web UI](#3-first-run--accessing-the-web-ui)
4. [Setting Up Credentials](#4-setting-up-credentials)
5. [Setting Up the Telegram Bot](#5-setting-up-the-telegram-bot)
6. [Importing PressPilot Workflows](#6-importing-presspilot-workflows)
7. [Activating Workflows](#7-activating-workflows)
8. [Testing the Draft Pipeline](#8-testing-the-draft-pipeline)
9. [Webhook URLs and Security](#9-webhook-urls-and-security)
10. [n8n Data Persistence](#10-n8n-data-persistence)
11. [Updating n8n](#11-updating-n8n)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. n8n in the PressPilot Stack

n8n is a self-hosted workflow automation tool. In PressPilot, it replaces services like Zapier or Make.com — it runs on your own Oracle VM with no per-execution costs.

```
┌─────────────────────────────────────────────────────────────────┐
│  n8n Workflows                                                  │
│                                                                 │
│  keyword-scoring.json                                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Cron (daily) → Read keyword sheet → LLM score           │   │
│  │ → Mark top 3 in sheet → Trigger research-draft          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  research-draft.json                                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Webhook trigger → Web research → LLM draft             │   │
│  │ → POST to Ghost Admin API (draft) → Telegram notify    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  publish-scheduler.json                                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Cron → Query Ghost drafts with tag → Publish X/day     │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

n8n communicates with:
- **Ghost Admin API** — to create and publish posts
- **LLM provider-layer** — to generate content (via HTTP node)
- **Telegram Bot API** — to notify you of new drafts
- **Google Sheets or NocoDB** — as the keyword store

---

## 2. n8n Container Configuration

Add the following to your `docker-compose.yml`:

```yaml
  n8n:
    image: n8nio/n8n:latest
    platform: linux/arm64         # Oracle VM is ARM64
    container_name: presspilot_n8n
    restart: unless-stopped
    ports:
      - "127.0.0.1:5678:5678"    # Bind to localhost only — Caddy proxies externally
    environment:
      # Public URL — must match what Caddy exposes
      N8N_HOST: n8n.mostlyprompt.com
      N8N_PORT: 5678
      N8N_PROTOCOL: https
      WEBHOOK_URL: https://n8n.mostlyprompt.com/
      # Security
      N8N_BASIC_AUTH_ACTIVE: "true"
      N8N_BASIC_AUTH_USER: ${N8N_BASIC_AUTH_USER}
      N8N_BASIC_AUTH_PASSWORD: ${N8N_BASIC_AUTH_PASSWORD}
      # Data
      N8N_USER_FOLDER: /home/node/.n8n
      # Timezone (set to your local time for correct cron scheduling)
      GENERIC_TIMEZONE: Asia/Dhaka
      TZ: Asia/Dhaka
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - presspilot

volumes:
  n8n_data:
```

> **Note:** The `n8nio/n8n:latest` image publishes ARM64 builds. No special handling is needed beyond `platform: linux/arm64`.

### Caddyfile entry for n8n

```
n8n.mostlyprompt.com {
    reverse_proxy n8n:5678
}
```

> **Tip:** You can also expose n8n on a path instead of a subdomain (e.g. `mostlyprompt.com/n8n`) but subdomains are simpler with Caddy and Ghost.

### Environment variables to add to .env

```bash
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your-strong-n8n-password-here
```

> **Warning:** Set a strong password. n8n's web interface has full access to all credentials and workflows. Use at least 20 characters with mixed case, numbers, and symbols.

### Start n8n

```bash
docker compose up -d n8n
docker compose logs -f n8n
```

You should see:
```
n8n ready on 0.0.0.0, port 5678
```

---

## 3. First Run — Accessing the Web UI

Navigate to `https://n8n.mostlyprompt.com` in your browser.

If you enabled basic auth (`N8N_BASIC_AUTH_ACTIVE: "true"`), your browser will prompt for username and password — enter the values from `N8N_BASIC_AUTH_USER` and `N8N_BASIC_AUTH_PASSWORD`.

### Creating your n8n owner account

After the basic auth prompt, n8n will show a **Setup** screen:

1. Enter your **email address** — this becomes your n8n login
2. Enter your **first name** and **last name**
3. Set a password — this can be the same as or different from the basic auth password above
4. Click **Next**
5. n8n may ask what you want to use it for — select **Automation** or skip

You will arrive at the n8n editor dashboard. The left sidebar shows:
- **Workflows** — all your automation workflows
- **Credentials** — saved API keys and auth configs
- **Executions** — run history with logs

---

## 4. Setting Up Credentials

n8n stores credentials encrypted in its database. All PressPilot workflows expect certain named credentials to exist before they can run.

To add a credential: **Credentials** (left sidebar) → **Add credential** (top right) → search for the credential type.

### 4.1 Ghost Admin API

**Credential type:** Ghost Admin API

| Field | Value |
|---|---|
| **Credential Name** | `Ghost — mostlyprompt.com` |
| **Web API URL** | `https://mostlyprompt.com` |
| **Admin API Key** | The key from Ghost Admin → Integrations → PressPilot n8n |

Repeat for each Ghost site:
- `Ghost — fellowcoder.com`
- `Ghost — aimovi.com`

> **Note:** n8n has a built-in Ghost node that handles JWT signing automatically. You do not need to generate tokens manually.

### 4.2 Telegram Bot

**Credential type:** Telegram API

| Field | Value |
|---|---|
| **Credential Name** | `Telegram — PressPilot Bot` |
| **Access Token** | Your bot token from @BotFather (see Section 5) |

### 4.3 HTTP Header Auth (provider-layer)

If you are using the internal provider-layer microservice, the n8n HTTP node needs to authenticate to it.

**Credential type:** Header Auth

| Field | Value |
|---|---|
| **Credential Name** | `PressPilot Provider Layer` |
| **Name** | `X-API-Key` |
| **Value** | The `PROVIDER_LAYER_API_KEY` value from your `.env` |

### 4.4 Google Sheets OAuth (if using Sheets as keyword store)

**Credential type:** Google Sheets OAuth2 API

> **Note:** This requires a Google Cloud project with the Sheets API enabled and OAuth 2.0 credentials. If you chose NocoDB instead, skip this section.

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Create a new project (or reuse an existing one)
3. Enable the **Google Sheets API**
4. Go to **APIs & Services** → **Credentials** → **Create Credentials** → **OAuth client ID**
5. Application type: **Web application**
6. Authorized redirect URI: `https://n8n.mostlyprompt.com/rest/oauth2-credential/callback`
7. Download the client credentials JSON

In n8n:
| Field | Value |
|---|---|
| **Credential Name** | `Google Sheets — PressPilot` |
| **Client ID** | From your Google OAuth client JSON |
| **Client Secret** | From your Google OAuth client JSON |

Click **Sign in with Google** and authorize access.

### 4.5 NocoDB API (if using NocoDB as keyword store)

**Credential type:** Header Auth

| Field | Value |
|---|---|
| **Credential Name** | `NocoDB — PressPilot Keywords` |
| **Name** | `xc-auth` |
| **Value** | Your NocoDB API token (NocoDB → Team & Auth → API Tokens → Add) |

---

## 5. Setting Up the Telegram Bot

Telegram notifications are how PressPilot tells you a new draft is ready for review. You will receive a message with the post title and a direct link to the Ghost draft.

### Step 1 — Create a bot with @BotFather

1. Open Telegram and search for `@BotFather`
2. Start a conversation: click **Start**
3. Send: `/newbot`
4. BotFather asks for a **name** — enter something like: `PressPilot Notifications`
5. BotFather asks for a **username** — must end in `bot`, e.g. `presspilot_notify_bot`
6. BotFather responds with your **bot token**:

```
Done! Congratulations on your new bot. You will find it at t.me/presspilot_notify_bot.
Use this token to access the HTTP API:
7123456789:AAFxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Copy this token — you will need it for the n8n credential.

> **Warning:** Your bot token is equivalent to a password. Anyone with it can send messages as your bot. Store it in `.env` and never commit it to git.

### Step 2 — Find your Telegram chat ID

n8n's Telegram node sends messages to a specific chat ID. You need to find your personal chat ID.

**Method A — @userinfobot (easiest):**
1. In Telegram, search for `@userinfobot`
2. Send `/start`
3. The bot replies with your user ID, e.g.: `Your id: 123456789`

**Method B — getUpdates API:**
1. Open your new bot in Telegram and send it `/start`
2. In your browser, visit:
   ```
   https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates
   ```
   Replace `<YOUR_TOKEN>` with your actual bot token.
3. Find `"chat":{"id":123456789}` in the JSON response — that number is your chat ID

### Step 3 — Add chat ID to n8n workflows

The PressPilot workflow JSON files contain a placeholder `TELEGRAM_CHAT_ID`. After importing workflows (see Section 6), open the Telegram node in each workflow and replace the placeholder with your actual chat ID.

Alternatively, add it to n8n as an environment variable:

```yaml
# In docker-compose.yml, under n8n environment:
TELEGRAM_CHAT_ID: ${TELEGRAM_CHAT_ID}
```

```bash
# In .env:
TELEGRAM_CHAT_ID=123456789
```

### Step 4 — Test the bot

You can test a Telegram message directly from curl before wiring up n8n:

```bash
curl -s -X POST \
  "https://api.telegram.org/bot<YOUR_TOKEN>/sendMessage" \
  -H "Content-Type: application/json" \
  -d '{
    "chat_id": 123456789,
    "text": "PressPilot test notification — bot is working!",
    "parse_mode": "HTML"
  }'
```

A successful response looks like:
```json
{
  "ok": true,
  "result": {
    "message_id": 42,
    "text": "PressPilot test notification — bot is working!"
  }
}
```

---

## 6. Importing PressPilot Workflows

The PressPilot workflows are stored as JSON files in `n8n-workflows/`. You import them into n8n via the UI.

### Workflow files

| File | Purpose | Trigger |
|---|---|---|
| `keyword-scoring.json` | Reads keyword store, scores keywords with LLM, marks top 3 | Daily cron |
| `research-draft.json` | Web research + LLM draft → Ghost draft + Telegram notify | Triggered by scoring workflow |
| `publish-scheduler.json` | Moves approved drafts to published on a schedule | Cron or manual |

### Import steps

1. In n8n, click **Workflows** in the left sidebar
2. Click **+ Add workflow** → **Import from file**
3. Select the JSON file from your local machine (or copy from the server)
4. n8n loads the workflow in the editor
5. Review the workflow nodes — n8n may show warnings on nodes that need credential assignment
6. Assign credentials:
   - Click any node showing a credential warning
   - Select the matching credential you created in Section 4
7. Click **Save** (top right)
8. Repeat for each workflow JSON file

> **Note:** After importing, workflows are in **Inactive** state by default. Do not activate them until you have verified all credentials are assigned and tested a manual run (see Section 8).

### Updating workflow credentials after import

If a workflow node shows "Credential not found" after import:
1. Click the node to open its settings panel
2. Under **Credential for Ghost Admin API** (or similar), click the dropdown
3. Select the matching credential you created
4. Save the workflow

---

## 7. Activating Workflows

Once credentials are assigned and you have tested manually:

1. Open a workflow in the editor
2. Find the **Active/Inactive toggle** in the top-right of the editor
3. Click to switch to **Active**
4. n8n confirms the workflow is now running on its schedule

> **Warning:** Activate `keyword-scoring` before `research-draft`. The scoring workflow triggers the research workflow — if research-draft is inactive when triggered, the trigger will be silently dropped.

### Recommended activation order

1. First: `research-draft` — activate this so it is ready to receive triggers
2. Then: `keyword-scoring` — this will trigger research-draft on its next cron run
3. Last: `publish-scheduler` — only activate when you are ready for auto-publishing

---

## 8. Testing the Draft Pipeline

Before activating scheduled runs, test the pipeline manually with a known keyword.

### Step 1 — Manually trigger research-draft

1. Open `research-draft` workflow in the n8n editor
2. The workflow starts with a **Webhook** or **Manual Trigger** node
3. Click **Execute workflow** (play button, top right)
4. n8n prompts for test input data — enter:
   ```json
   {
     "keyword": "best AI prompts for productivity",
     "domain": "mostlyprompt.com",
     "ghost_url": "https://mostlyprompt.com"
   }
   ```
5. Click **Execute**

### Step 2 — Watch the execution

n8n shows a live view of the execution flowing through each node. Green = success, red = error.

Check each node output:
- **Web Research node** — should return search results/page content
- **LLM Draft node** — should return generated post content
- **Ghost node** — should show the created post ID and URL
- **Telegram node** — should show `ok: true`

### Step 3 — Verify in Ghost Admin

Go to `https://mostlyprompt.com/ghost/#/posts` — the test post should appear at the top with status **Draft**.

### Step 4 — Verify Telegram notification

Check your Telegram — you should have received a message from your bot with the draft title and a link like:
```
📝 New draft ready: "Best AI Prompts for Productivity"
Review: https://mostlyprompt.com/ghost/#/editor/post/63d8f...
```

> **Tip:** If the Telegram message does not arrive but the Ghost draft was created, check the Telegram node in the execution log for the error. Common issue: incorrect chat ID.

---

## 9. Webhook URLs and Security

Some n8n workflows use webhooks — URLs that external systems (or other workflows) POST to in order to trigger them.

### Finding your webhook URL

When a workflow contains a **Webhook** trigger node:
1. Click the Webhook node
2. n8n shows the **Production URL** and **Test URL**:
   - **Test URL** — used when you click "Execute workflow" in the editor; works only while you are in the editor
   - **Production URL** — used after you activate the workflow; always-on

Production webhook URLs look like:
```
https://n8n.mostlyprompt.com/webhook/abc123def456
```

### Securing webhooks

By default, n8n webhook URLs are publicly accessible if someone knows the URL. For PressPilot's internal workflows (where n8n calls itself), this is fine — the URLs are unguessable random strings.

For any webhook exposed externally, add authentication:

1. In the Webhook node settings → **Authentication** → **Header Auth**
2. Set **Name:** `X-PressPilot-Key`, **Value:** a secret token
3. Any caller must include this header

For Telegram-triggered workflows (if you add a command bot later), Telegram signs its webhook requests — verify the signature using n8n's built-in verification options.

> **Note:** The Caddy reverse proxy already provides TLS termination — all n8n webhook traffic is encrypted in transit. The concern is authentication (who can trigger the webhook), not encryption.

---

## 10. n8n Data Persistence

All n8n data — workflows, credentials, execution history — is stored in a named Docker volume:

```yaml
volumes:
  - n8n_data:/home/node/.n8n
```

This means:
- Restarting the n8n container does **not** lose data
- Deleting the container does **not** lose data
- Only `docker volume rm presspilot_n8n_data` would delete the data

### What is stored in the volume

```
/home/node/.n8n/
├── config             # n8n application config
├── database.sqlite    # SQLite database (workflows, credentials, executions)
└── custom/            # Custom nodes, if any
```

> **Note:** n8n uses SQLite by default, which is sufficient for PressPilot's scale (a few workflows, dozens of daily executions). For teams or high-volume automation, n8n supports PostgreSQL as an external database — but that is out of scope here.

### Backing up n8n data

Include the n8n volume in your regular backup script:

```bash
# In scripts/backup.sh
docker run --rm \
  -v presspilot_n8n_data:/source \
  -v /path/to/backup:/backup \
  alpine tar czf /backup/n8n-backup-$(date +%Y%m%d).tar.gz -C /source .
```

### Exporting workflows for version control

n8n workflows are also exported as JSON in `n8n-workflows/`. Keep this directory updated when you modify workflows:

1. In n8n editor → open a workflow
2. **Menu** (three dots, top right) → **Download**
3. Save the JSON file to `n8n-workflows/` in your repo
4. Commit the changes

This means your workflow definitions are in git, even if the n8n database is in a Docker volume. The volume holds live state (execution history, credentials); git holds your workflow source of truth.

---

## 11. Updating n8n

n8n releases updates frequently. To update:

```bash
# Pull the latest image
docker compose pull n8n

# Recreate the container (data persists in the volume)
docker compose up -d n8n

# Verify the new version is running
docker compose exec n8n n8n --version
```

> **Warning:** Review the [n8n changelog](https://docs.n8n.io/release-notes/) before updating, especially for major version bumps. Node schemas occasionally change between versions, which can cause existing workflows to require manual adjustment.

> **Tip:** Pin to a specific version (e.g. `image: n8nio/n8n:1.45.0`) once you are stable, and update deliberately. `latest` can introduce breaking changes unexpectedly.

---

## 12. Troubleshooting

### n8n container fails to start

```bash
docker compose logs n8n
```

Common causes:
- **Port 5678 already in use:** Another process is using the port. Change the host-side port mapping.
- **Volume permission error:** The `n8n_data` volume may have wrong ownership. Fix with:
  ```bash
  docker compose run --rm --entrypoint chown n8n -R node:node /home/node/.n8n
  ```

### Workflows not triggering on schedule

1. Check that the workflow is **Active** (toggle must be green)
2. Verify the timezone is correct — cron schedules interpret times in `GENERIC_TIMEZONE`
3. Check **Executions** in the left sidebar — past runs show whether the trigger fired
4. If no executions appear, the cron may have drifted. Restart n8n:
   ```bash
   docker compose restart n8n
   ```

### Ghost node returns 401 Unauthorized

- The Ghost Admin API key may have been regenerated. Go to Ghost Admin → Integrations → PressPilot n8n → copy the current Admin API Key → update the n8n credential.

### Telegram node returns 400 Bad Request

- Usually caused by an invalid `chat_id` or malformed message text (e.g. unescaped HTML when `parse_mode: HTML` is set)
- Check the error details in the node execution output panel

### Workflow execution stuck / hanging

n8n has a default execution timeout. For long-running LLM calls:
1. Go to **Settings** (gear icon, bottom left) → **Workflow Settings**
2. Increase **Execution Timeout** (in seconds)

Or set globally:
```yaml
# In docker-compose.yml, under n8n environment:
EXECUTIONS_TIMEOUT: 600       # 10 minutes
EXECUTIONS_TIMEOUT_MAX: 3600  # 1 hour hard cap
```

### "Credential not found" after importing a workflow

After importing, credential references need to be re-linked to your local credentials:
1. Open the workflow
2. Click each node with a warning icon
3. In the node panel, click the credential dropdown and select the matching credential
4. Save the workflow
