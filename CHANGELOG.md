# Changelog

Milestones only. Full detail is in the commits and in [`docs/maintenance.md`](docs/maintenance.md).

## v0.1.13

- Rebuild on `loraham-pi-control` v0.1.15 (`4832aa3`): graywolf's 433 TX defaults to
  433.775 (single-channel, heard by stock ESP32 trackers; the RX/TX split stays
  available by config)

## v0.1.12

- Rebuild on `loraham-pi-control` v0.1.14 (`6e1d1e6`): the Certificates panel's `scp`
  fetch copyboxes render in every serving mode again, so a plain no-auth box can bootstrap
  cert auth from them (they carry the box's live IP and only active certs)

## v0.1.11

- Rebuild on `loraham-pi-control` v0.1.13 (`4abcefc`): graywolf gains an upstream-release
  check and a one-click update to the latest `.deb` (verified against upstream's own
  checksums.txt); the default pinned/reviewed fetch is unchanged

## v0.1.10

- Rebuild on `loraham-pi-control` v0.1.12 (`1735e2f`): boot-restore honors an explicit
  operator stop across reboots, the Certificates panel gains scp/download fetch helpers
  for the trust material, and fetched packages (graywolf) show their version with an
  Update offer when the pin moves

## v0.1.9

- Rebuild on `loraham-pi-control` v0.1.11 (`819e392`): graywolf replaces the deprecated igate
  (fetched `.deb`, own web login), GPS works out of the box (source `auto` + per-stack
  `use_gps` on — a box without gpsd simply runs without position), and the Stacks page no
  longer jumps when using the accordion

- Proxies the new `graywolf` stack's web UI: AP-only on Lite (`10.42.0.1:8446`), loopback-only on
  Desktop, following the existing `PROXY_MODE`. The proxy is no-auth like the others, but graywolf
  has its own generated login — the console shows where to read it. Appended to `PROXY_STACKS` so
  MeshCom (8444) and Meshtastic (8445) keep their ports

## v0.1.8

- Rebuild only — nothing in this repo changed. Picks up `loraham-pi-control` `f79da61`: the LoRaHAM daemon, chat and iGate are plain GPLv3 (the extra non-commercial and reporting conditions are gone, with the author's permission), and a finished task banner dated in the future no longer sticks on a box whose clock lags the build

## v0.1.7

- Image objects are root-owned again (the overlay copy handed `/`, `/etc` and `/usr` to the operator account); keyboard follows `KEYBOARD=` (default `de,us`, console + labwc); Desktop gains a Markdown viewer, console/README launchers, the console CA trusted in Chromium and a wallpaper; the build-time LHPC clone is dropped

## v0.1.6

- **Recovery no longer depends on a successful first boot.** SSH comes up before the rootfs
  expansion, and a distinct `lhpc-recovery-<suffix>` access point is raised while first boot is
  incomplete — a Wi-Fi-only box whose expansion failed is reachable instead of needing the card
  pulled.
- **First boot is convergent and interruption-safe.** A corrected `lhpc-config.txt` re-runs the
  affected steps and they now undo as well as apply; completion is a guarded, flushed transaction
  that survives a power cut; an existing device PKI is never recreated.
- **The shipped filesystem has real free space.** The safety margin used to be unallocated
  partition space, so images went out at their minimum size; ext4 is now grown into it and the
  build fails below 48 MiB free.
- **Destructive image steps fail closed.** A failed unmount or loop detach stops the build before
  repartitioning or truncation, instead of risking a second loop device over a mounted filesystem.
- **Per-variant posture is declared, not inferred.** Lite proxies the stack web UIs on its access
  point with no password; Desktop keeps them on loopback. Both apply the managed firewall, block
  the stacks' own ports, and ship SSH on every interface.
- **Lite no longer ships a graphical application.** Sideband is a desktop app but declared no
  graphical package to gate on, so it was installed on the headless image; it is now excluded like
  Voice and the Node Manager GUI, and Lite is roughly 300 MiB smaller (1058 -> 756 MiB).
- Timezone is configurable and defaults to `Europe/Berlin`; `tmux` and `btop` are included.
- Documentation rewritten around one zero-to-hero path, with the first-boot settings, the hardware
  table and the certificate flow.

## v0.1.5

- `lhpc-growroot.service` owns rootfs expansion as a fail-closed early oneshot, after the base's
  own resizer was found to disable itself during the build and ship an unexpanded filesystem.

## v0.1.0 – v0.1.4

- First releases: Lite and Desktop images built in CI on native arm64, sealed and gated by a
  throwaway first-boot plus cold-reboot run.
