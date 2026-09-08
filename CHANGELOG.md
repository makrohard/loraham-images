# Changelog

Milestones only. Full detail is in the commits and in [`docs/maintenance.md`](docs/maintenance.md).

## Unreleased

- `precheck` fails the build when the published binary index cannot satisfy the manifest on
  `loraham-pi-control` `main` — a missing binary stack, a missing covered component, a drifted sha
  or an unreadable index schema — instead of dying an hour later inside `auto-install`.
- The changelog entry for a rebuild whose only changed input is the LHPC commit is one line.

## v0.3.3

- Rebuild on `loraham-pi-control` **v0.3.3** (`f113028`): documentation only — one canonical owner
  per subject and the release-matrix rule. Source pins and binaries unchanged since v0.3.1.

## v0.3.2

- Rebuild on `loraham-pi-control` **v0.3.2** (`b57fa3f`): internal restructuring of the controller
  (core service coupling reduced, no behaviour change), CI coverage measurement on. Source pins and
  binaries unchanged since v0.3.1.

## v0.3.1

- Rebuild on `loraham-pi-control` **v0.3.1** (`c54a90f`): Meshtastic serves the newest web client
  (meshtastic/web v2.7.2, pinned and sha256-verified by the controller) from the republished
  meshtastic binary; source pins unchanged. An image is re-cut whenever a binary is republished.

## v0.3.0

- Rebuild on `loraham-pi-control` **v0.3.0** (`af819f5`): the `igate` stack is gone and Graywolf is the
  APRS station, so the image ships **nine** stacks; source pins and the published binaries are
  unchanged since v0.2.10 (Reticulum 1.5.2, MeshCom firmware 674413c with the QEMU overlay 579e463,
  Meshtastic v2.7.26). The controller's from-zero install, cross-cutting checks and boot restore were
  measured on a Zero 2 W before the tag (`docs/live-test.md` in that repo). Image docs ground-truthed
  (regional settings after first boot, the replayed first boot, the deferred webserver Apply, the
  prebuilt daemon and meshtasticd, Gate A2 scope).

## v0.2.10

- Rebuild on `loraham-pi-control` v0.2.10: **pins moved** — Reticulum 1.5.2, the MeshCom firmware
  `dev` tip 674413c with the QEMU overlay rebased onto it (meshcom-qemu-raspi 579e463: `setup.sh`
  fetches by ref, and the overlay bounds the tip's new per-loop GPS UART drain that starved the
  firmware loop under QEMU), Meshtastic on the stable release tag v2.7.26 (the known-working line
  follows stable tags, `dev` follows master); both binaries republished before this tag. Also the
  known-working fix for headless boxes (a skipped GUI sidecar no longer blocks the composition).
  Proven by the release test matrix (`docs/test-matrix.md`) on a Zero 2 W. The seal is unchanged

## v0.2.9

- Rebuild on `loraham-pi-control` v0.2.9: **Start means start** — a web Start or Restart runs the
  saved configuration (Settings is the only place configuration changes), runs detached with the
  task banner following it, and only a consequential choice (a stack to stop, dependents a restart
  takes down) asks for confirmation; pages read their evidence once per request (about half the
  render time on a Pi); the stack page shows the stored web-UI passwords; the Meshtastic CLI is an
  on-demand component listed on the Dashboard. No pins moved; the seal is unchanged

## v0.2.8

- Rebuild on `loraham-pi-control` v0.2.8: the MeshCore stack can run the **openHop repeater**
  (chat node, repeater, or both in one process; `lhpc config meshcore mode …`), proxied web pages
  are per component, proxy deny lists are spelling-tolerant. The openHop repeater and its
  RepeaterUI are added to the licence section (MIT). Re-cut on the final v0.2.8 head (the Stacks
  list no longer shows a version twice; denied proxy paths answer 404 so the openHop dashboard
  keeps its session); the seal strips CherryPy's public test key

## v0.2.6

- Rebuild on `loraham-pi-control` v0.2.6. The v0.2.2 and v0.2.4 images shipped as rebuild-only
  tags with no changelog entry of their own; v0.2.3 and v0.2.5 had no image release. This entry
  therefore also covers what those LHPC versions brought (MeshCore persistent identity + startup
  position, the guarded `lhpc meshtastic` passthrough, Voice on headless/Lite boxes, the
  Stacks-WebGUI proxy panel) alongside **coherent identities**
- **First boot: `CALL` must be your bare base callsign.** The global operator callsign takes no
  SSID and no `/P` — LHPC refuses one — so `lhpc-config.txt` now rejects it while naming the file
  and key, instead of failing mid-boot with "callsign set failed". Per-stack variants (Graywolf's
  APRS `-SSID`, MeshCom's `-1`…`-99`) are set after first boot
- **A stack without a resolvable identity refuses to start.** Licensed stacks inherit the global
  callsign while their own field is empty; Meshtastic and MeshCore never inherit one and need
  their own node names. README/first-steps corrected in both languages — the old instruction to
  enter the station callsign *with an APRS SSID* as the global setting would now be refused
- README: **Licenses & attribution** section — per-project licenses and source links for the
  binaries the images ship prebuilt (graywolf, Meshtastic web)
- The `v0.2.6` tag was moved twice before the published build (a first build failed on a stale
  openHop patch, then the baked docs were corrected). A clone that fetched an earlier `v0.2.6`
  keeps the old commit until `git fetch --tags --force`; the release assets are the final build

## v0.2.1

- Rebuild on `loraham-pi-control` v0.2.1 (`c9ae725`): the Network panel's **"Back to AP mode"**
  works on fresh images — the installed polkit rule now grants the NetworkManager `wifi.share.*`
  actions that re-activating the box's own (shared) AP requires

## v0.2.0

- Rebuild on `loraham-pi-control` v0.2.0 (`fbdec79`), version aligned to LHPC's. **On-device
  behavior is unchanged from the v0.1.17-based image**: LHPC 0.2.0's headline additions — the
  interactive in-browser **Pages demo** and the **Codespaces test lab** — ship nothing into the
  wheel or the image; the cloned LHPC source now also carries their `demo/` and `testlab/` trees,
  inert on the Pi
- README rebuilt around a browser-first **Install** walkthrough (12 steps, CLI collapsed per step);
  the on-device first-steps no longer tell a Lite box to update the OS while on its own
  AP, where it has no internet

## v0.1.15

- Rebuild on `loraham-pi-control` v0.1.17 (`50dcb4b`): **Network** panel on lite images —
  join an existing Wi-Fi from the console with the box's own AP as automatic fallback and
  an optional preferred network; power-button visibility fixed on fresh images

## v0.1.14

- Rebuild on `loraham-pi-control` v0.1.16 (`03b1804`): dashboard **Reboot / Shut down**
  buttons (polkit rule installed by bootstrap, so fresh images have them working out of
  the box); stopping a stack tears down the dependency chain it alone used; the
  Start-confirm page shows and edits dependency-stack parameters

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
