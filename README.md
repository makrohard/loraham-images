**[Hier geht's zur deutschen Anleitung](README_DE.md)**

# loraham-images

Ready-to-use **Raspberry Pi OS (Trixie, 64-bit)** images with
[LHPC](https://github.com/makrohard/loraham-pi-control) preinstalled. Flash it, boot it, and set it up
from your phone or a browser — no Linux experience needed.

## What's in the image

LHPC plus **nine stacks, already installed and built** — eight applications and the LoRaHAM radio
daemon they share. The applications fall into two families, and the difference matters legally:

- **Amateur radio** — LoRaHAM **Chat**, **Voice**, the **KISS adapter**, **Graywolf** (LoRa-APRS),
  and **MeshCom**.
  These run on amateur bands, identify with your callsign, and are normally **not encrypted**.
  They need an amateur radio licence.
- **Licence-free / encrypted** — **Meshtastic**, **MeshCore**, **Reticulum**. These are designed for
  licence-free ISM use and normally **encrypt** their traffic. No licence, but power and duty-cycle
  limits apply.

> **Your responsibility.** Which bands, power levels, duty cycles and encryption are lawful depends
> on your country and on whether you hold a licence — and the same radio can be used either way.
> LHPC will not decide this for you. Nothing transmits until you choose your hardware and start a
> stack, so check your local rules first.

> [!WARNING]
> **The defaults are public, and every image has the same ones.** Login `lhpc` / `lhpc`, Wi-Fi key
> `lorahampi`, and SSH answers on every network the Pi joins. They exist so a fresh card is usable
> at all — anyone who knows them owns the box. **Change them in
> [step 8](#8--change-the-two-shipped-defaults) before it leaves your desk**, and before you put it
> on a network you share.

## Contents

- [What's in the image](#whats-in-the-image)
- [Install](#install)
  - [1 · Download](#1--download)
  - [2 · Flash](#2--flash)
  - [3 · Get in](#3--get-in)
  - [4 · Open the WebGUI](#4--open-the-webgui)
  - [5 · Hardware + callsign](#5--hardware--callsign)
  - [6 · Start a stack once — its password appears on its own page](#6--start-a-stack-once--its-password-appears-on-its-own-page)
  - [7 · Make the web GUIs reachable from other hosts](#7--make-the-web-guis-reachable-from-other-hosts)
    - [7.1 · Authentication — issue and install your certificate](#71--authentication--issue-and-install-your-certificate)
    - [7.2 · Expose — the stack UIs, then the console](#72--expose--the-stack-uis-then-the-console)
    - [7.3 · Activate — on the box, over SSH](#73--activate--on-the-box-over-ssh)
  - [8 · Change the two shipped defaults](#8--change-the-two-shipped-defaults)
  - [9 · Reconnect (Lite)](#9--reconnect-lite)
  - [10 · Join your home Wi-Fi (Lite)](#10--join-your-home-wi-fi-lite)
  - [11 · Update](#11--update)
  - [12 · On the air](#12--on-the-air)
- [GPS (optional)](#gps-optional)
- [Troubleshooting](#troubleshooting)
- [Defaults](#defaults)
- [Licenses & attribution](#licenses--attribution)

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
**→ [latest release](https://github.com/makrohard/loraham-images/releases/latest)**

<details><summary><em>Check the download is intact (optional)</em></summary>

Download the `.sha256` file for **your** image from the same release, put it beside the image, then:

```bash
sha256sum -c loraham-lhpc-lite.img.xz.sha256
```
It should print `loraham-lhpc-lite.img.xz: OK`.
</details>

### 2 · Flash

- **[Raspberry Pi Imager](https://www.raspberrypi.com/software/) → Choose OS → Use custom → your `.img.xz` → Choose Storage → your SD card → Write**

Ignore Imager's "OS customisation" prompt — this image sets itself up. Card into the Pi, power on;
first boot takes about 1–2 minutes.

<details><summary><em>Optional: pre-configure before the first boot</em></summary>

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
CALL=DJ0CHE
```

When first boot succeeds it overwrites `PASSWORD=` and `AP_PSK=` in that file with `REDACTED`, so
the secrets do not sit on the boot partition afterwards — and a later boot that still finds
`REDACTED` stops with an error, so edit those lines or delete the file before rebooting with it.

`PASSWORD` and `AP_PSK` here turn step 8 into a quick check, and `CALL` pre-fills your callsign —
the **bare base call**, no SSID and no `/P` (per-stack variants come later).
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

Both of those are the public factory defaults — you change them in
[step 8](#8--change-the-two-shipped-defaults). Do it before the box goes anywhere.

**Lite note:** your device will warn **"no internet"** on this Wi-Fi — expected, the Pi's AP has
no upstream; stay connected anyway. And whenever the box reboots or loses its network its AP
comes back — but your phone/laptop does not always rejoin it by itself. If the console stops
answering, re-select the `lhpc-XXXX` Wi-Fi on your device first. (Step 10 is the exception: while
the box is joined to your Wi-Fi its AP stays down.)

<details><summary><em>Everything first boot sets up</em></summary>

| | Lite (headless) | Desktop (screen) |
|---|---|---|
| login | `lhpc` / `lhpc` | `lhpc` / `lhpc` |
| hostname | `lhpc-XXXX` | `lhpc-XXXX` |
| region | `Europe/Berlin` · `DE` · keyboard `de,us` | `Europe/Berlin` · `DE` · keyboard `de,us` |
| Wi-Fi | **its own AP** `lhpc-XXXX` / `lorahampi` at `10.42.0.1` | **joins yours** (Wi-Fi menu or Ethernet) |
| Web GUI | `https://10.42.0.1:8443` — AP only, no password | `https://127.0.0.1:8443` — on the Pi only |
| MeshCom UI | `https://10.42.0.1:8444` — AP only | `https://127.0.0.1:8444` — on the Pi only |
| Meshtastic UI | `https://10.42.0.1:8445` — AP only | `https://127.0.0.1:8445` — on the Pi only |
| Graywolf APRS UI | `https://10.42.0.1:8446` — AP only, **own login** | `https://127.0.0.1:8446` — on the Pi only |
| MeshCore UIs | not proxied — reach them with `lhpc webserver proxy`, or an SSH tunnel | same |
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

<details><summary><em>Seeing <code>lhpc-recovery-XXXX</code> instead?</em></summary>

The Pi booted but first boot did not finish. Join it (key `lorahampi` — the recovery network always
uses the factory key), `ssh lhpc@10.42.0.1`, and read `/var/log/lhpc-firstboot.log` plus
`systemctl status lhpc-growroot`. It retries on the next boot. No `lhpc-XXXX` Wi-Fi at all after
~2 min: re-seat/re-flash the card, check power.
</details>

### 4 · Open the WebGUI

- **Lite:** **`https://10.42.0.1:8443`** — from the phone/laptop on the AP.
- **Desktop:** **`https://127.0.0.1:8443`** — in the browser on the Pi.

**Lite:** accept the certificate warning — the box signs its own. Installing its CA in your browser
removes the warning for good: [step 7.1](#71--authentication--issue-and-install-your-certificate), points 2–3.
**Desktop:** normally no warning — first boot imports the box's CA into the pre-installed
browser's store (best-effort; another browser keeps its own and will still warn).
No password either way: the console is reachable only from the AP (Lite) or the Pi itself (Desktop).

### 5 · Hardware + callsign

- **Apps → LoRaHAM daemon → Configure → Hardware**<br>
  Pick your board under Hardware setup and save it. Not sure which one? Detect probes a band, and
  the board's LED lights while it initialises. This selector lives on the daemon's page; no other
  stack has it. You are done when the dashboard's "No radio hardware is configured" banner
  disappears.

- **Apps → LoRaHAM Pi Control → Global operator callsign**<br>
  Enter your bare base call (e.g. `G0ABC` — no SSID, no `/P`). It lives on the console's own row,
  not on a stack page. Licensed stacks (Chat, Voice, Graywolf, MeshCom) inherit it while their own
  callsign field is empty; Graywolf's own field carries the APRS `-SSID` variant (e.g. `G0ABC-10`)
  and overrides it. A stack with no resolvable identity refuses to start, and the refusal takes you
  straight to that stack's Settings row.

- **Apps → *stack* → Configure**<br>
  For Meshtastic and MeshCore only, which never inherit a callsign: give each node its own name
  here.

Nothing transmits yet — and nothing will until you start a stack.

<details><summary><em>CLI</em></summary>

```bash
lhpc hardware                        # list the boards
lhpc hardware uputronics             # e.g. a dual Uputronics rig
lhpc config operator --callsign G0ABC        # your OWN bare base call

# Meshtastic and MeshCore never inherit it — name each node before starting it:
lhpc config meshtastic node_name "G0ABC node"
lhpc config meshtastic node_short GABC       # max 4 bytes
lhpc config meshcore node_name "G0ABC node"
```
The operator callsign is global — licensed stacks inherit it while their own callsign field is
empty. Without a resolvable identity a stack refuses to start, so set this before step 6.
</details>

<details><summary><em>Boards & SPI</em></summary>

| `lhpc hardware` | board | bands |
|---|---|---|
| `loraham` | LoRaHAM dual-module (SX1278 + RFM95) | 433 + 868 |
| `uputronics` | Uputronics dual (CE0 433 + CE1 868) | 433 + 868 |
| `uputronics-x` | Uputronics dual, crossed modules (CE0 868 + CE1 433) | 433 + 868 |
| `uputronics-433` / `uputronics-868` | Uputronics 433 (CE0) / Uputronics 868 (CE1) | 433 / 868 |
| `waveshare-433` / `waveshare-868` | Waveshare SX1262 | 433 / 868 |

Both images ship SPI as **`soft-cs`** (`dtparam=spi=on` + `dtoverlay=spi0-0cs`), which is what every
board above needs — the radios drive their own chip-selects as GPIOs. Only change it if your board
truly uses kernel chip-selects — first remove the `dtoverlay=spi0-0cs` line from
`/boot/firmware/config.txt`, otherwise the script refuses and tells you so:
```bash
sudo bash ~/loraham-pi-control/src/loraham-pi-control/bootstrap-deps.sh --spi-mode hardware-cs
```
</details>

### 6 · Start a stack once — its password appears on its own page

A stack that has a login of its own creates it on **first start**, and the console then shows the
value. Start it once; you do not need to log in yet. Graywolf is the one that works this way out of
the box — MeshCore mints its dashboard password only in a repeater mode, and MeshCom's HMAC needs a
source install (both noted in the table and below).

- **Apps → *stack* → Start**<br>
  Starting Graywolf also starts the LoRaHAM KISS TNC and the LoRaHAM daemon it depends on, so three
  things coming up is expected rather than a fault. If it is refused for a missing callsign or node
  name, you land on that stack's Settings with the offending row marked; fill it in and start again.

- **Apps → *stack* → Password**<br>
  The account and the password, with a copy button.

| Stack | Login | Where it is stored |
|---|---|---|
| **Graywolf APRS** | `admin` | `state/graywolf/graywolf-admin.txt` — Graywolf itself creates it on first start |
| **MeshCore** repeater dashboard | `admin` | `config/secrets/openhop_repeater_admin.txt` — created once **Mode** is `chat+repeater` or `repeater`; until then the Password section says so |
| **MeshCom** | HMAC password, not a web login | `config/secrets/xr_pw` — changed only through the stack's HMAC actions, never by editing the file |

<details><summary><em>CLI</em></summary>

```bash
lhpc stack start graywolf
```
No command prints a password — the value deliberately never reaches a log or an API. From a
terminal, read the file itself:
```bash
cat ~/loraham-pi-control/state/graywolf/graywolf-admin.txt
```
</details>

<details><summary><em>MeshCom's HMAC · what Lite leaves out</em></summary>

The image installs MeshCom from the **binary** channel, and that published firmware is built with an
**empty** HMAC password — so the HMAC actions are refused until you reinstall MeshCom from source.

On **Lite** the two parts that need a desktop are deliberately not built — LoRaHAM Voice's GTK app
and Reticulum's Sideband. They report `not-applicable`; that is not an error. Desktop has both.
</details>

### 7 · Make the web GUIs reachable from other hosts

**Headless boxes need this; boxes with a screen may not.** On **Lite** there is no display, so a
browser on another machine is the only way in — and out of the box the UIs sit open on the AP with
no password, which is exactly what this step closes. On **Desktop** you can skip it entirely and
keep working in the browser on the Pi: staying local is a perfectly good answer, and nothing
listens beyond the Pi until you change it.

Opening them to other machines is three parts: prove who you are with a certificate, set the
exposure policy, then activate it on the box. Do them in that order — the certificate has to be on
your machine **before** you switch the policy, or you lock yourself out.

#### 7.1 · Authentication — issue and install your certificate

- **Apps → LoRaHAM Pi Control → Webserver (HTTPS / mTLS) → Certificates → Issue client cert**<br>
  Give it a label such as `lhpc-laptop` and press Issue. **Copy the one-time passphrase now** — it
  is shown exactly once, it is never recoverable, and you need it when you import the `.p12`. Lost
  it, or the file went somewhere it should not have? Revoke that certificate and issue a new one;
  nothing else has to change.

The same Certificates section then offers two copy boxes, with your address and paths already
filled in. Paste each on your own computer — on the AP they read:

```bash
scp lhpc@10.42.0.1:/home/lhpc/loraham-pi-control/config/tls/exports/lhpc-laptop.p12 .
scp lhpc@10.42.0.1:/home/lhpc/loraham-pi-control/config/tls/server-ca/ca.crt lhpc-server-ca.crt
```

On a phone, get the CA with the **Download ca.crt** link in the same section. The `.p12` has no
download link away from the Pi on purpose, because it holds a private key — fetch it with an
SFTP-capable app (same address, user and path as the `scp` command above), or fetch it on a
computer first and hand it to the phone by AirDrop, mail or USB, treating it like a key file.

Install both in your browser, using the how-tos below: the CA as an authority, and the `.p12` as
your own certificate — that one asks for the passphrase you copied.

#### 7.2 · Expose — the stack UIs, then the console

- **Apps → LoRaHAM Pi Control → Webserver (HTTPS / mTLS) → Stacks WebGUIs**<br>
  Five fields, then Apply: **Access** `lan` (who may reach the proxies), **Scheme** `https` (http
  forces no-auth, so https is what keeps certificate auth possible), **Access mode**
  `local-open-remote-auth`, **Allowed CIDRs** the network you are coming from — e.g.
  `192.168.1.0/24`, required for lan and public — and **Confirm** `enable-remote`. One policy covers
  every stack web UI at once and the ports stay per page; the per-stack panels remain for
  exceptions. (`enable-remote-danger` is the phrase for the riskier cases — a public listener, no
  authentication at all, or plain HTTP.)

- **Apps → LoRaHAM Pi Control → Webserver (HTTPS / mTLS) → LHPC WebGUI**<br>
  The same Scheme, Access mode, Allowed CIDRs and Confirm, plus **Bind** `0.0.0.0` so it listens
  beyond loopback. Do the console last: it is the page you are working in.

#### 7.3 · Activate — on the box, over SSH

The image ships the managed firewall applied, so exposure is gated on it: opening new ports leaves
the firewall with **pending changes**, and until those are applied the listeners do not come up.
`ssh lhpc@10.42.0.1`, then:

1. **Apply the managed firewall.** The console shows the same command:

   ```bash
   sudo bash ~/loraham-pi-control/config/files/firewall/firewall-apply.sh
   ```
2. **Let the Apply finish.** If Apply was refused earlier because the firewall was pending, press it
   again in the panel — or `lhpc webserver apply` here; that validates and activates the listeners.
3. **Restart the console only if it does not come back.** Apply normally restarts the front end
   itself through the managed restart watcher:

   ```bash
   systemctl --user restart lhpc-nginx lhpc-web
   ```

LHPC never touches your own firewall, and a port on your router stays yours —
[`docs/firewall.md`](https://github.com/makrohard/loraham-pi-control/blob/main/docs/firewall.md).

Reload the page — the browser now asks which certificate to present, and anyone without it is
refused. The console stays open **on the Pi itself** either way.

*Just debugging, or want nothing exposed at all?* An SSH tunnel reaches the console and any stack UI
without changing anything on the box:
[`docs/ssh-tunnel.md`](https://github.com/makrohard/loraham-pi-control/blob/main/docs/ssh-tunnel.md).

<details><summary><em>Install the certificate — Linux</em></summary>

- **Firefox → about:preferences#privacy → View Certificates → Your Certificates → Import**<br>
  The `.p12`
- **Firefox → about:preferences#privacy → View Certificates → Authorities → Import**<br>
  `ca.crt`, ticking "Trust this CA to identify websites"

**Chrome/Chromium** (NSS store — Chrome and older Chromium use `~/.pki/nssdb`, Chromium
150+ uses `~/.local/share/pki/nssdb`; run it against the one your browser has):
```bash
certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n lhpc-ca -i ca.crt
pk12util -d sql:$HOME/.pki/nssdb -i lhpc-laptop.p12
```
</details>

<details><summary><em>Install the certificate — Windows</em></summary>

- **Double-click `ca.crt` → Install Certificate → Trusted Root Certification Authorities**
- **Double-click the `.p12` → Personal**<br>
  It asks for the passphrase

Firefox users: import both in Firefox's own certificate manager instead.
</details>

<details><summary><em>Install the certificate — Android</em></summary>

- **Settings → Security → Encryption & credentials → Install a certificate → CA certificate**<br>
  `ca.crt`
- **Settings → Security → Encryption & credentials → Install a certificate → VPN & app user certificate**<br>
  The `.p12`
</details>

<details><summary><em>Install the certificate — iPhone / iPad</em></summary>

Send both files to the device (AirDrop or mail), then:

- **Settings → Profile Downloaded**<br>
  Install each profile
- **Settings → General → VPN & Device Management**<br>
  Finish the install
- **Settings → General → About → Certificate Trust Settings**<br>
  Enable full trust for the CA
</details>

<details><summary><em>CLI</em></summary>

On the Pi (`ssh lhpc@10.42.0.1`). The one-policy-for-every-stack form is a console feature; from a
shell you set each page, so the list mirrors `PROXY_STACKS`:
```bash
lhpc webserver cert issue lhpc-laptop        # prints a ONE-TIME passphrase — record it now
lhpc webserver cert export lhpc-laptop ~/lhpc-laptop.p12
lhpc webserver proxy meshcom    --auth local-open-remote-auth --confirm-phrase enable-remote
lhpc webserver proxy meshtastic --auth local-open-remote-auth --confirm-phrase enable-remote
lhpc webserver proxy graywolf   --auth local-open-remote-auth --confirm-phrase enable-remote
lhpc webserver expose --cidr 10.42.0.0/24 --access-mode local-open-remote-auth --confirm-phrase enable-remote
sudo bash ~/loraham-pi-control/config/files/firewall/firewall-apply.sh   # gate: exposure needs this
lhpc webserver apply                                                     # validate + activate
systemctl --user restart lhpc-nginx lhpc-web                             # only if it does not come back
```
On your computer — one file per command, **never** combined into one `scp`:
```bash
scp lhpc@10.42.0.1:lhpc-laptop.p12 .
scp lhpc@10.42.0.1:loraham-pi-control/config/tls/server-ca/ca.crt .
```
</details>

<details><summary><em>Reach the console from another network (LAN)</em></summary>

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

### 8 · Change the two shipped defaults

> [!IMPORTANT]
> This is the one step you should not skip. Until you do it, anyone who has ever seen this project
> knows how to log into your box.

Both are public and identical on every image, and SSH answers on every network the Pi joins:

```bash
ssh lhpc@10.42.0.1                                                 # password: lhpc
passwd                                                             # new user password
sudo nmcli connection modify lhpc-ap wifi-sec.psk 'your-new-key'   # Lite only: new AP key, 8+ chars
sudo nmcli connection up lhpc-ap                                   # drops your connection — expected
```

`sudo` asks for the password you have just set. The stack logins from step 6 are not touched here.

- **Desktop:** open the **Terminal** app instead of `ssh`, and skip the two `nmcli` lines.

### 9 · Reconnect *(Lite)*

Join `lhpc-XXXX` again with the **new** key. Did step 7? The console now asks for your certificate.

### 10 · Join your home Wi-Fi *(Lite)*

- **Apps → LoRaHAM Pi Control → Network**<br>
  **type** your network's name (there is no scanning while the Pi's own AP is up, normal and not a
  fault) and press **Join**.

The Wi-Fi password is asked on the
confirm page that follows, which also warns that the AP goes down the moment the box joins: your
phone or laptop stays on the dead AP until *you* switch it to your own network. Leave **"allow
console from that network"** ticked **only if you did step 7** — without a certificate it would open
the console to everyone on your network. If the panel comes back with a copyable `sudo` command, run
it over SSH (port 22 is open there); on the normal path there is none.

The Pi reappears at **`https://lhpc-XXXX.local:8443`**. Once you have confirmed it works there,
click **Prefer** on that network — otherwise the box returns to its own AP on every reboot. A
preferred network is re-joined automatically whenever it reappears; if it is lost the AP comes back
as the safety net and the box retries the preferred network every 10 minutes.

- **Desktop:** nothing to do — already on your network since step 3.

### 11 · Update

Now the box has internet.

- **Lite:** only from this point — its own AP has none, so updating earlier could not work.

```bash
ssh lhpc@lhpc-XXXX.local
sudo apt update && sudo apt full-upgrade -y
```

<details><summary><em>Updating LHPC and the stacks</em></summary>

- LHPC: `lhpc self-update --apply` (bare `lhpc self-update` only checks), or the one-click
  updater in the console.
- A single stack, only if you want a newer version than the image shipped: `lhpc update <stack>`.
  Stacks are already installed and built — updating is optional, not part of setup.
- Images are rebuilt monthly on the latest official base; **kernel, bootloader and firmware track
  that base**. Update in place — you don't need to reflash. Maintainer notes:
  [`docs/maintenance.md`](docs/maintenance.md).
</details>

### 12 · On the air

Start more stacks: **Apps → *stack* → Start** (or per band from **Home**, the dashboard). Only one stack owns
a band at a time — a conflicting start is not silently allowed: the console names the owner and
offers **Stop owner(s) & start**. Whatever is running when you reboot comes back
by itself (**autostart**, on by default).

<details><summary><em>CLI</em></summary>

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

Every stack that can use a position has `use_gps` **on** by default, so a normal box needs nothing
here. To turn it off (or back on) for one stack: **Apps → *stack* → Configure → `use_gps`** — the
stack must be **stopped** to save it, then start it again.

<details><summary><em>CLI</em></summary>

```bash
lhpc gps                                        # show the source (and what auto resolved to)
lhpc gps --source gpsd                          # explicit: gpsd on this box
lhpc gps --source nmea --device /dev/ttyACM0    # receiver direct, no gpsd
lhpc config meshtastic use_gps on               # per stack; the stack must be stopped
```
</details>

<details><summary><em>u-blox note: once it has met gpsd, it talks binary</em></summary>

gpsd switches u-blox receivers into UBX binary mode and they **stay** there after gpsd stops. A
`nmea` source then refuses with *"device is sending binary, not NMEA"*. Easiest answer: keep
using `--source gpsd`. (Meshtastic reading the receiver *directly* is unaffected — meshtasticd
speaks UBX itself.) A cold receiver needs minutes outdoors for its first fix; "reachable but no
fix" is a warning, not a failure.
</details>

## Troubleshooting

<details><summary><em>Common first-day problems</em></summary>

- **No `lhpc-XXXX` Wi-Fi after ~2 min** — re-seat/re-flash the card; check power. A
  **`lhpc-recovery-XXXX`** network instead: see step 3.
- **Web GUI won't open** — *Lite:* you must be joined to the AP, and use `https://10.42.0.1:8443`.
  *Desktop:* it is local-only, so open `https://127.0.0.1:8443` **on the Pi**. Accept the
  self-signed warning.
- **Moved the box onto your home Wi-Fi?** `10.42.0.1` and the AP-scoped GUI go away; **SSH stays
  reachable** on the new IP — which is why changing the password comes early. The box is then at
  `https://lhpc-XXXX.local:8443`; with *"allow console from that network"* ticked the console
  follows to the new subnet by itself.
- **Back on `lhpc-XXXX` after a reboot?** Expected unless you clicked **Prefer** on your network
  (step 10): without it the box does not re-join a Wi-Fi by itself. Re-join, then Prefer it.
- **`lhpc-XXXX.local` does not resolve?** Common on Android, which does not do `.local` at all —
  use the address your router gives the box, or reach it from a computer.
</details>

## Defaults

For local commissioning only. The login and the AP key are changed in **step 8**; the regional
values only in `lhpc-config.txt` before first boot (**step 2**) or by hand afterwards:

- user **`lhpc`** / password **`lhpc`**
- AP **`lhpc-XXXX`** / key **`lorahampi`**
- recovery AP **`lhpc-recovery-XXXX`** / key **`lorahampi`** (Lite only; factory key, always)
- Wi-Fi country **`DE`** · timezone **`Europe/Berlin`** · keyboard **`de,us`** (German; `Alt+Shift` for English)
- `XXXX` is a per-device suffix

**More docs** — LHPC upstream: [README](https://github.com/makrohard/loraham-pi-control#readme) ·
[docs](https://github.com/makrohard/loraham-pi-control/tree/main/docs). The same files are on the Pi
at `~/loraham-pi-control/src/loraham-pi-control/`, plus `lhpc --help`.

## Licenses & attribution

The images are distributed free of charge and non-commercially. They aggregate the software
below; each project remains under its own license (notice files ship inside the image).

- **LoRaHAM daemon, chat and Voice** — © **Alexander Walter**
  ([LoRaHAM project](https://github.com/LoRaHAM)) · GPL-3.0 · built from source from the maintained
  forks: [LoRaHAM_Daemon](https://github.com/makrohard/LoRaHAM_Daemon) (daemon and chat) and
  [LoRaHAM_Voice](https://github.com/makrohard/LoRaHAM_Voice).
- **[graywolf](https://github.com/chrissnell/graywolf)** — © Chris Snell, NW5W · GPL-2.0-only.
  Shipped as the unmodified upstream package; source for the pinned version is at the link.
- **[Meshtastic firmware](https://github.com/meshtastic/firmware)** — © Meshtastic contributors ·
  GPL-3.0 · built from source (the source tree ships in the image).
  **[Meshtastic web client](https://github.com/meshtastic/web)** — GPL-3.0 · shipped as the
  upstream build; source at the link.
- **[Sideband](https://github.com/markqvist/Sideband)** — © Mark Qvist ·
  [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) · unmodified · Desktop
  image only.
- **[Reticulum](https://github.com/markqvist/Reticulum)** and
  **[LXMF](https://github.com/markqvist/LXMF)** — © Mark Qvist · Reticulum License;
  **[NomadNet](https://github.com/markqvist/NomadNet)** — © Mark Qvist · GPL-3.0.
- **[MeshCom firmware](https://github.com/icssw-org/MeshCom-Firmware)** — © ICSSW · MIT.
- **[openHop](https://github.com/openhop-dev)** — © Lloyd Newton · MIT. The MeshCore
  implementation this image runs: **[openHop Core](https://github.com/openhop-dev/openhop_core)**,
  the node, built from source; **[openHop repeater](https://github.com/openhop-dev/openhop_repeater)**,
  the repeater daemon, built from source; and its bundled dashboard
  **[openHop RepeaterUI](https://github.com/openhop-dev/openHop_RepeaterUI)**, shipped prebuilt with
  the source at the link.
- **MeshCore clients** — MIT · [meshcore-webui](https://github.com/adradr/meshcore-webui), the
  browser client; [meshcore-cli](https://github.com/meshcore-dev/meshcore-cli).
- **[RadioLib](https://github.com/jgromes/RadioLib)** — © Jan Gromeš · MIT.
- **[LoRaHAM Pi Control](https://github.com/makrohard/loraham-pi-control)**, the KISS TNC, the
  MeshCom bridge and QEMU tooling — © makrohard · MIT.
- Base system: Raspberry Pi OS / Debian — package licenses in `/usr/share/doc/` on the Pi.
