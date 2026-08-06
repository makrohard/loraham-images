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
  documented onboarding password; rootfs expansion owned SOLELY by `lhpc-growroot.service` (armed +
  `growpart` present, both hard-asserted; firstboot `Requires=` it; base `rpi-resize` must stay
  disabled — seal fails on a second armed resizer)
- Gate A2 (throwaway copy, `--private-network`): out-of-box journey — user units, `/healthz`, web
  GUI loads, recovery sshd on all interfaces wherever `SSH_ENABLE=on` (both variants today),
  stack web-UI proxies configured per `PROXY_STACKS`, daemon start refused, fresh device PKI,
  swap fixture, firstboot idempotent — plus the **cold-reboot** gate + host-netns-unchanged
- seal also asserts: all four overlay programs executable, and `lhpc-recovery` +
  `lhpc-recovery-ap` armed and requiring nothing (a failed expansion must still leave a way in)
- static gate (`tests/static.sh`, before any build): shellcheck + `bash -n`; the real
  `lhpc-config.txt` parser against valid/misspelled/invalid input; strict phase-boundary detach
  under injected unmount/losetup failures; recovery-AP persisted-profile handling; and the
  device-suffix derivation being identical in `lhpc-firstboot` and `lhpc-recovery-ap`
- final compressed size ≤ 2 GiB

## Honest limits — hardware Gate B only (never claimed CI-proven)
- real Raspberry Pi firmware/device-tree boot, SPI/GPIO, radio operation
- **real rootfs expansion** — CI grows a throwaway copy to *simulate* it, so a broken resize passes CI.
  Found live 2026-08-05: the base's `rpi-resize` self-disables during our build boot → fs never grew →
  100% full → firstboot died at ENOSPC. Fixed: `lhpc-growroot.service` (early oneshot, fail-closed,
  growpart+resize2fs + size postconditions) is the sole owner; firstboot `Requires=` it. **A real Pi
  first boot must still be smoke-tested after base rolls.**
- **on-radio AP activation + live client DHCP** (nspawn has no wifi device; CI proves the
  address-dependent half and package presence, see R17)
- **the console starting under the unit configuration we actually ship.** Gate A2 injects a
  CI-only drop-in relaxing `ProtectKernelModules` / `ProtectKernelTunables` /
  `ProtectControlGroups` on `lhpc-web` and `lhpc-nginx`, because a non-root user manager cannot
  drop bounding-set capabilities under nspawn (218/CAPABILITIES). So "the console comes up" —
  the product promise — is validated against a *modified* unit set. The shipped hardening is
  never exercised until a real boot.
- **the managed firewall's live ruleset and AP-source filtering** (nspawn has no nftables; the
  first-boot step configures and applies, but only hardware proves what is actually reachable)
- **fallback recovery AP** (`lhpc-recovery-ap`): force `lhpc-growroot` to fail on a real Zero and
  confirm from another device that `lhpc-recovery-<suffix>` appears, SSH answers, firstboot stays
  blocked, and the handover is clean once expansion is restored.
- **`step_timezone`** on real hardware (CI asserts the parser, not `/etc/localtime`)

## First boot: resume and re-run
`run_step` marks each step done under `/var/lib/lhpc/firstboot.d`, so a failed boot resumes
rather than repeating work. The resolved `lhpc-config.txt` overrides are fingerprinted: when they
change, the markers are dropped and the whole sequence re-runs, so an operator's correction to
`PASSWORD`/`HOSTNAME`/etc. takes effect instead of being silently skipped.

Completion is a guarded transaction. Redaction of `PASSWORD=`/`AP_PSK=` must happen *before*
`.firstboot-done` — otherwise an interruption between them leaves those credentials in plaintext
on the FAT partition and the unit condition guarantees nothing ever returns to clean them. But
that ordering alone would strand a box: the next boot finds `REDACTED`, which the parser refuses.
So `/var/lib/lhpc/.firstboot-finalizing` is written first, and a boot that finds it finishes the
transaction (idempotent redaction, marker, disable) **without replaying any step** — every step
had already succeeded. `.firstboot-done` is written before the finalizing marker is removed, so a
power loss after that point is harmless. Each transition is `sync`ed — the transaction spans
the FAT boot config and the ext4 markers, and unsynced writes can persist out of order in
either direction — and the redaction is verified by reading the file back rather than
trusting `sed`'s exit status. On Lite the finalizer also hands the radio back (delete
`lhpc-recovery-ap`, activate `lhpc-ap`) before declaring completion, because
`lhpc-recovery-ap` runs first and only stands down when `.firstboot-done` already exists.

