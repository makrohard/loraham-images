#!/usr/bin/env python3
"""Keep the last N *bot-made* image releases; never touch a hand-made one.

An image is cut for every controller release, so releases accumulate. Only the ones an
automated release produced are pruned, and only when they are COMPLETE:

  * **bot-made** — the release carries the `AUTO-RELEASE` asset, which `publish-tag` writes from
    the tag's own `auto-release:` annotation. A marker on the release, not a guess from the tag
    name: `v0.3.5` looks identical whoever cut it.
  * **complete** — not a draft, and carrying both variants with their evidence. An incomplete
    attempt is exactly what a retry needs to find; deleting it would destroy the retry.

Everything else — every hand-made release, every draft, every tag — is left alone. Tags are
never deleted: a tag is a few bytes and it is how `image v0.3.1 carried controller c54a90f`
stays answerable after the assets are gone.

    prune-releases.py --keep 3 < releases.json     # prints the tags to delete, one per line
    prune-releases.py --keep 3 --repo o/r          # asks gh, then deletes them

The JSON is what `gh release list --json tagName,isDraft,assets` produces, so the decision is
testable offline against fixtures.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys

MARKER = "AUTO-RELEASE"
REQUIRED = ("loraham-lhpc-lite.img.xz", "loraham-lhpc-desktop.img.xz", "SHA256SUMS")


def _version(tag: str):
    m = re.fullmatch(r"v(\d+)\.(\d+)\.(\d+)", tag)
    return tuple(int(x) for x in m.groups()) if m else None


def _assets(rel: dict) -> set:
    return {a.get("name") for a in rel.get("assets") or []}


def complete_bot_releases(releases: list) -> list:
    """(version, tag) of every release this prune is allowed to consider, newest last."""
    out = []
    for rel in releases:
        tag = rel.get("tagName") or rel.get("tag_name") or ""
        ver = _version(tag)
        if ver is None or rel.get("isDraft") or rel.get("draft"):
            continue
        names = _assets(rel)
        if MARKER not in names or not set(REQUIRED) <= names:
            continue
        out.append((ver, tag))
    return sorted(out)


def to_delete(releases: list, keep: int) -> list:
    """Tags of the bot-made complete releases beyond the newest `keep`, oldest first."""
    if keep < 1:
        raise ValueError("keep must be at least 1")
    considered = complete_bot_releases(releases)
    surplus = considered[:-keep] if len(considered) > keep else []
    return [tag for _v, tag in surplus]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--keep", type=int, default=3)
    ap.add_argument("--repo", default="")
    ap.add_argument("--apply", action="store_true",
                    help="actually delete (default: print what would go)")
    args = ap.parse_args()

    if args.repo:
        raw = subprocess.run(
            ["gh", "release", "list", "--repo", args.repo, "--limit", "200",
             "--json", "tagName,isDraft,assets"],
            capture_output=True, text=True, check=True).stdout
    else:
        raw = sys.stdin.read()
    releases = json.loads(raw)

    doomed = to_delete(releases, args.keep)
    kept = [t for _v, t in complete_bot_releases(releases)][-args.keep:]
    print(f"keeping {args.keep} bot-made release(s): {', '.join(kept) or 'none'}")
    for tag in doomed:
        print(tag)
        if args.apply and args.repo:
            # The RELEASE only. The tag stays: it is the provenance of an image people may
            # still be running.
            subprocess.run(["gh", "release", "delete", tag, "--repo", args.repo, "--yes"],
                           check=True)
    if not doomed:
        print("nothing to prune")
    return 0


if __name__ == "__main__":
    sys.exit(main())
