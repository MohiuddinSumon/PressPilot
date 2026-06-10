# PressPilot — Project Context

> Multi-domain automated content generation & publishing system.
> This document is the full context handoff for a coding session (Claude Code).
> Owner: Mohiuddin Sumon (Bon) — Dhaka, Bangladesh (UTC+6) — linkedin.com/in/mohiuddin0sumon

---

## 1. Vision

A self-hosted, low-maintenance system that runs multiple Ghost blogs on a single free Oracle Cloud server, with an AI-powered content pipeline that:

1. Reads a keyword/topic sheet (per domain)
2. Periodically (daily cron) scores keywords and picks the top ~3
3. Does market/web research on the chosen keywords
4. Drafts SEO-ready blog posts via LLM API
5. Saves drafts to the correct Ghost instance via Ghost Admin API
6. Notifies the owner (Telegram/email) for review — semi-auto mode
7. Optionally publishes on a schedule (e.g. 1–2 posts/day/site) — full-auto mode

**Design principles:**
- Owner is busy/lazy by design — everything must be automated or one-command
- Zero/near-zero hosting cost (Oracle Always Free tier)
- Adding a new domain must be a documented, ~15-minute runbook
- LLM-provider agnostic: user plugs in one or more API keys (Anthropic, OpenAI, xAI/Grok, Gemini, Ollama) — see §6

---

## 2. Current State (as of this handoff)

| Item | Status |
|---|---|
| Oracle Cloud account | ✅ Created. Home region: **ap-singapore-1** (Singapore). Free tier. |
| Oracle VM | ❌ **NOT provisioned yet** — docs must cover from zero (see §8) |
| Domains | ✅ All on **Hostinger** DNS |
| squarebrowser.com | ✅ Live — static landing page on Vercel (A record → 76.76.21.21, CNAME www → cname.vercel-dns.com) |
| Other 4 domains | ❌ Not set up yet |
| Anthropic API key | ❌ Not yet obtained |
| Mailgun (Ghost newsletters) | ❌ Not yet — optional initially |
| Keyword sheet (Google Sheets vs NocoDB) | ❓ Undecided |
| GitHub repo | ❌ To be created in coding session |

## 3. Domains & Purposes

| Domain | Purpose | Platform plan | Priority |
|---|---|---|---|
| mostlyprompt.com | AI prompting tips & tricks blog | Ghost (Oracle) | **1** |
| fellowcoder.com | Coding tutorials blog | Ghost (Oracle) | 2 |
| aimovi.com | AI niche (undecided — leaning AI tool directory/curator) | Ghost or Next.js | 2 |
| squarebrowser.com | Landing page for Android app (play.google.com/store/apps/details?id=com.squarebrowser.app) | ✅ Vercel static | 3 |
| mpmohi.com | Personal blog & portfolio | Vercel (Next.js/Astro) or Ghost | 3 |

Owner may buy more domains later — the system must make onboarding a new one trivial.

---

## 4. Target Architecture

```
                      ┌─────────────────────────────────────────┐
                      │   Oracle Cloud VM (Always Free)         │
                      │   VM.Standard.A1.Flex — 4 OCPU, 24 GB   │
                      │   Ubuntu 24.04 ARM64, Singapore         │
                      │                                         │
  Cloudflare (free)   │  ┌────────┐   ┌──────────────────────┐  │
  CDN + DNS proxy ────┼─▶│ Caddy  │──▶│ Ghost #1 mostlyprompt│  │
                      │  │ (auto  │──▶│ Ghost #2 fellowcoder │  │
                      │  │  SSL)  │──▶│ Ghost #N ...         │  │
                      │  └────────┘   └──────────────────────┘  │
                      │       │                                 │
                      │       ▼                                 │
                      │  ┌────────┐   ┌──────────────────────┐  │
                      │  │  n8n   │──▶│ LLM Provider Layer   │  │
                      │  │ (cron  │   │ (Anthropic/OpenAI/   │  │
                      │  │ agents)│   │  Grok/Gemini/Ollama) │  │
                      │  └────────┘   └──────────────────────┘  │
                      │       │                                 │
                      │       ▼                                 │
                      │  Keyword store (Google Sheets API       │
                      │  or NocoDB container — TBD)             │
                      └─────────────────────────────────────────┘
```

