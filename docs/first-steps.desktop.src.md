# LoRaHAM Pi (Desktop) — first steps

Flashed from a **loraham-images** release. Values below come from the image's onboarding defaults.

## Get in

1. It boots to a desktop. Sign in as **@OPERATOR_USER@** / **@OPERATOR_PASSWORD@**.
2. Connect Wi-Fi from the network menu, or use Ethernet.
3. Open a browser **on this Pi**: **https://127.0.0.1:@CONSOLE_PORT@/** — first boot already trusts
   this box's CA in the pre-installed browser, so there should be no warning. In another browser,
   accept it or install the CA.

SSH is **on**, on every network this Pi joins (`ssh @OPERATOR_USER@@<pi-ip>`), so a failed first boot
cannot lock you out.

## Do these first

- **Change the password** (`passwd`). It is a public default and SSH is reachable.
- **Update the OS:** `sudo apt update && sudo apt full-upgrade`.
- **Pick your radio hardware** (`lhpc hardware`) and **set your callsign**
  (`lhpc config operator --callsign YOURCALL` — the bare base call, no SSID). Without a
  resolvable identity a stack refuses to start, so nothing can transmit until you do.
- **Name the licence-free nodes** — Meshtastic and MeshCore never inherit the callsign:
  `lhpc config meshtastic node_name "<name>"`, `lhpc config meshtastic node_short <=4 bytes>`
  and `lhpc config meshcore node_name "<name>"`. They refuse to start until you do.

## What is already set up

- Console on **https://127.0.0.1:@CONSOLE_PORT@**, MeshCom on **:8444**, Meshtastic on **:8445**,
  Graywolf APRS on **:8446** — all on this Pi only. The stacks are not exposed to any network.
  Graywolf has a login of its own, shown on its stack page after you start it once.
- The managed firewall is **already applied**; the stacks' own ports are blocked.
- Regional defaults are **German**: timezone **@TIMEZONE@**, Wi-Fi country **@WIFI_COUNTRY@**,
  keyboard **@KEYBOARD@** (`Alt+Shift` switches layout). Set them in `lhpc-config.txt` before the
  first boot; afterwards change them by hand (`sudo timedatectl set-timezone …`,
  `sudo raspi-config nonint do_wifi_country …`, `/etc/default/keyboard`).
  Wi-Fi country is a regulatory setting — set your own before operating the radio.
  A Pi has no battery clock, so an offline box keeps the time it last knew.
- **Every stack is already installed and built** — none is running, and nothing transmits
  just from booting. Start what you want with `lhpc stack start <name>`.
- Boot auto-restore is **on**: whatever is running when you reboot comes back by itself
  (`lhpc autostart` to see or change it).

## Reaching the console from another machine

Expose it deliberately, with a client certificate — see the repo README.
