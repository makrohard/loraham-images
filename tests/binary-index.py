#!/usr/bin/env python3
"""Negative + positive tests for builder/check-binary-index.py.

The check exists to fail BEFORE a 27-minute build, so the cases that matter are the ones a
merely self-consistent index would sail through: a missing binary stack, a missing covered
component, a schema this builder cannot read. Run offline against fixtures; the live index is
checked separately by `--live`.
"""
from __future__ import annotations

import copy
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "builder"))
import importlib.util

_spec = importlib.util.spec_from_file_location(
    "check_binary_index",
    pathlib.Path(__file__).resolve().parents[1] / "builder" / "check-binary-index.py")
cbi = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cbi)

MANIFEST = '''
[[stack]]
id = "daemon"
[stack.binary]
covers = ["loraham-daemon", "radiolib"]
[[stack.component]]
id = "loraham-daemon"
[stack.component.source]
pin_commit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
[[stack.component.param]]
name = "x"

[[stack]]
id = "meshtastic"
[stack.binary]
covers = ["meshtastic"]
[[stack.component]]
id = "meshtastic"
[stack.component.source]
pin_commit = "cccccccccccccccccccccccccccccccccccccccc"

[[stack]]
id = "kiss"
[[stack.component]]
id = "loraham-kiss-tnc"
[stack.component.source]
pin_commit = "dddddddddddddddddddddddddddddddddddddddd"
'''
# radiolib is a component of the daemon stack; declared separately so the fixture stays readable
MANIFEST = MANIFEST.replace('[[stack.component.param]]\nname = "x"\n', '''[[stack.component]]
id = "radiolib"
[stack.component.source]
pin_commit = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
''')

GOOD = {
    "schema": 2,
    "stacks": {
        "daemon": {"components": {"loraham-daemon": "a" * 40, "radiolib": "b" * 40}},
        "meshtastic": {"components": {"meshtastic": "c" * 40}},
    },
}

FAILURES = 0


def case(name: str, index, must_fail: bool, expect: str = "") -> None:
    global FAILURES
    bad = cbi.check(MANIFEST, json.dumps(index) if not isinstance(index, str) else index)
    failed = bool(bad)
    ok = failed == must_fail and (not expect or any(expect in b for b in bad))
    print(f"  {'ok  ' if ok else 'FAIL'} {name}" + (f" -> {bad[0]}" if bad else ""))
    if not ok:
        FAILURES += 1


print("== builder/check-binary-index.py ==")
case("the real shape passes", GOOD, must_fail=False)

stale = copy.deepcopy(GOOD)
stale["stacks"]["daemon"]["components"]["loraham-daemon"] = "9" * 40
case("a stale covered sha fails", stale, must_fail=True, expect="loraham-daemon artifact")

missing_comp = copy.deepcopy(GOOD)
del missing_comp["stacks"]["daemon"]["components"]["radiolib"]
case("a missing covered component fails", missing_comp, must_fail=True,
     expect="covered component 'radiolib' is missing")

missing_stack = copy.deepcopy(GOOD)
del missing_stack["stacks"]["meshtastic"]
case("a missing binary stack fails", missing_stack, must_fail=True,
     expect="the index has no entry")

wrong_schema = copy.deepcopy(GOOD)
wrong_schema["schema"] = 3
case("an unreadable schema fails", wrong_schema, must_fail=True, expect="schema is 3")

no_schema = {"stacks": GOOD["stacks"]}
case("a missing schema fails", no_schema, must_fail=True, expect="schema is None")

no_stacks = {"schema": 2, "stacks": {}}
case("an empty index fails", no_stacks, must_fail=True, expect="declares no stacks")

carried = copy.deepcopy(GOOD)
carried["stacks"]["daemon"]["components"]["loraham-kiss-tnc"] = "d" * 40
case("an extra CARRIED component that matches its pin passes", carried, must_fail=False)

carried_stale = copy.deepcopy(carried)
carried_stale["stacks"]["daemon"]["components"]["loraham-kiss-tnc"] = "e" * 40
case("an extra carried component that drifted fails", carried_stale, must_fail=True,
     expect="carried, not covered")

case("malformed JSON fails", "{not json", must_fail=True, expect="not valid JSON")

if "--live" in sys.argv:
    print("== live index vs loraham-pi-control main ==")
    bad = cbi.check(cbi._read(cbi.MANIFEST), cbi._read(cbi.INDEX))
    print("  " + ("ok   live index satisfies main" if not bad else "FAIL " + "; ".join(bad)))
    FAILURES += bool(bad)

print("BINARY-INDEX TESTS " + ("PASSED" if not FAILURES else f"FAILED ({FAILURES})"))
sys.exit(1 if FAILURES else 0)
