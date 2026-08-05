# loraham-images — maintenance

A checklist for the repo owner. What CI enforces vs. what is manual, plus the honest limits.

## What the build gates enforce (per variant, in CI)
- base sha256 verified before use; codename=trixie + arch=arm64 + layout verified on the mount
- `bootstrap-deps.sh --dry-run` (Lite: any nonzero fails; exit 6 = GUI leaked)
- Lite GUI package count == 0 in the sealed rootfs
- `auto-install` reported no failed/blocked stack (GUI/optional skips allowed)
- provisioning marker `/var/lib/lhpc/.provisioned` + `/etc/lhpc-image.json` populated
- **AP DHCP/NAT deps present** (`dnsmasq-base` + nftables/iptables) — else Lite hands out no address
- seal: no private-key PEM markers anywhere; LHPC PKI/host-keys/machine-id gone; account hash ==
  documented onboarding password; expansion hook intact
- Gate A2 (throwaway copy, `--private-network`): out-of-box journey — user units, `/healthz`, web
  GUI loads, AP-bound sshd (`10.42.0.1` only), daemon start refused, fresh device PKI, swap fixture,
  firstboot idempotent — plus the **cold-reboot** gate (steady state) and host-netns-unchanged
- final compressed size ≤ 2 GiB

## Honest limits — hardware Gate B only (never claimed CI-proven)
- real Raspberry Pi firmware/device-tree boot, SPI/GPIO, radio operation, real rootfs expansion
- **on-radio AP activation + live client DHCP** (nspawn has no wifi device; CI proves the
  address-dependent half and package presence, see R17)

## Routine release
- Re-run the workflow (dispatch or tag `v*`); artifacts + logs upload; a `v*` tag publishes per
  variant **independently** (Lite can release while Desktop is still red/oversized).

## Base image roll
- `BASE_URL`/`BASE_SHA256` are RESOLVED each run (latest official build) and verified together; a
  base roll is the one change that can break provisioning silently — read the logs.
- **Kernel/bootloader/firmware are PINNED to the base image**, not separately upgraded. They are held
  during the in-container `apt full-upgrade` (nspawn cannot regenerate an initramfs), so they stay at
  the base version and advance only when the base rolls. All other packages ARE brought current. The
  build fails closed if any hold survives or `update-initramfs` isn't restored to the real binary.

## LHPC + binary channel (pin-of-pins)
- Each run resolves `loraham-pi-control` `main` and records the installed SHA in
  `/etc/lhpc-image.json`; that commit pins daemon/bridge/meshcom-qemu/firmware, and the binary
  channel pins artifact shas.
- **Cross-repo dependency:** the binary stacks only install when `lhpc-binaries` has artifacts
  matching the resolved `main` manifest pins. If `main` outruns the channel the run fails those
  stacks by design (no `--source pinned` workaround) — rebuild `lhpc-binaries`, then re-run.

## Dependencies to keep an eye on
- `INVOCATION_ID`-unset operator path (delta-7 focused test): revalidate against new LHPC SHAs.
- The base's first-user mechanism (userconf/custom.toml) — inspected per base, not hardcoded.
- Monthly `schedule:` **builds both unconditionally** (so a package-only Debian/RPi security update is
  picked up even with no new base or LHPC commit) and publishes a dated `img-YYYY.MM.DD-HHMM` release
  **only when the full provenance signature** (base sha + package-manifest sha + LHPC commit + component
  report sha) differs from the latest release — else finishes green with no duplicate. GitHub disables idle schedules
  (~60 days) — dispatch manually to re-enable.

## Upstream asks (not implemented here)
- `install.sh --ref <sha|tag>` for pinned-not-recorded reproducibility.
- Treat `N0CALL` as unset in the console dashboard predicate.
- Gate B: self-hosted Pi runner + Zero-2W DUT for the hardware-only properties above.
