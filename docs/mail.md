# Self-hosted mail (Mailu) — operator runbook

> Status: opt-in via `docker-compose.mail.yml`. Loads on top of the
> staging compose; not part of the default dev bring-up.
> Source-of-truth files:
> [`docker-compose.mail.yml`](../docker-compose.mail.yml),
> [`.env.mail.example`](../.env.mail.example),
> [`nginx/templates/mail.conf.template`](../nginx/templates/mail.conf.template).

This document records the live setup as it exists on the VM today —
the architecture, the prerequisites we worked through to make
`mail.gym-pass.net` actually deliver, the bring-up procedure, and a
troubleshooting catalogue of every issue we hit during the original
install. If you change the topology, update this file in the same PR.

---

## 1 · What this gets you

| Capability | URL / port | Notes |
|---|---|---|
| Admin UI (manage mailboxes, aliases, domains, DKIM) | `https://mail.gym-pass.net/admin` | Initial login bootstrapped from `.env.mail` |
| Webmail (Roundcube) | `https://mail.gym-pass.net/webmail` | Same credentials as the mailbox |
| Inbound SMTP from the internet | `mail.gym-pass.net:25` | STARTTLS supported |
| Submission for outbound clients | `mail.gym-pass.net:587` (STARTTLS) or `:465` (implicit TLS) | Authenticated |
| IMAP for clients | `:143` (STARTTLS) or `:993` (implicit TLS) | Authenticated |
| Sieve managesieve (filters) | `:4190` | Used by Roundcube |

Eight Mailu containers + one extra Redis ride alongside the rest of
the stack on the same VM. RAM budget: ~1.5 GB at idle.

---

## 2 · Architecture

```
┌──────────────────────── default network ────────────────────────┐
│  db   redis   backend   admin   gym-partner   website   adminer │
│                          └─ celery-worker / celery-beat         │
│                                                                 │
│                            ┌────────┐                           │
│                            │ nginx  │ ◄── host :80 / :443       │
│                            └────────┘                           │
└─────────────────────────────│───────────────────────────────────┘
                              │ (also attached to mailu network)
┌─────────────────────────────│─────────── mailu network (192.168.203.0/24) ─┐
│                             ▼                                              │
│                       ┌───────────┐ :443 (HTTPS, proxy_ssl_verify off)     │
│                       │ mail-front│  ──→  /admin, /webmail                 │
│                       └─────┬─────┘                                        │
│                             │                                              │
│   ┌────────┐  ┌──────────┐  ├─→ mail-admin  (admin UI, SQLite)             │
│   │ resolver│ │ mail-redis│ ├─→ mail-webmail (Roundcube)                   │
│   │ .254    │ └──────────┘  ├─→ mail-imap   (Dovecot, IMAP/LMTP)           │
│   └────────┘                ├─→ mail-smtp   (Postfix)                      │
│                             └─→ mail-antispam (Rspamd, DKIM signing)       │
│                                                                            │
│  Host-published ports (DNS-only A record bypasses Cloudflare):             │
│    25, 465, 587  →  mail-front  (SMTP / submission)                        │
│    143, 993, 4190 → mail-front  (IMAP / sieve)                             │
└────────────────────────────────────────────────────────────────────────────┘
```

**Why two networks.** Mailu's containers boot-check `/etc/resolv.conf`
and refuse to start when it points at Docker's embedded DNS
(`127.0.0.11`) because that resolver doesn't validate DNSSEC. The
fix is to set `dns:` on each Mailu container to the IP of Mailu's own
Unbound — which means Unbound needs a stable, predictable IP — which
means an IPAM-configured subnet. Adding IPAM to the existing default
network would require recreating it (taking the whole stack down), so
we give Mailu its own subnet (`192.168.203.0/24`, matching Mailu's
documented default) and pin Unbound to `.254`. The outer nginx joins
both networks so it can keep proxying admin/api/partner/website on
`default` *and* proxy `mail.gym-pass.net → mail-front` on `mailu`.

