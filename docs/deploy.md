# Pre-prod deployment — gym-pass.net

Target: `khuzaymah@35.203.162.232`, fronted by Cloudflare. Brief: dev
mode (no real SMS, no payments, dev OTP `1234`), four public hosts
(`gym-pass.net`, `api`, `admin`, `partner`), APK sideload via the
marketing site.

This is the operator runbook. Follow top to bottom on a fresh VM;
re-run §4 onward on every deploy.

---

## 0. Prerequisites (one-time)

### 0.1 Cloudflare DNS

Four A-records, all proxied (orange cloud), all pointing at the VM IP:

| Host                   | Type | Value             | Proxied |
| ---------------------- | ---- | ----------------- | ------- |
| `gym-pass.net`         | A    | `35.203.162.232`  | ✅      |
| `www.gym-pass.net`     | A    | `35.203.162.232`  | ✅      |
| `api.gym-pass.net`     | A    | `35.203.162.232`  | ✅      |
| `admin.gym-pass.net`   | A    | `35.203.162.232`  | ✅      |
| `partner.gym-pass.net` | A    | `35.203.162.232`  | ✅      |

SSL/TLS mode for the zone: **Full (strict)**.

### 0.2 Cloudflare Origin Certificate

Dashboard → `gym-pass.net` zone → **SSL/TLS → Origin Server → Create
Certificate**.

- Hostnames: `gym-pass.net`, `*.gym-pass.net`
- Key type: RSA 2048
- Validity: 15 years
- **Copy BOTH the cert and the private key** — the private key is
  only shown once.

Save them temporarily on your laptop as `gym-pass.net.pem` (cert)
and `gym-pass.net.key` (key).

---

## 1. VM bootstrap (one-time)

```bash
# SSH in
ssh khuzaymah@35.203.162.232

# Install Docker + Compose (Ubuntu)
sudo apt update
sudo apt install -y docker.io docker-compose-plugin git
sudo usermod -aG docker $USER

# Log out and back in for the group change to take effect.
exit
ssh khuzaymah@35.203.162.232

# Verify
docker info >/dev/null && echo "docker ok"
docker compose version

# Firewall: open 80/443
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow OpenSSH
sudo ufw --force enable

# Clone the repo (SSH is already wired to GitHub per the brief)
sudo mkdir -p /opt/gympass
sudo chown $USER:$USER /opt/gympass
git clone git@github.com:khuzaymahz/gym-pass-pro.git /opt/gympass
cd /opt/gympass
```

---

## 2. Configure secrets + cert (one-time per environment)

```bash
cd /opt/gympass

# .env.prod
cp .env.prod.example .env.prod
nano .env.prod
#   - POSTGRES_PASSWORD     → openssl rand -base64 32
#   - JWT_SECRET             → openssl rand -hex 48
#   - NEXTAUTH_SECRET        → openssl rand -base64 48
#   - ADMIN_EXCHANGE_SECRET  → openssl rand -base64 48
#   - ADMIN_BOOTSTRAP_PASSWORD → choose a strong one; you'll log in with this
#   - Confirm the four *_DOMAIN values are gym-pass.net subdomains

# Cert + key (paste in the two files from §0.2)
mkdir -p nginx/certs
nano nginx/certs/gym-pass.net.pem   # paste the CERTIFICATE block
nano nginx/certs/gym-pass.net.key   # paste the PRIVATE KEY block
chmod 644 nginx/certs/gym-pass.net.pem
chmod 600 nginx/certs/gym-pass.net.key

# Quick verify the key + cert match. The two `openssl ... | md5sum`
# outputs must be identical or nginx will refuse to start.
openssl x509 -noout -modulus -in nginx/certs/gym-pass.net.pem | md5sum
openssl rsa  -noout -modulus -in nginx/certs/gym-pass.net.key | md5sum

# Confirm the cert covers the right hostnames.
openssl x509 -in nginx/certs/gym-pass.net.pem -noout -text \
  | grep -A1 "Subject Alternative Name"
# Must show: DNS:gym-pass.net, DNS:*.gym-pass.net
```

---

## 3. APK build (parallel — see scripts/build-apk.sh)

