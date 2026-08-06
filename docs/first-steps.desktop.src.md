# LoRaHAM Pi (Desktop) — first steps

Flashed from a **loraham-images** release. Values below come from the image's onboarding defaults.

## Get in

1. It boots to a desktop. Sign in as **@OPERATOR_USER@** / **@OPERATOR_PASSWORD@**.
2. Connect Wi-Fi from the network menu, or use Ethernet.
3. Open a browser **on this Pi**: **https://127.0.0.1:@CONSOLE_PORT@/** — accept the certificate warning.

SSH is **on**, on every network this Pi joins (`ssh @OPERATOR_USER@@<pi-ip>`), so a failed first boot
cannot lock you out.

## Do these first

- **Change the password** (`passwd`). It is a public default and SSH is reachable.
- **Update the OS:** `sudo apt update && sudo apt full-upgrade`.
- **Pick your radio hardware** (`lhpc hardware`) and **set your callsign**
  (`lhpc config operator --callsign YOURCALL`). Nothing transmits until you do.

## What is already set up

- Console on **127.0.0.1:@CONSOLE_PORT@**, MeshCom on **:8444**, Meshtastic on **:8445** — all on this
  Pi only. The stacks are not exposed to any network.
- The managed firewall is **already applied**; the stacks' own ports are blocked.
- Timezone **@TIMEZONE@**, Wi-Fi country **@WIFI_COUNTRY@** — change either in `lhpc-config.txt`.
  A Pi has no battery clock, so an offline box keeps the time it last knew.
- **Every stack is already installed and built** — none is running, and nothing transmits
  just from booting. Start what you want with `lhpc stack start <name>`.
- Boot auto-restore is **on**: whatever is running when you reboot comes back by itself
  (`lhpc autostart` to see or change it).

## Reaching the console from another machine

Expose it deliberately, with a client certificate — see the repo README.
