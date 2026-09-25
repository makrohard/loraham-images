#!/usr/bin/env python3
"""Seal assertion (j): no key-named file in the image carries bytes the build produced.

Usage: check-key-files.py <root>   (key-named paths, one per line, on stdin, absolute in <root>)

A key-named file passes only when its bytes are still the bytes a Debian package shipped —
checked against dpkg's own record of them: `var/lib/dpkg/info/*.md5sums` for ordinary files, the
`Conffiles:` hashes in `var/lib/dpkg/status` for conffiles. Package OWNERSHIP alone is not
enough: a postinst or a later build step can rewrite a package-owned path, and dpkg still lists
it as the package's. Anything else fails: no package records the file (the build wrote it), no
recorded checksum, or bytes that changed since install. Packaged bytes are identical on every
install of that package, so they are public; build-written bytes are the same secret on every
card. Prints one line per offending file and exits 1 if there is any.
"""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path


def packaged_md5s(root: Path) -> dict[str, str]:
    """Absolute path -> the md5 dpkg recorded for it at install (md5sums + conffile hashes)."""
    out: dict[str, str] = {}
    for f in (root / "var/lib/dpkg/info").glob("*.md5sums"):
        for line in f.read_text(errors="replace").splitlines():
            digest, _, rel = line.partition("  ")
            if rel:
                out["/" + rel.lstrip("/")] = digest.strip()
    status = root / "var/lib/dpkg/status"
    if status.exists():
        in_conffiles = False
        for line in status.read_text(errors="replace").splitlines():
            if line.startswith("Conffiles:"):
                in_conffiles = True
                continue
            if in_conffiles and line.startswith(" "):
                parts = line.split()
                if len(parts) >= 2:
                    out[parts[0]] = parts[1]
                continue
            in_conffiles = False
    return out


def offenders(root: Path, paths: list[str]) -> list[tuple[str, str]]:
    recorded = packaged_md5s(root)
    bad: list[tuple[str, str]] = []
    for path in paths:
        want = recorded.get(path)
        if want is None:
            bad.append((path, "no package records it — written during the build"))
            continue
        got = hashlib.md5((root / path.lstrip("/")).read_bytes()).hexdigest()
        if got != want:
            bad.append((path, "bytes differ from what its package shipped — changed after install"))
    return bad


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    paths = [p for p in sys.stdin.read().splitlines() if p]
    bad = offenders(Path(sys.argv[1]), paths)
    for path, why in bad:
        print(f"  {path}: {why}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
