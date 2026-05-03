# Cloudflare Worker Setup (KeyAuth Gateway)

## 1) Install Wrangler

```bash
npm install -g wrangler
wrangler login
```

## 2) Configure Worker variables

Edit `wrangler.toml`:

- `ALLOWED_ORIGIN` -> your website origin (example: `https://gurp.cc`)
- `DOWNLOAD_OBJECT_KEY` -> path to your file inside R2 (example: `downloads/lghub_system.exe`)
- `DOWNLOAD_FILENAME` -> file name users receive (example: `lghub_system.exe`)
- `[[r2_buckets]] bucket_name` -> your actual R2 bucket name

## 3) Set token secret

Use a long random string:

```bash
wrangler secret put TOKEN_SECRET
```

## 3.1) Set Turnstile verification

1. Create a Turnstile widget in Cloudflare Dashboard (Managed challenge is fine).
2. Copy the **Site Key** and **Secret Key**.
3. Update `wrangler.toml`:
   - `TURNSTILE_SITE_KEY` -> your Turnstile site key
4. Set Worker secret:

```bash
wrangler secret put TURNSTILE_SECRET
```

## 4) Deploy Worker

From this folder:

```bash
wrangler deploy
```

Copy the returned URL (example: `https://gurp-keyauth-gateway.<subdomain>.workers.dev`).

## 5) Update website files

In both:

- `access.html`
- `download.html`

Replace:

- `https://REPLACE_WITH_YOUR_WORKER_URL.workers.dev`

with your deployed Worker URL.

Also in `access.html`, set:

- `TURNSTILE_SITE_KEY` to the same site key from Cloudflare Turnstile.

## 6) Test

1. Open `access.html`
2. Register/login
3. Redirect to `download.html`
4. Download button should unlock after token validation

## Protected download behavior

- `download.html` validates the login session token with the Worker.
- On success, Worker returns a short-lived download ticket URL (`/dl?ticket=...`).
- The Worker then verifies the ticket and streams the file from your private R2 bucket.

This setup keeps the actual file private in R2 and only serves it when authentication + ticket checks pass.
