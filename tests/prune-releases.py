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

FULL = list(prune.REQUIRED)


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


# --- deletion stops at the minor ----------------------------------------------------------
# The rule is "keep the newest three patches of the current line, and never touch the .0 that
# opens it or anything below". A plain "newest three overall" gets every case below wrong.

# A new minor has opened. Everything in the OLD line is now below the boundary, so no number of
# newer releases may reach it — even though only one patch exists above the .0.
NEXT_MINOR = [
    rel("v0.3.1"), rel("v0.3.2"), rel("v0.3.3"), rel("v0.3.4"),
    rel("v0.4.0", bot=False), rel("v0.4.1"),
]
check("a new minor puts the whole previous line out of reach",
      prune.to_delete(NEXT_MINOR, 3), [])
check("even keeping only one, nothing below the current .0 is touched",
      prune.to_delete(NEXT_MINOR, 1), [])

# Within the current line, the newest three patches stay and the rest go — the .0 never counts
# toward the three and is never a candidate.
DEEP_LINE = [
    rel("v0.4.0", bot=False),
    rel("v0.4.1"), rel("v0.4.2"), rel("v0.4.3"), rel("v0.4.4"), rel("v0.4.5"),
]
check("in one line, keep the newest three patches and delete the rest",
      prune.to_delete(DEEP_LINE, 3), ["v0.4.1", "v0.4.2"])
check("the .0 is not one of the three and is never deleted",
      [t for t in prune.to_delete(DEEP_LINE, 1) if t == "v0.4.0"], [])

# A bot-cut .0 would still be the boundary, not a candidate: what protects it is its position,
# not who made it.
check("a .0 is protected even when the bot cut it",
      prune.to_delete([rel("v0.5.0"), rel("v0.5.1"), rel("v0.5.2"),
                       rel("v0.5.3"), rel("v0.5.4")], 2), ["v0.5.1", "v0.5.2"])

# A draft of the next minor must not move the boundary and start protecting the current line.
check("an unpublished draft does not open a new line",
      prune.to_delete(DEEP_LINE + [rel("v0.5.0", draft=True)], 3), ["v0.4.1", "v0.4.2"])

check("keep 1 keeps only the newest marked release",
      prune.to_delete(FIXTURE, 1), ["v0.3.1", "v0.3.2", "v0.3.3"])

check("a draft is never deleted — it is a retry in progress",
      "v0.3.5" in prune.to_delete(FIXTURE, 1), False)

check("an incomplete marked release (Desktop missing) is not prunable",
      prune.to_delete([rel("v0.1.1", assets=["loraham-lhpc-lite.img.xz", "SHA256SUMS"]),
                       rel("v0.1.2"), rel("v0.1.3"), rel("v0.1.4")], 3), [])

# An incomplete release must also not COUNT toward the retained three: it is what a retry looks
# for, and counting it would push a good release out of the window.
_no_provenance = [a for a in FULL if a != "provenance-desktop.json"]
check("an incomplete release neither counts nor is deleted",
      prune.to_delete([rel("v0.2.1", assets=_no_provenance), rel("v0.2.2"), rel("v0.2.3"),
                       rel("v0.2.4")], 3), [])

check("the completeness contract is the publisher's own asset set",
      sorted(prune.REQUIRED) == sorted(FULL), True)

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
