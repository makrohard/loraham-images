#!/usr/bin/env python3
"""Which components a variant may legitimately be missing.

The rule is LHPC's, not this repository's: `gui_unavailable_components()` names what cannot run
on this box. What differs by variant is what that ANSWER means. Lite has no toolkit, so the
answer is normal and those components may be absent. Desktop exists to provide the toolkit, so
the same answer is the defect — and applying Lite's allowance there would let a Desktop image
ship without the applications it is built for.
"""
from __future__ import annotations

import importlib.util
import pathlib
import sys

_spec = importlib.util.spec_from_file_location(
    "check_composition",
    pathlib.Path(__file__).resolve().parents[1] / "builder" / "check-composition.py")
cc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cc)


def check(name, got, want):
    if got != want:
        print(f"  FAIL {name}: got {got!r}, want {want!r}")
        sys.exit(1)
    print(f"  ok: {name}")


GUI = {"sideband", "loraham-voice"}

allow, broken = cc.omission_allowance("lite", GUI)
check("lite may omit every genuinely GUI-unavailable component", allow, GUI)
check("lite is not itself broken by that", broken, "")

allow, broken = cc.omission_allowance("desktop", GUI)
check("desktop may omit NOTHING", allow, set())
check("desktop naming GUI components is itself the defect", "toolkit is missing" in broken, True)
check("desktop names which ones", "sideband" in broken and "loraham-voice" in broken, True)

allow, broken = cc.omission_allowance("desktop", set())
check("a healthy desktop reports no defect", (allow, broken), (set(), ""))

allow, broken = cc.omission_allowance("lite", set())
check("a lite image with a full toolkit may still omit nothing", (allow, broken), (set(), ""))

print("  composition policy: all cases pass")
