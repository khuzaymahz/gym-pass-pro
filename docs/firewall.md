# Firewall & VM hardening plan — GymPass staging/prod

Operator runbook for locking down the single Contabo VPS that hosts the
GymPass stack (`35.203.162.232`, behind Cloudflare). Pair this with
[`docs/deploy.md`](deploy.md) (bring-up) and
[`docs/operations.md`](operations.md) (day-2).

The plan has two layers:

1. **Cloudflare** — first hit, drops obvious junk and rate-limits before
   anything reaches the VM. Free.
2. **Host firewall (ufw + Docker iptables hardening)** — last word.
   What ufw allows is the *only* thing the VM accepts from the
   internet, regardless of what Docker tries to publish.

Threat model: opportunistic scanners, brute-force SSH, credential
stuffing on `admin.gym-pass.net`, accidental exposure of internal
services (Adminer, Postgres, Redis, Mailu admin). Not targeted APT.

---

## 0 · Inventory — what listens on the VM

Run on the VM before/after changes to confirm reality matches this doc:

```bash
sudo ss -tulpn | grep LISTEN
sudo iptables -L DOCKER-USER -n --line-numbers
sudo ufw status verbose
```

Expected externally-reachable ports after this plan is applied:

| Port  | Proto | Service              | Source           | Notes                                   |
|-------|-------|----------------------|------------------|-----------------------------------------|
| 22    | tcp   | OpenSSH              | operator IPs     | Key-only, rate-limited                  |
| 80    | tcp   | nginx (HTTP → 301)   | Cloudflare only  | Only used for HTTP→HTTPS redirect       |
| 443   | tcp   | nginx (HTTPS)        | Cloudflare only  | Origin Cert, all four web vhosts        |
| 25    | tcp   | Mailu SMTP (inbound) | `0.0.0.0/0`      | Only if mail overlay loaded             |
| 465   | tcp   | Mailu SMTPS          | `0.0.0.0/0`      | Only if mail overlay loaded             |
| 587   | tcp   | Mailu submission     | `0.0.0.0/0`      | Only if mail overlay loaded             |
| 993   | tcp   | Mailu IMAPS          | `0.0.0.0/0`      | Only if mail overlay loaded             |
| 143   | tcp   | Mailu IMAP+STARTTLS  | `0.0.0.0/0`      | Only if mail overlay loaded             |
| 4190  | tcp   | Mailu Sieve          | operator IPs     | Optional; drop entirely if not used     |

Everything else (Postgres 5432, Redis 6379, Adminer 8080, backend 8000,
admin 3000, partner 3001, website 3002) **must not be reachable from
the public IP**. Adminer is already loopback-bound (`127.0.0.1:8080`)
in `docker-compose.yml`; the app + DB + cache services are
`ports: !reset []` in `docker-compose.staging.yml` so they're only on
the internal Docker network.

---

## 1 · VM bootstrap order

The order matters — apply SSH hardening **before** opening the firewall,
or you can lock yourself out.

```
0. Snapshot the VM (Contabo panel).
1. Create a non-root operator user with sudo + SSH key.
2. Harden sshd_config (key-only, no root login).
3. Configure ufw rules with SSH allowed FIRST.
4. Enable ufw.
5. Reboot and re-verify SSH still works from a second terminal
   BEFORE closing your current session.
6. Install fail2ban (SSH jail) and unattended-upgrades.
7. Patch Docker's iptables behavior so `ports:` in compose can't
   silently bypass ufw.
```

If step 5 fails, you have ~30 minutes via the Contabo serial console
to revert before the snapshot from step 0 is your fallback.

---

## 2 · SSH hardening

`/etc/ssh/sshd_config.d/99-gympass.conf` (a drop-in, so the distro's
base config keeps tracking updates):

