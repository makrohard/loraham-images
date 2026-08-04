# loraham-images

Ready-to-use **Raspberry Pi OS Trixie (arm64)** images with [LHPC](https://github.com/makrohard/loraham-pi-control)
preinstalled, built in GitHub Actions on native arm64 runners. Flash, boot, use.

| Image | For | Network | Out of the box |
|-------|-----|---------|----------------|
| **lite** | headless field box (e.g. Pi Zero 2 W) | its own Wi-Fi access point | console reachable at `https://10.42.0.1:8443` |
| **desktop** | a Pi with a screen | your Wi-Fi/Ethernet (DHCP) | console on the box itself (loopback) |

## Onboarding defaults (change them after setup)

These are **intentional public defaults** so the box works immediately. They are for local
commissioning, not permanent secure operation, and the console is not exposed to your LAN or
the Internet by default.

- user **`lhpc`**, password **`lhpc`**
- hostname / AP SSID **`lhpc-<device-suffix>`**
- AP key **`lorahampi`**  · Wi-Fi country **`DE`**

## Flash

1. Download `loraham-lhpc-<variant>.img.xz` + verify: `sha256sum -c loraham-lhpc-<variant>.img.xz.sha256`.
2. Raspberry Pi Imager → *Use custom image* → select the `.img.xz` → write. (Imager's OS
   customisation is unreliable on Trixie custom images; this image self-configures at first boot.)
3. Boot. **Lite:** join Wi-Fi `lhpc-…`, open `https://10.42.0.1:8443`. **Desktop:** find it on
   your network by hostname `lhpc-….local`.

Then: change the password, change the AP key, pick hardware, set your callsign. See the
`README.txt` on the boot partition, and the installed LHPC docs
(`~/loraham-pi-control/src/loraham-pi-control/README.md`, its `docs/`, `lhpc --help`).

## Optional pre-boot config

Edit `lhpc-config.txt` on the FAT boot partition to override defaults (`HOSTNAME`, `PASSWORD`,
`AP_SSID`, `AP_PSK`, `WIFI_COUNTRY`, `CALL`, …). Optional — the image boots without it.

## Moving Lite onto your home Wi-Fi

Lite's SSH is bound to the AP address `10.42.0.1` and the console is scoped to the AP subnet.
When you join the box to a normal network the AP address disappears, so reach it on the new
network and re-point exposure there. Do not open a wildcard SSH listener — that re-exposes the
shared default password.

## Bands (what can run where)

- 433 MHz only: Chat, iGate, MeshCom · 868 MHz only: MeshCore · either band: KISS, Meshtastic,
  Reticulum, Voice. One owner per band at a time; *installed ≠ simultaneously runnable*; which
  bands are available depends on the hardware you pick. LHPC refuses conflicting starts.

## Security & rotation

Default credentials + an unpatched base age badly. A **monthly workflow** rebuilds both images
on the latest base + packages + current LHPC. Always `sudo apt full-upgrade` an older download.

## Maintenance / upstream asks

See [`docs/maintenance.md`](docs/maintenance.md). Not maintained here: you update LHPC on the
running box, not by reflashing. Upstream asks: `install.sh --ref`, treat `N0CALL` as unset in
the console, hardware-in-the-loop Gate B.