**Why nginx proxies to `mail-front:443` over HTTPS, not plain :80.**
Mailu's bundled nginx has a hardcoded HTTP→HTTPS 301 on its `:80`
listener with no `X-Forwarded-Proto` escape hatch. Proxying our outer
HTTPS request to plain `:80` puts the client in a redirect loop. So
we terminate TLS at the outer nginx, then re-encrypt over the private
Docker network to `mail-front:443` using the same wildcard Cloudflare
Origin Cert mounted into both nginx instances. `proxy_ssl_verify off`
because the upstream hostname (`mail-front`) wouldn't match the cert
SAN.

**Why each Mailu service has a short-name network alias.** Mailu's
internal nginx and Postfix configs hard-reference peer services by
short names (`admin`, `imap`, `smtp`, `antispam`, `webmail`, `front`,
`redis`, `resolver`) — the `HOST_*` env vars only cover the Python
layer, not nginx stream / Postfix configs. We prefix our compose
services with `mail-` to avoid clashes with the main stack's existing
`admin` and `redis`, then add a single-word network alias on each
service so Mailu's expectations are met without forking the images.

---

## 3 · Prerequisites you have to do manually

Compose can spin up the containers; it cannot fix DNS, reverse DNS,
or carrier-blocked ports. Walk these top-to-bottom — each later step
depends on the earlier ones.

### 3.1 · Outbound port 25

Most cloud providers (GCP, AWS, DigitalOcean) block outbound TCP 25
by default to stop their VMs from being abused as spam cannons.

