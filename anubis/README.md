# Anubis in front of GitHub Pages

Public traffic:

`visitor -> Cloudflare DNS -> your VPS (Caddy + Anubis) -> https://lrd14.github.io`

The Worker, catalog, docs, and status subdomains stay on Cloudflare. Only the main site (`gurp.cc`) goes through Anubis.

## 1. Install Docker on the VPS

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker "$USER"
```

Log out and back in, then copy this `anubis/` folder onto the VPS.

## 2. Start Anubis

```bash
cd anubis
docker compose up -d
docker compose logs -f
```

Caddy will get a Let's Encrypt cert after DNS points at the VPS.

## 3. Stop the GitHub Pages custom-domain redirect

If `gurp.cc` stays attached to the GitHub Pages site, `lrd14.github.io` 301s back to `gurp.cc` and Anubis loops.

In the GitHub repo: **Settings -> Pages -> Custom domain -> Remove**.

Also delete the `CNAME` file in this repo after you cut over, or GitHub will put the custom domain back.

The live site will still be `https://gurp.cc`. GitHub only hosts the files at `https://lrd14.github.io`.

## 4. Point DNS at the VPS

In Cloudflare DNS for `gurp.cc`:

| Type | Name | Target | Proxy |
| --- | --- | --- | --- |
| A | `@` | your VPS IPv4 | DNS only (grey cloud) first |
| AAAA | `@` | your VPS IPv6 (if you have one) | DNS only |
| CNAME | `www` | `gurp.cc` | DNS only |

Leave these alone:

- `catalog`, `docs`, `status`
- the KeyAuth worker (`*.workers.dev`)
- any existing Worker/custom routes

SSL: if you later orange-cloud `gurp.cc`, set Cloudflare SSL to **Full (strict)**.

## 5. Check

1. `https://YOUR_VPS_IP` will not look right. Use `https://gurp.cc`.
2. First visit should show the Anubis challenge, then the normal homepage.
3. Login/download should still talk to `gurp-keyauth-gateway.lrd14.workers.dev`.

## Notes

- Do not set `TARGET` to `https://gurp.cc`. That is a loop.
- One Anubis instance protects one backend. Add another service if you want `catalog.gurp.cc` challenged too.
- Ports 80 and 443 on the VPS must be open.
