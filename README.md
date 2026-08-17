🇩🇪 **[Hier geht's zur deutschen Anleitung](README_DE.md)**

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
> usable at all — close them before the box goes anywhere:
> [Install](#install), steps 7–8.

## Contents

- [Install](#install) — flash → configure from the browser → on the air, in 12 short steps
- [GPS (optional)](#gps-optional)
- [Troubleshooting](#troubleshooting)
- [Defaults](#defaults)

## Install

Browser first: every step shows the click path, and the same thing as commands is in a collapsed
**CLI** block. **Lite** (headless — makes its own Wi-Fi) and **Desktop** (screen — joins your
network) differ only where marked.

You need: a Pi (e.g. Zero 2 W), an SD card, a phone or laptop — and your **radio board attached**
before step 5.

### 1 · Download

| Image | Use it for |
|-------|-----------|
| **lite** | a headless Pi (e.g. Pi Zero 2 W). It makes **its own Wi-Fi** so you configure it from a phone. |
| **desktop** | a Pi with a screen. It joins **your** Wi-Fi/Ethernet and boots to a desktop. |

Grab `loraham-lhpc-lite.img.xz` **or** `loraham-lhpc-desktop.img.xz` from the
### → [**latest release**](https://github.com/makrohard/loraham-images/releases/latest)

<details><summary>Check the download is intact (optional)</summary>

Download the `.sha256` file for **your** image from the same release, put it beside the image, then:

```bash
sha256sum -c loraham-lhpc-lite.img.xz.sha256
```
It should print `loraham-lhpc-lite.img.xz: OK`.
</details>

### 2 · Flash

**[Raspberry Pi Imager](https://www.raspberrypi.com/software/)** → *Choose OS → Use custom* → your
`.img.xz` → *Choose Storage* → your SD card → **Write**. Ignore Imager's "OS customisation" prompt —
this image sets itself up. Card into the Pi, power on; first boot takes about 1–2 minutes.

<details><summary>Optional: pre-configure before the first boot</summary>

After flashing, a small drive named **`bootfs`** appears. **Create** a file on it called
**`lhpc-config.txt`** — the image does not ship one; without it every default applies. Plain
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

`PASSWORD` and `AP_PSK` here turn step 8 into a quick check, and `CALL` pre-fills your callsign.
`AP_PSK` applies to **Lite** only — Desktop joins your network instead of making one. Everything
else applies to both.

If first boot fails partway, fix the file and reboot — the Pi notices the change and re-runs the
affected steps, so your correction actually applies.

`AP_PSK` must be 8–63 characters, `WIFI_COUNTRY` your two-letter code (e.g. `DE`, `US`, `GB`),
`TIMEZONE` a zone name from `/usr/share/zoneinfo` (e.g. `America/New_York`) and `KEYBOARD` one to
four xkb layout names, first is primary (e.g. `us`, or `de,us` for German with English on
`Alt+Shift`). An invalid file is rejected on first boot, with the reason written to
`lhpc-config-error.txt` on this same drive.
</details>

### 3 · Get in

- **Lite:** join the Wi-Fi **`lhpc-XXXX`** (key **`lorahampi`**) from a phone or laptop.
- **Desktop:** sign in on the Pi (**`lhpc`** / **`lhpc`**) and join your network (Wi-Fi menu or Ethernet).

**Lite note:** your device will warn **"no internet"** on this Wi-Fi — expected, the Pi's AP has
no upstream; stay connected anyway. And whenever the box reboots or changes networks
(steps 8–10), its AP comes back — but your phone/laptop does not always rejoin it by itself.
If the console stops answering, re-select the `lhpc-XXXX` Wi-Fi on your device first.

<details><summary>Everything first boot sets up</summary>

| | Lite (headless) | Desktop (screen) |
|---|---|---|
| login | `lhpc` / `lhpc` | `lhpc` / `lhpc` |
| hostname | `lhpc-XXXX` | `lhpc-XXXX` |
| region | `Europe/Berlin` · `DE` · keyboard `de,us` | `Europe/Berlin` · `DE` · keyboard `de,us` |
| Wi-Fi | **its own AP** `lhpc-XXXX` / `lorahampi` at `10.42.0.1` | **joins yours** (Wi-Fi menu or Ethernet) |
| Web GUI | `https://10.42.0.1:8443` — AP only, no password | `https://127.0.0.1:8443` — on the Pi only |
| MeshCom UI | `10.42.0.1:8444` — AP only | `127.0.0.1:8444` — on the Pi only |
| Meshtastic UI | `10.42.0.1:8445` — AP only | `127.0.0.1:8445` — on the Pi only |
| Graywolf APRS UI | `10.42.0.1:8446` — AP only, **own login** | `127.0.0.1:8446` — on the Pi only |
| SSH | on, **every** network the Pi is on | on, **every** network the Pi is on |
| firewall | on; the stacks' own ports are blocked | on; the stacks' own ports are blocked |
| stacks | installed & built, **minus the desktop-only parts**, none running | **all** installed & built, none running |
| autostart | **on** — stacks running at shutdown come back after a reboot | same |
| radios | **nothing runs, nothing transmits** | **nothing runs, nothing transmits** |

`XXXX` is a per-device suffix.

**The regional defaults are German** — timezone `Europe/Berlin`, Wi-Fi country `DE`, keyboard
`de,us` (German, with English on `Alt+Shift`). Set `TIMEZONE`, `WIFI_COUNTRY` and `KEYBOARD` in
`lhpc-config.txt` (step 2) to change them. **`WIFI_COUNTRY` is a regulatory setting: outside
Germany you must set your own before operating the radio.**
</details>

<details><summary>Seeing <code>lhpc-recovery-XXXX</code> instead?</summary>

The Pi booted but first boot did not finish. Join it (key `lorahampi` — the recovery network always
uses the factory key), `ssh lhpc@10.42.0.1`, and read `/var/log/lhpc-firstboot.log` plus
`systemctl status lhpc-growroot`. It retries on the next boot. No `lhpc-XXXX` Wi-Fi at all after
~2 min: re-seat/re-flash the card, check power.
</details>

### 4 · Open the console

- **Lite:** **`https://10.42.0.1:8443`** — from the phone/laptop on the AP.
- **Desktop:** **`https://127.0.0.1:8443`** — in the browser on the Pi.

Accept the certificate warning — the box signs its own. Installing its CA in your browser removes
the warning for good: [step 7](#7--optional-lock-the-web-uis-with-a-certificate), points 2–3.
No password: it is reachable only from the AP (Lite) or the Pi itself (Desktop).

### 5 · Hardware + callsign

**Apps → Graywolf APRS → Configure**: pick your **radio board** from the dropdown, enter your
**Station callsign** with an APRS SSID (e.g. `N0CALL-10`) → Save. The callsign is a **global
setting** — every licensed stack inherits it; Graywolf just carries the APRS `-SSID` variant.
Nothing transmits yet — and nothing will until you start a stack.

<details><summary>CLI</summary>

```bash
lhpc hardware                        # list the boards
lhpc hardware uputronics             # e.g. a dual Uputronics rig
lhpc config operator --callsign N0CALL
```
The operator callsign is global — every stack without a callsign field of its own inherits it.
</details>

<details><summary>Boards & SPI</summary>

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
</details>

### 6 · Start Graywolf once

**Apps → Graywolf APRS → Start.** Its first start generates the app's **own login password** —
you do **not** need to log in now; starting once is all it takes. **Apps → Graywolf APRS →
Password** shows the account and a copyable command that prints the password — you'll run that
in step 8. (Forgot the callsign? The start-confirm page asks for it.)

<details><summary>CLI</summary>

```bash
lhpc stack start graywolf
```
</details>

<details><summary>Why Graywolf has its own login · what Lite leaves out</summary>

Graywolf is the one proxied UI with its own account — it generates the password on first start and
stores it in `state/graywolf/graywolf-admin.txt` (readable only on the Pi). The console and the
other proxied UIs have no login of their own; step 7 is what locks them.

On **Lite** the three parts that need a desktop are deliberately not built — Voice, MeshCore's Node
Manager GUI and Reticulum's Sideband. They report `not-applicable`; that is not an error.
Desktop has all of them.
</details>

### 7 · Optional: lock the web UIs with a certificate

Do this whenever others can reach the UIs — on **Lite** that is true out of the box (anyone on the
AP), on any box once you expose the console to a LAN. It replaces "no password" with "only browsers
holding your certificate".

1. **Apps → LoRaHAM Pi Control → Webserver (HTTPS / mTLS) → Certificates → Issue client cert**:
   label `lhpc-laptop` → **Issue** → **copy the one-time passphrase** — it is shown once.
2. The same **Certificates** section now shows two copy boxes with your real address and paths
   filled in — *"Fetch an issued client certificate (.p12) to your PC"* and *"Fetch the server
   trust (CA) to your PC"*. Paste each on **your computer** (on the AP they read):

   ```bash
   scp lhpc@10.42.0.1:/home/lhpc/loraham-pi-control/config/tls/exports/lhpc-laptop.p12 lhpc-laptop.p12
   scp lhpc@10.42.0.1:/home/lhpc/loraham-pi-control/config/tls/server-ca/ca.crt lhpc-server-ca.crt
   ```
   **On a phone**: get the CA with the **Download ca.crt** link in the same section. The `.p12`
   has no download link away from the Pi on purpose (it holds a private key) — fetch it with an
   SFTP-capable app (same address, user and path as the `scp` command above), or fetch it on a
   computer first and hand it to the phone (AirDrop, mail, USB), treating it like a key file.
3. Install both in your browser (how-tos below): the CA as an *authority*, the `.p12` as *your*
   certificate (it asks for the one-time passphrase you copied in point 1).
4. For each stack of **MeshCom**, **Meshtastic**, **Graywolf**:
   **Apps → *stack* → Webserver (web UI proxy) → Settings**: set **Access mode →
   `local-open-remote-auth`**, type `enable-remote` into **Confirm phrase** → **Apply**.
5. Same for the console itself, **last**:
   **Apps → LoRaHAM Pi Control → Webserver (HTTPS / mTLS) → Settings**: **Access mode →
   `local-open-remote-auth`**, Confirm phrase `enable-remote` → **Apply**.
   Reload — the browser asks which certificate to present. Anyone without it is refused.

<details><summary>Install the certificate — Linux</summary>

**Firefox** (own store): `about:preferences#privacy` → *View Certificates* → **Your Certificates**
→ *Import* the `.p12`; **Authorities** → *Import* `ca.crt`, tick "Trust this CA to identify
websites". **Chrome/Chromium** (NSS store):
```bash
certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n lhpc-ca -i ca.crt
pk12util -d sql:$HOME/.pki/nssdb -i lhpc-laptop.p12
```
</details>

<details><summary>Install the certificate — Windows</summary>

Double-click `ca.crt` → *Install Certificate* → **Trusted Root Certification Authorities**.
Double-click the `.p12` → import into **Personal** (enter the passphrase). Firefox users: import
both in Firefox's own certificate manager instead.
</details>

<details><summary>Install the certificate — Android</summary>

Settings → Security → *Encryption & credentials* → *Install a certificate* — `ca.crt` under
**CA certificate**, the `.p12` under **VPN & app user certificate**.
</details>

<details><summary>Install the certificate — iPhone / iPad</summary>

Send both files to the device (AirDrop/mail), install each profile (Settings → *Profile
Downloaded*), finish under Settings → General → *VPN & Device Management*, and for the CA also
enable full trust under Settings → General → About → *Certificate Trust Settings*.
</details>

<details><summary>CLI</summary>

On the Pi (`ssh lhpc@10.42.0.1`):
```bash
lhpc webserver cert issue lhpc-laptop        # prints a ONE-TIME passphrase — record it now
lhpc webserver cert export lhpc-laptop ~/lhpc-laptop.p12
lhpc webserver proxy meshcom    --auth local-open-remote-auth --confirm-phrase enable-remote
lhpc webserver proxy meshtastic --auth local-open-remote-auth --confirm-phrase enable-remote
lhpc webserver proxy graywolf   --auth local-open-remote-auth --confirm-phrase enable-remote
lhpc webserver expose --cidr 10.42.0.0/24 --access-mode local-open-remote-auth --confirm-phrase enable-remote
lhpc webserver apply
```
On your computer — one file per command, **never** combined into one `scp`:
```bash
scp lhpc@10.42.0.1:lhpc-laptop.p12 .
scp lhpc@10.42.0.1:loraham-pi-control/config/tls/server-ca/ca.crt .
```
</details>

<details><summary>Reach the console from another network (LAN)</summary>

With the certificate installed, allowing another network is one command on the Pi (repeat `--cidr`
per range) — on **Lite** the Network panel does this for you when you join your Wi-Fi (step 10):

```bash
lhpc webserver expose --cidr 192.168.1.0/24 --access-mode local-open-remote-auth --confirm-phrase enable-remote
lhpc webserver apply
```
`local-open-remote-auth` keeps the console open **on the Pi itself** and requires the certificate
from everywhere else. `lhpc webserver cert list` shows what is issued; `revoke` withdraws one.
Opening a port at your router stays your job — LHPC never edits your router or your own firewall.
</details>

### 8 · Passwords — one terminal visit

Both defaults are public and identical on every image, and SSH answers on every network the Pi joins:

```bash
ssh lhpc@10.42.0.1                                                 # password: lhpc
cat ~/loraham-pi-control/state/graywolf/graywolf-admin.txt         # your Graywolf login — copy it
passwd                                                             # new user password
sudo nmcli connection modify lhpc-ap wifi-sec.psk 'your-new-key'   # Lite only: new AP key, 8+ chars
sudo nmcli connection up lhpc-ap                                   # drops your connection — expected
```

- **Desktop:** open the **Terminal** app instead of `ssh`, and skip the two `nmcli` lines.

### 9 · Reconnect *(Lite)*

Join `lhpc-XXXX` again with the **new** key. Did step 7? The console now asks for your certificate.

### 10 · Join your home Wi-Fi *(Lite)*

**Apps → LoRaHAM Pi Control → Network**: **type** your network's name and password — there is no
scanning while the Pi's own AP is up (normal, not a fault). Leave **"allow console from that
network"** ticked **only if you did step 7** — without a certificate it would open the console to
everyone on your network. Run the one copyable `sudo` command the panel shows (over SSH — port 22
is open there).

The Pi reappears at **`https://lhpc-XXXX.local:8443`**, and its own AP comes back by itself
whenever your Wi-Fi is lost.

- **Desktop:** nothing to do — already on your network since step 3.

### 11 · Update

Now the box has internet.

- **Lite:** only from this point — its own AP has none, so updating earlier could not work.

```bash
ssh lhpc@lhpc-XXXX.local
sudo apt update && sudo apt full-upgrade -y
```

<details><summary>Updating LHPC and the stacks</summary>

- LHPC: `lhpc self-update` (or the one-click updater in the console).
- A single stack, only if you want a newer version than the image shipped: `lhpc update <stack>`.
  Stacks are already installed and built — updating is optional, not part of setup.
- Images are rebuilt monthly on the latest official base; **kernel, bootloader and firmware track
  that base**. Update in place — you don't need to reflash. Maintainer notes:
  [`docs/maintenance.md`](docs/maintenance.md).
</details>

### 12 · On the air

Start more stacks: **Apps → *stack* → Start** (or per band from **Home**, the dashboard). Only one stack owns
a band at a time — LHPC refuses a conflicting start. Whatever is running when you reboot comes back
by itself (**autostart**, on by default).

<details><summary>CLI</summary>

```bash
lhpc status                      # what is installed and what is running
lhpc stack start meshtastic      # start one
lhpc stack stop meshtastic       # stop it again
lhpc autostart                   # see or change boot auto-restore
```
</details>

## GPS (optional)

One position source feeds every stack; without a receiver everything still runs, just without
position.

- **Receiver already on the box** (a GPS HAT or one built into your radio board — it appears as a
  serial device): usable **directly**, no gpsd needed.
  **Apps → LoRaHAM Pi Control → Position (GPS)**: source **nmea** + the device path (e.g.
  `/dev/ttyAMA0`) → Save. Direct mode feeds **one** consuming stack only.
- **No onboard GPS**: plug in a **USB receiver** (e.g. a u-blox stick) and run it through
  **gpsd** — a system service you set up yourself, once:

  ```bash
  sudo apt install -y gpsd gpsd-clients
  sudo systemctl enable --now gpsd
  cgps                                   # verify: sentences scroll, and (outdoors) a fix appears
  ```
  Debian picks up USB receivers automatically (`USBAUTO`), and LHPC's default source (`auto`)
  finds a local gpsd by itself — nothing else to configure.

Then switch position on per stack: **Apps → *stack* → Configure → `use_gps`** → Save (stack
restart applies it).

<details><summary>CLI</summary>

```bash
lhpc gps                                        # show the source (and what auto resolved to)
lhpc gps --source gpsd                          # explicit: gpsd on this box
lhpc gps --source nmea --device /dev/ttyACM0    # receiver direct, no gpsd
lhpc config meshtastic use_gps on               # per stack
```
</details>

<details><summary>u-blox note: once it has met gpsd, it talks binary</summary>

gpsd switches u-blox receivers into UBX binary mode and they **stay** there after gpsd stops. A
`nmea` source then refuses with *"device is sending binary, not NMEA"*. Easiest answer: keep
using `--source gpsd`. (Meshtastic reading the receiver *directly* is unaffected — meshtasticd
speaks UBX itself.) A cold receiver needs minutes outdoors for its first fix; "reachable but no
fix" is a warning, not a failure.
</details>

## Troubleshooting

<details><summary>Common first-day problems</summary>

- **No `lhpc-XXXX` Wi-Fi after ~2 min** — re-seat/re-flash the card; check power. A
  **`lhpc-recovery-XXXX`** network instead: see step 3.
- **Web GUI won't open** — *Lite:* you must be joined to the AP, and use `https://10.42.0.1:8443`.
  *Desktop:* it is local-only, so open `https://127.0.0.1:8443` **on the Pi**. Accept the
  self-signed warning.
- **Moved the box onto your home Wi-Fi?** `10.42.0.1` and the AP-scoped GUI go away; **SSH stays
  reachable** on the new IP — which is why changing the password comes early. To get the GUI back,
  see steps 7 and 10.
</details>

## Defaults

For local commissioning only — change them (steps 7–8):

- user **`lhpc`** / password **`lhpc`**
- AP **`lhpc-XXXX`** / key **`lorahampi`**
- recovery AP **`lhpc-recovery-XXXX`** / key **`lorahampi`** (factory key, always)
- Wi-Fi country **`DE`** · timezone **`Europe/Berlin`** · keyboard **`de,us`** (German; `Alt+Shift` for English)
- `XXXX` is a per-device suffix

**More docs** — LHPC upstream: [README](https://github.com/makrohard/loraham-pi-control#readme) ·
[docs](https://github.com/makrohard/loraham-pi-control/tree/main/docs). The same files are on the Pi
at `~/loraham-pi-control/src/loraham-pi-control/`, plus `lhpc --help`.
