# DNS & Cloudflare Setup Guide

Point your domains to your Oracle VM through Cloudflare for free CDN, DDoS protection, and automatic HTTPS.

**Prerequisites:**
- You have completed [oracle-setup.md](oracle-setup.md) and have your Oracle VM's public IP address
- Your domains are registered at Hostinger (or another registrar)
- You have completed [server-bootstrap.md](server-bootstrap.md) and the server is running

---

## Why Cloudflare?

Cloudflare sits between your visitors and your Oracle server. When someone visits `mostlyprompt.com`, they hit Cloudflare's global edge network first, not your VM directly. This gives you:

| Benefit | What it means for you |
|---|---|
| **Free CDN** | Static assets (images, CSS, JS) cached at Cloudflare's edge — fast for US/EU readers even though your server is in Singapore |
| **DDoS protection** | Cloudflare absorbs attack traffic before it reaches your VM |
| **Hides your origin IP** | Attackers cannot directly target your Oracle server's IP |
| **Free SSL** | Cloudflare issues certificates for your domains automatically |
| **Analytics** | Basic traffic analytics without needing Google Analytics |

The free Cloudflare plan covers all of PressPilot's needs.

---

## Overview of the SSL Chain

Understanding this will save you from the most common misconfiguration:

```
Visitor → Cloudflare Edge (Cloudflare certificate) → Oracle VM/Caddy (Let's Encrypt certificate)
```

There are two SSL connections:

1. **Visitor ↔ Cloudflare:** Cloudflare presents its own certificate to the visitor's browser. This always works.
2. **Cloudflare ↔ Caddy (your server):** Cloudflare connects to your server and verifies Caddy's Let's Encrypt certificate.

Cloudflare has four SSL modes:

| Mode | Visitor↔CF | CF↔Origin | Safe? |
|---|---|---|---|
| **Off** | No SSL at all | No SSL | Never use |
| **Flexible** | SSL ✅ | No SSL (plain HTTP) | Insecure — password data in plaintext to your server |
| **Full** | SSL ✅ | SSL ✅ (certificate not verified) | OK but allows invalid certs |
| **Full (strict)** | SSL ✅ | SSL ✅ (certificate verified) | **Use this** |

> **Warning:** If you use "Flexible" mode, Cloudflare sends traffic to your server over plain HTTP even though visitors see HTTPS in their browser. This is insecure and will also break Caddy's redirect logic. Always use **Full (strict)**.

Caddy automatically obtains a valid Let's Encrypt certificate for your domain, which is what makes "Full (strict)" possible.

---

## 1. Add Your Site to Cloudflare

### 1.1 Create a Cloudflare Account