```conf
# Identity
Port 22
AddressFamily inet
ListenAddress 0.0.0.0

# Auth — keys only
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
PubkeyAuthentication yes

# Session
MaxAuthTries 3
LoginGraceTime 20
MaxSessions 4
ClientAliveInterval 300
ClientAliveCountMax 2

# Forwarding — off unless we need it
AllowAgentForwarding no
AllowTcpForwarding yes        # leave on; we rely on -L tunnels (Adminer)
X11Forwarding no

# Users
AllowUsers khuzaymah
```

Apply:

```bash
sudo install -d -m 0755 /etc/ssh/sshd_config.d
sudo nano /etc/ssh/sshd_config.d/99-gympass.conf   # paste above
sudo sshd -t                                       # syntax-check
sudo systemctl reload ssh
```

Open a **second terminal** and SSH back in before closing the first.
If the new session works, you're safe.

> Optional: change the SSH port from 22 to something high (e.g.
> `2222`). Doesn't add real security but cuts scanner log noise by
> ~95%. If you do, update the ufw rule in §3 and the Cloudflare
> `Spectrum` config if you use it.

---

## 3 · `ufw` ruleset

The base policy: deny inbound, allow outbound, allow established. Then
explicit allows for the surfaces we serve.

```bash
# Reset to a clean state (only do this when you're certain you have
# console access — a typo here can lock you out).
sudo ufw --force reset

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw default deny routed

# --- SSH (FIRST — do this before enabling) -----------------------------
# Replace 0.0.0.0/0 with your operator IPs if you have a static one.
# `limit` adds a rate-limit (6 conns / 30s per source IP) — cheap
# brute-force defence on top of fail2ban.
sudo ufw limit 22/tcp comment 'SSH (rate-limited)'

# --- Web (Cloudflare → nginx) ------------------------------------------
# Restricted to Cloudflare's published IP ranges so anyone hitting
# the origin IP directly gets dropped. Updated via the helper in §4.
for ip in $(curl -s https://www.cloudflare.com/ips-v4); do
  sudo ufw allow from "$ip" to any port 80  proto tcp comment 'CF HTTP'
  sudo ufw allow from "$ip" to any port 443 proto tcp comment 'CF HTTPS'
done

# --- Mail (Mailu) — only if mail overlay is loaded ---------------------
# SMTP must be open to the world (other mail servers connect inbound).
# Submission + IMAP could in theory be locked to operator IPs, but
# that breaks mobile clients on hotel/cellular networks.
sudo ufw allow 25/tcp   comment 'SMTP'
sudo ufw allow 465/tcp  comment 'SMTPS'
sudo ufw allow 587/tcp  comment 'Submission'
sudo ufw allow 993/tcp  comment 'IMAPS'
sudo ufw allow 143/tcp  comment 'IMAP STARTTLS'

# Sieve — operator-only if you use Roundcube filters; drop otherwise.
# sudo ufw allow from <OPERATOR_IP>/32 to any port 4190 proto tcp \
#    comment 'Mailu Sieve (operator)'

# --- ICMP (optional) ---------------------------------------------------
# ufw allows ICMP echo by default via /etc/ufw/before.rules. Leave it
# on so monitoring + traceroute work.

# --- Enable -----------------------------------------------------------
sudo ufw --force enable
sudo ufw status verbose
```

### What gets denied implicitly

- Postgres 5432, Redis 6379, backend 8000, admin 3000, partner 3001,
  website 3002 — never published in `docker-compose.staging.yml`.
- Adminer 8080 — bound to `127.0.0.1` only.
- Mailu admin/webmail — only on 443 via the nginx mail vhost (see
  [`docs/mail.md`](mail.md)).
- Anything else Docker might try to publish (see §5).

---

## 4 · Cloudflare IP-list refresh

Cloudflare rotates their IP ranges occasionally. Pin them once at
bootstrap, then re-sync weekly. A 50-line script in
`scripts/refresh-cloudflare-ufw.sh`:

