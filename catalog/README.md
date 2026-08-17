# catalog.gurp.cc setup

## Files

- `catalog/index.html` - browse + download UI
- `catalog/upload.html` - upload UI (separate page)
- `catalog/admin.html` - delete/moderation UI (separate page)
- `catalog/catalog.css` - styles
- `catalog/auth.js` - shared session auth helper
- `catalog/catalog.js` - browse + download logic
- `catalog/upload.js` - upload logic with Turnstile
- `catalog/admin.js` - admin delete logic

## What this catalog supports

- Browse and download are public (no login)
- Uploading **configs** and **Lua** files still requires gurp login
- Required fields: type, name, description, file, preview image
- Author is automatically set to the logged-in gurp username
- Upload page requires Cloudflare Turnstile verification
- Browse listing with search + type filter
- Download from listing page

Upload restrictions:

- `config` uploads must be `.gurp`
- `lua` uploads must be `.lua`
- config/lua max file size: **1MB**
- preview image max size: **5MB**
- max uploads per user: **3 per UTC day**

## Worker API endpoints used

- `GET /catalog/public/list`
- `GET /catalog/public/item?id=...`
- `GET /catalog/public/image?id=...`
- `GET /catalog/public/download?id=...`
- `POST /catalog/upload` (multipart form upload)
- `POST /catalog/delete` (owner delete, or admin delete with token)

All browse/download endpoints are public:

- `GET /catalog/public/list`
- `GET /catalog/public/item?id=...`
- `GET /catalog/public/image?id=...`
- `GET /catalog/public/download?id=...`

Upload and delete still require `Authorization: Bearer <session token>` from `access.html`.

## Cloudflare Worker requirements

Add a second R2 bucket binding to `cloudflare-worker/wrangler.toml`:

- binding: `CATALOG_FILES`
- bucket: `gurp-catalog` (or your preferred name)

Suggested vars:

- `CATALOG_MAX_FILE_BYTES` (default 1 MB)
- `CATALOG_MAX_IMAGE_BYTES` (default 5 MB)
- `CATALOG_DAILY_UPLOAD_LIMIT` (default 3/day)

Turnstile is required for uploads and reuses existing Worker settings:

- `TURNSTILE_SITE_KEY` in vars
- `TURNSTILE_SECRET` as Worker secret
- `CATALOG_ADMIN_TOKEN` as Worker secret (used for delete actions)

Set admin token:

```bash
wrangler secret put CATALOG_ADMIN_TOKEN
```

Create bucket if needed:

```bash
wrangler r2 bucket create gurp-catalog
```

Then deploy Worker:

```bash
cd cloudflare-worker
wrangler deploy
```

## Deploy as `https://catalog.gurp.cc`

Recommended setup is a separate static site for only this `catalog/` folder.

CLI example:

```bash
wrangler pages project create gurp-catalog
wrangler pages deploy catalog --project-name gurp-catalog
```

Then set custom domain in Cloudflare Pages:

- `catalog.gurp.cc`
