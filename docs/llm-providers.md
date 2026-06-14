# LLM Providers Setup

This guide explains how to configure the AI providers that power PressPilot's content generation pipeline. PressPilot is designed to be provider-agnostic — you can mix and match Anthropic, OpenAI, xAI, Google Gemini, and local Ollama models.

> **Note:** You do not need all providers. Start with one (Anthropic is recommended for quality) and add others over time to reduce costs or add redundancy.

---

## Table of Contents

1. [Provider Abstraction Overview](#1-provider-abstraction-overview)
2. [Getting Your API Keys](#2-getting-your-api-keys)
   - [Anthropic (Claude)](#21-anthropic-claude)
   - [OpenAI (GPT)](#22-openai-gpt)
   - [xAI (Grok)](#23-xai-grok)
   - [Google Gemini](#24-google-gemini)
   - [Ollama (Local, Self-Hosted)](#25-ollama-local-self-hosted)
3. [How the Provider Layer Routes Tasks](#3-how-the-provider-layer-routes-tasks)
4. [Adding Keys to .env](#4-adding-keys-to-env)
5. [Configuring the Provider Layer Service](#5-configuring-the-provider-layer-service)
6. [Testing a Provider](#6-testing-a-provider)
7. [Cost Estimates](#7-cost-estimates)
8. [Graceful Degradation](#8-graceful-degradation)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Provider Abstraction Overview

The PressPilot **provider layer** is an internal microservice (`provider-layer/`) that sits between n8n and the various LLM APIs. n8n calls it with a task type and prompt; the provider layer decides which model to use and calls the appropriate API.

```
┌──────────────────────────────────────────────────────────────────┐
│  n8n Workflow                                                    │
│                                                                  │
│  POST /generate                                                  │
│  { "task": "draft", "prompt": "...", "domain": "mostlyprompt" } │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│  Provider Layer (provider-layer/ service)                        │
│                                                                  │
│  task = "scoring" → cheapest available provider                  │
│  task = "research" → mid-tier provider                           │
│  task = "draft" → strongest available provider                   │
│                                                                  │
│  Fallback chain: primary → secondary → tertiary → error         │
└──────┬──────────┬──────────┬──────────┬──────────┬──────────────┘
       │          │          │          │          │
       ▼          ▼          ▼          ▼          ▼
   Anthropic   OpenAI     xAI/Grok  Google     Ollama
   (Claude)    (GPT)      (Grok)    (Gemini)   (local)
```

**How degradation works:**

The provider layer checks which API keys are present in the environment. It builds a routing table at startup:
- If `ANTHROPIC_API_KEY` is set → Anthropic is available
- If `OPENAI_API_KEY` is set → OpenAI is available
- If neither strong-model provider is available, it falls back to whatever is configured

If only one provider is configured, all tasks route to that provider regardless of task type.

> **Note:** The minimum viable setup is **one API key**. You do not need all five providers. Configure what you have; the system adapts.

---

## 2. Getting Your API Keys

### 2.1 Anthropic (Claude)

**Recommended as the primary provider.** Claude models excel at long-form, structured content generation — ideal for SEO blog posts.

**Steps:**

1. Go to [console.anthropic.com](https://console.anthropic.com)
2. Sign up or log in
3. In the left sidebar, click **API Keys**
4. Click **+ Create Key**
5. Give it a name: `PressPilot Production`
6. Copy the key immediately — it will not be shown again

The key looks like:
```
sk-ant-api03-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Recommended models (as of June 2026):**

| Model ID | Use case | Speed | Cost |
|---|---|---|---|
| `claude-sonnet-4-6` | Final drafts — high quality, balanced | Medium | $$ |
| `claude-haiku-4-5-20251001` | Keyword scoring — fast and cheap | Fast | $ |

> **Note:** Model IDs change as Anthropic releases new versions. Always verify current model IDs in [console.anthropic.com/docs/models](https://console.anthropic.com/docs/models) before hard-coding them. The provider-layer config file is the single place to update model IDs.

**Setting up billing:**

Anthropic requires prepaid credits. Go to **Billing** in the console and add a minimum of $5 to start. Usage auto-deducts from your balance.

> **Note:** Anthropic API is available from Bangladesh — pay with your Visa/Mastercard with international transactions enabled (the same card that worked for Oracle).

---

### 2.2 OpenAI (GPT)

**Good secondary provider.** GPT-4o is competitive with Claude for drafting; GPT-4o-mini is very cheap for scoring tasks.

**Steps:**

1. Go to [platform.openai.com](https://platform.openai.com)
2. Sign up or log in
3. Click your profile (top right) → **API Keys**
4. Click **+ Create new secret key**
5. Name it: `PressPilot`
6. Copy the key immediately

The key looks like:
```
sk-proj-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Recommended models:**

| Model ID | Use case | Speed | Cost |
|---|---|---|---|
| `gpt-4o` | Final drafts — strong, reliable | Medium | $$ |
| `gpt-4o-mini` | Keyword scoring, summarization | Fast | $ |

**Setting up billing:**

Go to **Billing** in the platform dashboard → Add payment method → Add a minimum credit balance. OpenAI uses prepaid credits (pay-as-you-go on newer accounts).

---

### 2.3 xAI (Grok)

**Optional strong-model provider.** Grok-2 is competitive with GPT-4o for content generation and may offer different "voice" or style characteristics.

**Steps:**

1. Go to [console.x.ai](https://console.x.ai)
2. Sign in with your X (Twitter) account or create one
3. Navigate to **API Keys**
4. Click **Create API Key**
5. Name it: `PressPilot`
6. Copy the key

The key looks like:
```
xai-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Recommended models:**

| Model ID | Use case |
|---|---|
| `grok-2` | Strong drafts, similar capability to GPT-4o |
| `grok-2-mini` | Cheaper scoring/summarization tasks |

> **Note:** xAI's API availability and pricing may differ by region. Check [docs.x.ai](https://docs.x.ai) for the latest model IDs and rate limits.

---

### 2.4 Google Gemini

**Good for research summarization.** Gemini Flash is extremely fast and has a generous free tier, making it useful for high-volume tasks like keyword scoring.

**Steps:**

1. Go to [aistudio.google.com](https://aistudio.google.com)
2. Sign in with your Google account
3. Click **Get API key** (top right or in the left sidebar)
4. Click **Create API key**
5. Select a Google Cloud project (or let it create one automatically)
6. Copy the key

The key looks like:
```
AIzaSyxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Recommended models:**

| Model ID | Use case | Speed | Cost |
|---|---|---|---|
| `gemini-2.0-flash` | Keyword scoring, fast summarization | Very fast | Free tier / $ |
| `gemini-2.0-pro` | Final drafts when Anthropic/OpenAI unavailable | Medium | $$ |

**Free tier:**

Gemini Flash has a generous free tier through Google AI Studio (not Google Cloud Vertex AI). Limits as of 2026: 1,500 requests/day, 1M tokens/minute. This is sufficient for PressPilot's keyword scoring (a few dozen calls per day).

> **Note:** The free tier API key from AI Studio is sufficient. You do **not** need a Google Cloud billing account to start. If you need higher limits, enable billing on your Google Cloud project.

---

### 2.5 Ollama (Local, Self-Hosted)

**Best for cost optimization.** Ollama runs open-source models directly on the Oracle VM. No API costs — but uses the VM's CPU/RAM.

**ARM64 compatibility:** Ollama supports ARM64 natively. The Oracle VM (4 OCPU / 24 GB RAM) can run 7B models comfortably; 13B models are borderline (may be slow).

**Recommended use:** Route keyword scoring to Ollama to eliminate API costs for that task (~30 scoring calls/day across 2 domains).

#### Installing Ollama via Docker

Add to `docker-compose.yml`:

```yaml
  ollama:
    image: ollama/ollama:latest
    platform: linux/arm64
    container_name: presspilot_ollama
    restart: unless-stopped
    volumes:
      - ollama_data:/root/.ollama
    networks:
      - presspilot
    # No ports exposed externally — only accessible within Docker network

volumes:
  ollama_data:
```

```yaml
# In .env:
OLLAMA_URL=http://ollama:11434
```

#### Pulling a model

After the container starts, pull a model (this downloads it to the `ollama_data` volume):

```bash
# Pull Llama 3.1 8B — good balance of quality and speed on ARM64
docker compose exec ollama ollama pull llama3.1:8b

# Or a smaller, faster model:
docker compose exec ollama ollama pull qwen2.5:7b

# Check downloaded models:
docker compose exec ollama ollama list
```

> **Warning:** Model downloads are large — `llama3.1:8b` is ~4.7 GB. Make sure your Oracle VM boot volume (200 GB) has sufficient space. Check with: `df -h /`

**Model recommendations for ARM64 4 OCPU / 24 GB:**

| Model | Size | Good for | Notes |
|---|---|---|---|
| `llama3.1:8b` | ~4.7 GB | Scoring, summarization | Fast on ARM64, good quality |
| `qwen2.5:7b` | ~4.4 GB | Scoring, short tasks | Excellent instruction following |
| `mistral:7b` | ~4.1 GB | Scoring, research summaries | Very fast |
| `llama3.1:70b` | ~40 GB | Final drafts | Too large for 24 GB VM — do not use |

> **Warning:** Do **not** try to run 13B+ models on this VM for PressPilot's production pipeline. The Oracle VM has 24 GB RAM shared with Ghost instances, MySQL, n8n, and Caddy. A 7B model uses ~5–6 GB RAM; 13B models use ~10–12 GB and will cause out-of-memory crashes. Stick to 7B/8B for Ollama tasks and use API providers for final drafts.

---

## 3. How the Provider Layer Routes Tasks

The `provider-layer/` service reads a routing config file (`provider-layer/config.json`) to decide which provider handles each task type.

### Task types

| Task | Description | Quality need | Cost priority |
|---|---|---|---|
| `scoring` | Evaluate and score keyword relevance (1–10 scale) | Low — structured output | Minimize cost |
| `research` | Summarize web search results into a research brief | Medium — good comprehension | Balance |
| `draft` | Write full SEO blog post from research brief | High — best quality | Quality first |

### Default routing table

```json
{
  "routing": {
    "scoring": {
      "primary": "ollama/llama3.1:8b",
      "fallback": ["gemini/gemini-2.0-flash", "anthropic/claude-haiku-4-5-20251001", "openai/gpt-4o-mini"]
    },
    "research": {
      "primary": "gemini/gemini-2.0-flash",
      "fallback": ["anthropic/claude-haiku-4-5-20251001", "openai/gpt-4o-mini", "ollama/llama3.1:8b"]
    },
    "draft": {
      "primary": "anthropic/claude-sonnet-4-6",
      "fallback": ["openai/gpt-4o", "xai/grok-2", "gemini/gemini-2.0-pro"]
    }
  }
}
```

**How fallback works:**
1. Provider layer checks if the primary provider's API key is set
2. If set, calls the primary model
3. If the call fails (API error, rate limit, timeout), tries the first fallback
4. Continues down the fallback list until a call succeeds
5. If all providers fail, returns a structured error to n8n

> **Note:** If you only have one API key (e.g. only `ANTHROPIC_API_KEY`), all tasks will route to Anthropic regardless of the routing table. The fallback chain simply skips providers whose keys are not present.

### Customizing the routing

Edit `provider-layer/config.json` to change which model handles each task. For example, if you want to use Gemini Flash for research (free tier, fast) and Grok-2 for drafts:

```json
{
  "routing": {
    "research": {
      "primary": "gemini/gemini-2.0-flash",
      "fallback": ["anthropic/claude-haiku-4-5-20251001"]
    },
    "draft": {
      "primary": "xai/grok-2",
      "fallback": ["anthropic/claude-sonnet-4-6", "openai/gpt-4o"]
    }
  }
}
```

After editing, restart the provider-layer service:

```bash
docker compose restart provider_layer
```

---

## 4. Adding Keys to .env

Open `.env` on your server and add your API keys:

```bash
nano /path/to/presspilot/.env
```

```bash
# ── LLM Provider API Keys ─────────────────────────────────────────────────
# Add the keys you have. Leave others empty or commented out.

# Anthropic (Claude) — https://console.anthropic.com/api-keys
ANTHROPIC_API_KEY=sk-ant-api03-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# OpenAI (GPT) — https://platform.openai.com/api-keys
OPENAI_API_KEY=sk-proj-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# xAI (Grok) — https://console.x.ai
XAI_API_KEY=xai-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Google Gemini — https://aistudio.google.com/app/apikey
GEMINI_API_KEY=AIzaSyxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Ollama (local — no key needed, just set the URL)
# Only set this if you added the Ollama container to docker-compose.yml
OLLAMA_URL=http://ollama:11434

# ── Provider Layer ────────────────────────────────────────────────────────
# Internal API key for n8n to authenticate to the provider-layer service
PROVIDER_LAYER_API_KEY=generate-a-random-32-char-string-here
```

After editing `.env`, restart the provider-layer service:

```bash
docker compose up -d provider_layer
```

> **Warning:** Never commit `.env` to git. The `.gitignore` in the repo root already excludes `.env` — double-check with `git status` to confirm it is not staged.

---

## 5. Configuring the Provider Layer Service

The provider-layer service is a lightweight Node.js (or Python) HTTP API. It runs as a Docker container alongside Ghost and n8n.

Add to `docker-compose.yml`:

```yaml
  provider_layer:
    build: ./provider-layer       # Built from source in the repo
    platform: linux/arm64
    container_name: presspilot_provider_layer
    restart: unless-stopped
    ports:
      - "127.0.0.1:3000:3000"    # Internal only — n8n calls it directly
    environment:
      PORT: 3000
      API_KEY: ${PROVIDER_LAYER_API_KEY}
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
      OPENAI_API_KEY: ${OPENAI_API_KEY}
      XAI_API_KEY: ${XAI_API_KEY}
      GEMINI_API_KEY: ${GEMINI_API_KEY}
      OLLAMA_URL: ${OLLAMA_URL}
    volumes:
      - ./provider-layer/config.json:/app/config.json:ro
    networks:
      - presspilot
```

### API endpoints

The provider-layer exposes these endpoints:

| Method | Path | Description |
|---|---|---|
| `POST` | `/generate` | Main endpoint — generates text for a given task |
| `GET` | `/health` | Health check — returns available providers |
| `GET` | `/providers` | Lists configured providers and their status |

### Request format

```json
POST /generate
Authorization: Bearer your-provider-layer-api-key

{
  "task": "draft",
  "prompt": "Write a 1500-word SEO blog post about...",
  "context": {
    "keyword": "best AI prompts for productivity",
    "domain": "mostlyprompt.com",
    "research_brief": "..."
  },
  "options": {
    "max_tokens": 4000,
    "temperature": 0.7
  }
}
```

### Response format

```json
{
  "content": "# Best AI Prompts for Productivity\n\n...",
  "provider": "anthropic",
  "model": "claude-sonnet-4-6",
  "tokens_used": {
    "input": 450,
    "output": 1820
  },
  "cost_usd": 0.0042
}
```

---

## 6. Testing a Provider

After adding your API keys, verify the provider-layer can reach each provider:

### Check which providers are available

```bash
curl -s https://n8n.mostlyprompt.com/provider-health \
  -H "Authorization: Bearer ${PROVIDER_LAYER_API_KEY}" | python3 -m json.tool
```

Or from inside the Docker network:

```bash
docker compose exec n8n curl -s http://provider_layer:3000/health \
  -H "Authorization: Bearer your-key"
```

Expected response:

```json
{
  "status": "ok",
  "providers": {
    "anthropic": { "available": true, "models": ["claude-sonnet-4-6", "claude-haiku-4-5-20251001"] },
    "openai": { "available": true, "models": ["gpt-4o", "gpt-4o-mini"] },
    "gemini": { "available": true, "models": ["gemini-2.0-flash"] },
    "xai": { "available": false, "reason": "API key not set" },
    "ollama": { "available": true, "models": ["llama3.1:8b"] }
  }
}
```

### Test a generate call

```bash
curl -s -X POST http://localhost:3000/generate \
  -H "Authorization: Bearer your-provider-layer-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "task": "scoring",
    "prompt": "Score this keyword from 1-10 for SEO value: \"best AI prompts for beginners\". Consider search volume, competition, and relevance to AI tools. Return JSON: {\"score\": N, \"reasoning\": \"...\"}",
    "options": { "max_tokens": 200 }
  }'
```

Expected response:
```json
{
  "content": "{\"score\": 8, \"reasoning\": \"High search volume for 'AI prompts' category, moderate competition, very relevant to the target audience\"}",
  "provider": "ollama",
  "model": "llama3.1:8b",
  "tokens_used": { "input": 68, "output": 42 },
  "cost_usd": 0
}
```

### Test each task type

```bash
# Test scoring (should use cheapest provider)
curl -s -X POST http://localhost:3000/generate \
  -H "Authorization: Bearer your-key" \
  -H "Content-Type: application/json" \
  -d '{"task": "scoring", "prompt": "Score keyword: AI writing tools"}' | python3 -m json.tool

# Test drafting (should use strongest provider)
curl -s -X POST http://localhost:3000/generate \
  -H "Authorization: Bearer your-key" \
  -H "Content-Type: application/json" \
  -d '{"task": "draft", "prompt": "Write a brief intro paragraph about AI productivity tools"}' | python3 -m json.tool
```

Verify the `"provider"` field in each response matches your expected routing table.

---

## 7. Cost Estimates

Rough monthly cost estimates for **3 posts/day across 2 domains** (6 posts/day total, ~180 posts/month).

### Token estimates per post

| Task | Approx input tokens | Approx output tokens |
|---|---|---|
| Keyword scoring (per keyword, ~10 keywords/day) | 100 | 50 |
| Research summarization (per post) | 2,000 | 800 |
| Final draft (per post) | 3,000 | 2,000 |

### Daily totals (6 posts + 60 scoring calls)

| Task | Daily input tokens | Daily output tokens |
|---|---|---|
| Scoring (60 keywords) | 6,000 | 3,000 |
| Research (6 posts) | 12,000 | 4,800 |
| Draft (6 posts) | 18,000 | 12,000 |
| **Total** | **36,000** | **19,800** |

### Monthly cost by scenario

**Scenario A: Anthropic only (all tasks)**

| | Input | Output | Monthly cost |
|---|---|---|---|
| Claude Haiku (scoring + research) | ~540K tokens | ~237K tokens | ~$0.18 |
| Claude Sonnet (drafts) | ~540K tokens | ~360K tokens | ~$4.32 |
| **Total** | | | **~$4.50/month** |

**Scenario B: Optimized mix (recommended)**

| Task | Provider | Monthly cost |
|---|---|---|
| Scoring (60 calls/day) | Ollama (free) | $0.00 |
| Research (6/day) | Gemini Flash (free tier) | $0.00 |
| Drafts (6/day) | Claude Sonnet | ~$4.32 |
| **Total** | | **~$4.32/month** |

**Scenario C: Budget minimum (GPT-4o-mini for everything)**

| | Monthly cost |
|---|---|
| All tasks via GPT-4o-mini | ~$0.40/month |

> **Note:** These are rough estimates based on approximate 2026 pricing. Actual costs depend on post length, research depth, and provider pricing changes. Monitor your actual spend in each provider's dashboard for the first month.

> **Tip:** The cheapest production-quality setup is Scenario B: use Ollama for scoring (free), Gemini Flash free tier for research (free), and one paid provider (Anthropic or OpenAI) only for final drafts. At 6 posts/day, draft generation is ~$4–5/month total.

---

## 8. Graceful Degradation

The provider layer is designed to keep working even when some providers are down or rate-limited.

### What happens when a provider fails

1. **API key missing** — provider is skipped silently at startup; never attempted
2. **Rate limit (429)** — provider layer waits and retries once, then falls back to next provider
3. **API error (500, timeout)** — immediately falls back to next provider
4. **All providers fail** — returns error JSON to n8n; n8n logs the failure and skips this execution

### Minimum viable configuration

You can run PressPilot with just **one API key**. The routing table automatically collapses:

```
Only ANTHROPIC_API_KEY set → All tasks use claude-sonnet-4-6
```

In this mode:
- Scoring calls are slightly more expensive than necessary (Sonnet vs Haiku)
- Everything still works correctly

### Adding Ollama for zero-cost scoring

If you add Ollama later (after initial setup), update `provider-layer/config.json` to route scoring to Ollama first, then restart the provider-layer. No n8n workflow changes are needed.

---

## 9. Troubleshooting

### Provider layer returns "provider unavailable"

1. Check that the API key environment variable is set:
   ```bash
   docker compose exec provider_layer env | grep API_KEY
   ```
2. Verify the key has not expired or been revoked in the provider's console
3. Check the provider's status page for outages:
   - Anthropic: [status.anthropic.com](https://status.anthropic.com)
   - OpenAI: [status.openai.com](https://status.openai.com)

### Ollama not responding

```bash
# Check Ollama container is running
docker compose ps ollama

# Check Ollama logs
docker compose logs ollama

# Verify a model is pulled
docker compose exec ollama ollama list
```

If no models are listed, pull one:
```bash
docker compose exec ollama ollama pull llama3.1:8b
```

### High costs — scoring calls using expensive models

Verify Ollama is available and the routing config has scoring pointing to Ollama:
```bash
curl -s http://localhost:3000/health | python3 -m json.tool
```

If `ollama.available` is `false`, check the Ollama container. If it shows `true` but scoring still uses Anthropic, verify `provider-layer/config.json` has Ollama as the primary for scoring.

### Draft quality is poor

- Switch `draft.primary` in `config.json` to a stronger model
- Increase `max_tokens` in the draft task call (some models truncate at default limits)
- Review the research brief fed into the draft task — poor research input produces poor drafts

### Provider returns truncated responses

Each LLM has a maximum output token limit. If posts are being cut off:
- Add `"max_tokens": 4000` to the `/generate` request options
- Note: Claude Sonnet supports up to 8,192 output tokens; GPT-4o supports up to 16,384

```json
{
  "task": "draft",
  "prompt": "...",
  "options": {
    "max_tokens": 4000,
    "temperature": 0.7
  }
}
```

### Rate limits

Each provider has rate limits (requests per minute, tokens per minute). At 6 posts/day, you are extremely unlikely to hit them. If you do:

- **Anthropic:** Check your tier in console.anthropic.com (Tier 1 starts at ~$0 spend)
- **OpenAI:** Check usage limits in platform.openai.com/account/limits
- **Gemini:** Free tier is 1,500 requests/day — very generous for PressPilot's scale

The provider layer implements automatic retry with exponential backoff for rate limit errors (429 responses).
