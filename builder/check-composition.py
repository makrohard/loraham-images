#!/usr/bin/env python3
"""Is what this image INSTALLED what the controller release says it should be?

Runs inside the provisioned image, as the operator user, against the lhpc the image installed.
It asks LHPC's own code the two questions this builder must never answer for itself:

  * **which components may be absent here** — `gui_unavailable_components()`, the one predicate
    behind every GUI skip. A Lite image has no GTK/X11 toolkit, so the components that need one
    (Sideband, the Voice GTK variant) are legitimately absent; Desktop installs them. Anything
    else missing is a defect, and a `differs` on any installed managed source is a defect.
  * **is this component really that commit** — `source_registry.verify_identity()` for a live
    checkout and `binary_receipt.verify_files()` for an artifact. The readable
    `lhpc status --versions` report stays beside this as evidence; it is not the check.

Writes /var/log/lhpc-composition.json and exits non-zero with the reasons.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys

REPORT = "/var/log/lhpc-composition.json"


def main() -> int:
    from lhpc.core import binary_receipt, source_registry
    from lhpc.core.services import ControllerService

    svc = ControllerService()
    paths, system, config = svc._paths, svc._system, svc.config()
    variant = os.environ.get("VARIANT", "?")
    expected_lhpc = os.environ.get("EXPECTED_LHPC_SHA", "")

    rows, bad = [], []
    for stack in svc.stacks():
        skippable = set(svc.gui_unavailable_components(stack))
        for comp in stack.components:
            spec = getattr(comp, "source", None)
            pin = getattr(spec, "pin_commit", "") if spec else ""
            if not spec or not pin:
                continue
            dest = paths.resolve_source(spec.path)
            row = {"stack": stack.id, "component": comp.id, "pin": pin,
                   "gui_optional_here": comp.id in skippable}
            if not dest.exists():
                row["state"] = "absent"
                rows.append(row)
                if comp.id not in skippable:
                    bad.append(f"{stack.id}/{comp.id}: mandatory component is not installed")
                continue
            rec, why = source_registry.verify_identity(paths, system, config, comp, dest)
            if rec is None:
                row["state"] = "unprovable"
                row["reason"] = why
                rows.append(row)
                bad.append(f"{stack.id}/{comp.id}: identity not provable — {why}")
                continue
            head = subprocess.run(["git", "-C", str(dest), "rev-parse", "HEAD"],
                                  capture_output=True, text=True, check=False).stdout.strip()
            row["head"] = head
            row["state"] = "match" if head == pin else "differs"
            rows.append(row)
            if head != pin:
                bad.append(f"{stack.id}/{comp.id}: installed {head[:9]} but the manifest pins "
                           f"{pin[:9]}")

    pins = {c.id: c.source.pin_commit for s in svc.stacks() for c in s.components
            if getattr(c, "source", None) and getattr(c.source, "pin_commit", "")}
    for stack in svc.stacks():
        if not svc.binary_spec(stack.id):
            continue
        state, rec, why = binary_receipt.receipt_state(paths, stack.id)
        row = {"stack": stack.id, "component": f"{stack.id} (binary)", "state": state}
        if state != "valid":
            rows.append(row)
            bad.append(f"{stack.id}: binary receipt {state} — {why}")
            continue
        ok, mismatched = binary_receipt.verify_files(paths, rec)
        row["artifact"] = rec.artifact_sha256
        row["components"] = dict(rec.components)
        rows.append(row)
        if not ok:
            bad.append(f"{stack.id}: installed artifact does not match its receipt: "
                       f"{mismatched}")
        for cid, commit in rec.components.items():
            if cid in pins and commit != pins[cid]:
                bad.append(f"{stack.id}: artifact carries {cid} {commit[:9]}, the manifest "
                           f"pins {pins[cid][:9]}")

    report = {"variant": variant, "expected_lhpc_commit": expected_lhpc,
              "components": rows, "problems": bad}
    with open(REPORT, "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2, sort_keys=True)

    for line in bad:
        print(f"[composition] {line}", file=sys.stderr)
    print(f"[composition] {len(rows)} component(s) checked on {variant}, "
          f"{len(bad)} problem(s); report at {REPORT}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
