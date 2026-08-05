#!/usr/bin/env python3
"""Deterministic change-signature for the refresh publisher.

Signs over what determines image CONTENT provenance — per variant: the base image sha256, the
resolved loraham-pi-control commit, the installed-package-manifest sha256 (catches Debian/RPi
package updates), and the component-report sha256 (catches binary-channel/composition changes) —
NOT the image file hash (images are provenance-reproducible, not byte-reproducible). The monthly
refresh builds unconditionally and publishes a new dated release only when this signature changes.

Usage: signature.py <dir-with-provenance-*.json>   -> prints a short hex signature
"""
import sys, os, json, hashlib

d = sys.argv[1] if len(sys.argv) > 1 else "."
parts = []
for v in ("lite", "desktop"):
    p = os.path.join(d, f"provenance-{v}.json")
    if os.path.exists(p):
        try:
            j = json.load(open(p))
        except Exception:
            continue
        parts.append(
            f"{v}:base={j.get('base_sha256','')}:lhpc={j.get('lhpc_commit','')}"
            f":pkgs={j.get('package_manifest_sha256','')}:comp={j.get('component_report_sha256','')}"
        )
sig = ";".join(sorted(parts))
print(hashlib.sha256(sig.encode()).hexdigest()[:16] if sig else "empty")
