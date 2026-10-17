#!/usr/bin/env python3
"""Refuse a stale binary index BEFORE the build, not an hour into provisioning.

`provision.sh` runs a flagless `lhpc auto-install --yes`. The binary channel's pins-must-match
gate refuses any artifact whose component commits differ from the manifest, and auto-install has
no source fallback, so ONE un-republished pin fails every stack that depends on it and the run
dies deep inside provisioning. images v0.1.8 (2026-08-08) was lost exactly that way.

Validation is driven FROM THE MANIFEST, not from the index: an index that is merely
self-consistent can still be missing the stack or the component the build will ask for. For
every manifest stack that declares `[stack.binary]`, its entry must exist in the index and every
component named in `binary.covers` must be present with the manifest's pinned commit. The index is
the one the manifest's `[stack.binary] index_url` names (index.json when it names none): schema 2
holds one entry per stack, schema 3 (index-v3.json) a list per stack, newest first, of which any
entry may match.

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
SCHEMAS = (2, 3)                # 2: one entry per stack; 3: a list per stack, newest first


def _read(where: str) -> str:
    if where.startswith(("http://", "https://")):
        with urllib.request.urlopen(where, timeout=30) as r:      # noqa: S310 (fixed hosts)
            return r.read().decode()
    with open(where, encoding="utf-8") as fh:
        return fh.read()


def index_url(manifest_text: str) -> str:
    """The one index the manifest's binary stacks name (index.json when they name none)."""
    urls = {(s.get("binary") or {}).get("index_url", INDEX)
            for s in tomllib.loads(manifest_text).get("stack", []) if s.get("binary")}
    if len(urls) > 1:
        raise ValueError(f"the binary stacks name two or more indexes: {', '.join(sorted(urls))}")
    return urls.pop() if urls else INDEX


def _entry_problems(sid: str, binary: dict, entry, pins: dict) -> list[str]:
    """Every reason this one index entry cannot serve the stack, [] when it can."""
    if not isinstance(entry, dict):
        return [f"{sid}: the manifest declares a binary stack, the index has no entry"]
    comps = entry.get("components")
    if not isinstance(comps, dict):
        return [f"{sid}: the index entry declares no components map"]
    bad = []
    for cid in binary.get("covers", []):
        want = pins.get(cid)
        got = comps.get(cid)
        if got is None:
            bad.append(f"{sid}: covered component {cid!r} is missing from the artifact")
        elif not isinstance(got, str):
            bad.append(f"{sid}: {cid} artifact commit is not a string ({got!r})")
        elif want is None:
            bad.append(f"{sid}: covered component {cid!r} has no pin in the manifest")
        elif got != want:
            bad.append(f"{sid}: {cid} artifact {got[:9]} != manifest pin {want[:9]}")
    # An artifact may carry MORE than it covers (meshcom ships meshcom-gps-relay). That is
    # allowed, but a component the manifest pins must still match wherever it appears.
    for cid, got in comps.items():
        want = pins.get(cid)
        if cid in binary.get("covers", []) or not want or got == want:
            continue
        if not isinstance(got, str):
            bad.append(f"{sid}: {cid} artifact commit is not a string ({got!r})")
        else:
            bad.append(f"{sid}: {cid} artifact {got[:9]} != manifest pin {want[:9]} "
                       f"(carried, not covered)")
    return bad


def check(manifest_text: str, index_text: str) -> list[str]:
    """Every reason this index cannot satisfy this manifest, [] when it can."""
    manifest = tomllib.loads(manifest_text)
    try:
        index = json.loads(index_text)
    except json.JSONDecodeError as exc:
        return [f"the binary index is not valid JSON: {exc}"]

    schema = index.get("schema") if isinstance(index, dict) else None
    if schema not in SCHEMAS:
        return [f"binary index schema is {schema!r} when this builder reads "
                f"schema 2 or 3 — refusing to build against an index it cannot judge"]
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
        covered += len(binary.get("covers", []))
        if schema == 2:
            bad += _entry_problems(sid, binary, stacks.get(sid), pins)
            continue
        entries = stacks.get(sid)
        if not isinstance(entries, list) or not entries:
            entries = [None]
        problems = [_entry_problems(sid, binary, e, pins) for e in entries]
        if all(problems):
            bad += problems[0]                  # none matches: the newest entry's reasons

    if not covered and not bad:
        bad.append("no manifest stack declares [stack.binary] — refusing to build blind")
    return bad


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", default=MANIFEST)
    ap.add_argument("--index", default="", help="default: the manifest's [stack.binary] index_url")
    args = ap.parse_args()
    try:
        manifest_text = _read(args.manifest)
        index_text = _read(args.index or index_url(manifest_text))
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
