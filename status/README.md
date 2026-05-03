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
