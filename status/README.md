# status.gurp.cc setup

## Files

- `status/index.html` - status page
- `status/status.css` - styling
- `status/status.js` - renders status blocks
- `status/data.json` - edit this to update current status

## Update status quickly

Edit `status/data.json`:

- `updatedAt` - timestamp string
- `message` - short global message
- `services[]` - status per service (`ok`, `degraded`, `down`)
- `incidents[]` - bullet list of incidents

## Make it `https://status.gurp.cc`

Recommended setup is a separate static project for the `status/` folder.

1. Deploy only the `status/` folder as a static site (Cloudflare Pages or your host).
2. In Cloudflare DNS, add:
   - Type: `CNAME`
   - Name: `status`
   - Target: your status project domain (for Pages this is usually `<project>.pages.dev`)
   - Proxy: Enabled
3. In your hosting dashboard, add custom domain:
   - `status.gurp.cc`

After DNS + SSL finish, `https://status.gurp.cc` will serve this status page.

## Store history + update from anywhere

This setup now supports:

- public endpoint: `/status/public`
- admin update endpoint: `/status/admin/update`
- history persisted in Cloudflare KV
- simple admin UI: `status/admin.html`

### Worker requirements

In `cloudflare-worker/wrangler.toml` set `STATUS_KV` namespace id values.

Create namespace:

```bash
wrangler kv namespace create STATUS_KV
```

Then set secret admin token:

```bash
wrangler secret put STATUS_ADMIN_TOKEN
```

Redeploy:

```bash
wrangler deploy
```

Open:

- `https://status.gurp.cc/admin.html`

Use your token there to mark services up/down and publish updates.
