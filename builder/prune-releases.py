#!/usr/bin/env python3
"""Keep the newest N patch images of the current series; never touch the `.0` or anything older.

An image is cut for every controller release, so releases accumulate. Deletion sweeps down from
the newest and stops at the `.0` that opens the current major/minor line: neither it nor any
older line is ever a candidate, so every minor stays answerable however many patches come and go
above it. Within that line the newest N patches stay and the rest go, by numeric version.

Who cut a release does not decide this — a hand-made patch inside the range is treated like any
other. What is exempt is exempt for its own reason:

  * **a draft** — somebody's retry in progress.
  * **an incomplete release** — not carrying the publisher's whole asset set. That is exactly
    what a retry needs to find; deleting it would destroy the retry, and it must not count
    toward the retained N either.
  * **a tag** — never deleted. A tag is a few bytes and it is how `image v0.3.1 carried
    controller c54a90f` stays answerable after the assets are gone.

    prune-releases.py --keep 3 < releases.json     # prints the tags to delete, one per line
    prune-releases.py --keep 3 --repo o/r --apply  # asks the API, then deletes them

The JSON is a list of `{tagName, isDraft, assets:[{name}]}`. `gh release list` cannot produce
that shape — it has no `assets` field, and asking for one makes it exit non-zero, which is how
this script silently did nothing after the v0.3.7 publish — so the assets come from the REST
releases endpoint, which returns them with each release.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys

# Written from the tag's own `auto-release:` annotation. It no longer decides what may be
# deleted — the maintainer's rule is about a release's POSITION in the series, not its author —
# but it still identifies an automated publication in reports and provenance.
MARKER = "AUTO-RELEASE"
# What a COMPLETE release carries. Both images, both checksums, both provenance records, both
# component reports and the sums file — the same set `publish-tag` refuses to publish without.
# A release missing any of it is an incomplete attempt: it must neither count toward the
# retained three nor be selected for deletion, because it is exactly what a retry looks for.
REQUIRED = ("loraham-lhpc-lite.img.xz", "loraham-lhpc-desktop.img.xz",
            "loraham-lhpc-lite.img.xz.sha256", "loraham-lhpc-desktop.img.xz.sha256",
            "provenance-lite.json", "provenance-desktop.json",
            "components-lite.txt", "components-desktop.txt",
            "packages-lite.txt", "packages-desktop.txt",
            "SHA256SUMS", "signature.txt")


def _version(tag: str):
    m = re.fullmatch(r"v(\d+)\.(\d+)\.(\d+)", tag)
    return tuple(int(x) for x in m.groups()) if m else None


def _assets(rel: dict) -> set:
    return {a.get("name") for a in rel.get("assets") or []}


def prunable_releases(releases: list) -> list:
    """(version, tag) of every release this prune is allowed to consider, newest last.

    NOT limited to the ones the bot made. The maintainer's rule is about patch-image releases as
    such: a hand-made patch inside the current series is retained or deleted on its position, not
    on who cut it. What stays exempt is what has its own reason to be — a draft is somebody's
    retry in progress, an incomplete release is what a retry looks for, and the `.0` and older
    lines are excluded by `to_delete`, not here.
    """
    out = []
    for rel in releases:
        tag = rel.get("tagName") or rel.get("tag_name") or ""
        ver = _version(tag)
        if ver is None or rel.get("isDraft") or rel.get("draft"):
            continue
        if not set(REQUIRED) <= _assets(rel):
            continue
        out.append((ver, tag))
    return sorted(out)


def current_line(releases: list):
    """The `(major, minor)` of the newest PUBLISHED release, whoever cut it. `None` if there is
    none.

    Read from every release, not only the bot-made ones: the `.0` that opens a minor line is a
    maintainer's release, so a rule that only looked at what the bot made could not see the
    boundary it must stop at. Drafts do not count — an unpublished retry must not move the
    boundary and start protecting things early.
    """
    versions = [_version(rel.get("tagName") or rel.get("tag_name") or "")
                for rel in releases if not (rel.get("isDraft") or rel.get("draft"))]
    versions = [v for v in versions if v is not None]
    return max(versions)[:2] if versions else None


def to_delete(releases: list, keep: int) -> list:
    """Tags of the deletable releases, oldest first.

    Deletion sweeps down from the newest and STOPS at the minor. Only patches of the current
    minor line are ever candidates, beyond the newest `keep` of them; the `.0` that opens that
    line, and everything below it, is kept for good. So the repository always answers "what did
    this minor ship with", however many patches have come and gone above it.
    """
    if keep < 1:
        raise ValueError("keep must be at least 1")
    line = current_line(releases)
    if line is None:
        return []
    in_line = [(v, tag) for v, tag in prunable_releases(releases)
               if v[:2] == line and v[2] > 0]
    surplus = in_line[:-keep] if len(in_line) > keep else []
    return [tag for _v, tag in surplus]


def fetch(repo: str, pages: int = 5) -> list:
    """Every release of `repo`, with its assets, through the REST endpoint.

    `gh release list` is not usable here: it has no `assets` JSON field, so asking for one fails
    the whole call. `gh api` reaches the same endpoint with the same credential and returns the
    assets inline.
    """
    out = []
    for page in range(1, pages + 1):
        raw = subprocess.run(
            ["gh", "api", f"repos/{repo}/releases?per_page=100&page={page}"],
            capture_output=True, text=True, check=True).stdout
        batch = json.loads(raw)
        if not batch:
            break
        out.extend({"tagName": r.get("tag_name", ""), "isDraft": bool(r.get("draft")),
                    "assets": [{"name": a.get("name", "")} for a in r.get("assets", [])]}
                   for r in batch)
        if len(batch) < 100:
            break
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--keep", type=int, default=3)
    ap.add_argument("--repo", default="")
    ap.add_argument("--apply", action="store_true",
                    help="actually delete (default: print what would go)")
    args = ap.parse_args()

    if args.repo:
        releases = fetch(args.repo)
    else:
        releases = json.loads(sys.stdin.read())

    doomed = to_delete(releases, args.keep)
    # Say what is actually kept, per the rule that actually runs. This printed the newest three
    # bot-made releases overall, which is the rule this replaced: with an older line still
    # present it named releases from it while keeping every one of them.
    line = current_line(releases)
    in_line = [tag for v, tag in prunable_releases(releases)
               if line and v[:2] == line and v[2] > 0]
    kept = [tag for tag in in_line if tag not in doomed]
    where = f"v{line[0]}.{line[1]}" if line else "no released line"
    print(f"{where}: keeping {len(kept)} patch release(s): {', '.join(kept) or 'none'}; "
          f"the .0 and every older line are kept in full")
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
