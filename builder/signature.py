#!/usr/bin/env python3
"""Deterministic change-signature for the release/refresh publisher — FAIL-CLOSED.

Signs over what determines image CONTENT provenance — per variant: the base image sha256, the
resolved loraham-pi-control commit, the installed-package-manifest sha256 (catches Debian/RPi
package updates), and the component-report sha256 (catches binary-channel/composition changes) —
NOT the image file hash (images are provenance-reproducible, not byte-reproducible). The monthly
refresh builds unconditionally and publishes a new dated release only when this signature changes.

For every image present in <dir> (loraham-lhpc-<v>.img.xz) the matching provenance-<v>.json must
exist, parse, and carry all four required fields — otherwise this EXITS NON-ZERO (never prints an
empty/partial signature that could mask a real change or ship an image without evidence).

Usage: signature.py <dir>   -> prints a short hex signature, or exits non-zero with a reason.
"""
import sys, os, json, hashlib

d = sys.argv[1] if len(sys.argv) > 1 else "."
REQUIRED = ("base_sha256", "lhpc_commit", "package_manifest_sha256",
            "component_report_sha256", "image_build_commit")
parts = []
for v in ("lite", "desktop"):
    if not os.path.exists(os.path.join(d, f"loraham-lhpc-{v}.img.xz")):
        continue  # this variant is not in this release
    p = os.path.join(d, f"provenance-{v}.json")
    if not os.path.exists(p):
        sys.exit(f"FATAL: {v} image present but provenance-{v}.json is missing")
    try:
        j = json.load(open(p))
    except Exception as e:
        sys.exit(f"FATAL: provenance-{v}.json is invalid JSON: {e}")
    missing = [f for f in REQUIRED if not j.get(f)]
    if missing:
        sys.exit(f"FATAL: provenance-{v}.json missing required field(s): {', '.join(missing)}")
    parts.append(
        f"{v}:base={j['base_sha256']}:lhpc={j['lhpc_commit']}"
        f":pkgs={j['package_manifest_sha256']}:comp={j['component_report_sha256']}"
        f":build={j['image_build_commit']}"
    )
if not parts:
    sys.exit("FATAL: no image + provenance pair found to sign")
sig = ";".join(sorted(parts))
print(hashlib.sha256(sig.encode()).hexdigest()[:16])
