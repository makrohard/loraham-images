# loraham-images

Ready-to-use **Raspberry Pi OS (Trixie, 64-bit)** images with
[LHPC](https://github.com/makrohard/loraham-pi-control) preinstalled. Flash it, boot it, and set it up
from your phone or a browser — no Linux experience needed.

## 1 · Pick an image

| Image | Use it for |
|-------|-----------|
| **lite** | a headless Pi (e.g. Pi Zero 2 W). It makes **its own Wi-Fi** so you configure it from a phone. |
| **desktop** | a Pi with a screen. It joins **your** Wi-Fi/Ethernet and boots to a desktop. |

## 2 · Download

### → [**Download the latest images**](https://github.com/makrohard/loraham-images/releases/latest)

Grab `loraham-lhpc-lite.img.xz` **or** `loraham-lhpc-desktop.img.xz`.

<details><summary>Check the download is intact (optional)</summary>

Download `SHA256SUMS` from the same release, put it beside the image, then:

```bash
sha256sum -c SHA256SUMS      # should say "OK" for your image
```
</details>

## 3 · Flash

1. Install **[Raspberry Pi Imager](https://www.raspberrypi.com/software/)**.
2. **Choose OS → Use custom** → pick the `.img.xz` you downloaded.
3. **Choose Storage** → your SD card. *(Ignore Imager's “OS customisation” prompt — this image sets
   itself up.)*
4. **Write.** Put the card in the Pi and power on. First boot takes about 1–2 minutes.

<details><summary>Optional: pre-configure before the first boot</summary>

After flashing, a small drive named **`bootfs`** appears. Open it and edit **`lhpc-config.txt`** —
plain `KEY=VALUE`, one per line, **no inline comments**; anything you leave out keeps the default:

```
HOSTNAME=lhpc-shack
PASSWORD=choose-a-password
AP_PSK=choose-a-wifi-key
WIFI_COUNTRY=DE
CALL=N0CALL
```

`AP_PSK` must be 8–63 characters and `WIFI_COUNTRY` your two-letter code (e.g. `DE`, `US`, `GB`). An
invalid file is rejected on first boot, with the reason written to `lhpc-config-error.txt` on this
same drive.
</details>

## 4 · Connect

**Lite** — on your phone/laptop, join the Wi-Fi network **`lhpc-XXXX`** (password **`lorahampi`**),
then open **`https://10.42.0.1:8443`** and accept the certificate warning.

**Desktop** — it boots to a desktop; sign in as **`lhpc`** / **`lhpc`**. Join your Wi-Fi from the
desktop's network menu (or use Ethernet), then open a browser **on the Pi** and go to
**`https://127.0.0.1:8443`**. (The console is local-only until you choose to expose it.)

On Lite you can also `ssh lhpc@10.42.0.1` (user **`lhpc`**, password **`lhpc`**).

## 5 · Do these first ⚠️

The defaults are **public** — change them straight away. Open a terminal: on **Lite** `ssh lhpc@10.42.0.1`
(password `lhpc`); on **Desktop** use the **Terminal** app. Then:

1. **Change the OS password** — run `passwd` and follow the prompts.
2. **Change the Wi-Fi AP key** *(Lite only)* —
   ```bash
   sudo nmcli connection modify lhpc-ap wifi-sec.psk 'your-new-key'   # 8+ characters
   sudo nmcli connection up lhpc-ap                                   # rejoin the Wi-Fi with the new key
   ```
3. **Set your callsign** —
   ```bash
   lhpc config operator --callsign YOURCALL
   ```
   (or the operator/daemon settings in the Web GUI).
4. **Pick your radio hardware** — `lhpc hardware` and choose your rig (or the **“Configure hardware”**
   prompt on the Web GUI dashboard). **Nothing can transmit until you do this.**

> Booting the image starts **no radio stack** and transmits **nothing** on its own. The console is
> reachable only on the Lite access point (or locally on Desktop), not your LAN — keep it that way
> until you deliberately expose it (turn on the managed firewall first).

<details><summary>Troubleshooting</summary>

- **No `lhpc-XXXX` Wi-Fi after ~2 min** — re-seat/re-flash the card; check power. The country must be
  set (it is, to `DE`, unless you changed it).
- **Web GUI won't open** — you must be **on the AP** (Lite) or the same network (Desktop); accept the
  self-signed certificate warning.
- **Moved the box onto your home Wi-Fi?** The AP address `10.42.0.1` (and AP-only SSH) go away — reach
  it on the new network instead. Don't open a wildcard SSH listener (it re-exposes the default password).
- **First boot still running / failed** — logs are in `/var/log/lhpc-firstboot.log`; it retries on the
  next boot.
</details>

<details><summary>Which stacks run on which band</summary>

433 MHz: Chat, iGate, MeshCom · 868 MHz: MeshCore · either band: KISS, Meshtastic, Reticulum, Voice.
Only one owner per band at a time; *installed ≠ running*; available bands depend on the hardware you
pick. LHPC refuses conflicting starts.
</details>

<details><summary>Updating &amp; maintenance</summary>

- Update LHPC on the running box: `lhpc self-update` (or the one-click updater in the console).
- OS packages: `sudo apt full-upgrade`.
- Fresh images are rebuilt monthly on the latest official base image with current packages and LHPC —
  the **kernel, bootloader and firmware track that base** (updated when the base is). Update the box in
  place — you don't
  need to reflash. Maintainer notes: [`docs/maintenance.md`](docs/maintenance.md).
</details>

---

**Defaults** (for local commissioning only — change them): user `lhpc` / `lhpc` · AP `lhpc-XXXX` /
`lorahampi` · Wi-Fi country `DE`. `XXXX` is a per-device suffix.

**More docs** live on the Pi: `~/loraham-pi-control/src/loraham-pi-control/README.md`, its `docs/`, and
`lhpc --help`.
