# Payments & Monetization

This guide covers the monetization options available for PressPilot's Ghost blogs, with specific attention to what works for Bangladesh-based operators. It also clarifies the payment approach for other PressPilot properties (squarebrowser.com, future Next.js apps).

---

## Table of Contents

1. [Ghost Membership System Overview](#1-ghost-membership-system-overview)
2. [The Stripe Situation in Bangladesh](#2-the-stripe-situation-in-bangladesh)
3. [Recommended Option: LemonSqueezy](#3-recommended-option-lemonsqueeezy)
4. [Alternative: Paddle](#4-alternative-paddle)
5. [Connecting LemonSqueezy to Ghost](#5-connecting-lemonsqueeezy-to-ghost)
6. [Free Newsletter Tiers (Start Here)](#6-free-newsletter-tiers-start-here)
7. [Google AdSense — Simplest Monetization for Content Blogs](#7-google-adsense--simplest-monetization-for-content-blogs)
8. [squarebrowser.com — Android App Monetization](#8-squarebrowsercom--android-app-monetization)
9. [Future: aimovi.com as a Next.js Directory App](#9-future-aimovicom-as-a-nextjs-directory-app)
10. [Monetization Comparison Table](#10-monetization-comparison-table)
11. [Recommended Rollout Order](#11-recommended-rollout-order)

---

## 1. Ghost Membership System Overview

Ghost has a built-in member and subscription system. It is powerful and requires no extra plugins or code — it is baked into every Ghost 5.x installation.

**What Ghost memberships give you:**

- **Email newsletter**: Send posts to subscribers via email (requires SMTP — see below)
- **Free members**: Visitors can sign up with email for free. Great for building an audience before you monetize.
- **Paid tiers**: You can define paid subscription tiers (e.g. "$5/month for full access"). Ghost handles the membership logic, but it needs a payment processor to actually charge the card.
- **Member-only content**: Mark specific posts as members-only or paid-only. Visitors see a paywall.
- **Ghost Portal**: A floating widget on your site (signup button, account management) that appears automatically — no coding required.

**What Ghost does NOT include:**

- A built-in payment processor. Ghost outsources this to Stripe (default) — or, as you will see below, alternatives for Bangladesh operators.

**SMTP requirement:**

Ghost's newsletter and membership features require a working SMTP server to send emails. Without SMTP:
- Members cannot verify their email addresses
- You cannot send newsletters
- Password reset does not work

PressPilot plans to use **Mailgun free tier** for this. Until SMTP is configured, Ghost memberships will not function — but the blog itself will work fine for public readers.

See `docs/ghost-instance.md` for the Mailgun SMTP setup steps.

---

## 2. The Stripe Situation in Bangladesh

> **Warning:** As of 2026, **Stripe does not support Bangladesh as a country for payouts**. This means you cannot create a Stripe account that pays out to a Bangladeshi bank account. Stripe's supported countries list does not include Bangladesh for merchants/sellers.

Specifically:
- You **cannot** receive Stripe payouts to a Bangladeshi bank account.
- You **cannot** create a Stripe account registered to a Bangladesh business entity.
- Ghost's default payment integration uses Stripe exclusively — the Ghost Portal payment flow is designed around Stripe Connect.

This is not a Visa/Mastercard restriction. The issue is that Stripe does not have payout infrastructure in Bangladesh, regardless of your card type.

**What this means for PressPilot:**
Ghost's built-in paid membership tier (the one you configure under Ghost Admin → Settings → Membership) is tied to Stripe. Do not use it — you will hit a wall at payout time.

Instead, use one of the alternatives documented below.

> **Note:** This situation may change in the future. Stripe occasionally expands to new countries. Check [stripe.com/global](https://stripe.com/global) periodically if you want to use the native Ghost membership integration.

---

## 3. Recommended Option: LemonSqueezy

[LemonSqueezy](https://lemonsqueeezy.com) is a merchant of record platform that supports sellers from Bangladesh. As a "merchant of record," LemonSqueezy takes legal responsibility for collecting and remitting taxes (VAT, GST) globally — you do not have to deal with international tax compliance.

**Why LemonSqueezy works for Bangladesh:**
- Accepts sellers from Bangladesh
- Supports international bank wire transfers for payouts (no local bank account required in the US/EU)
- Handles VAT/GST automatically — customers worldwide pay correct tax
- Simple flat fee model (5% + payment processing — no monthly fee)
- Reliable API and webhook system, compatible with custom Ghost integration

### Setting Up LemonSqueezy

**Step 1: Create your account**

1. Go to [app.lemonsqueeezy.com](https://app.lemonsqueeezy.com) and sign up.
2. Complete account verification — you will need to provide your name, country (Bangladesh), and bank details.
3. For payouts, LemonSqueezy supports **SWIFT/international wire transfer**. Use your Bangladeshi bank's SWIFT code. Most major Bangladeshi banks (Dutch-Bangla, BRAC, Eastern Bank, City Bank) support international SWIFT transfers.

**Step 2: Create a Store**

1. In the dashboard, go to **Stores → Add Store**.
2. Name it after your blog (e.g. `MostlyPrompt`).
3. Set the currency (USD is recommended for international audiences).

**Step 3: Create a Subscription Product**

1. Go to **Products → Add Product**.
2. Set the **Product type** to **Subscription**.
3. Configure your tiers. Example for a content blog:
   ```
   Free tier:    $0/month — newsletter subscriber, public posts only
   Supporter:    $5/month — all posts, no ads, supporter badge
   Pro:          $15/month — all posts + monthly "best prompts" PDF download
   ```
4. For each paid tier, click **Add variant** and set the monthly price.
5. Click **Save**.

**Step 4: Get Your API Keys**

1. Go to **Settings → API**.
2. Click **Generate new API key**.
3. Copy the key and save it in your `.env` file:
   ```env
   LEMONSQUEEZY_API_KEY=your_api_key_here
   LEMONSQUEEZY_STORE_ID=12345
   LEMONSQUEEZY_PRODUCT_ID=67890
   ```
4. Go to **Settings → Webhooks** → **Add webhook**.
5. Set the URL to where you will handle webhooks (e.g. `https://n8n.yourdomain.com/webhook/lemonsqueezy`).
6. Select these events: `subscription_created`, `subscription_updated`, `subscription_cancelled`.
7. Copy the signing secret.

---

## 4. Alternative: Paddle

[Paddle](https://paddle.com) is another merchant of record platform that supports Bangladesh sellers. It is similar to LemonSqueezy but is aimed at larger businesses and has a higher minimum payout threshold.

**Paddle vs LemonSqueezy comparison:**

| Feature | LemonSqueezy | Paddle |
|---|---|---|
| Bangladesh support | Yes | Yes |
| Fee structure | 5% + processing | 5% + processing (similar) |
| Minimum payout | Low | Higher (~$100 minimum) |
| Best for | Small/solo creators | Larger software products |
| API quality | Modern REST API | Mature, well-documented |
| Tax handling | Yes (MoR) | Yes (MoR) |
| Setup complexity | Simple | Moderate |

**Recommendation:** Use **LemonSqueezy** first. It has a simpler setup, lower payout minimums, and is widely used by solo content creators. Switch to Paddle later if your revenue scales and you need Paddle-specific features.

**Paddle setup:**

1. Go to [paddle.com](https://paddle.com) → **Get Started**.
2. Fill in business details (Bangladesh is accepted under "individual seller" or company registration if you have one).
3. Create a **Subscription Plan** under your product.
4. Get your Vendor ID and API key from **Developer Tools → Authentication**.
5. Set up a webhook endpoint for subscription events.

---

## 5. Connecting LemonSqueezy to Ghost

Ghost does not have a native LemonSqueezy integration. There are two approaches:

### Approach A: Ghost Portal + LemonSqueezy Checkout (Hybrid — Recommended)

This is the most practical approach. Ghost handles free members (email collection) and LemonSqueezy handles paid subscriptions. They work in parallel.

**How it works:**
1. Visitor signs up free via Ghost Portal (standard Ghost signup)
2. For paid tiers, Ghost Portal redirects to a **LemonSqueezy checkout link** instead of a Stripe checkout
3. After successful payment, LemonSqueezy fires a webhook
4. n8n (or a small webhook handler) receives the webhook and calls the Ghost Admin API to upgrade the member to a paid tier in Ghost

**Setup steps:**

1. **Ghost Portal configuration** (Ghost Admin → Settings → Portal):
   - Enable portal and free signup
   - Under paid tiers, add a custom link button pointing to your LemonSqueezy product checkout URL:
     ```
     https://yourstorename.lemonsqueeezy.com/checkout/buy/your-product-variant-id
     ```

2. **Create an n8n webhook workflow**:
   - Add an **n8n Webhook** node (POST, path: `/lemonsqueezy`)
   - Validate the webhook signature using the signing secret:
     ```javascript
     const crypto = require('crypto');
     const signature = $input.headers['x-signature'];
     const body = $input.rawBody;
     const secret = $env.LEMONSQUEEZY_WEBHOOK_SECRET;
     const expected = crypto.createHmac('sha256', secret).update(body).digest('hex');
     if (signature !== expected) throw new Error('Invalid webhook signature');
     ```
   - On `subscription_created`: call Ghost Admin API to mark the member as paid
   - On `subscription_cancelled`: downgrade the member back to free

3. **Ghost Admin API — Update member tier**:
   ```
   PUT https://yourdomain.com/ghost/api/admin/members/{member_id}/
   Headers:
     Authorization: Ghost {jwt_token}
   Body:
     { "members": [{ "tiers": [{ "id": "your_paid_tier_id" }] }] }
   ```

> **Note:** Ghost Admin API authentication uses JWT tokens, not the raw API key directly. See the Ghost Admin API docs at `ghost.org/docs/admin-api` for how to generate a JWT from your Admin API key.

### Approach B: Standalone LemonSqueezy Checkout (Simpler)

Skip Ghost memberships entirely and use LemonSqueezy as a standalone paywall:

1. Sell access via LemonSqueezy
2. Deliver a private newsletter or private Ghost members area via email invite
3. Use LemonSqueezy's License Key or "Customer portal" to manage access

This requires less integration work but the experience is less seamless for members.

---

## 6. Free Newsletter Tiers (Start Here)

> **Tip:** Before setting up paid tiers, spend the first 1–3 months building a free subscriber list. Free members are easier to grow and they establish your audience before you ask anyone for money.

Ghost makes free newsletters easy:

1. **Enable membership** in Ghost Admin → Settings → Membership.
2. Set the **default plan** to "Free only" — visitors can sign up but there are no paid tiers yet.
3. Configure **Ghost Portal** to show the signup form.
4. Write and send **email newsletters** from Ghost Admin → Email newsletter.

**The funnel:**

```
Blog reader → Free newsletter subscriber → (paid upsell later)
```

Once you have 500+ free subscribers and are publishing consistently, adding a paid tier converts 1–5% of free members to paid — that is 5–25 paying customers for every 500 free subscribers, at zero marginal cost.

**SMTP requirement reminder:**

For newsletters to work, configure Mailgun in Ghost:

```
Ghost Admin → Settings → Email newsletter → Mailgun settings
  SMTP host:  smtp.mailgun.org
  SMTP port:  587
  SMTP user:  postmaster@mg.yourdomain.com
  SMTP pass:  (from Mailgun dashboard)
```

Mailgun free tier gives you 100 emails/day (3,000/month) — plenty to start.

---

## 7. Google AdSense — Simplest Monetization for Content Blogs

If you do not want to manage subscriptions at all, **Google AdSense** is the simplest path to revenue for content blogs.

**Advantages:**
- No payment processing to set up
- No subscription management
- Works anywhere in the world, including Bangladesh — AdSense pays to a Bangladesh bank account via EFT or check
- Revenue scales automatically with traffic
- AdSense approval is the main hurdle (requires original content and some existing traffic)

**AdSense vs Memberships comparison:**

| | Google AdSense | Paid Memberships (LemonSqueezy) |
|---|---|---|
| Setup complexity | Low | High |
| Works in Bangladesh | Yes (EFT payout) | Yes (SWIFT) |
| Revenue per visitor | Low (~$0.001–0.005/pageview) | Higher (depends on conversion) |
| Traffic needed to earn | High (50k+ pageviews/month) | Low (even 10 paying members = $50/mo) |
| Content restrictions | Moderate (AdSense policies) | None |
| Best for | High-traffic, broad-topic blogs | Niche, loyal audience blogs |

**Setting up AdSense on Ghost:**

1. Apply at [adsense.google.com](https://adsense.google.com). You need an existing site with original content (typically 20+ published posts helps approval).
2. Once approved, get your AdSense Publisher ID (`ca-pub-XXXXXXXXXXXXXXXX`).
3. In Ghost Admin → Settings → Code injection → Site Header, add the AdSense auto-ads script:
   ```html
   <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-XXXXXXXXXXXXXXXX" crossorigin="anonymous"></script>
   ```
4. AdSense auto-ads will automatically place ads on your pages.

> **Warning:** AdSense and paid memberships can conflict. AdSense requires content to be publicly accessible for ads to show. If you put most content behind a paywall, AdSense may not place ads (or may reject your application). Run ads on public posts and save paywalled content for paid tiers.

---

## 8. squarebrowser.com — Android App Monetization

> **Note:** This section is for reference only. `squarebrowser.com` is a static landing page on Vercel and is not part of the Ghost/PressPilot setup. Do not touch the Vercel deployment or DNS for this domain.

The Square Browser Android app ([Google Play](https://play.google.com/store/apps/details?id=com.squarebrowser.app)) is monetized through **Google Play in-app purchases**, not Ghost memberships.

**Relevant tools:**
- **RevenueCat** (`revenuecat.com`): SDK that abstracts in-app purchase management across Google Play (and App Store). Handles subscription logic, entitlements, and webhook events. If/when in-app purchases are added to Square Browser, RevenueCat is the recommended implementation.
- **Google Play Billing**: The underlying payment system. Payouts from Google Play to Bangladesh work via international wire transfer or check.

RevenueCat and Ghost/PressPilot are completely separate systems and share no infrastructure.

---

## 9. Future: aimovi.com as a Next.js Directory App

If `aimovi.com` becomes a Next.js AI directory app (instead of a Ghost blog), payments would be handled at the application layer, not through Ghost memberships.

**Options for a Next.js directory app:**
- **LemonSqueezy**: Works well with Next.js — use their `@lemonsqueeezy/lemonsqueeezy.js` SDK
- **Paddle**: Similarly integrates with Next.js via their JS SDK
- **Lemon.js** (LemonSqueezy's checkout overlay): Embed a checkout modal directly in the Next.js app

This is a future concern. The core PressPilot stack (Ghost blogs + n8n automation) does not depend on this decision.

---

## 10. Monetization Comparison Table

| Method | Bangladesh Payout | Setup Effort | Revenue Potential | Best For |
|---|---|---|---|---|
| Google AdSense | Yes (EFT/check) | Low | Low–Medium (needs traffic) | High-traffic, public blogs |
| LemonSqueezy (memberships) | Yes (SWIFT) | Medium | Medium–High | Niche audience blogs |
| Paddle (memberships) | Yes (SWIFT) | Medium | Medium–High | Larger scale |
| Ghost native (Stripe) | **No** (Bangladesh blocked) | N/A | N/A | Not usable |
| Google Play IAP (RevenueCat) | Yes (separate payout) | High | App-dependent | squarebrowser.com only |

---

## 11. Recommended Rollout Order

Follow this sequence to monetize PressPilot blogs sustainably:

**Phase 1 — Build audience (months 1–3):**
- Enable Ghost Portal with free membership only
- Configure Mailgun SMTP so newsletter works
- Publish consistently via n8n automation
- Goal: 200+ free subscribers per blog

**Phase 2 — Add AdSense (month 2+, once 20+ posts exist):**
- Apply for AdSense
- Add auto-ads script via Ghost Code Injection
- Start earning from traffic without subscription friction

**Phase 3 — Add paid tiers (month 4+, once audience trusts you):**
- Create LemonSqueezy account and store
- Set up subscription products ($5–$15/month)
- Build the Ghost ↔ LemonSqueezy webhook integration in n8n
- Announce paid tier to free newsletter subscribers
- Goal: 10–50 paying members per blog

**Phase 4 — Optimize:**
- A/B test pricing
- Add annual plans (LemonSqueezy supports yearly subscriptions)
- Consider removing AdSense from paid-tier content to improve experience for subscribers
- Explore sponsorships as traffic grows (often more lucrative than AdSense at 10k+ monthly readers)

> **Tip:** Do not skip Phase 1 and 2 by jumping straight to paid tiers. A blog with 20 posts and 0 subscribers will not convert paid members. Build the free audience first — then the conversion to paid is straightforward.
