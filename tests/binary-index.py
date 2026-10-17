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


def case(name: str, index, must_fail: bool, expect: str = "", expect_not: str = "") -> None:
    global FAILURES
    try:
        bad = cbi.check(MANIFEST, json.dumps(index) if not isinstance(index, str) else index)
    except Exception as exc:                                   # noqa: BLE001 (a crash is a FAIL)
        print(f"  FAIL {name} -> raised {type(exc).__name__}: {exc}")
        FAILURES += 1
        return
    failed = bool(bad)
    ok = (failed == must_fail and (not expect or any(expect in b for b in bad))
          and not (expect_not and any(expect_not in b for b in bad)))
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
wrong_schema["schema"] = 4
case("an unreadable schema fails", wrong_schema, must_fail=True, expect="schema is 4")

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

# Schema 3 (index-v3.json): a list per stack, newest first; any entry that matches the pins passes.
V3 = {"schema": 3, "stacks": {sid: [e] for sid, e in GOOD["stacks"].items()}}
case("a schema-3 index with matching entries passes", V3, must_fail=False)

v3_older = copy.deepcopy(V3)
v3_older["stacks"]["daemon"].insert(0, stale["stacks"]["daemon"])
case("schema 3: an older entry that matches passes", v3_older, must_fail=False)

v3_stale = copy.deepcopy(V3)
v3_stale["stacks"]["daemon"] = [stale["stacks"]["daemon"]]
case("schema 3: no matching entry fails with the newest entry's reason", v3_stale, must_fail=True,
     expect="loraham-daemon artifact")

v3_two_stale = copy.deepcopy(V3)
v3_two_stale["stacks"]["daemon"] = [stale["stacks"]["daemon"], missing_comp["stacks"]["daemon"]]
case("schema 3: two failing entries report the newest one's reason only", v3_two_stale,
     must_fail=True, expect="loraham-daemon artifact", expect_not="radiolib")

v3_absent = copy.deepcopy(V3)
del v3_absent["stacks"]["meshtastic"]
case("schema 3: a stack key that is absent fails", v3_absent, must_fail=True,
     expect="the index has no entry")

# A malformed entry (a pinned component that is not a commit string) is that entry's problem: it
# neither crashes the check nor hides a valid entry beside it.
daemon = GOOD["stacks"]["daemon"]
null_carried = {"components": dict(daemon["components"], **{"loraham-kiss-tnc": None})}
int_covered = {"components": dict(daemon["components"], radiolib=5)}
for label, entries in (("a malformed entry before a valid one", [null_carried, daemon]),
                       ("a malformed entry after a valid one", [daemon, null_carried])):
    v3_bad = copy.deepcopy(V3)
    v3_bad["stacks"]["daemon"] = entries
    case(f"schema 3: {label} passes", v3_bad, must_fail=False)
v3_bad = copy.deepcopy(V3)
v3_bad["stacks"]["daemon"] = [null_carried]
case("schema 3: a carried pinned component that is null fails", v3_bad, must_fail=True,
     expect="loraham-kiss-tnc artifact commit is not a string")
v3_bad["stacks"]["daemon"] = [int_covered]
case("schema 3: a covered component that is not a string fails", v3_bad, must_fail=True,
     expect="radiolib artifact commit is not a string")

v3_empty = copy.deepcopy(V3)
v3_empty["stacks"]["meshtastic"] = []
case("schema 3: an empty list fails", v3_empty, must_fail=True, expect="the index has no entry")

# The real files of the 0.12.11 image run: v0.12.11's binary stacks against both published indexes.
DATA = pathlib.Path(__file__).resolve().parent / "data"
M11 = (DATA / "manifest-v0.12.11-binary-stacks.toml").read_text()


def real(name: str, index_file: str, must_fail: bool, expect: str = "") -> None:
    global MANIFEST
    MANIFEST, saved = M11, MANIFEST
    try:
        case(name, (DATA / index_file).read_text(), must_fail, expect)
    finally:
        MANIFEST = saved


real("v0.12.11 on its index-v3.json (4e8d665f) passes", "index-v3-4e8d665f.json", must_fail=False)
real("v0.12.11 on the schema-2 index.json (65e317c0) names the meshcom pin",
     "index-schema2-65e317c0.json", must_fail=True,
     expect="meshcom-qemu artifact 8692acd69 != manifest pin 4369e529f")


def url_case(name: str, manifest: str, want: str) -> None:
    """want: the exact URL, or "refused" when the manifest must raise ValueError."""
    global FAILURES
    try:
        got = cbi.index_url(manifest)
    except ValueError as exc:
        got, why = "refused", str(exc)
    else:
        why = got
    ok = got == want
    print(f"  {'ok  ' if ok else 'FAIL'} {name} -> {why}")
    FAILURES += not ok


BIN = "https://github.com/makrohard/lhpc-binaries/releases/download/binaries/"
url_case("the index is the manifest's [stack.binary] index_url", M11, BIN + "index-v3.json")
url_case("a manifest without index_url reads index.json", MANIFEST, BIN + "index.json")
url_case("binary stacks naming two indexes are refused",
         M11.replace("index-v3.json", "other.json", 1), "refused")

if "--live" in sys.argv:
    print("== live index vs loraham-pi-control main ==")
    live = cbi._read(cbi.MANIFEST)
    bad = cbi.check(live, cbi._read(cbi.index_url(live)))
    print("  " + ("ok   live index satisfies main" if not bad else "FAIL " + "; ".join(bad)))
    FAILURES += bool(bad)

print("BINARY-INDEX TESTS " + ("PASSED" if not FAILURES else f"FAILED ({FAILURES})"))
sys.exit(1 if FAILURES else 0)
