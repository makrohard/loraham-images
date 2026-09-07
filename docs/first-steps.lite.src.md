# LoRaHAM Pi — first steps

Flashed from a **loraham-images** release. Values below come from the image's onboarding defaults.

## Get in

1. Power on. After ~1–2 minutes it creates its own Wi-Fi.
2. Join **@AP_SSID@** with key **@AP_PSK@**.
3. Open **https://@AP_ADDR@:@CONSOLE_PORT@/** and accept the certificate warning.
4. Or SSH: `ssh @OPERATOR_USER@@@AP_ADDR@` — user **@OPERATOR_USER@**, password **@OPERATOR_PASSWORD@**.

If you see **lhpc-recovery-…** instead of **@AP_SSID@**, first boot did not finish.
Join it with the same key **@AP_PSK@** (the recovery network always uses the factory key) and read
`/var/log/lhpc-firstboot.log`.

## Do these first

- **Change the password** (`passwd`) and **the AP key**
  (`sudo nmcli connection modify lhpc-ap wifi-sec.psk 'new-key' && sudo nmcli connection up lhpc-ap`).
  Both are public defaults, and SSH answers on **every** network the Pi joins.
- **Pick your radio hardware** (`lhpc hardware`) and **set your callsign**
  (`lhpc config operator --callsign YOURCALL` — the bare base call, no SSID). Without a
  resolvable identity a stack refuses to start, so nothing can transmit until you do.
- **Name the licence-free nodes** — Meshtastic and MeshCore never inherit the callsign:
  `lhpc config meshtastic node_name "<name>"`, `lhpc config meshtastic node_short <=4 bytes>`
  and `lhpc config meshcore node_name "<name>"`. They refuse to start until you do.

Click-by-click walkthrough (browser-first, certificates, home Wi-Fi):
https://github.com/makrohard/loraham-images#install

## What is already set up

- Console on **https://@AP_ADDR@:@CONSOLE_PORT@**, MeshCom on **:8444**, Meshtastic on **:8445**,
  Graywolf APRS on **:8446** — all reachable from this access point only. The console and the first
  two need no password; Graywolf has a login of its own, shown on its stack page after you start it
  once.
- The managed firewall is **already applied**: the stacks' own ports are blocked, so those proxies
  are the only way in. SSH stays reachable everywhere.
- Regional defaults are **German**: timezone **@TIMEZONE@**, Wi-Fi country **@WIFI_COUNTRY@**,
  keyboard **@KEYBOARD@** (`Alt+Shift` switches layout). Set them in `lhpc-config.txt` before the
  first boot; afterwards change them by hand (`sudo timedatectl set-timezone …`,
  `sudo raspi-config nonint do_wifi_country …`, `/etc/default/keyboard`).
  Wi-Fi country is a regulatory setting — set your own before operating the radio.
  A Pi has no battery clock, so an offline box keeps the time it last knew.
- **The stacks are already installed and built** — except the two parts that need a desktop
  (LoRaHAM Voice's GTK app and Reticulum's Sideband), which this headless image skips on purpose.
  None is running and nothing transmits just from booting; start what you want with
  `lhpc stack start <name>`.
- Boot auto-restore is **on**: whatever is running when you reboot comes back by itself
  (`lhpc autostart` to see or change it).

## Moving it onto your home Wi-Fi

The AP address @AP_ADDR@ and the AP-scoped console go away; **SSH stays reachable** on the new IP —
which is why changing the password comes first. The Network panel offers to extend the console to
the network you join, so it follows by itself; do that only with a client certificate in place, or
the console stands open to everyone on that network (see the repo README). Click **Prefer** on the
network once it works, or the box falls back to its own access point on every reboot. The console
is then at **https://<hostname>.local:@CONSOLE_PORT@**. Then, **with internet for the first time**,
update the OS:
`sudo apt update && sudo apt full-upgrade` (the box's own AP has no upstream, so updating before
this point cannot work).
