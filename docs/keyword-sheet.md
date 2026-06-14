# Keyword Sheet — The Content Pipeline's Input Queue

This guide explains how to set up and maintain the keyword store that drives PressPilot's automated content pipeline. Every post that PressPilot ever writes starts here — as a keyword row in this sheet.

---

## Table of Contents

1. [What is the Keyword Sheet?](#1-what-is-the-keyword-sheet)
2. [Choosing a Backend: Google Sheets vs NocoDB](#2-choosing-a-backend-google-sheets-vs-nocodb)
3. [Schema Reference](#3-schema-reference)
4. [Status Workflow](#4-status-workflow)
5. [Option A: Google Sheets Setup](#5-option-a-google-sheets-setup)
6. [Option B: NocoDB Setup](#6-option-b-nocodb-setup)
7. [Adding Keywords in Bulk (CSV Import)](#7-adding-keywords-in-bulk-csv-import)
8. [How n8n Reads the Sheet](#8-how-n8n-reads-the-sheet)
9. [Tips for Good Keywords](#9-tips-for-good-keywords)

---

## 1. What is the Keyword Sheet?

The keyword sheet is a simple table (a spreadsheet or database table) where you list topics and keywords you want PressPilot to write about. Think of it as the editorial calendar — but instead of you scheduling posts, the AI reads it every morning, picks the best keywords, researches them, and drafts the posts automatically.

**The pipeline in plain English:**

```
You add keywords to the sheet
    → n8n scoring workflow runs daily at 6 AM
        → LLM scores each "pending" keyword (0–100)
            → Top 3 marked as "selected"
                → Research & draft workflow kicks off
                    → Ghost draft created + Telegram notification sent to you
```

You only need to do two things:
1. Add keywords to the sheet (can be done from your phone).
2. Review and approve drafts in Ghost (via Telegram link).

---

## 2. Choosing a Backend: Google Sheets vs NocoDB

PressPilot supports two keyword store backends. Pick one and stick with it.

| Feature | Google Sheets | NocoDB |
|---|---|---|
| Setup time | ~15 min | ~10 min (already in Docker Compose) |
| Phone access | Excellent (native app) | Good (mobile web or app) |
| Requires Google account | Yes | No |
| API calls | Google Sheets API (OAuth) | Simple REST API (token-based) |
| Rate limits | 300 req/min (very generous) | None (self-hosted) |
| Offline access | Yes (Google Sheets app) | No |
| Cost | Free | Free (self-hosted) |
| Data portability | CSV export | CSV export |
| Recommended if... | You want to edit from phone easily | You want everything self-hosted |

> **Recommendation:** Start with **Google Sheets** if you want the easiest phone access. Switch to **NocoDB** later if you prefer keeping everything on your own server. Both use the same schema and the same n8n workflow logic — you only change the HTTP endpoint.

---

## 3. Schema Reference

Regardless of which backend you choose, the table has the same six columns:

| Column | Type | Required | Description |
|---|---|---|---|
| `domain` | text | Yes | The blog this keyword belongs to, e.g. `mostlyprompt.com` |
| `keyword` | text | Yes | The target search keyword or phrase, e.g. `best AI writing tools 2026` |
| `status` | enum | Yes | Current state in the pipeline — see [Status Workflow](#4-status-workflow) |
| `score` | number | No | LLM-assigned relevance/opportunity score from 0–100. Set automatically. |
| `last_used` | date | No | Date this keyword was last selected. Prevents repeating recent topics. |
| `notes` | text | No | Your own notes: angle ideas, target audience, related keywords, etc. |

**Example rows:**

| domain | keyword | status | score | last_used | notes |
|---|---|---|---|---|---|
| mostlyprompt.com | best ChatGPT prompts for students | pending | | | Target: college students, back to school angle |
| mostlyprompt.com | how to write prompts for image generation | selected | 87 | | Already trending on Reddit |
| fellowcoder.com | python list comprehension tutorial | drafted | 72 | 2026-06-10 | |
| mostlyprompt.com | midjourney vs DALL-E 3 | published | 91 | 2026-06-08 | Good traffic potential |
| fellowcoder.com | javascript async await explained | skipped | 34 | | Too competitive, low score |

---

## 4. Status Workflow

Each keyword moves through these states:

```
pending → selected → drafted → published
                   ↘
                    skipped
```

| Status | Who sets it | What it means |
|---|---|---|
| `pending` | You (manually) | Keyword is queued, waiting to be scored and selected |
| `selected` | Scoring workflow (n8n) | Keyword scored highly, draft generation is in progress |
| `drafted` | Research & draft workflow (n8n) | Ghost draft created, Telegram notification sent to you |
| `published` | Publish scheduler (n8n) or you manually | Post is live on the blog |
| `skipped` | Scoring workflow (n8n) | Low score, passed over this cycle; stays in the sheet for future reconsideration |

> **Note:** A `skipped` keyword is not deleted. The scoring workflow will reconsider it in the next cycle if its score improves (e.g. if a trend picks up). You can also manually reset it to `pending` to force reconsideration.

---

## 5. Option A: Google Sheets Setup

### Step 1: Create the Sheet

1. Go to [sheets.google.com](https://sheets.google.com) and create a new blank spreadsheet.
2. Name it `PressPilot Keywords` (or anything you like — just remember it).
3. In the first row, add these exact headers (copy-paste to avoid typos):

```
domain	keyword	status	score	last_used	notes
```

4. Add a few test rows to make sure it looks right.
5. Note the **Spreadsheet ID** from the URL:
   ```
   https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms/edit
                                         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                         This part is the Spreadsheet ID
   ```

### Step 2: Create a Google Cloud Service Account

n8n needs a service account to access your sheet without logging in interactively.

1. Go to [console.cloud.google.com](https://console.cloud.google.com).
2. Create a new project (or use an existing one). Name it `PressPilot`.
3. In the left menu, go to **APIs & Services → Library**.
4. Search for **Google Sheets API** and click **Enable**.
5. Go to **APIs & Services → Credentials**.
6. Click **Create Credentials → Service Account**.
   - Name: `presspilot-n8n`
   - Click **Create and Continue**, then **Done**.
7. Click on the newly created service account in the list.
8. Go to the **Keys** tab → **Add Key → Create new key → JSON**.
9. A `.json` file will download. This is your credentials file. Keep it safe.

> **Warning:** The credentials JSON file contains a private key. Never commit it to Git. Store it securely (e.g. as a file on your server or as a base64-encoded environment variable).

### Step 3: Share the Sheet with the Service Account

1. Open the credentials JSON file in a text editor.
2. Find the `client_email` field — it looks like:
   ```
   presspilot-n8n@your-project-id.iam.gserviceaccount.com
   ```
3. Go to your Google Sheet → click **Share** (top right).
4. Paste that email address and give it **Editor** access.
5. Click **Send**.

### Step 4: Add Credentials to n8n

1. Open your n8n instance at `https://n8n.yourdomain.com`.
2. Go to **Settings → Credentials → New Credential**.
3. Search for **Google Sheets API**.
4. Choose **Service Account** authentication.
5. Paste the entire contents of your credentials JSON file.
6. Click **Save**.

### Step 5: Note Your Sheet Details

You will need these when configuring the n8n workflow:

- **Spreadsheet ID**: (from the URL, step 1 above)
- **Sheet name**: `Sheet1` (default) or whatever you named the tab

---

## 6. Option B: NocoDB Setup

NocoDB is already included in the PressPilot Docker Compose file and runs as a container on your Oracle VM.

### Step 1: Access NocoDB

Once your stack is running, NocoDB is available at:

```
https://nocodb.yourdomain.com
```

> **Note:** You need to add a Caddyfile entry and a Docker Compose service for NocoDB. Check `docker-compose.yml` — if the `nocodb` service is present, it's already running. If not, add it (see the NocoDB ARM64-compatible image: `nocodb/nocodb:latest` — supports arm64 as of 2024).

### Step 2: Create an Account and Project

1. On first visit, NocoDB will ask you to create an admin account. Use a strong password and save it in your password manager.
2. Click **New Project** → **Create New Project**.
3. Name it `PressPilot`.

### Step 3: Create the Keywords Table

1. Inside your project, click **Add new table**.
2. Name it `keywords`.
3. Add the following fields (click **+** to add each one):

| Field Name | Field Type | Notes |
|---|---|---|
| `domain` | Single line text | Required |
| `keyword` | Single line text | Required |
| `status` | Single select | Add options: `pending`, `selected`, `drafted`, `published`, `skipped` |
| `score` | Number | Allow decimals: off (integers only) |
| `last_used` | Date | |
| `notes` | Long text | |

4. Click **Save** after adding all fields.

### Step 4: Get Your API Token

1. In NocoDB, click your profile icon (top right) → **Team & Settings**.
2. Go to **Tokens** → **Add new token**.
3. Name it `n8n-access`.
4. Copy the token and save it — you will only see it once.
5. Add it to your `.env` file:
   ```env
   NOCODB_API_TOKEN=your_token_here
   NOCODB_BASE_URL=https://nocodb.yourdomain.com
   ```

### Step 5: Get Your Table ID

1. In NocoDB, open the `keywords` table.
2. Look at the URL:
   ```
   https://nocodb.yourdomain.com/dashboard/#/signin
   ```
3. After signing in, navigate to your table. The URL will contain your Table ID:
   ```
   https://nocodb.yourdomain.com/dashboard/#/nc/p_abc123/table/md_xyz789
                                                                  ^^^^^^^^
                                                                  Table ID
   ```
4. Note this down — you will use it in n8n HTTP requests.

---

## 7. Adding Keywords in Bulk (CSV Import)

Both Google Sheets and NocoDB support CSV import, which is the fastest way to load many keywords at once.

### Preparing Your CSV

Create a file called `keywords.csv` with this format:

```csv
domain,keyword,status,score,last_used,notes
mostlyprompt.com,best ChatGPT prompts for coding,pending,,,
mostlyprompt.com,how to use Claude for writing,pending,,,Target beginners
mostlyprompt.com,AI tools for social media,pending,,,
fellowcoder.com,python web scraping tutorial,pending,,,
fellowcoder.com,docker for beginners,pending,,,
fellowcoder.com,git branching strategies,pending,,,Popular topic
```

Rules:
- Leave `score`, `last_used` empty for new keywords (the workflow fills them in).
- Set `status` to `pending` for all new rows.
- You can add as many rows as you like — the scoring workflow handles prioritization.

### Importing into Google Sheets

1. Open your Google Sheet.
2. Go to **File → Import**.
3. Choose **Upload** and select your `keywords.csv`.
4. Choose **Append to current sheet** (so you don't overwrite existing rows).
5. Click **Import data**.

### Importing into NocoDB

1. Open your `keywords` table in NocoDB.
2. Click the **Import** icon (toolbar, looks like an upload arrow).
3. Select **CSV file** and upload your file.
4. Map the CSV columns to NocoDB fields (they should auto-map if the column names match).
5. Click **Import**.

---

## 8. How n8n Reads the Sheet

The n8n scoring workflow reads the keyword sheet using HTTP requests. Here is how each backend is called:

### Google Sheets API (via n8n Google Sheets node)

The n8n workflow uses the built-in **Google Sheets** node:

- **Operation**: Read Rows
- **Spreadsheet ID**: `{{ $env.KEYWORD_SHEET_ID }}`
- **Sheet Name**: `Sheet1`
- **Filters**: Return only rows where `status = pending`

To update a row after scoring:

- **Operation**: Update Row
- **Row Number**: (from the read step)
- **Fields to update**: `status`, `score`, `last_used`

### NocoDB API (via n8n HTTP Request node)

**Read pending keywords:**

```
GET https://nocodb.yourdomain.com/api/v1/db/data/noco/{project_id}/{table_id}
Headers:
  xc-token: your_api_token
Query params:
  where=(status,eq,pending)
  limit=50
```

**Update a keyword row:**

```
PATCH https://nocodb.yourdomain.com/api/v1/db/data/noco/{project_id}/{table_id}/{row_id}
Headers:
  xc-token: your_api_token
  Content-Type: application/json
Body:
{
  "status": "selected",
  "score": 87,
  "last_used": "2026-06-14"
}
```

> **Note:** In n8n, configure these as **HTTP Request** nodes. Store the API token and base URL as n8n **Credentials** (or reference them from environment variables via `{{ $env.NOCODB_API_TOKEN }}`). Never hardcode tokens in workflow JSON — workflow files may be committed to Git.

---

## 9. Tips for Good Keywords

The quality of PressPilot's output depends on the quality of your keyword input.

**Good keywords to add:**
- Specific phrases (3–5 words), not single words
- Questions people actually search (e.g. `how to write a cover letter with ChatGPT`)
- Comparison terms (e.g. `Claude vs ChatGPT for coding`)
- Tutorial/how-to intent (performs well for content blogs)
- Trending topics in your niche (check Reddit, Twitter/X, Google Trends)

**Keywords to avoid:**
- Single generic words (`AI`, `coding`) — too broad, LLM can't angle them well
- Exact keywords you already have a published post for — add them as `skipped` to prevent reruns
- Highly competitive short-tail keywords without a unique angle in the `notes` column

**Using the `notes` column:**
The scoring workflow passes your notes to the LLM as context. Use it to guide the angle:

```
notes: "Target junior developers, use Python examples, include a real-world project"
notes: "Beginner audience, avoid jargon, focus on free tools only"
notes: "Trending on Hacker News this week — prioritize this"
```

> **Tip:** Aim to keep at least 20–30 `pending` keywords per domain at all times. This gives the scoring workflow enough variety to pick the best topic each day without running out of queue.