Re-running first boot on a COMMISSIONED box is not a supported operation, and the obvious
recipe is a trap. `lhpc-firstboot.service` disables itself on success and carries
`ConditionPathExists=!/var/lib/lhpc/.firstboot-done`, so deleting state files alone does nothing.
If you force it anyway: completion has already rewritten `PASSWORD=`/`AP_PSK=` in
`lhpc-config.txt` to `REDACTED` (the parser now refuses that value rather than setting your
password to the literal word); Lite recreates its AP unconditionally, resetting an operator key
set later with `nmcli`; and a missing `device_pki.done` reissues both CAs, invalidating every
client certificate already in a browser. Change settings on a live box with the ordinary tools —
`lhpc config`, `lhpc webserver …`, `passwd`, `nmcli` — not by replaying first boot.

Because a rerun replays the WHOLE sequence, the steps must be convergent, not just skippable:
- `device_pki.done` is the one marker PRESERVED across a config-change rerun. `webserver init`
  over an existing PKI is refused (exit 1 — recreating the CAs is destructive), so replaying the
  step would loop forever; if the first attempt never got that far there is no marker and
  initialisation still runs. Do NOT gate this on `lhpc webserver verify`: that command also
  validates nginx config, the console unit and the exposure plan, so an attempt that died at
  expose/console would fail it *with* the PKI present and run init anyway. An existing PKI is
  kept as-is, so changing `HOSTNAME` later leaves the old `<host>.local` SAN — access by IP is
  unaffected; reissue deliberately with `lhpc webserver init --confirm-recreate`. When the marker
  IS absent the step inits with `--confirm-recreate`, because creation and the marker are not
  atomic: a power cut in between leaves CA material that a plain init would refuse forever. Safe
  only in that bounded case — the sealed image ships no PKI, so anything present came from an
  interrupted, uncommitted attempt.
- `expose` restores a loopback-only console when the resolved scope is not `ap`, and `callsign`
  clears a previously applied callsign when `CALL` is empty or `N0CALL`. Both are required
  convergence operations, so a failure fails the step — it must not be marked done while the old
  exposure or callsign is still live.
- `ap`/`confirm_ap` are deliberately NOT marker-tracked: radio ownership is re-established on
  every incomplete boot, otherwise an unchanged retry could finish while `lhpc-recovery-ap` still
  held the radio and leave a "complete" box advertising the recovery SSID.

## Routine release
- Re-run the workflow (dispatch or tag `v*`); artifacts + logs upload; a `v*` tag publishes per
  variant **independently** (Lite can release while Desktop is still red/oversized).

## Base image roll
- `BASE_URL`/`BASE_SHA256` are RESOLVED each run (latest official build) and verified together; a
  base roll is the one change that can break provisioning silently — read the logs.
- **Brittle external dependency (fail-closed):** `resolve-base.sh` scrapes the Raspberry Pi OS
  autoindex HTML with two `curl | grep -oE` passes and has **no fallback** (the `*_REF` values were
  deliberately removed). If Raspberry Pi changes that page's format, **every build stops** until the
  scraper is rewritten. This is intentional (a wrong base is far worse than no build), but it is the
  single most fragile upstream coupling — check here first if all builds suddenly fail to resolve a base.
- **Kernel/bootloader/firmware are PINNED to the base image**, not separately upgraded. They are held
  during the in-container `apt full-upgrade` (nspawn cannot regenerate an initramfs), so they stay at
  the base version and advance only when the base rolls. All other packages ARE brought current. The
  build fails closed if any hold survives or `update-initramfs` isn't restored to the real binary.

## LHPC + binary channel (pin-of-pins)
- Each run resolves `loraham-pi-control` `main` and records the installed SHA in
  `/etc/lhpc-image.json`; that commit pins daemon/bridge/meshcom-qemu/firmware, and the binary
  channel pins artifact shas.
- The recorded SHA is only as durable as the commit it names. If that commit is later amended or
  force-pushed in `loraham-pi-control`, an already-published image cites something unreachable
  from `main` — and a provenance SHA that will not resolve is the first thing anyone reaches for
  on a bug report. Nothing here can prevent it (the SHA is resolved at job start; the rewrite
  happens afterwards), so the rule is simply: do not build against a commit you intend to rewrite.
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