The APK is built on **your laptop**, not the VM (Flutter / Android SDK
isn't installed on the VM). The resulting `.apk` ends up in
`website/public/downloads/` which is gitignored — you'll push the file
manually to the VM, or you can rebuild on the VM after installing
Flutter there.

On your laptop:

```bash
cd /home/khuzaymah/Desktop/gym-pass-pro/gym-pass-pro
cp mobile/dart_defines.prod.example.json mobile/dart_defines.prod.json
# Defines are already set to https://api.gym-pass.net — leave them.

./scripts/build-apk.sh
# Output: website/public/downloads/gympass.apk + .sha256
# Takes ~5-10 min on a cold build. Subsequent builds ~2 min.
```

Then ship the APK to the VM (it's gitignored on purpose — too big and
not source code):

```bash
scp website/public/downloads/gympass.apk \
    website/public/downloads/gympass.apk.sha256 \
    khuzaymah@35.203.162.232:/opt/gympass/website/public/downloads/
```

After the website container restarts (next deploy step), the APK is
served at `https://gym-pass.net/downloads/gympass.apk`.

---

## 4. Deploy (every release)

On the VM:

```bash
cd /opt/gympass

# Pull the latest commit on the deploy branch
git pull origin master

# One-shot — does sanity checks, pulls third-party images, builds
# app images, brings the stack up, runs migrations, smoke-tests
# the four public hostnames.
./scripts/deploy.sh
```

`deploy.sh` aborts on any failure and prints what failed; nothing is
half-deployed.

---

## 5. Smoke-test from your laptop

```bash
curl -sI https://gym-pass.net               | head -5
curl -sI https://api.gym-pass.net/health    | head -5
curl -sI https://admin.gym-pass.net/login   | head -5
curl -sI https://partner.gym-pass.net/login | head -5
```

All four should return HTTP 200 (or 307→200 for the partner+admin
which redirect to /login). Bodies are gzip-compressed.

Sign in flows to smoke-test:

- **Admin:** https://admin.gym-pass.net/login →
  email = `ADMIN_BOOTSTRAP_EMAIL` from .env.prod, password =
  `ADMIN_BOOTSTRAP_PASSWORD`.
- **Partner:** https://partner.gym-pass.net/login → use a phone from
  the seed data (run `docker compose -f docker-compose.yml -f
  docker-compose.prod.yml --env-file .env.prod exec backend uv run
  python scripts/seed.py --info` to list them), password = `dev-pass`
  (or whatever seed.py sets).
- **API:** open https://api.gym-pass.net/docs (Swagger — only exposed
  because `APP_ENV=development`; gated by `is_dev` in production).

---

## 6. Sideload the APK on your phone

1. On the phone, browse to `https://gym-pass.net` → tap the
   **Sideload · Android · GymPass APK** button.
2. First time only: the browser will warn about installing from
   unknown sources. In Android settings, grant your browser
   "Install unknown apps" permission.
3. After install, open the app, sign in with phone OTP. In dev mode
   the OTP is `1234` regardless of the phone number — no SMS is sent.

---

## 7. Operations

### Logs

```bash
cd /opt/gympass
# All services
docker compose -f docker-compose.yml -f docker-compose.prod.yml \
  --env-file .env.prod logs --tail=200 -f

# One service
docker compose -f docker-compose.yml -f docker-compose.prod.yml \
  --env-file .env.prod logs -f backend
```

### Restart a single service without full redeploy

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml \
  --env-file .env.prod restart gym-partner
```

### Stop the whole stack

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml \
  --env-file .env.prod down
```

### Database access

```bash
# Postgres shell
docker compose -f docker-compose.yml -f docker-compose.prod.yml \
  --env-file .env.prod exec db psql -U gympass

# Adminer is opt-in via the `dev-tools` profile and binds to
# 127.0.0.1:8080 only — even when started it isn't reachable from
# the public IP. To use it for ad-hoc DB inspection on the VM:
#   ssh -L 8080:localhost:8080 khuzaymah@35.203.162.232
#   # In a second shell on the VM:
#   docker compose --profile dev-tools \
#     -f docker-compose.yml -f docker-compose.prod.yml \
#     --env-file .env.prod up -d adminer
# Then open http://localhost:8080 on your laptop. Stop it again
# when you're done: `docker compose stop adminer`.
```

### Renew TLS

Cloudflare Origin Certificates last 15 years. There's nothing to
renew until 2041. Set a calendar reminder for 2040 anyway.

---

## 8. What this stack is NOT

This is **pre-prod**, deliberately. Before pointing real users at it:

- Flip `APP_ENV` to `production` in `.env.prod` and rebuild — real
  SMS provider, real payment gateway, generic error responses (no
  stack traces, no `/docs`).
- Wire `SMS_PROVIDER` to a real SMS service. Set `SMS_API_KEY`.
- Choose a payment gateway. Set `PAYMENT_PROVIDER` + creds.
- Switch the Postgres volume to a managed DB (RDS / Cloud SQL /
  Neon) so an instance crash doesn't lose data.
- Add backups. `pg_dump` on a cron is the floor; PITR is the
  ceiling.
- Add observability: Sentry for app errors, Grafana + Prometheus
  (or a SaaS equivalent) for metrics, structured logs shipped to
  a central log store.
- Add rate limits on the Cloudflare side too — WAF managed rules,
  bot fight mode.
- Tighten CORS (already locked to the four hostnames in .env.prod,
  but production should also reject any cross-origin requests the
  mobile app doesn't need).
- HTTP basic-auth or Cloudflare Access in front of `admin.gym-pass.net`
  as defence-in-depth on top of NextAuth.

The skip list above is intentional for the pre-prod sprint —
testing on real subdomains, on a real phone, without committing to
SMS/payments costs first.
