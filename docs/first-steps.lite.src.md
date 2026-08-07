# LoRaHAM Pi — first steps

Flashed from a **loraham-images** release. Values below come from the image's onboarding defaults.

## Get in

1. Power on. After ~1–2 minutes it creates its own Wi-Fi.
2. Join **@AP_SSID@** with key **@AP_PSK@**.
3. Open **https://@AP_ADDR@:@CONSOLE_PORT@/** and accept the certificate warning.
4. Or SSH: `ssh @OPERATOR_USER@@@AP_ADDR@` — user **@OPERATOR_USER@**, password **@OPERATOR_PASSWORD@**.

If you see **@AP_SSID@**-style naming replaced by **lhpc-recovery-XXXX**, first boot did not finish.
Join it with the same key **@AP_PSK@** (the recovery network always uses the factory key) and read
`/var/log/lhpc-firstboot.log`.

## Do these first

- **Change the password** (`passwd`) and **the AP key**
  (`sudo nmcli connection modify lhpc-ap wifi-sec.psk 'new-key' && sudo nmcli connection up lhpc-ap`).
  Both are public defaults, and SSH answers on **every** network the Pi joins.
- **Update the OS:** `sudo apt update && sudo apt full-upgrade`.
- **Pick your radio hardware** (`lhpc hardware`) and **set your callsign**
  (`lhpc config operator --callsign YOURCALL`). Nothing transmits until you do.

## What is already set up

- Console on **@AP_ADDR@:@CONSOLE_PORT@**, MeshCom on **:8444**, Meshtastic on **:8445** — all reachable
  from this access point only, with no password, like the console.
- The managed firewall is **already applied**: the stacks' own ports are blocked, so those proxies
  are the only way in. SSH stays reachable everywhere.
- Regional defaults are **German**: timezone **@TIMEZONE@**, Wi-Fi country **@WIFI_COUNTRY@**,
  keyboard **@KEYBOARD@** (`Alt+Shift` switches layout). Change any of them in `lhpc-config.txt`.
  Wi-Fi country is a regulatory setting — set your own before operating the radio.
  A Pi has no battery clock, so an offline box keeps the time it last knew.
- **The stacks are already installed and built** — except the three parts that need a desktop
  (Voice, MeshCore's Node Manager GUI, Reticulum's Sideband), which this headless image skips on
  purpose. None is running and nothing transmits just from booting; start what you want with
  `lhpc stack start <name>`.
- Boot auto-restore is **on**: whatever is running when you reboot comes back by itself
  (`lhpc autostart` to see or change it).

## Moving it onto your home Wi-Fi

The AP address @AP_ADDR@ and the AP-scoped console go away; **SSH stays reachable** on the new IP —
which is why changing the password comes first. To reach the console there, expose it with a client
certificate: see the repo README.