- **Contabo** (this is the one we're on): port 25 outbound is allowed
  by default. Verify on the VM with:
  ```bash
  timeout 5 bash -c 'exec 3<>/dev/tcp/smtp.gmail.com/25 && head -1 <&3'
  # Want: 220 smtp.gmail.com ESMTP ...
  ```
- **If blocked** (GCP / AWS / etc.): either file an unblock request
  with the provider, or switch to outbound-only-via-relay (Mailgun,
  Postmark) by setting `RELAYHOST` in `.env.mail`. The Mailu admin
  UI also exposes this under **Relay hosts**.

Until port 25 is open, the stack will boot and you can *receive*
mail, but every reply sits forever in the Postfix deferred queue.

### 3.2 · Reverse DNS (PTR), both IPv4 and IPv6

Receivers cross-check the PTR against the HELO hostname. A mismatch
(e.g. PTR says `vmiXXXXXX.contaboserver.net` while HELO says
`mail.gym-pass.net`) gets the mail rejected or spam-foldered by
Gmail / Outlook / Yahoo.

Set BOTH the IPv4 and the IPv6 PTR — Postfix may pick either family
for any given outbound delivery, and an IPv6 PTR mismatch causes
intermittent (= miserable to debug) failures.

- **Contabo**: Customer Control Panel → **Networking → DNS Reverse →
  Update PTR**, set both:
  - `194.163.140.28` → `mail.gym-pass.net`
  - `2a02:c207:2331:604::1` → `mail.gym-pass.net`

Verify (propagation typically 5–30 min):
```bash
dig -x 194.163.140.28 +short @1.1.1.1
dig -x 2a02:c207:2331:604::1 +short @1.1.1.1
# Both should print: mail.gym-pass.net.
```

### 3.3 · DNS records in Cloudflare

The `mail.` A/AAAA records must NOT be proxied — Cloudflare cannot
proxy SMTP/IMAP, and proxying breaks the HTTPS admin too. All other
records here are DNS-only.

**Delete first** if you previously had Cloudflare Email Routing
enabled — it auto-populates MX/SPF/DKIM records that conflict with
self-hosted mail:
- Cloudflare dashboard → **Email → Email Routing → Settings →
  Disable**
- Then in DNS, remove any `routeN.mx.cloudflare.net` MX records and
  any `cf2024-N._domainkey` TXT records.

**Add / verify**:

| Type | Name | Content | Proxy |
|---|---|---|---|
| A | `mail` | `194.163.140.28` | **DNS only** |
| AAAA | `mail` | `2a02:c207:2331:604::1` | **DNS only** |
| MX | `gym-pass.net` (apex / `@`) | `mail.gym-pass.net` priority 10 | DNS only |
| TXT | `gym-pass.net` (apex / `@`) | `v=spf1 mx ~all` | DNS only |
| TXT | `_dmarc` | `v=DMARC1; p=quarantine; rua=mailto:postmaster@gym-pass.net; fo=1` | DNS only |

DKIM is added **after** first boot (see §5) — Mailu generates the
keypair when you regenerate it through the admin UI and prints the
exact TXT record to publish.

Verify:
```bash
dig mail.gym-pass.net  A    +short @1.1.1.1   # → 194.163.140.28
dig gym-pass.net       MX   +short @1.1.1.1   # → 10 mail.gym-pass.net.
dig gym-pass.net       TXT  +short @1.1.1.1   # → "v=spf1 mx ~all"
dig _dmarc.gym-pass.net TXT +short @1.1.1.1   # → "v=DMARC1; ..."
```

### 3.4 · TLS cert filenames

The Cloudflare Origin Cert covers `*.gym-pass.net` + apex, so the
same cert serves every subdomain including `mail.`. Both the staging
overlay and the mail overlay bind-mount it from:
```
nginx/certs/gym-pass.net.pem
nginx/certs/gym-pass.net.key
```
If your cert is on the VM under different filenames (we hit this
during the original install — files were named `gym-pas.crt` /
`gym-pas.key`), rename them to match. Lock down permissions:
```bash
chmod 644 nginx/certs/gym-pass.net.pem
chmod 600 nginx/certs/gym-pass.net.key
```

Verify the cert is the right one and unexpired:
```bash
openssl x509 -in nginx/certs/gym-pass.net.pem -noout \
  -subject -dates -ext subjectAltName
# subject should be CloudFlare Origin Certificate
# SAN should include *.gym-pass.net AND gym-pass.net
```

---

## 4 · First boot

The compose is set up so a fresh deploy is `up -d` — no `mkdir`,
no manual `alembic upgrade`, no `flask mailu admin`, no clicking
"Regenerate keys" in the UI. Two one-shot services do the work:

  - **`migrator`** (staging overlay) — runs `alembic upgrade head`
    and then `python -m scripts.bootstrap_admin` (idempotent admin
    creation from `ADMIN_BOOTSTRAP_EMAIL`/`_PASSWORD`). Backend,
    celery-worker, and celery-beat all depend on it with
    `service_completed_successfully` so they never see a
    half-migrated schema.
  - **`mail-init`** (mail overlay) — waits for `mail-admin` healthy,
    then runs `flask mailu admin --mode ifmissing` (Mailu admin
    bootstrap) and the same DKIM key generation Mailu's UI does
    (`generate_dkim_key()` + `session.commit()`). Idempotent on
    every re-run.

Both services run on every `up -d` and exit immediately when there's
nothing to do, so they're safe to leave wired into the bring-up.

```bash
# On the VM, working dir = repo root.

# 1. Generate a Mailu SECRET_KEY (Mailu validates it as exactly 16
#    alphanumeric chars and refuses to boot otherwise).
python3 -c "import secrets,string; print(''.join(secrets.choice(string.ascii_letters+string.digits) for _ in range(16)))"

# 2. Create .env.mail and .env.staging from the templates. Fill in
#    the CHANGE_ME values + the SECRET_KEY from step 1.
cp .env.mail.example     .env.mail
cp .env.staging.example  .env.staging
chmod 600 .env.mail .env.staging
$EDITOR .env.mail .env.staging

# 3. Put the Cloudflare Origin Cert in place — the bind-mount expects
#    these exact filenames (see §3.4 if your cert is named otherwise).
ls nginx/certs/gym-pass.net.pem nginx/certs/gym-pass.net.key

# 4. Bring it all up.
docker compose -f docker-compose.yml \
               -f docker-compose.staging.yml \
               -f docker-compose.mail.yml \
               --env-file .env.staging \
               --env-file .env.mail \
               up -d --build

# 5. Watch the one-shot init services until they exit successfully.
docker compose -f docker-compose.yml \
               -f docker-compose.staging.yml \
               -f docker-compose.mail.yml \
               --env-file .env.staging --env-file .env.mail \
               logs -f migrator mail-init
```

When the logs show `bootstrap_admin: created admin@gym-pass.net` and
`mail-init: done`, both ends are bootstrapped. Point a browser at:

- **https://admin.gym-pass.net** — log in with
  `ADMIN_BOOTSTRAP_EMAIL` / `ADMIN_BOOTSTRAP_PASSWORD` from
  `.env.staging`.
- **https://mail.gym-pass.net/admin** — log in with
  `admin@${DOMAIN}` / `INITIAL_ADMIN_PW` from `.env.mail`.

Both passwords should be changed via the respective UIs immediately
after first login. The bootstrap scripts are **idempotent and
non-destructive** — once a user exists, they leave the row alone
(they don't reset passwords on subsequent deploys).

---

## 5 · Publishing the DKIM record (one manual DNS step)

The DKIM **key** is generated automatically by `mail-init` on the
first boot — the only thing left for you is publishing the public
half in DNS. Without it, DMARC (`p=quarantine`) drops outbound mail
into spam folders.

Get the exact record to publish:

```bash
docker exec gym-pass-pro-mail-admin-1 python -c "
from mailu import create_app, models
with create_app().app_context():
    print(models.Domain.query.filter_by(name='gym-pass.net').first().dns_dkim)
"
```

That prints a BIND-style line, e.g.
```
dkim._domainkey.gym-pass.net. 600 IN TXT "v=DKIM1; k=rsa; p=MIGf..." "...trailing portion..."
```

Add it to Cloudflare DNS — **paste the value as one continuous
string** (Cloudflare splits it onto the wire automatically):

| Type | Name | Content | Proxy |
|---|---|---|---|
| TXT | `dkim._domainkey` | the full `v=DKIM1; k=rsa; p=…` string with no line breaks | **DNS only** |

> **Paste gotcha**: if your terminal wrapped the key across lines,
> the resulting Cloudflare record will have literal `\010` / `\012`
> bytes embedded in the base64 and DKIM validators reject it. Paste
> with Ctrl+Shift+V (paste-as-plain-text) in the Cloudflare UI, or
> use the API form below.

Or, fully automated via the Cloudflare API:

```bash
# ZONE_ID + CF_API_TOKEN from https://dash.cloudflare.com → API
DKIM_TXT=$(docker exec gym-pass-pro-mail-admin-1 python -c "
from mailu import create_app, models
with create_app().app_context():
    d = models.Domain.query.filter_by(name='gym-pass.net').first()
    # Strip BIND zone-file wrapping + concat the split strings
    raw = d.dns_dkim.split('TXT', 1)[1].strip()
    print(''.join(p.strip('\"').strip() for p in raw.split('\" \"')).strip().strip('\"'))
")
curl -sX POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"type\":\"TXT\",\"name\":\"dkim._domainkey\",\"content\":\"$DKIM_TXT\",\"ttl\":300,\"proxied\":false}"
```

Verify (~5 min for propagation):

```bash
dig dkim._domainkey.gym-pass.net TXT +short @1.1.1.1
# Want: one continuous "v=DKIM1; k=rsa; p=..." string, no \010 bytes.
```

---

## 6 · Day-two: adding a mailbox

This is the "generate a new email address" flow:

1. Admin UI → **Users → New user**.
2. Local part (e.g. `noreply` for `noreply@gym-pass.net`).
3. Set a password. The admin UI does NOT email it — distribute out of
   band (1Password / Signal / etc.).
4. The new user can log in immediately at
   **https://mail.gym-pass.net/webmail**, or configure a mail client:
   - IMAP host `mail.gym-pass.net`, port 993, SSL/TLS, username =
     full email, password as set.
   - SMTP host `mail.gym-pass.net`, port 587, STARTTLS, same creds.

Aliases (e.g. `support@` → `admin@`) live under **Aliases** in the
same UI — no separate mailbox, no extra storage.

---

## 7 · Wiring the backend to send through this server

When `APP_ENV` flips to `production` and emails stop logging to
stdout (CLAUDE.md §4), the backend needs to actually deliver.
There's no SMTP client in the backend yet, so this is two changes:

1. Add an SMTP service in `backend/app/services/` modelled on
   `payment_service.py` (provider interface, single concrete
   adapter), wired in via FastAPI `Depends`.
2. In `.env.staging` / `.env.prod`:
   ```
   SMTP_HOST=mail-smtp            # internal Docker hostname
   SMTP_PORT=587
   SMTP_USERNAME=noreply@gym-pass.net
   SMTP_PASSWORD=<from Mailu admin UI>
   SMTP_FROM=noreply@gym-pass.net
   SMTP_USE_TLS=true
   ```

The backend talks to `mail-smtp:587` directly over the Docker
network. **Caveat**: the backend lives on the `default` network and
`mail-smtp` is on the `mailu` network — you'll either need to attach
the backend to `mailu` as well, or have it talk to the host's
published `:587` (which is available regardless of network split).

---

## 8 · End-to-end deliverability test

Once DKIM is published, send a test message from the admin UI's
compose window to a one-time address from **https://mail-tester.com**.
Aim for ≥9/10. Anything lower, the report breaks down what's missing
(SPF alignment, DKIM presence, reverse DNS, blacklist hits).

---

## 9 · Troubleshooting

Catalogue of the issues that came up during the original install,
with the actual root cause and fix. Hit any of these again? Start
here before re-engineering anything.

### 9.1 · `mail-resolver` crash-loop: "expected deny, refuse, ... as access control action"

```
/etc/unbound/unbound.conf:11: error: expected deny, refuse, ...
[...] fatal error: Could not read config file
```

**Cause.** Mailu's Unbound template renders
`access-control: {{ SUBNET }} allow`. If `SUBNET` isn't set in the
container env, the rendered line becomes `access-control:  allow`
(no netblock), which Unbound rejects.

**Fix.** Make sure `mail-resolver` has `env_file: [.env.mail]` and
that `.env.mail` defines `SUBNET=192.168.203.0/24`. Both are already
in the compose / template, but it's easy to lose one when copy-paste
editing.

Confirm by rendering the config out of a fresh container:
```bash
docker cp gym-pass-pro-mail-resolver-1:/etc/unbound/unbound.conf /tmp/r.conf
grep access-control /tmp/r.conf
# Should show: access-control: 192.168.203.0/24 allow
```

### 9.2 · `mail-front` crash-loop: "invalid number of arguments in 'location' directive"

```
nginx: [emerg] invalid number of arguments in "location" directive in /etc/nginx/nginx.conf:169
```

**Cause.** Mailu's internal nginx template renders
`location ${WEB_WEBMAIL} { ... }` and `location ${WEB_ADMIN} { ... }`
verbatim. If those env vars are unset, the rendered config has
`location  {` (empty path) which nginx refuses to parse.

**Fix.** `.env.mail` must define both:
```
WEB_ADMIN=/admin
WEB_WEBMAIL=/webmail
```
These are in `.env.mail.example`. If you trimmed them, put them back.

### 9.3 · `mail-admin` crash-loop: "Your DNS resolver at 127.0.0.11 isn't doing DNSSEC validation"

**Cause.** Docker's embedded DNS (`127.0.0.11`) is what every
container gets in `/etc/resolv.conf` by default. It doesn't do
DNSSEC, and Mailu's bootstrap aborts on that.

**Fix.** Set `dns: [192.168.203.254]` on every Mailu service that
checks DNSSEC (admin / imap / smtp / antispam / webmail / front), and
pin `mail-resolver` to that IP via `ipv4_address: 192.168.203.254`
under the `mailu` network. Both are wired in `docker-compose.mail.yml`
already. If you see this error, it usually means you broke the IPAM
config or the resolver service isn't running.

### 9.4 · `mail-front` crash-loop: "host not found in upstream 'imap'"

```
nginx: [emerg] host not found in upstream "imap" in /etc/nginx/nginx.conf:274
```

**Cause.** Mailu's nginx stream module references `imap` (and
`smtp`, `admin`, etc.) as hardcoded short hostnames — the `HOST_*`
env vars only cover the Python layer, not nginx stream/upstream
blocks (which resolve hostnames at startup). Our services are named
`mail-imap` / `mail-smtp` / etc., so the literal `imap` doesn't
resolve.

**Fix.** Each `mail-*` service gets a single-word network alias
matching what Mailu hardcodes:

| Compose service | Network alias |
|---|---|
| `mail-front` | `front` |
| `mail-admin` | `admin` |
| `mail-imap` | `imap` |
| `mail-smtp` | `smtp` |
| `mail-antispam` | `antispam` |
| `mail-webmail` | `webmail` |
| `mail-redis` | `redis` |
| `mail-resolver` | `resolver` (also `ipv4_address: 192.168.203.254`) |

Already wired in `docker-compose.mail.yml`. If you add a new Mailu
service, give it the alias it expects.

### 9.5 · Webmail / admin URL returns "too many redirects"

`curl -L` to `https://mail.gym-pass.net/admin/` exits with code 47
(redirect loop). Browser shows
"ERR_TOO_MANY_REDIRECTS" / "redirected you too many times".

**Cause.** Mailu's `:80` server block in the front container is
hardcoded as:
```
location / { return 301 https://$host$request_uri; }
```
No `X-Forwarded-Proto` escape hatch. If our outer nginx proxies to
`http://mail-front:80`, mail-front returns 301 → outer nginx
forwards 301 to client → client retries `https://...` → outer nginx
re-proxies to `:80` → loop.

**Fix.** Our `mail.conf.template` proxies to `mail-front:443`
(HTTPS) instead, with `proxy_ssl_verify off` and
`proxy_ssl_server_name on`. mail-front already serves `:443` using
the same Cloudflare Origin Cert we mount into both nginx instances,
so internal TLS works with no extra cert provisioning. If you're
re-deriving this config from scratch, do NOT proxy to `:80`.

### 9.6 · Cloudflare proxy intercepting SMTP / IMAP

Symptom: `mail.gym-pass.net:25` from outside connects (Cloudflare
accepts TCP on a few ports as part of the proxy) but the SMTP banner
is wrong or the TLS handshake fails.

**Cause.** Free-tier Cloudflare can only proxy HTTP/HTTPS — it
*intercepts* other TCP connections but doesn't actually forward them
to your origin. Worse, on plan upgrades it sometimes accepts the
connection on port 25 and then drops it silently.

**Fix.** The `mail` A and AAAA records MUST be set to **DNS only**
(grey cloud) in Cloudflare. Verify in the Cloudflare DNS panel —
look for the cloud icon next to the record, it must be grey, not
orange.

### 9.7 · Mount-inside-mount error when adding the mail vhost template

```
failed to create mountpoint for /etc/nginx/templates/mail.conf.template
mount: read-only file system
```

**Cause.** The staging overlay bind-mounts the whole
`./nginx/templates` directory as `:ro`. You can't then add a sub-file
mount on top of an already-mounted read-only directory.

**Fix.** Keep `mail.conf.template` in `nginx/templates/` (where it's
covered by the existing directory mount). To handle the "what if the
mail overlay isn't loaded" case, the template uses
`resolver 127.0.0.11 valid=10s` + `set $mail_upstream ...` +
`proxy_pass https://$mail_upstream` — variable proxy_pass defers DNS
resolution to request time, so nginx boots cleanly even when
`mail-front` doesn't exist (a hit to `mail.gym-pass.net` then
returns 502 instead of taking the proxy down).