```bash
#!/usr/bin/env bash
# Refresh ufw rules for Cloudflare IPv4 ranges.
# Idempotent: deletes the old CF rules, adds the current ones.
set -euo pipefail

mark_http='CF HTTP'
mark_https='CF HTTPS'

# Pull the canonical lists.
mapfile -t ips < <(curl -fsS https://www.cloudflare.com/ips-v4)

# Drop existing CF-marked rules (look them up by comment).
while ufw status numbered | grep -E "${mark_http}|${mark_https}" -q; do
  num=$(ufw status numbered \
        | grep -E "${mark_http}|${mark_https}" \
        | head -1 \
        | sed -E 's/^\[\s*([0-9]+)\].*/\1/')
  yes | ufw delete "$num"
done

# Re-add for the current list.
for ip in "${ips[@]}"; do
  ufw allow from "$ip" to any port 80  proto tcp comment "$mark_http"
  ufw allow from "$ip" to any port 443 proto tcp comment "$mark_https"
done

ufw reload
```

Cron, weekly:

```cron
0 4 * * 1 cd /opt/gympass && bash scripts/refresh-cloudflare-ufw.sh \
          >> /var/log/cf-ufw-refresh.log 2>&1
```

The window between Cloudflare adding a new range and our cron picking
it up is at worst 7 days; Cloudflare announces changes weeks ahead, so
this is fine for staging. For production, drop to daily.

---

## 5 · Docker + ufw — fixing the silent bypass

Docker manipulates iptables directly and **inserts its own rules above
ufw's**. A service with `ports: - "5432:5432"` in compose will be
publicly reachable even when ufw says `5432/tcp DENY`. This has bitten
us before — it's why the staging overlay uses `ports: !reset []` on
everything except nginx and mail.

Two belt-and-braces fixes:

### 5.1 — `DOCKER-USER` chain

Docker honours rules added to the `DOCKER-USER` chain (Docker docs
guarantee this). Drop anything that wasn't explicitly allowed:

```bash
sudo iptables -I DOCKER-USER -i eth0 -j ufw-user-input
sudo iptables -A DOCKER-USER -i eth0 -j DROP
```

Persist via `iptables-persistent`:

```bash
sudo apt install -y iptables-persistent
sudo netfilter-persistent save
```

Now even if someone accidentally adds `ports: - "5432:5432"` to a
compose file, ufw's deny rule applies because the packet is filtered
through `ufw-user-input` before Docker's NAT rules.

### 5.2 — bind to `127.0.0.1` in compose

Defence in depth. For any service that *must* publish a port but
shouldn't be public, use `"127.0.0.1:<port>:<port>"` (the bind address
prefix). Examples already in this repo:

```yaml
adminer:
  ports:
    - "127.0.0.1:8080:8080"   # loopback only
```

Code review rule: any new `ports:` entry without an IP prefix must
either be `80`/`443`/Mailu (publicly intended) or get a `# 127.0.0.1`
prefix. Anything else is a bug.

---

## 6 · fail2ban (SSH brute-force)

`/etc/fail2ban/jail.d/sshd.local`:

```ini
[sshd]
enabled  = true
port     = ssh
filter   = sshd
backend  = systemd
maxretry = 4
findtime = 10m
bantime  = 1h
ignoreip = 127.0.0.1/8 ::1
```

```bash
sudo apt install -y fail2ban
sudo systemctl enable --now fail2ban
sudo fail2ban-client status sshd       # confirm the jail is active
```

ufw's `limit 22/tcp` already throttles, but fail2ban gives you an
explicit list of banned IPs you can inspect and audit. Don't run
both at full aggression — `ufw limit` handles the burst, fail2ban
handles the sustained.

We don't run a fail2ban jail for nginx because Cloudflare already
absorbs the volumetric brute-force at its edge; adding one on the
origin just creates duplicate state and false positives.

---

## 7 · Unattended security upgrades

Auto-apply critical security patches; do NOT auto-reboot (we don't
want surprise restarts).

```bash
sudo apt install -y unattended-upgrades apt-listchanges
sudo dpkg-reconfigure --priority=low unattended-upgrades   # → Yes
```

