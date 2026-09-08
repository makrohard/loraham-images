#!/usr/bin/env python3
"""Refuse a stale binary index BEFORE the build, not an hour into provisioning.

`provision.sh` runs a flagless `lhpc auto-install --yes`. The binary channel's pins-must-match
gate refuses any artifact whose component commits differ from the manifest, and auto-install has
no source fallback, so ONE un-republished pin fails every stack that depends on it and the run
dies deep inside provisioning. images v0.1.8 (2026-08-08) was lost exactly that way.

Validation is driven FROM THE MANIFEST, not from the index: an index that is merely
self-consistent can still be missing the stack or the component the build will ask for. For
every manifest stack that declares `[stack.binary]`, its entry must exist in the index and every
component named in `binary.covers` must be present with the manifest's pinned commit.

Usage:  check-binary-index.py [--manifest PATH|URL] [--index PATH|URL]
Exit 0 when the index can satisfy this manifest, 1 with the reason when it cannot.
"""
from __future__ import annotations

import argparse
import json
import sys
import tomllib
import urllib.request

MANIFEST = ("https://raw.githubusercontent.com/makrohard/loraham-pi-control/main"
            "/lhpc/data/manifest.example.toml")
INDEX = "https://github.com/makrohard/lhpc-binaries/releases/download/binaries/index.json"
SCHEMA = 2                      # the only index schema this builder knows how to read


def _read(where: str) -> str:
    if where.startswith(("http://", "https://")):
        with urllib.request.urlopen(where, timeout=30) as r:      # noqa: S310 (fixed hosts)
            return r.read().decode()
    with open(where, encoding="utf-8") as fh:
        return fh.read()


def check(manifest_text: str, index_text: str) -> list[str]:
    """Every reason this index cannot satisfy this manifest, [] when it can."""
    manifest = tomllib.loads(manifest_text)
    try:
        index = json.loads(index_text)
    except json.JSONDecodeError as exc:
        return [f"the binary index is not valid JSON: {exc}"]

    if not isinstance(index, dict) or index.get("schema") != SCHEMA:
        return [f"binary index schema is {index.get('schema')!r} when this builder reads "
                f"schema {SCHEMA} — refusing to build against an index it cannot judge"]
    stacks = index.get("stacks")
    if not isinstance(stacks, dict) or not stacks:
        return ["the binary index declares no stacks"]

    pins, bad = {}, []
    for stack in manifest.get("stack", []):
        for comp in stack.get("component", []):
            pin = (comp.get("source") or {}).get("pin_commit")
            if pin:
                pins[comp["id"]] = pin

    covered = 0
    for stack in manifest.get("stack", []):
        binary = stack.get("binary")
        if not binary:
            continue
        sid = stack["id"]
        entry = stacks.get(sid)
        if not isinstance(entry, dict):
            bad.append(f"{sid}: the manifest declares a binary stack, the index has no entry")
            continue
        comps = entry.get("components")
        if not isinstance(comps, dict):
            bad.append(f"{sid}: the index entry declares no components map")
            continue
        for cid in binary.get("covers", []):
            want = pins.get(cid)
            got = comps.get(cid)
            if got is None:
                bad.append(f"{sid}: covered component {cid!r} is missing from the artifact")
            elif want is None:
                bad.append(f"{sid}: covered component {cid!r} has no pin in the manifest")
            elif got != want:
                bad.append(f"{sid}: {cid} artifact {got[:9]} != manifest pin {want[:9]}")
            covered += 1
        # An artifact may carry MORE than it covers (meshcom ships meshcom-gps-relay). That is
        # allowed, but a component the manifest pins must still match wherever it appears.
        for cid, got in comps.items():
            want = pins.get(cid)
            if cid not in binary.get("covers", []) and want and got != want:
                bad.append(f"{sid}: {cid} artifact {got[:9]} != manifest pin {want[:9]} "
                           f"(carried, not covered)")

    if not covered and not bad:
        bad.append("no manifest stack declares [stack.binary] — refusing to build blind")
    return bad


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", default=MANIFEST)
    ap.add_argument("--index", default=INDEX)
    args = ap.parse_args()
    try:
        manifest_text, index_text = _read(args.manifest), _read(args.index)
    except Exception as exc:                                       # noqa: BLE001
        print(f"::error::cannot read the manifest or the binary index: {exc}")
        return 1
    bad = check(manifest_text, index_text)
    if bad:
        print("::error::the published binary index cannot satisfy this manifest — republish the")
        print("::error::affected binaries BEFORE tagging an image (docs/maintenance.md).")
        for reason in bad:
            print(f"::error::{reason}")
        return 1
    print("binary index satisfies the manifest's binary stacks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
