# Oracle Cloud Setup Guide

Setting up an Oracle Cloud Always Free VM for PressPilot — from account creation to first SSH login.

---

## Prerequisites

- A valid email address (your Oracle account)
- A credit/debit card with international transactions enabled (required for identity verification — you will **not** be charged on the free tier)
- An SSH client: Windows 10/11 has OpenSSH built in (use PowerShell or Windows Terminal)

---

## 1. Create an Oracle Cloud Account

### 1.1 Sign up

1. Go to [cloud.oracle.com](https://cloud.oracle.com) and click **Start for free**.
2. Enter your email and country. Click **Next**.
3. Complete the profile form — name, address, phone number.
4. Verify your email via the link Oracle sends.
5. Set a password (keep it somewhere safe).

### 1.2 Choose your Home Region — Singapore (CRITICAL)

During sign-up you will be asked to select a **Home Region**.

> **Warning: The home region is locked forever the moment you complete sign-up. You cannot change it later.**
>
> Oracle Always Free ARM (Ampere) compute instances can only be provisioned in your home region. If you choose the wrong region, you will have to create a brand-new Oracle account.

**Select: `ap-singapore-1` (Japan — Singapore)**

It may appear in the dropdown as **"Asia Pacific (Singapore)"**.

[SCREENSHOT: Oracle sign-up home region dropdown with "Asia Pacific (Singapore)" highlighted]

### 1.3 Add a Payment Method

Oracle requires a credit or debit card for identity verification. A Bangladeshi Visa/Mastercard with international transactions enabled works fine. Oracle places a temporary $1 hold that is released within a few days. You will not be charged as long as you stay within Always Free limits.

> **Note:** If your card is declined, try enabling international/online transactions through your bank's app first, then retry.

### 1.4 Complete Verification

Oracle may call or SMS your phone number with a PIN to verify. Enter it when prompted. Account activation can take a few minutes to an hour.

---

## 2. Create the VM Instance

### 2.1 Navigate to Compute Instances

1. Log in to [cloud.oracle.com](https://cloud.oracle.com).
2. Open the hamburger menu (top-left) → **Compute** → **Instances**.
3. Make sure the region shown in the top-right header says **Singapore**. If it shows something else, click it and switch to Singapore.

[SCREENSHOT: Oracle Cloud top-right region selector showing "Singapore"]

### 2.2 Click "Create Instance"

Click the **Create instance** button.

[SCREENSHOT: Compute Instances list page with "Create instance" button highlighted]

### 2.3 Name the Instance

Give it a recognizable name, e.g. `presspilot-vm`.

### 2.4 Choose Availability Domain

You will see an **Availability domain** dropdown — it will show options like `AD-1`, `AD-2`, `AD-3`. The exact names look like `mCUQ:AP-SINGAPORE-1-AD-1`.

> **Note:** Remember which AD you select. If you get "Out of Capacity" errors (covered in the next section), you will need to try different ADs.

Leave it as the default for now; you can change it during retries.

### 2.5 Select Image: Ubuntu 24.04 (ARM64)

1. Under **Image and shape**, click **Change image**.
2. In the **Platform images** tab, select **Canonical Ubuntu**.
3. Change the OS version to **24.04**.

> **Important:** Make sure the image says `aarch64` or `ARM64` in the description. Do NOT select the `x86_64` image — the ARM shape will not boot it.

[SCREENSHOT: Image selection showing Ubuntu 24.04 with aarch64 highlighted]

### 2.6 Select Shape: VM.Standard.A1.Flex (Always Free ARM)

1. Click **Change shape**.
2. Under **Shape series**, select **Ampere** (the ARM option).
3. Select **VM.Standard.A1.Flex**.
4. Set:
   - **Number of OCPUs:** `4`
   - **Amount of memory (GB):** `24`

> **Note:** The Always Free tier allows up to 4 OCPUs and 24 GB RAM total across all A1 instances. Using the full allocation on one instance is perfectly valid and recommended for PressPilot.

[SCREENSHOT: Shape configuration showing 4 OCPUs and 24 GB RAM for VM.Standard.A1.Flex]

### 2.7 Set Boot Volume to 200 GB

Scroll down to **Boot volume**.

1. Check **Specify a custom boot volume size**.
2. Enter `200` GB.

> **Note:** The Always Free tier includes up to 200 GB of block storage total. If you have no other block volumes, you can use all 200 GB here.

### 2.8 Configure SSH Keys

You need an SSH key pair to log in. See [Section 4](#4-ssh-key-setup) for how to generate one.

When you have your public key ready:

1. Under **Add SSH keys**, select **Paste public keys**.
2. Paste the contents of your `.pub` file (the public key — the one that starts with `ssh-ed25519 ...`).

[SCREENSHOT: SSH key paste box with a sample key]

### 2.9 Review and Create

Scroll to the bottom and click **Create**. The instance will take 1–2 minutes to provision.

---

## 3. Handling "Out of Capacity" Errors

Oracle Always Free ARM instances are popular. You may see this error when trying to create the instance:

```
Out of host capacity.
```

This is common and expected. Oracle's free-tier ARM slots fill up quickly. **Do not give up** — there are several strategies.

### Strategy 1: Retry Across Availability Domains

Oracle Singapore has multiple Availability Domains (AD-1, AD-2, AD-3). Capacity is per-AD, so one AD may be full while another has slots.

1. Go back to **Create instance**.
2. Change the **Availability domain** to a different one (e.g. AD-2 or AD-3).
3. Try creating again.
4. Repeat for each AD.

### Strategy 2: The Retry Loop (Manual)

Many users have success by simply trying the same configuration repeatedly:

1. Fill in all instance settings.
2. Click **Create**.
3. If you get "Out of Capacity", click the browser back button.
4. Click **Create** again immediately.
5. Repeat — sometimes within 10–30 attempts you will get through as Oracle reclaims capacity from inactive accounts.

> **Tip:** Some users write a simple browser automation script or use Oracle's API/CLI to retry automatically. Searching for "Oracle always free out of capacity script" will find community-written retry tools.

### Strategy 3: Convert to Pay-As-You-Go (PAYG)

This is the most reliable fix. Upgrading to PAYG does not mean you will be charged — Oracle's Always Free resources remain free on a PAYG account. The upgrade simply removes some restrictions and tends to give better access to capacity.

1. In Oracle Cloud, click your profile avatar (top-right) → **Billing & Cost Management**.
2. Click **Upgrade and manage payment**.
3. Follow the upgrade flow. Your card will be charged $0 as long as you stay within Always Free limits.

> **Warning:** Once on PAYG, be careful not to provision resources that exceed Always Free limits (e.g. multiple large block volumes, additional VMs beyond the free allowance). Set up budget alerts in **Billing → Budgets** to notify you if spending exceeds $0.01/month.

After upgrading to PAYG, try creating the VM again — success rates are much higher.

### Strategy 4: Hetzner Fallback

If Oracle capacity remains unavailable for more than a few days, consider Hetzner Cloud (hetzner.com) as an alternative. A Hetzner CX32 (4 vCPU, 8 GB RAM) costs around €4/month and supports ARM64. PressPilot's Docker Compose stack will work identically on Hetzner.

---

## 4. SSH Key Setup (Windows)

Windows 10 and 11 include OpenSSH by default. Use PowerShell or Windows Terminal.

### 4.1 Generate an ED25519 Key Pair

Open PowerShell and run:

```powershell
ssh-keygen -t ed25519 -C "presspilot-oracle"
```

You will be prompted:

```
Enter file in which to save the key (C:\Users\YourName/.ssh/id_ed25519):
```

Press **Enter** to accept the default location, or type a custom path like `C:\Users\YourName\.ssh\presspilot_ed25519`.

```
Enter passphrase (empty for no passphrase):
```

A passphrase adds security but requires you to enter it each login. For a server you access regularly, an empty passphrase is acceptable. Press **Enter** twice to skip.

This creates two files:

| File | Description |
|---|---|
| `id_ed25519` (or your custom name) | **Private key** — never share this |
| `id_ed25519.pub` | **Public key** — this is what you paste into Oracle |

### 4.2 View the Public Key

```powershell
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub
```

Copy the entire output. It will look like:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... presspilot-oracle
```

This is what you paste into Oracle's **Add SSH keys** field when creating the instance.

---

## 5. Configure VCN Security List (Open Ports 80 and 443)

Oracle blocks all inbound traffic by default via the Virtual Cloud Network (VCN) Security List. Even if Ubuntu's own firewall allows a port, Oracle's VCN will block it first.

You must open ports **22** (SSH, probably already open), **80** (HTTP), and **443** (HTTPS).

### 5.1 Find Your VCN Security List

1. In Oracle Cloud, open the hamburger menu → **Networking** → **Virtual cloud networks**.
2. Click on your VCN (usually named `vcn-YYYYMMDD-XXXX` or similar — created automatically with your instance).
3. Click on **Security Lists** in the left panel.
4. Click on the **Default Security List**.

[SCREENSHOT: VCN Security List page showing existing ingress rules]

### 5.2 Add Ingress Rules

Click **Add Ingress Rules** and add the following rules one at a time (or together if the interface allows multiple):

**Rule 1 — HTTP**

| Field | Value |
|---|---|
| Stateless | No (unchecked) |
| Source CIDR | `0.0.0.0/0` |
| IP Protocol | TCP |
| Destination Port Range | `80` |
| Description | `HTTP for Caddy` |

**Rule 2 — HTTPS**

| Field | Value |
|---|---|
| Stateless | No (unchecked) |
| Source CIDR | `0.0.0.0/0` |
| IP Protocol | TCP |
| Destination Port Range | `443` |
| Description | `HTTPS for Caddy` |

> **Note:** SSH on port 22 should already have an ingress rule from when the instance was created. Verify it exists; if not, add it the same way with port `22`.

[SCREENSHOT: "Add Ingress Rules" form with port 443 filled in]

Click **Add Ingress Rules** to save.

> **Warning:** Without these VCN rules, your websites will be completely unreachable even if Docker, Caddy, and Ubuntu's firewall are all configured correctly. This is the #1 cause of "site not loading" issues on Oracle Cloud.

---

## 6. Connect via SSH for the First Time

Once your instance is running (green "RUNNING" status), find its **Public IP address** on the instance details page.

[SCREENSHOT: Instance details page with Public IP address highlighted]

### 6.1 Connect from Windows PowerShell

```powershell
ssh -i $env:USERPROFILE\.ssh\id_ed25519 ubuntu@YOUR_PUBLIC_IP
```

Replace `YOUR_PUBLIC_IP` with the actual IP (e.g. `152.67.xxx.xxx`).

**First connection:** You will see a fingerprint warning:

```
The authenticity of host '152.67.xxx.xxx' can't be established.
ED25519 key fingerprint is SHA256:xxxx...
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

Type `yes` and press **Enter**. This adds the server to your known hosts file.

You should now see:

```
ubuntu@presspilot-vm:~$
```

You are logged in as the `ubuntu` user with `sudo` access.

### 6.2 Save an SSH Config Entry (Optional but Recommended)

Create or edit `C:\Users\YourName\.ssh\config` and add:

```
Host presspilot
    HostName YOUR_PUBLIC_IP
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
```

After saving, you can connect with just:

```powershell
ssh presspilot
```

---

## 7. Ubuntu Firewall (iptables) — Important Note

Oracle's Ubuntu 24.04 images come with `iptables` rules that **also block ports 80 and 443** at the OS level, independent of the VCN Security List. Opening the VCN rules alone is not enough.

You must configure iptables on the server as well. This is covered in detail in [server-bootstrap.md](server-bootstrap.md), but be aware that both layers must allow traffic:

1. **Oracle VCN Security List** (done in Section 5 above)
2. **Ubuntu iptables rules** (done in server-bootstrap.md)

Both must be open for web traffic to reach your Docker containers.

---

## 8. What's Next

With your Oracle VM running and SSH access confirmed, proceed to:

- **[server-bootstrap.md](server-bootstrap.md)** — Install Docker, configure the firewall, and deploy PressPilot
- **[dns-cloudflare.md](dns-cloudflare.md)** — Point your domains to this VM via Cloudflare

---

## Quick Reference

| Setting | Value |
|---|---|
| Home region | `ap-singapore-1` (Asia Pacific — Singapore) |
| Shape | `VM.Standard.A1.Flex` |
| OCPUs | `4` |
| RAM | `24 GB` |
| Boot volume | `200 GB` |
| OS | Ubuntu 24.04 (aarch64 / ARM64) |
| Default SSH user | `ubuntu` |
| Ports to open in VCN | `22`, `80`, `443` |
