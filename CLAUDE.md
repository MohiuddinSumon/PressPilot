# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PressPilot is a self-hosted, AI-powered content generation and publishing system. It runs multiple Ghost blogs on a single Oracle Cloud Always Free VM (ARM64, Singapore), with n8n automating a daily pipeline: keyword scoring → web research → LLM-drafted posts → Ghost Admin API → Telegram notification for review.

Full project context, decisions, and open questions are in [PRESSPILOT_PROJECT_CONTEXT.md](PRESSPILOT_PROJECT_CONTEXT.md).

---

## Architecture

### Infrastructure Stack (all Docker Compose on one Oracle ARM64 VM)

```
Cloudflare (CDN/DNS) → Caddy (reverse proxy + auto-SSL) → Ghost instances
                                                         → n8n
                                                         → MySQL (shared)
                                                         → NocoDB (keyword store, optional)
```

- **Every Docker image must support `linux/arm64`** — the Oracle VM is ARM64 (VM.Standard.A1.Flex). Verify before adding any new image.
- Oracle blocks ports by default — both the VCN Security List **and** Ubuntu `iptables` must allow 80/443.
- Caddy handles Let's Encrypt SSL automatically via the Caddyfile.
- Ghost instances each get their own container but share a single MySQL 8 container (separate databases per site, saves RAM on 24 GB).

### Content Pipeline (n8n workflows)

Four workflows, exported as JSON under `n8n-workflows/`:

| Workflow | Trigger | Description |
|---|---|---|
| `keyword-scoring.json` | Daily cron | Reads keyword sheet → LLM scores each keyword → marks top 3 → triggers next |
| `research-draft.json` | Triggered by scoring | Web research + LLM draft → POST to Ghost Admin API as draft → Telegram notification |
| `publish-scheduler.json` | Cron or manual | Moves approved drafts to published on a configurable schedule |
| `add-domain.json` *(stretch)* | Manual | Checklist-driven new Ghost instance onboarding |

### LLM Provider Layer

Configured via environment variables. Must route per task (cheap model for scoring, strong model for final draft) and degrade gracefully when only some keys are present:

```
ANTHROPIC_API_KEY, OPENAI_API_KEY, XAI_API_KEY, GEMINI_API_KEY, OLLAMA_URL
```

Implementation is either n8n-native LLM nodes **or** an internal routing microservice at `provider-layer/` — this choice is still open (see §10 of project context). Prefer the microservice approach: it's reusable and testable outside n8n.

### Keyword Store

Either Google Sheets (phone-accessible) or NocoDB (self-hosted, API-native) — undecided. Schema regardless: `domain, keyword, status, score, last_used, notes`.

---

## Planned Repository Structure

```
presspilot/
├── docker-compose.yml          # Caddy, Ghost xN, MySQL, n8n, (NocoDB)
├── Caddyfile
├── .env.example                # all secrets/keys documented with descriptions
├── scripts/
│   ├── setup-server.sh         # fresh Ubuntu 24.04 ARM64 bootstrap
│   ├── add-domain.sh           # adds a new Ghost instance + Caddy entry
│   └── backup.sh               # DB + content dumps to object storage
├── n8n-workflows/              # exported workflow JSONs (import via n8n UI)
├── provider-layer/             # internal LLM routing service (if chosen)
└── docs/                       # step-by-step guides (see below)
```

---

## Key Constraints

- **ARM64 images only** — Ghost ✅, MySQL 8 ✅ (`mysql:8-oracle` or `oraclelinux` variant), n8n ✅, Caddy ✅, NocoDB ✅. Check new images before adding.
- **Oracle port rules** — both VCN Security List AND host `iptables` must allow 80/443. Forgetting either is the #1 connectivity failure.
- **No Stripe in Bangladesh** — owner cannot use Stripe directly. Use Paddle or LemonSqueezy for Ghost membership monetization.
- Ghost requires real SMTP for member features; Mailgun free tier is planned but optional for initial launch.
- Singapore is the locked Oracle home region — Always Free ARM compute provisions only there.

---

## Domains

| Domain | Role |
|---|---|
| mostlyprompt.com | Priority 1 — AI prompting tips blog (first Ghost to provision) |
| fellowcoder.com | Coding tutorials blog |
| aimovi.com | AI niche (Ghost blog vs Next.js directory — undecided) |
| squarebrowser.com | Android app landing page — already live on Vercel, do not touch |
| mpmohi.com | Owner personal blog — planned Vercel/Next.js or Ghost |

---

## Open Decisions (resolve before implementing affected components)

1. Keyword store: Google Sheets vs NocoDB
2. Provider layer: n8n-native nodes vs internal microservice (`provider-layer/`)
3. aimovi.com: Ghost vs Next.js
4. Shared MySQL vs per-Ghost MySQL (lean shared — saves RAM)

---

## Phase 1 Success Criteria

- `docker compose up -d` brings up Caddy + Ghost (mostlyprompt.com) + n8n on the Oracle VM
- mostlyprompt.com serves over HTTPS via Cloudflare
- n8n workflow drafts one AI post into Ghost from a hardcoded keyword
- Telegram notification received with draft link

## Docs to Write (docs/)

`oracle-setup.md`, `server-bootstrap.md`, `dns-cloudflare.md`, `ghost-instance.md`, `n8n-setup.md`, `llm-providers.md`, `keyword-sheet.md`, `add-new-domain.md`, `payments-monetization.md`. See §8 of project context for full scope of each.
