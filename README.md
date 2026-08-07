# loraham-images

Ready-to-use **Raspberry Pi OS (Trixie, 64-bit)** images with
[LHPC](https://github.com/makrohard/loraham-pi-control) preinstalled. Flash it, boot it, and set it up
from your phone or a browser — no Linux experience needed.

## What's in the image

LHPC plus **nine stacks, already installed and built** — eight applications and the LoRaHAM radio
daemon they share. The applications fall into two families, and the difference matters legally:

- **Amateur radio** — LoRaHAM **Chat**, **iGate**, **Voice**, **KISS/APRS TNC**, and **MeshCom**.
  These run on amateur bands, identify with your callsign, and are normally **not encrypted**.
  They need an amateur radio licence.
- **Licence-free / encrypted** — **Meshtastic**, **MeshCore**, **Reticulum**. These are designed for
  licence-free ISM use and normally **encrypt** their traffic. No licence, but power and duty-cycle
  limits apply.

> **Your responsibility.** Which bands, power levels, duty cycles and encryption are lawful depends
> on your country and on whether you hold a licence — and the same radio can be used either way.
> LHPC will not decide this for you. Nothing transmits until you choose your hardware and start a
> stack, so check your local rules first.

> **The defaults are public.** The login (`lhpc` / `lhpc`) and the Wi-Fi key (`lorahampi`) are the
> same on every image, and SSH answers on every network the Pi joins. They exist so a fresh card is
> usable at all — close them before the box goes anywhere: [Zero to hero](#5--zero-to-hero),
> steps 2–3.

## Contents

- [What's in the image](#whats-in-the-image)
- [1 · Pick an image](#1--pick-an-image)
- [2 · Download](#2--download)
- [3 · Flash](#3--flash)
- [4 · What first boot sets up](#4--what-first-boot-sets-up)
- [5 · Zero to hero](#5--zero-to-hero)

## 1 · Pick an image

| Image | Use it for |
|-------|-----------|
| **lite** | a headless Pi (e.g. Pi Zero 2 W). It makes **its own Wi-Fi** so you configure it from a phone. |
| **desktop** | a Pi with a screen. It joins **your** Wi-Fi/Ethernet and boots to a desktop. |

## 2 · Download

### → [**Download the latest images**](https://github.com/makrohard/loraham-images/releases/latest)

Grab `loraham-lhpc-lite.img.xz` **or** `loraham-lhpc-desktop.img.xz`.

<details><summary>Check the download is intact (optional)</summary>

Download the `.sha256` file for **your** image from the same release, put it beside the image, then:

```bash
sha256sum -c loraham-lhpc-lite.img.xz.sha256
```
It should print `loraham-lhpc-lite.img.xz: OK`.
</details>

## 3 · Flash

1. Install **[Raspberry Pi Imager](https://www.raspberrypi.com/software/)**.
2. **Choose OS → Use custom** → pick the `.img.xz` you downloaded.
3. **Choose Storage** → your SD card. *(Ignore Imager's “OS customisation” prompt — this image sets
   itself up.)*
4. **Write.** Put the card in the Pi and power on. First boot takes about 1–2 minutes.

<details><summary>Optional: pre-configure before the first boot</summary>

After flashing, a small drive named **`bootfs`** appears. **Create** a file on it called
**`lhpc-config.txt`** — the image does not ship one; without it every default below applies. Plain
`KEY=VALUE`, one per line, **no inline comments**; anything you leave out keeps its default:

```
HOSTNAME=lhpc-shack
PASSWORD=choose-a-password
AP_PSK=choose-a-wifi-key
WIFI_COUNTRY=DE
TIMEZONE=Europe/Berlin
KEYBOARD=de,us
CALL=N0CALL
```

`AP_PSK` applies to **Lite** only — Desktop joins your network instead of making one, so the key is
accepted and then ignored there. Everything else applies to both.

If first boot fails partway, fix the file and reboot — the Pi notices the change and re-runs the
affected steps, so your correction actually applies.

`AP_PSK` must be 8–63 characters, `WIFI_COUNTRY` your two-letter code (e.g. `DE`, `US`, `GB`) and
`TIMEZONE` a zone name from `/usr/share/zoneinfo` (e.g. `America/New_York`) and `KEYBOARD` one to
four xkb layout names, first is primary (e.g. `us`, or `de,us` for German with English on
`Alt+Shift`). An
invalid file is rejected on first boot, with the reason written to `lhpc-config-error.txt` on this
same drive.
</details>

## 4 · What first boot sets up

| | Lite (headless) | Desktop (screen) |
|---|---|---|
| login | `lhpc` / `lhpc` | `lhpc` / `lhpc` |
| hostname | `lhpc-XXXX` | `lhpc-XXXX` |
| region | `Europe/Berlin` · `DE` · keyboard `de,us` | `Europe/Berlin` · `DE` · keyboard `de,us` |
| Wi-Fi | **its own AP** `lhpc-XXXX` / `lorahampi` at `10.42.0.1` | **joins yours** (Wi-Fi menu or Ethernet) |
| Web GUI | `https://10.42.0.1:8443` — AP only, no password | `https://127.0.0.1:8443` — on the Pi only |
| MeshCom UI | `10.42.0.1:8444` — AP only | `127.0.0.1:8444` — on the Pi only |
| Meshtastic UI | `10.42.0.1:8445` — AP only | `127.0.0.1:8445` — on the Pi only |
| SSH | on, **every** network the Pi is on | on, **every** network the Pi is on |
| firewall | on; the stacks' own ports are blocked | on; the stacks' own ports are blocked |
| stacks | installed & built, **minus the desktop-only parts**, none running | **all** installed & built, none running |
| autostart | **on** — stacks running at shutdown come back after a reboot | same |
| radios | **nothing runs, nothing transmits** | **nothing runs, nothing transmits** |

`XXXX` is a per-device suffix. If you see **`lhpc-recovery-XXXX`** instead, first boot did not finish —
join it (key `lorahampi`, always the factory one) and see Troubleshooting.

> **The regional defaults are German** — timezone `Europe/Berlin`, Wi-Fi country `DE`, keyboard
> `de,us` (German, with English on `Alt+Shift`). Set `TIMEZONE`, `WIFI_COUNTRY` and `KEYBOARD` in
> `lhpc-config.txt` before the first boot to change them. **`WIFI_COUNTRY` is a regulatory setting:
> outside Germany you must set your own before operating the radio.**

## 5 · Zero to hero

Same steps for both images; differences are marked.

**1 · Connect.**
*Lite:* join the Wi-Fi `lhpc-XXXX` (key `lorahampi`) from a phone or laptop, then `ssh lhpc@10.42.0.1`
(password `lhpc`).
*Desktop:* sign in on the Pi, join your network, open the **Terminal** app.

**2 · Change the password** — it is public, and SSH answers on every network the Pi joins.
```bash
passwd
```

**3 · Change the Wi-Fi key** *(Lite only)* — also public.
```bash
sudo nmcli connection modify lhpc-ap wifi-sec.psk 'your-new-key'   # 8+ characters
sudo nmcli connection up lhpc-ap                                   # rejoin with the new key
```

**4 · Update the OS.**
```bash
sudo apt update && sudo apt full-upgrade -y
```

**5 · Set your callsign.**
```bash
lhpc config operator --callsign DL1ABC
```

**6 · Pick your radio hardware** — nothing can transmit until you do.
```bash
lhpc hardware                    # shows the choices
lhpc hardware uputronics         # e.g. a dual Uputronics rig
```

| `lhpc hardware` | board | bands |
|---|---|---|
| `loraham` | LoRaHAM dual-module (SX1278 + RFM95) | 433 + 868 |
| `uputronics` | Uputronics dual (CE0 + CE1) | 433 + 868 |
| `uputronics-433` / `uputronics-868` | Uputronics single | 433 / 868 |
| `waveshare-433` / `waveshare-868` | Waveshare SX1262 | 433 / 868 |

Both images ship SPI as **`soft-cs`** (`dtparam=spi=on` + `dtoverlay=spi0-0cs`), which is what every
board above needs — the radios drive their own chip-selects as GPIOs. Only change it if your board
truly uses kernel chip-selects:
```bash
sudo bash ~/loraham-pi-control/src/loraham-pi-control/bootstrap-deps.sh --spi-mode hardware-cs
```

**7 · Start a stack.** The stacks are **already installed and built** — you only start what you
want, from the Web GUI or:
```bash
lhpc status                      # what is installed and what is running
lhpc stack start meshtastic      # start one
lhpc stack stop meshtastic       # stop it again
```
On **Lite** the three parts that need a desktop are deliberately not built — Voice, MeshCore's Node
Manager GUI and Reticulum's Sideband; everything headless is there. Desktop has all of them.

Only one stack owns a band at a time; LHPC refuses a conflicting start. **Boot auto-restore is on**,
so whatever is running when you reboot starts again by itself — check with `lhpc autostart`, and
switch it off there if you would rather start things by hand.

<details><summary>Reach the Web GUI from your LAN (needs a client certificate)</summary>

By default the console is AP-only (Lite) or local-only (Desktop). To reach it from your network,
expose it and install a client certificate in your browser. `local-open-remote-auth` keeps the
console open **on the Pi itself** and requires the certificate from everywhere else — that is the
mode you normally want. (`auth-everywhere` would demand a certificate on the Pi too.)

```bash
# 1 · expose to your LAN: open on the Pi itself, certificate required from anywhere else
lhpc webserver expose --cidr 192.168.1.0/24 \
     --access-mode local-open-remote-auth --confirm-phrase enable-remote
lhpc webserver apply

# 2 · issue a certificate — this prints a one-time passphrase, copy it now
lhpc webserver cert issue phone

# 3 · write the .p12 out, then copy it off the Pi (last line runs on your computer)
lhpc webserver cert export phone ~/phone.p12
scp lhpc@<pi-ip>:~/phone.p12 .
```
Import `phone.p12` into your browser/OS keystore using that passphrase, then open
`https://<pi-ip>:8443` and pick the certificate when asked. `lhpc webserver cert list` shows what is
issued; `revoke` withdraws one. Without a certificate the connection is refused, which is the point.

**Optional — trust the Pi's CA** so the browser stops warning about the server certificate. Each box
generates its own CA at first boot; copy it and add it to your trust store:
```bash
scp lhpc@<pi-ip>:~/loraham-pi-control/config/tls/server-ca/ca.crt lhpc-ca.crt
```
Import `lhpc-ca.crt` as a **certificate authority** (browser or OS keystore) — not as a personal
certificate. It is that Pi's own CA and signs nothing else, so trusting it grants nothing beyond
that box. Skipping this only means you keep accepting the warning.
</details>

<details><summary>Troubleshooting</summary>

- **No `lhpc-XXXX` Wi-Fi after ~2 min** — re-seat/re-flash the card; check power. If a
  **`lhpc-recovery-XXXX`** network appears instead, the Pi booted but first boot did not finish: join it
  (key `lorahampi`), `ssh lhpc@10.42.0.1`, and read `/var/log/lhpc-firstboot.log` plus
  `systemctl status lhpc-growroot`. It retries on the next boot.
- **Web GUI won't open** — *Lite:* you must be joined to the AP, and use `https://10.42.0.1:8443`.
  *Desktop:* it is local-only, so open `https://127.0.0.1:8443` **on the Pi**. Accept the self-signed
  warning.
- **Moved the box onto your home Wi-Fi?** `10.42.0.1` and the AP-scoped GUI go away; **SSH stays
  reachable** on the new IP — which is why changing the password comes first. To get the GUI back, see
  the certificate section above.
</details>

<details><summary>Updating &amp; maintenance</summary>

- LHPC: `lhpc self-update` (or the one-click updater in the console).
- OS: `sudo apt update && sudo apt full-upgrade`.
- A single stack, only if you want a newer version than the image shipped: `lhpc update <stack>`.
  Stacks are already installed and built — updating is optional, not part of setup.
- Images are rebuilt monthly on the latest official base; **kernel, bootloader and firmware track that
  base**. Update in place — you don't need to reflash. Maintainer notes:
  [`docs/maintenance.md`](docs/maintenance.md).
</details>

---

**Defaults** — for local commissioning only, change them:

- user **`lhpc`** / password **`lhpc`**
- AP **`lhpc-XXXX`** / key **`lorahampi`**
- recovery AP **`lhpc-recovery-XXXX`** / key **`lorahampi`** (factory key, always)
- Wi-Fi country **`DE`** · timezone **`Europe/Berlin`** · keyboard **`de,us`** (German; `Alt+Shift` for English)
- `XXXX` is a per-device suffix

**More docs** — LHPC upstream: [README](https://github.com/makrohard/loraham-pi-control#readme) ·
[docs](https://github.com/makrohard/loraham-pi-control/tree/main/docs). The same files are on the Pi
at `~/loraham-pi-control/src/loraham-pi-control/`, plus `lhpc --help`.