- **All containers via Docker Compose** on one VM (ARM64 — all images must support arm64)
- **Caddy** = reverse proxy + automatic Let's Encrypt SSL for all domains
- **Cloudflare free** in front (origin region doesn't matter for US/EU readers — edge caching handles it)
- Each Ghost instance: own container + own MySQL 8 container (or shared MySQL with separate DBs — decide in session; shared saves RAM)
- **n8n** container for all automation workflows
- Optional later: NocoDB container as keyword store, Uptime Kuma for monitoring

## 5. Content Pipeline (n8n workflows)

**Workflow A — Daily keyword scoring (per domain)**
- Cron daily → read keyword sheet rows for domain
- Score each keyword via LLM reasoning (v1: no paid SEO API; v2 may add DataForSEO/Google Trends)
- Mark top 3 in sheet → trigger Workflow B

**Workflow B — Research & draft**
- For each selected keyword: web research (search + scrape top results)
- Build research brief → call LLM provider layer → generate SEO post (title, meta, headings, body, tags)
- POST to correct Ghost Admin API as **draft**
- Notify owner via Telegram with preview link

**Workflow C — Publish scheduler**
- Configurable: manual approve (semi-auto) or auto-publish queue (e.g. every N hours / X posts per day)

**Workflow D — New domain onboarding helper** (stretch)
- Checklist-driven: new Ghost container, Caddy entry, sheet tab, DNS instructions

## 6. LLM Provider Abstraction (core requirement)

- User configures one or more providers via env vars / config file:
  `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `XAI_API_KEY`, `GEMINI_API_KEY`, `OLLAMA_URL`
- Per-task model routing, e.g.:
  - keyword scoring → cheap/fast model
  - research summarization → mid model
  - final draft → strongest available model
- Implementation options (decide in session):
  - n8n native LLM nodes per provider, or
  - a tiny internal API service (Node/Python) exposing `/generate` that routes to providers — cleaner, reusable, testable
- Must degrade gracefully if only one key is present

## 7. Repository Structure (proposed)

```
presspilot/
├── README.md
├── docker-compose.yml          # Caddy, Ghost xN, MySQL, n8n, (NocoDB)
├── Caddyfile
├── .env.example                # all secrets/keys documented
├── scripts/
│   ├── setup-server.sh         # fresh Ubuntu 24.04 ARM bootstrap
│   ├── add-domain.sh           # automates new Ghost instance + Caddy entry
│   └── backup.sh               # DB + content dumps → object storage
├── n8n-workflows/              # exported workflow JSONs (import via n8n UI)
│   ├── keyword-scoring.json
│   ├── research-draft.json
│   └── publish-scheduler.json
├── provider-layer/             # if internal LLM routing service chosen
└── docs/                       # see §8
```

## 8. Documentation Requirements (docs/)

Step-by-step, beginner-friendly guides (with screenshots placeholders) for:

1. **oracle-setup.md** — From zero: Oracle account → create VM.Standard.A1.Flex (4 OCPU / 24 GB / 200 GB boot, Ubuntu 24.04, Singapore region, handling "out of capacity" by retrying ADs or converting to PAYG), VCN security list ingress rules (80/443), SSH key setup, iptables on Ubuntu
2. **server-bootstrap.md** — Docker, Docker Compose, firewall, running setup-server.sh
3. **dns-cloudflare.md** — Moving/pointing Hostinger DNS, Cloudflare proxy setup per domain
4. **ghost-instance.md** — Adding a Ghost site, Mailgun config, theme install
5. **n8n-setup.md** — First-run, credentials, importing workflows, Telegram bot setup
6. **llm-providers.md** — Getting API keys from each provider (Anthropic console, OpenAI, xAI, Google AI Studio), plugging into config
7. **keyword-sheet.md** — Sheet schema: domain, keyword, status, score, last_used, notes
8. **add-new-domain.md** — The 15-minute runbook
9. **payments-monetization.md** — Stripe for Ghost memberships (note: Stripe availability in Bangladesh is limited — research alternatives like Paddle/LemonSqueezy for the owner's situation); RevenueCat only if mobile-app monetization for squarebrowser comes into scope
10. **supabase.md** *(optional/future)* — only if a future feature (e.g. aimovi.com app) needs hosted Postgres/auth; not part of core stack

> NOTE: Owner mentioned "Supabase" and "RevenueCat" via voice (transcription uncertain). Confirm scope in session — they are NOT required for the core blog pipeline.

## 9. Key Decisions Already Made

- Ghost (self-hosted) over WordPress — owner preference, github.com/tryghost/ghost
- Oracle Always Free over Hetzner/DO — $0 cost wins; Hetzner CX33 is the fallback if Oracle capacity fails
- Singapore home region (already locked at signup — Always Free compute only provisions in home region)
- Caddy over Nginx — auto-SSL, less config
- Cloudflare free in front of everything
- Vercel for static/landing sites (squarebrowser done; mpmohi planned)
- Semi-auto publishing first (human review via Telegram), full-auto as a toggle later

## 10. Open Decisions for the Coding Session

1. Keyword store: **Google Sheets** (phone-editable, familiar) vs **NocoDB** (self-hosted, API-native, no Google quota) — lean NocoDB if RAM allows
2. Shared MySQL container vs per-Ghost MySQL — lean shared (RAM efficiency on 24 GB)
3. Provider layer: n8n-native nodes vs internal routing microservice
4. aimovi.com: Ghost blog vs Next.js directory app — defer
5. Project name final confirmation (working name: PressPilot)

## 11. Constraints & Gotchas

- **ARM64 only** — every Docker image must have arm64 builds (Ghost ✅, MySQL 8 ✅ via oraclelinux variants or mysql:8-oracle, n8n ✅, Caddy ✅, NocoDB ✅)
- Oracle blocks ports by default — BOTH VCN security list AND Ubuntu iptables must allow 80/443
- Oracle Always Free ARM capacity in Singapore is scarce — docs must cover retry strategy / PAYG conversion (stays free within limits)
- Owner is in Bangladesh: Stripe direct is not available — flag in monetization docs
- Ghost requires real SMTP (Mailgun free tier) for member features; can run without it initially
- Owner's card: Bangladeshi Visa/Mastercard with international transactions enabled (already used for Oracle verification)

## 12. Success Criteria (Phase 1)

- [ ] `docker compose up -d` brings up Caddy + 1 Ghost (mostlyprompt.com) + n8n on the Oracle VM
- [ ] mostlyprompt.com serves over HTTPS via Cloudflare
- [ ] n8n workflow drafts one AI-generated post into Ghost from a hardcoded keyword
- [ ] Telegram notification received with draft link
- [ ] docs/oracle-setup.md complete enough that a stranger could replicate the server

## 13. Build Phases

1. **Foundation** — repo, docker-compose, Caddyfile, setup script, Ghost #1 live
2. **Automation core** — n8n + provider layer + Workflow B (draft pipeline)
3. **Intelligence** — Workflow A (scoring) + research step
4. **Scale** — remaining domains, add-domain.sh, Workflow C scheduler
5. **Polish** — backups, monitoring, full docs, optional NocoDB UI

---
*Generated from planning conversation, June 2026. Hand this file to the coding session as initial context.*