`/etc/apt/apt.conf.d/52unattended-upgrades-local`:

```conf
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Mail "root";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
```

Reboot status check (run from operator habit, weekly):

```bash
ls /var/run/reboot-required 2>/dev/null && echo "Reboot pending"
```

---

## 8 · Cloudflare-side rules (defence layer 1)

In the Cloudflare dashboard for the `gym-pass.net` zone:

### 8.1 SSL/TLS
- **Mode:** Full (strict).
- **Minimum TLS version:** 1.2.
- **Always Use HTTPS:** on.
- **Authenticated Origin Pulls:** on, with the cert pinned in
  nginx (`ssl_client_certificate cloudflare-origin-pull-ca.pem`,
  `ssl_verify_client on`). Means anyone hitting the origin IP
  directly without the CF client cert gets 403 even if the IP
  firewall fails open.

### 8.2 Security
- **Bot Fight Mode:** on (free plan) or Super Bot Fight Mode (paid).
- **Security Level:** Medium (Essentially Off for `api.gym-pass.net`
  if it gets in the way of legitimate mobile traffic).
- **Browser Integrity Check:** on.

### 8.3 WAF custom rules

| Rule | Expression | Action |
|------|------------|--------|
| Block direct admin login bots | `(http.host eq "admin.gym-pass.net") and (cf.threat_score gt 30)` | Block |
| Rate-limit OTP requests | `(http.host eq "api.gym-pass.net") and (http.request.uri.path eq "/api/v1/auth/otp")` | Rate-limit: 5 req / min / IP |
| Rate-limit login | `(http.request.uri.path contains "/login") and (http.request.method eq "POST")` | Rate-limit: 10 req / 5 min / IP |
| Geo-block `admin.*` outside JO/operator GEOs | `(http.host eq "admin.gym-pass.net") and (ip.geoip.country ne "JO")` | Managed Challenge |

These are reversible from the dashboard in seconds if they break a
real user — keep the rule comments useful.

### 8.4 DNS

The four A records are proxied (orange cloud). Don't add unproxied
records for `gym-pass.net` subdomains unless they're mail-related —
unproxied = origin IP leaked.

Mail records (`mail.gym-pass.net`, MX, SPF, DKIM, DMARC) are
necessarily unproxied because Cloudflare doesn't proxy SMTP. The
origin IP for `mail.gym-pass.net` is the only public clue to the VM's
IP, and that's unavoidable.

---

## 9 · App-layer rate limits (defence layer 3)

Belt-and-braces with the Cloudflare WAF rules in §8.3 — the backend
itself enforces:

- **OTP endpoint** (`POST /api/v1/auth/otp/request`) — 5 per phone
  per 10 minutes. Already enforced in `backend/app/services/otp.py`.
- **Login endpoint** (`POST /api/v1/auth/login`) — 10 per IP per 5
  minutes, sliding window. Backed by Redis.
- **Admin session exchange** — `POST /api/v1/admin/session-token`.
  Requires a valid NextAuth session cookie; 50 / IP / minute upper
  bound.

If Cloudflare gets bypassed (Authenticated Origin Pulls failed, IP
firewall failed, attacker pivots through a compromised CF account),
these are what's left. They're not a substitute for §8.3 — they're a
last line.

---

## 10 · Audit + drift detection

A weekly check that the firewall is doing what we think:

```bash
# scripts/firewall-audit.sh — run from cron weekly.
set -euo pipefail

echo "=== ufw status ==="
sudo ufw status verbose

echo "=== Listening sockets (should match docs/firewall.md §0) ==="
sudo ss -tulpn | grep LISTEN

echo "=== DOCKER-USER chain (should DROP unmatched) ==="
sudo iptables -L DOCKER-USER -n --line-numbers

echo "=== fail2ban (sshd jail) ==="
sudo fail2ban-client status sshd

echo "=== Recent ufw blocks (last 24h) ==="
sudo journalctl --since "24 hours ago" -u ufw | tail -40

echo "=== Outbound test — origin should reach app.cloudflare.com ==="
curl -sI https://api.cloudflare.com/client/v4/ips | head -1
```

