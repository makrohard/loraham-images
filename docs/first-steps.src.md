# LoRaHAM Pi — first steps

This box was flashed from a **loraham-images** release. Placeholders like @AP_SSID@ are
filled in from the image's onboarding defaults when this file is generated.

## Lite (headless, Wi-Fi access point)

1. Power on. After ~1–2 minutes it creates its own Wi-Fi network.
2. Join Wi-Fi **@AP_SSID@** with key **@AP_PSK@**.
3. Open **https://@AP_ADDR@:@CONSOLE_PORT@/** and accept the local certificate warning.
4. Log in / SSH: user **@OPERATOR_USER@**, password **@OPERATOR_PASSWORD@**
   (`ssh @OPERATOR_USER@@@AP_ADDR@`).

## Then, in order

- **Change the OS password** and **change the AP key** — these are shared onboarding
  defaults, for local commissioning only, not permanent secure operation.
- **Pick your radio hardware** and **set your callsign** in the console.
- Nothing transmits: no stack starts and no RF happens just from booting.
- Before starting a stack that opens an unauthenticated non-loopback port (e.g. Meshtastic),
  configure and apply the managed firewall in the console.
- Region: this image ships **WIFI_COUNTRY=@WIFI_COUNTRY@**. Outside that country, set your
  regulatory domain before normal radio/Wi-Fi use.

## If you move the box onto your home Wi-Fi (AP → client)

The AP address @AP_ADDR@ goes away, so the AP-only SSH and the console stop being reachable
that way. Reach it on the new network, then re-point the console/SSH — do **not** open a
wildcard SSH listener (that re-exposes the default password). See the repo README.
