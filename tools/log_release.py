"""Logs the gurp release notes from GitHub into updates.json (shown at https://gurp.cc/updates).

The loader downloads gurp from the `consumer` release of lrd14/miniature-spork, and that one
release is edited in place for every update, so GitHub only ever has the latest notes. This
script (run every 15 minutes by .github/workflows/log-updates.yml) keeps the history:

- a new release name (e.g. v0.2.20 -> v0.2.21) adds a new entry with that release's notes;
- a new gurp.gurp upload under the same name is recorded on that version's entry (builds);
- edited notes for the current version update its entry.

Run it by hand with:  python tools/log_release.py
"""
import json
import os
import sys
import urllib.request
from pathlib import Path

REPO = "lrd14/miniature-spork"
TAG = "consumer"
ASSET = "gurp.gurp"
ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "updates.json"


def fetch_release() -> dict:
    req = urllib.request.Request(f"https://api.github.com/repos/{REPO}/releases/tags/{TAG}",
                                 headers={"Accept": "application/vnd.github+json", "User-Agent": "gurp-updates-log"})
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def main() -> int:
    release = fetch_release()
    version = (release.get("name") or release.get("tag_name") or "").strip()
    notes = (release.get("body") or "").replace("\r\n", "\n").strip()
    asset = next((a for a in release.get("assets", []) if a.get("name") == ASSET), None)
    build = (asset or {}).get("updated_at") or release.get("published_at") or ""
    if not version:
        print("release has no name; nothing logged")
        return 0

    data = json.loads(DATA.read_text(encoding="utf-8")) if DATA.exists() else {"updates": []}
    updates = data.setdefault("updates", [])
    latest = updates[0] if updates else None

    changed = False
    if latest is None or latest.get("version") != version:
        updates.insert(0, {"version": version, "date": build, "notes": notes, "builds": [build] if build else []})
        print(f"new version {version}")
        changed = True
    else:
        if build and build not in latest.setdefault("builds", []):
            latest["builds"].append(build)
            latest["date"] = build
            print(f"{version}: new build {build}")
            changed = True
        if notes != latest.get("notes"):
            latest["notes"] = notes
            print(f"{version}: notes edited")
            changed = True

    if changed:
        DATA.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    else:
        print(f"{version}: no change")
    return 0


if __name__ == "__main__":
    sys.exit(main())
