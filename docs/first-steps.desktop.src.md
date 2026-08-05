# LoRaHAM Pi (Desktop) — first steps

This box was flashed from a **loraham-images** release. Placeholders are filled in from the
image's onboarding defaults when this file is generated.

## Get in

1. It boots to a desktop. Sign in as **@OPERATOR_USER@** / **@OPERATOR_PASSWORD@**.
2. Connect Wi-Fi from the desktop's network menu (or use Ethernet).
3. Open a browser **on this Pi** and go to **https://127.0.0.1:@CONSOLE_PORT@/** — accept the
   local certificate warning. The console is **local-only** (not exposed to your network), and
   **SSH is off** by default.

## Then, in order

- **Change the OS password** — it is a shared default (`passwd` in a terminal).
- **Pick your radio hardware** and **set your callsign** in the console (or `lhpc hardware` /
  `lhpc config operator --callsign YOURCALL`).
- Nothing transmits: no stack starts and no RF happens just from booting.
- Before starting a stack that opens an unauthenticated non-loopback port (e.g. Meshtastic),
  configure and apply the managed firewall in the console.
- Region: this image ships **WIFI_COUNTRY=@WIFI_COUNTRY@**. Outside that country, set your
  regulatory domain before normal radio/Wi-Fi use.
- To reach the console from another machine, or to enable SSH, do it deliberately (the console's
  exposure controls / `raspi-config`).