### 9.8 · Can't log in to the admin UI on first boot

**Status (current code): handled automatically by the `mail-init`
one-shot service** — it runs `flask mailu admin --mode ifmissing` on
every `up -d`, which idempotently creates the admin when missing
without overwriting a rotated password.

**Historical context** (kept for anyone debugging an older
deployment): Mailu's `INITIAL_ADMIN_*` env-var bootstrap is
load-bearing on the *very first* boot succeeding cleanly — if any
mail service crash-loops during the initial bring-up (resolver /
DNSSEC / network reconfig), the SQLite DB gets created without the
admin row, and `INITIAL_ADMIN_MODE=ifmissing` sees "DB exists" on
later boots and skips re-asserting the user. That's what motivated
the `mail-init` service.

**Recovery if `mail-init` itself failed** — check its logs:
```bash
docker logs gym-pass-pro-mail-init-1
```
The most common failure is a startup race where `mail-admin`'s
health check turned green before its API was fully ready. Re-run:
```bash
docker compose -f docker-compose.yml -f docker-compose.staging.yml \
               -f docker-compose.mail.yml \
               --env-file .env.staging --env-file .env.mail \
               up --no-deps --force-recreate mail-init
```

### 9.9 · `gym-partner` build failure during `docker compose up --build`

```
Type error: ... is missing the following properties from type
'PendingButtonProps': pendingLabel, idleLabel
```

