#!/usr/bin/env python3
"""Tests for builder/check-key-files.py (seal assertion (j)).

The property under test is that a key-named file passes only while its bytes are the bytes its
package shipped. The case that matters most is the one a plain ownership check lets through: a
package-owned path whose bytes were rewritten after install.
"""
from __future__ import annotations

import hashlib
import importlib.util
import pathlib
import sys
import tempfile

_spec = importlib.util.spec_from_file_location(
    "check_key_files",
    pathlib.Path(__file__).resolve().parents[1] / "builder" / "check-key-files.py")
ckf = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ckf)

FAILS = 0


def check(name: str, cond: bool) -> None:
    global FAILS
    print(f"  {'ok' if cond else 'FAIL'}: {name}")
    FAILS += 0 if cond else 1


def md5(b: bytes) -> str:
    return hashlib.md5(b).hexdigest()


def fixture(root: pathlib.Path) -> None:
    """dns-root-data ships /usr/share/dns/root.key (md5sums); openssh-client-ish ships a
    key-named conffile; a package lists /usr/share/doc/x/unsummed.key but records no checksum."""
    info = root / "var/lib/dpkg/info"
    info.mkdir(parents=True)
    (root / "usr/share/dns").mkdir(parents=True)
    (root / "usr/share/dns/root.key").write_bytes(b"public trust anchor\n")
    (info / "dns-root-data.list").write_text("/usr/share/dns\n/usr/share/dns/root.key\n")
    (info / "dns-root-data.md5sums").write_text(
        f"{md5(b'public trust anchor' + bytes([10]))}  usr/share/dns/root.key\n")
    (root / "etc/demo").mkdir(parents=True)
    (root / "etc/demo/demo.key").write_bytes(b"shipped placeholder\n")
    (info / "demo.list").write_text("/etc/demo/demo.key\n/usr/share/doc/x/unsummed.key\n")
    (root / "usr/share/doc/x").mkdir(parents=True)
    (root / "usr/share/doc/x/unsummed.key").write_bytes(b"docs\n")
    (root / "var/lib/dpkg/status").write_text(
        "Package: demo\nStatus: install ok installed\nConffiles:\n"
        f" /etc/demo/demo.key {md5(b'shipped placeholder' + bytes([10]))}\n"
        "Description: demo\n\n")


def run(paths: list[str], mutate=None) -> list[tuple[str, str]]:
    with tempfile.TemporaryDirectory() as d:
        root = pathlib.Path(d)
        fixture(root)
        if mutate:
            mutate(root)
        return ckf.offenders(root, paths)


check("packaged bytes (md5sums) pass", run(["/usr/share/dns/root.key"]) == [])
check("same package-owned path, bytes changed after install, FAILS",
      [p for p, _ in run(["/usr/share/dns/root.key"],
                         lambda r: (r / "usr/share/dns/root.key").write_bytes(b"generated secret\n"))]
      == ["/usr/share/dns/root.key"])
check("packaged conffile bytes pass", run(["/etc/demo/demo.key"]) == [])
check("conffile rewritten after install FAILS",
      [p for p, _ in run(["/etc/demo/demo.key"],
                         lambda r: (r / "etc/demo/demo.key").write_bytes(b"per-build key\n"))]
      == ["/etc/demo/demo.key"])
check("package-owned but no recorded checksum FAILS (fail closed)",
      [p for p, _ in run(["/usr/share/doc/x/unsummed.key"])] == ["/usr/share/doc/x/unsummed.key"])


def add_vnc(r: pathlib.Path) -> None:
    (r / "root/.vnc").mkdir(parents=True)
    (r / "root/.vnc/private.key").write_bytes(b"realvnc\n")


check("a file no package records FAILS (the RealVNC key)",
      [p for p, _ in run(["/root/.vnc/private.key"], add_vnc)] == ["/root/.vnc/private.key"])
check("no key-named files at all passes", run([]) == [])

sys.exit(1 if FAILS else 0)
