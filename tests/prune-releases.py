#!/usr/bin/env python3
"""Tests for builder/prune-releases.py — what may be deleted, and what may never be.

The cases that matter are the ones a naive "keep the newest three tags" would get wrong: a
hand-made release older than the kept window, a draft that is somebody's retry in progress, and
a marked release that is missing a variant. Run offline against fixtures.
"""
from __future__ import annotations

import importlib.util
import pathlib
import sys

_spec = importlib.util.spec_from_file_location(
    "prune_releases",
    pathlib.Path(__file__).resolve().parents[1] / "builder" / "prune-releases.py")
prune = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(prune)

FULL = ["loraham-lhpc-lite.img.xz", "loraham-lhpc-desktop.img.xz", "SHA256SUMS",
        "provenance-lite.json", "provenance-desktop.json"]


def rel(tag, *, bot=True, draft=False, assets=None):
    names = list(assets if assets is not None else FULL)
    if bot:
        names.append("AUTO-RELEASE")
    return {"tagName": tag, "isDraft": draft, "assets": [{"name": n} for n in names]}


def check(name, got, want):
    if got != want:
        print(f"  FAIL {name}: got {got!r}, want {want!r}")
        sys.exit(1)
    print(f"  ok: {name}")


# The auditor's fixture: FOUR complete marked releases, plus a draft and two hand-made ones.
# Keeping three must delete exactly one — the oldest marked release — and nothing else.
FIXTURE = [
    rel("v0.3.1"), rel("v0.3.2"), rel("v0.3.3"), rel("v0.3.4"),
    rel("v0.3.5", draft=True),
    rel("v0.2.9", bot=False), rel("v0.3.0", bot=False),
]

check("four marked + draft + two hand-made, keep 3 -> the oldest marked goes",
      prune.to_delete(FIXTURE, 3), ["v0.3.1"])

check("a hand-made release is never deleted, however old",
      [t for t in prune.to_delete(FIXTURE, 1) if t in ("v0.2.9", "v0.3.0")], [])

check("keep 1 keeps only the newest marked release",
      prune.to_delete(FIXTURE, 1), ["v0.3.1", "v0.3.2", "v0.3.3"])

check("a draft is never deleted — it is a retry in progress",
      "v0.3.5" in prune.to_delete(FIXTURE, 1), False)

check("an incomplete marked release (Desktop missing) is not prunable",
      prune.to_delete([rel("v0.1.1", assets=["loraham-lhpc-lite.img.xz", "SHA256SUMS"]),
                       rel("v0.1.2"), rel("v0.1.3"), rel("v0.1.4")], 3), [])

check("nothing to do when there are no more than `keep` marked releases",
      prune.to_delete([rel("v0.1.1"), rel("v0.1.2")], 3), [])

check("a non-version tag is ignored entirely",
      prune.to_delete([rel("img-2026.09.01-0400"), rel("v0.1.1"), rel("v0.1.2"),
                       rel("v0.1.3"), rel("v0.1.4")], 3), ["v0.1.1"])

try:
    prune.to_delete(FIXTURE, 0)
except ValueError:
    print("  ok: keep=0 is refused")
else:
    print("  FAIL: keep=0 was accepted")
    sys.exit(1)

print("  prune-releases: all cases pass")