Not a mail issue — pre-existing TypeScript drift in
`gym-partner/src/components/DayPassSection.tsx`. The `PendingButton`
component was tightened to require `pendingLabel` and `idleLabel`
props, but the `DayPassSection` caller still passed `children`.

**Fix.** Compare to `GymProfileForm.tsx:234` and follow the same
pattern:
```tsx
<PendingButton
  pending={pending}
  pendingLabel={t("saving")}
  idleLabel={t("save")}
  ...
/>
```
(already merged on master).

### 9.10 · General debugging recipes

```bash
# Is anything in the Postfix deferred queue?
docker exec gym-pass-pro-mail-smtp-1 postqueue -p

# Tail Postfix logs as you trigger a send.
docker logs -f gym-pass-pro-mail-smtp-1 | grep -i "to=<recipient@example.com>"

# Confirm Postfix's myhostname matches reality.
docker exec gym-pass-pro-mail-smtp-1 postconf -d | grep myhostname
# myhostname should be mail.gym-pass.net

# Confirm we're not an open relay.
#   https://www.mailgenius.com/  →  enter mail.gym-pass.net

# Full SPF / DKIM / DMARC alignment + content scoring.
#   https://www.mail-tester.com/  →  send to the one-time address,
#   refresh the report, aim for ≥9/10.

# Reputation / blacklist check.
#   https://mxtoolbox.com/blacklists.aspx
# If the IP is listed on Spamhaus / SORBS / Barracuda, the cheapest
# fix is usually requesting a new IP from Contabo (and re-doing PTRs
# for v4 + v6).
```