Go to [cloudflare.com](https://cloudflare.com) and sign up for a free account. Use an email you check regularly — Cloudflare sends important notifications there.

### 1.2 Add Your First Domain

1. After logging in, click **Add a site** (or **Add domain** on newer dashboards).
2. Enter your domain name, e.g. `mostlyprompt.com`. Do not include `www`.
3. Click **Continue**.

[SCREENSHOT: Cloudflare "Add a site" input field]

### 1.3 Select the Free Plan

On the plan selection screen, scroll down and select **Free**. Click **Continue**.

[SCREENSHOT: Cloudflare plan selection with Free plan highlighted]

### 1.4 Review Existing DNS Records

Cloudflare will scan your domain's current DNS records and import them. Review the list:

- If you see old A records pointing somewhere else, delete them — you will add the correct ones in the next section.
- If Hostinger set up any default records (parking pages, etc.), remove those too.
- Keep any MX records if you use Hostinger's email for this domain.

Click **Continue** when done.

### 1.5 Note Your Cloudflare Nameservers

Cloudflare will show you two nameservers, something like:

```
aria.ns.cloudflare.com
bob.ns.cloudflare.com
```

Write these down — you will need them in the next step.

[SCREENSHOT: Cloudflare showing the two nameserver addresses to use]

---

## 2. Change Nameservers at Hostinger

You need to tell Hostinger to use Cloudflare's nameservers instead of Hostinger's own. This transfers DNS control to Cloudflare.

### 2.1 Log In to Hostinger

Go to [hpanel.hostinger.com](https://hpanel.hostinger.com) and log in.

### 2.2 Find DNS / Nameserver Settings

1. Go to **Domains** in the top navigation.
2. Click on the domain you are setting up (e.g. `mostlyprompt.com`).
3. Click **DNS / Nameservers** in the left sidebar (or look for a "Nameservers" tab).

[SCREENSHOT: Hostinger domain management page with DNS/Nameservers option]

### 2.3 Switch to Custom Nameservers

1. Select **Change nameservers** or **Custom nameservers**.
2. Delete Hostinger's default nameservers (e.g. `ns1.hostinger.com`, `ns2.hostinger.com`).
3. Enter Cloudflare's two nameservers:
   - `aria.ns.cloudflare.com` (use your actual nameservers from step 1.5)
   - `bob.ns.cloudflare.com`
4. Save the changes.

[SCREENSHOT: Hostinger nameserver fields with Cloudflare nameservers entered]

> **Note:** Nameserver changes propagate globally within a few minutes to a few hours, though Hostinger typically applies them within 30–60 minutes. Cloudflare will email you when it detects the nameserver change and activates your domain.

### 2.4 Repeat for Each Domain

Repeat steps 2.1–2.3 for every domain you want to put on Cloudflare:
- `mostlyprompt.com`
- `fellowcoder.com`
- `aimovi.com` (when ready)
- `mpmohi.com` (when ready)

> **Note:** `squarebrowser.com` is already live on Vercel — do not touch its DNS settings.

---

## 3. Configure DNS Records in Cloudflare

Once Cloudflare is active for your domain (you'll receive a confirmation email), set up the DNS records.

### 3.1 Navigate to DNS Settings

1. In Cloudflare, click on your domain (e.g. `mostlyprompt.com`).
2. Click **DNS** in the left sidebar.
3. Click **Records**.

### 3.2 Add an A Record for the Root Domain

Click **Add record** and fill in:

| Field | Value |
|---|---|
| Type | `A` |
| Name | `@` (represents the root domain, i.e. mostlyprompt.com) |
| IPv4 address | Your Oracle VM's public IP, e.g. `152.67.xxx.xxx` |
| Proxy status | **Proxied** (orange cloud — enabled) |
| TTL | Auto |

Click **Save**.

[SCREENSHOT: Cloudflare DNS record editor with orange proxy cloud enabled]

### 3.3 Add a www CNAME Record

Click **Add record** again:

| Field | Value |
|---|---|
| Type | `CNAME` |
| Name | `www` |
| Target | `@` (or `mostlyprompt.com`) |
| Proxy status | **Proxied** (orange cloud — enabled) |
| TTL | Auto |

Click **Save**.

> **Note:** The CNAME `www → @` means `www.mostlyprompt.com` redirects to `mostlyprompt.com`. Caddy handles the actual redirect to the canonical domain.

### 3.4 Per-Domain DNS Summary

Repeat for each domain. Your final DNS setup in Cloudflare should look like this:

**mostlyprompt.com**

| Type | Name | Content | Proxy |
|---|---|---|---|
| A | `@` | `152.67.xxx.xxx` | Proxied (orange) |
| CNAME | `www` | `@` | Proxied (orange) |

**fellowcoder.com**

| Type | Name | Content | Proxy |
|---|---|---|---|
| A | `@` | `152.67.xxx.xxx` | Proxied (orange) |
| CNAME | `www` | `@` | Proxied (orange) |

> **Note:** All domains point to the same Oracle VM IP. Caddy's reverse proxy routes each domain to the correct Ghost instance based on the hostname in the request.

### 3.5 Proxied vs DNS-Only

The proxy toggle (orange cloud vs grey cloud) is important:

- **Proxied (orange cloud):** Traffic flows through Cloudflare's network. Your origin IP is hidden. Cloudflare's CDN, DDoS protection, and caching are active. **Use this for all web domains.**
- **DNS-only (grey cloud):** DNS resolves to your real IP directly. No Cloudflare features. Use only for subdomains that need a direct connection (e.g. email MX records, some APIs).

---

## 4. Configure SSL/TLS Mode in Cloudflare

This is the most important Cloudflare setting to get right.

### 4.1 Set SSL Mode to "Full (strict)"

1. In Cloudflare, click on your domain.
2. Click **SSL/TLS** in the left sidebar.
3. Click **Overview**.
4. Under **Your SSL/TLS encryption mode**, select **Full (strict)**.

[SCREENSHOT: Cloudflare SSL/TLS settings showing Full (strict) selected]

> **Warning:** Do NOT select "Flexible". With Flexible mode, Cloudflare sends traffic to your server over plain HTTP, which means:
> 1. Sensitive data (passwords, form submissions) travels unencrypted between Cloudflare and your server
> 2. Caddy will see HTTP requests and redirect them to HTTPS, creating an infinite redirect loop
> 3. Visitors will see redirect errors or broken sites

### 4.2 Enable Automatic HTTPS Rewrites

1. Click **SSL/TLS** → **Edge Certificates**.
2. Enable **Automatic HTTPS Rewrites** — this upgrades any HTTP links in your pages to HTTPS.

### 4.3 "Always Use HTTPS" Setting — Leave Disabled

On the same **Edge Certificates** page, there is an **Always Use HTTPS** toggle.

**Leave this OFF (disabled).** Caddy already handles HTTP → HTTPS redirects. If both Cloudflare and Caddy redirect HTTP to HTTPS, visitors may experience redirect loops.

> **Note:** Caddy's built-in HTTP → HTTPS redirect is reliable. You do not need Cloudflare to do this as well.

---

## 5. Verify DNS Propagation

### 5.1 Check with Cloudflare's Dashboard

Cloudflare shows you the current status of your domain at the top of the **Overview** page. Wait for it to show **"Active"**.

### 5.2 Check with Online Tools

Use any of these tools to verify your domain resolves to your Oracle IP:

- [dnschecker.org](https://dnschecker.org) — Shows resolution from multiple locations worldwide
- [whatsmydns.net](https://whatsmydns.net) — Similar global propagation checker
- [mxtoolbox.com/DNSLookup.aspx](https://mxtoolbox.com/DNSLookup.aspx)

Enter `mostlyprompt.com` and check the A record. You should see Cloudflare's proxy IPs (not your Oracle IP — Cloudflare hides your origin IP when proxied).

### 5.3 Test from the Command Line

From your local Windows PowerShell:

```powershell
nslookup mostlyprompt.com
```

You should see Cloudflare's IP addresses (from the `104.xxx.xxx.xxx` or `172.6x.xxx.xxx` ranges), not your Oracle IP.

To bypass Cloudflare and test your origin server directly:

```bash
# From your Oracle VM (SSH in), test that Caddy is responding
curl -H "Host: mostlyprompt.com" http://localhost
```

---

## 6. Test HTTPS in a Browser

Once DNS is propagated and Cloudflare shows "Active":

1. Open a browser and go to `https://mostlyprompt.com`.
2. You should see the Ghost setup page (or your live site if already configured).
3. The padlock icon should show in the address bar.
4. Click the padlock and verify **Certificate: Cloudflare, Inc.** — this means traffic is flowing through Cloudflare correctly.

If you see a certificate warning or "Not Secure" — check your SSL mode setting (Section 4) and ensure Caddy obtained a Let's Encrypt certificate successfully (`docker compose logs caddy`).

---

## 7. Add n8n Subdomain (Optional)

If you want to access n8n at a subdomain like `n8n.mostlyprompt.com`:

1. In Cloudflare DNS for `mostlyprompt.com`, add:

| Type | Name | Content | Proxy |
|---|---|---|---|
| A | `n8n` | `152.67.xxx.xxx` | Proxied (orange) |

2. In your `Caddyfile`, add a block for `n8n.mostlyprompt.com` pointing to the n8n container.

3. In your `.env`, set `N8N_HOST=n8n.mostlyprompt.com`.

> **Warning:** n8n's interface is sensitive. Put it behind basic auth or restrict access to your IP. Never expose n8n to the public internet without authentication — anyone with access can execute arbitrary code via n8n workflows.

---

## 8. Cloudflare Caching Tips (Optional)

### 8.1 Default Caching Behavior

Cloudflare caches static assets (images, CSS, JS) by default. Dynamic HTML pages from Ghost are typically not cached. This is fine for most blog setups.

### 8.2 Cache Rules for Ghost Admin

Ghost's admin interface (`/ghost/`) must never be cached — logged-in sessions would break. Cloudflare should bypass cache for this automatically (it doesn't cache authenticated requests), but you can add an explicit rule:

1. Go to **Caching** → **Cache Rules** in Cloudflare.
2. Click **Create rule**.
3. Set condition: **URI Path starts with** `/ghost/`
4. Set action: **Bypass cache**
5. Save.

### 8.3 Purge Cache When Needed

If you update content and visitors still see the old version:

1. Go to **Caching** → **Configuration**.
2. Click **Purge Everything** to clear Cloudflare's cache.

Or purge just specific URLs if you know which pages changed.

### 8.4 Development Mode

When actively making changes to your site's theme or configuration, enable **Development Mode** temporarily:

1. Go to **Caching** → **Configuration**.
2. Enable **Development Mode**.

This bypasses Cloudflare's cache for 3 hours so you can see changes immediately. Remember to disable it when done.

---

## 9. Per-Domain Checklist

Use this checklist for each domain you set up:

- [ ] Domain added to Cloudflare
- [ ] Hostinger nameservers updated to Cloudflare's nameservers
- [ ] Cloudflare shows domain as "Active"
- [ ] A record added: `@` → Oracle VM IP, Proxied
- [ ] CNAME added: `www` → `@`, Proxied
- [ ] SSL/TLS mode set to "Full (strict)"
- [ ] "Always Use HTTPS" disabled (Caddy handles it)
- [ ] Caddy config includes a block for this domain
- [ ] SSL certificate issued (check `docker compose logs caddy`)
- [ ] Site loads over HTTPS in browser

---

## Troubleshooting

### "Too many redirects" error in browser (ERR_TOO_MANY_REDIRECTS)

**Cause:** Cloudflare SSL mode is set to "Flexible". Cloudflare sends HTTP to Caddy, Caddy redirects to HTTPS, Cloudflare sends HTTP again — infinite loop.

**Fix:** Set Cloudflare SSL mode to **Full (strict)** (Section 4.1).

### Site shows "SSL handshake failed" or certificate error

**Cause:** Caddy hasn't obtained a certificate yet, or obtained one for the wrong domain.

**Fix:**
1. Check Caddy logs: `docker compose logs caddy`
2. Ensure the domain in your `Caddyfile` matches the domain exactly
3. Ensure port 80 is open (Caddy needs it for the Let's Encrypt HTTP-01 challenge)
4. Wait a few minutes — certificate issuance can take up to 1 minute after first request

### DNS not propagating / site not loading

**Cause:** Nameserver change hasn't propagated yet, or Cloudflare hasn't activated the domain.

**Fix:**
1. Wait up to 24 hours (usually much faster, under 1 hour)
2. Check Cloudflare dashboard — does it show the domain as "Active"?
3. Check [dnschecker.org](https://dnschecker.org) for your domain
4. Try clearing your browser's DNS cache: in Chrome, go to `chrome://net-internals/#dns` and click "Clear host cache"

### Cloudflare shows domain as "Pending Nameserver Update"

**Cause:** Hostinger hasn't propagated the nameserver change yet.

**Fix:** Wait. Check Hostinger's domain panel to confirm you saved the nameserver change correctly. Typically resolves within 1–2 hours.

### Ghost admin is broken / login doesn't work after enabling Cloudflare

**Cause:** Cloudflare is caching the admin session or interfering with cookies.

**Fix:**
1. Add a Cache Rule to bypass cache for `/ghost/` (Section 8.2)
2. Make sure your Ghost `url` config uses `https://` — Ghost generates session cookies based on its configured URL

---

## Quick Reference

| Setting | Value |
|---|---|
| Cloudflare SSL mode | Full (strict) |
| Proxy status | Proxied (orange cloud) for all web domains |
| Root domain record | A record, `@` → Oracle VM public IP |
| www record | CNAME, `www` → `@` |
| Always Use HTTPS | OFF (Caddy handles it) |
| Automatic HTTPS Rewrites | ON |
| Cache Admin area | Bypass cache for `/ghost/` |

---

## What's Next

With Cloudflare set up and DNS propagated:

- **ghost-instance.md** — Complete Ghost's setup wizard for each site
- **n8n-setup.md** — Configure n8n and import the PressPilot automation workflows