Cron, weekly, mail the diff to the operator:

```cron
0 6 * * 1 cd /opt/gympass && bash scripts/firewall-audit.sh \
          | mail -s "GymPass firewall audit $(date +%F)" you@example.com
```

If `ss` shows a port that isn't in §0, **investigate before
anything else** — that's almost always either a compose bug or a
compromise indicator.

---

## 11 · Rollback / break-glass

If a firewall change locks you out:

1. **Contabo VNC console** — `https://my.contabo.com` → VPS → Console.
   You're root via the password from the panel; no SSH required.
2. From the console:
   ```bash
   sudo ufw disable
   sudo systemctl restart ssh
   ```
3. SSH back in, fix the rule, re-enable.

If iptables-persistent is misbehaving (e.g. `DOCKER-USER` drop rule
broke web traffic):

```bash
sudo iptables -F DOCKER-USER
sudo iptables -A DOCKER-USER -j RETURN     # Docker's default
sudo netfilter-persistent save
```

Then re-derive §5.1 carefully.

If Cloudflare Origin-Pull TLS verification breaks (`ssl_verify_client`
returning 400/403 for legitimate traffic): comment the
`ssl_client_certificate` + `ssl_verify_client` lines in
`nginx/snippets/ssl.conf`, restart nginx, debug separately.

---

## 12 · What this plan does NOT do (yet)

Intentional gaps — flag them if/when they become real:

- **No host IDS** (no auditd, no Wazuh, no OSSEC). Single-VM staging;
  cost/complexity doesn't justify it. Revisit at >1 VM or first real
  customer data.
- **No outbound egress filtering.** The app makes outbound calls to
  Google OAuth, SMS provider (future), Sentry (future) — egress
  allowlisting is fragile until those endpoints are firmly chosen.
  Until then: `default allow outgoing`.
- **No automated CIS-Benchmark sweep.** Manual audit via §10 is the
  current floor.
- **No private network between containers and an external DB.** The
  DB is on-host in Docker; if/when we move to managed Postgres (RDS /
  Cloud SQL / Neon), revisit the connectivity model entirely.
- **No DDoS scrubbing beyond Cloudflare's free tier.** Acceptable
  pre-launch. For production, evaluate Cloudflare Pro or a Magic
  Transit equivalent.

These belong in [`docs/operations.md`](operations.md)'s "before
real users" checklist alongside the SMS provider / payment gateway
decisions.

---

## 13 · Quick checklist

Use this when bringing up a fresh VM, or when auditing an existing one.

- [ ] VM snapshot before any firewall change.
- [ ] Operator SSH key installed; `PasswordAuthentication no` set.
- [ ] `sshd -t` passes; second SSH session confirmed before closing
      first.
- [ ] `ufw default deny incoming` + `default allow outgoing`.
- [ ] SSH allowed (rate-limited or operator-IP-only).
- [ ] 80 + 443 allowed **only from Cloudflare IPv4 ranges**.
- [ ] Mail ports open only if `docker-compose.mail.yml` is loaded.
- [ ] `iptables-persistent` installed; `DOCKER-USER` chain ends in
      `DROP` for `eth0`.
- [ ] `ss -tulpn` matches §0 exactly — no surprise listeners.
- [ ] `fail2ban-client status sshd` shows the jail active.
- [ ] `unattended-upgrades --dry-run` runs clean.
- [ ] Cloudflare: Full (strict), Authenticated Origin Pulls on, WAF
      rules in §8.3 deployed.
- [ ] `scripts/refresh-cloudflare-ufw.sh` in weekly cron.
- [ ] `scripts/firewall-audit.sh` in weekly cron, output mailed.
- [ ] Rollback path (§11) validated — operator has Contabo VNC
      console credentials saved somewhere they can reach without
      SSH.
