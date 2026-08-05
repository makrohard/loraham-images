#!/usr/bin/env python3
"""Deterministic change-signature for the refresh publisher.

Signs over what actually determines image CONTENT provenance — the base image sha256 per
variant and the resolved loraham-pi-control commit — NOT the image file hash (images are
provenance-reproducible, not byte-reproducible, so their hashes always differ). The monthly
refresh publishes a new dated release only when this signature changes.

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
        parts.append(f"{v}:base={j.get('base_sha256','')}:lhpc={j.get('lhpc_commit','')}")
sig = ";".join(sorted(parts))
print(hashlib.sha256(sig.encode()).hexdigest()[:16] if sig else "empty")