---

## 10 · Backups

Mailboxes are in the `mail_mail` named volume (Maildir format —
one file per message). Admin DB and DKIM keys live alongside.
Snapshot all of them together:

```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
docker run --rm \
  -v gym-pass-pro_mail_data:/data:ro \
  -v gym-pass-pro_mail_mail:/mail:ro \
  -v gym-pass-pro_mail_dkim:/dkim:ro \
  -v "$(pwd)/backups":/out \
  alpine tar czf "/out/mail-${TIMESTAMP}.tar.gz" /data /mail /dkim
```

**DKIM keys MUST be in the backup.** Restoring without them means
every outbound message is unsigned (failing DMARC) until you publish
a fresh key in DNS. Test the restore process at least once before
relying on it — back up cron `gym-pass:/etc/cron.d/mail-backup` is
the right place to schedule the snapshot.

---

## 11 · Tearing it down

```bash
# Stop the mail stack but leave the rest running.
docker compose -f docker-compose.yml \
               -f docker-compose.staging.yml \
               -f docker-compose.mail.yml \
               --env-file .env.staging --env-file .env.mail \
               stop mail-front mail-admin mail-imap mail-smtp \
                    mail-antispam mail-webmail mail-resolver mail-redis

# Or take everything down (mail + main stack).
docker compose -f docker-compose.yml \
               -f docker-compose.staging.yml \
               -f docker-compose.mail.yml \
               --env-file .env.staging --env-file .env.mail \
               down
# Add `-v` to also delete the volumes — destroys all mailboxes,
# admin DB, and DKIM keys. Don't do this casually.
```

Bringing the rest of the stack up *without* the mail overlay just
means omitting `-f docker-compose.mail.yml` from the compose
invocation. The mail vhost stays defined in nginx but proxies to a
variable upstream (`mail-front` via Docker DNS) that fails-soft to
HTTP 502 when the mail-front container isn't running — nginx itself
boots clean either way.
