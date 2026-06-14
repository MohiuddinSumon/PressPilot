# PressPilot

Self-hosted, AI-powered content pipeline for multiple Ghost blogs on a single Oracle Cloud Always Free VM.

**Pipeline:** keyword sheet → daily LLM scoring → web research → draft post → Ghost Admin API → Telegram review notification

**Stack:** Docker Compose · Caddy (auto-SSL) · Ghost 5 · MySQL 8 · n8n · LLM provider layer (Anthropic / OpenAI / Gemini / xAI / Ollama)

---

## Quick Start (on server)

```bash
git clone https://github.com/YOUR_USERNAME/presspilot.git /opt/presspilot
cd /opt/presspilot
cp .env.example .env
nano .env          # fill in passwords, API keys, Telegram token
bash scripts/setup-server.sh
```

After setup:
- Ghost admin: `https://mostlyprompt.com/ghost`
- n8n: `https://n8n.mostlyprompt.com`
- Import workflows from `n8n-workflows/`

---

## Docs

| Guide | What it covers |
|---|---|
| [oracle-setup.md](docs/oracle-setup.md) | Oracle account → VM provisioning → SSH access |
| [server-bootstrap.md](docs/server-bootstrap.md) | Docker, firewall, running the stack |
| [dns-cloudflare.md](docs/dns-cloudflare.md) | Cloudflare DNS setup for all domains |
| [ghost-instance.md](docs/ghost-instance.md) | Ghost setup, Mailgun, themes, API keys |
| [n8n-setup.md](docs/n8n-setup.md) | n8n credentials, workflows, Telegram bot |
| [llm-providers.md](docs/llm-providers.md) | API keys for all providers, routing config |
| [keyword-sheet.md](docs/keyword-sheet.md) | Keyword store schema (NocoDB or Google Sheets) |
| [add-new-domain.md](docs/add-new-domain.md) | 15-minute runbook for a new Ghost site |
| [payments-monetization.md](docs/payments-monetization.md) | LemonSqueezy setup (no Stripe in BD) |

---

## Repository Structure

```
presspilot/
├── docker-compose.yml      # full stack definition
├── Caddyfile               # reverse proxy + SSL config
├── .env.example            # copy to .env, fill in values
├── scripts/
│   ├── setup-server.sh     # bootstrap fresh Ubuntu 24.04 ARM64
│   ├── add-domain.sh       # add a new Ghost domain in ~15 min
│   ├── backup.sh           # dump DBs + volumes → Oracle Object Storage
│   └── mysql-init/init.sql # creates all Ghost databases on first start
├── n8n-workflows/
│   ├── keyword-scoring.json   # daily keyword scorer
│   ├── research-draft.json    # research + LLM draft + Ghost API
│   └── publish-scheduler.json # auto-publish oldest N drafts/day
├── provider-layer/         # internal LLM routing microservice
│   ├── Dockerfile
│   ├── package.json
│   └── src/
│       ├── index.js        # Express server, /generate endpoint
│       ├── router.js       # routes tasks to providers with fallback
│       └── providers/      # anthropic.js, openai.js, gemini.js, ollama.js
└── docs/                   # step-by-step guides (see table above)
```

---

## Domains

| Domain | Status | Platform |
|---|---|---|
| mostlyprompt.com | Priority 1 | Ghost (Oracle) |
| fellowcoder.com | Phase 2 | Ghost (Oracle) |
| aimovi.com | TBD | Ghost or Next.js |
| squarebrowser.com | ✅ Live | Vercel (static, do not touch) |
| mpmohi.com | Phase 3 | Vercel or Ghost |

---

## Phase 1 Success Criteria

- [ ] `docker compose up -d` brings up Caddy + Ghost (mostlyprompt.com) + n8n
- [ ] mostlyprompt.com serves over HTTPS
- [ ] n8n drafts one AI post into Ghost from a hardcoded keyword
- [ ] Telegram notification received with draft link

---

## Key Constraints

- **ARM64 only** — all Docker images must support `linux/arm64`
- **Oracle ports** — both VCN Security List AND host `iptables` must allow 80/443
- **No Stripe** — owner is in Bangladesh; use LemonSqueezy or Paddle
- **Singapore region** — Oracle home region locked at signup; can't change
