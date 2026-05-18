# docs.gurp.cc setup

## Files

- `docs/index.html` - main docs page
- `docs/docs.css` - docs styling
- `docs/docs.js` - sidebar active state + search filter

## How to add your Lua documentation

1. Open `docs/index.html`
2. Replace placeholder text/code in each section:
   - Getting Started
   - Lua Environment
   - API sections
   - Events
   - Utilities
   - Examples
   - FAQ
3. Keep each section `id` as-is if you want sidebar links to keep working.

## Search behavior

- Search reads each section's:
  - `data-title`
  - visible text content
- To improve search results, add keywords to each section's `data-title`.

## Make it `https://docs.gurp.cc`

Recommended setup is a separate static project for only the `docs/` folder.

1. Deploy only `docs/` as its own static site (Cloudflare Pages or your host).
2. In Cloudflare DNS, add:
   - Type: `CNAME`
   - Name: `docs`
   - Target: your docs project domain (for Pages this is usually `<project>.pages.dev`)
   - Proxy: Enabled
3. In the hosting dashboard, add custom domain:
   - `docs.gurp.cc`

After DNS + SSL finish, `https://docs.gurp.cc` will serve your docs.
