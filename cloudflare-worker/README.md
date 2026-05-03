# Cloudflare Worker Setup (KeyAuth Gateway)

## 1) Install Wrangler

```bash
npm install -g wrangler
wrangler login
```

## 2) Configure Worker variables

Edit `wrangler.toml`:

- `ALLOWED_ORIGIN` -> your website origin (example: `https://gurp.cc`)
- `DOWNLOAD_URL` -> your direct loader URL

## 3) Set token secret

Use a long random string:

```bash
wrangler secret put TOKEN_SECRET
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

## 6) Test

1. Open `access.html`
2. Register/login
3. Redirect to `download.html`
4. Download button should unlock after token validation
