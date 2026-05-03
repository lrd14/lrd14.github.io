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

## Domain routing

If you want `status.gurp.cc` to show this page directly, map that hostname to this `status/` build target in your host/router (or deploy `status/` as a separate static site project).
