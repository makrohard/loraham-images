# LoRaHAM Pi — first steps

This box was flashed from a **loraham-images** release. Placeholders like @AP_SSID@ are
filled in from the image's onboarding defaults when this file is generated.

## Lite (headless, Wi-Fi access point)

1. Power on. After ~1–2 minutes it creates its own Wi-Fi network.
2. Join Wi-Fi **@AP_SSID@** with key **@AP_PSK@**.
3. Open **https://@AP_ADDR@:@CONSOLE_PORT@/** and accept the local certificate warning.
4. Log in / SSH: user **@OPERATOR_USER@**, password **@OPERATOR_PASSWORD@**. SSH is on for
   recovery on **every** network the Pi is connected to — over the AP (`ssh @OPERATOR_USER@@@AP_ADDR@`)
   or on its Ethernet/Wi-Fi IP (`ssh @OPERATOR_USER@@<pi-ip>`). This login is a shared public
   default with **sudo** — change the password immediately (below).

## Then, in order

- **Change the OS password FIRST** and **change the AP key** — these are shared onboarding
  defaults, for local commissioning only, not permanent secure operation. SSH is reachable on
  every interface with this default, so change it before putting the box on an untrusted network.
- **Pick your radio hardware** and **set your callsign** in the console.
- Nothing transmits: no stack starts and no RF happens just from booting.
- Before starting a stack that opens an unauthenticated non-loopback port (e.g. Meshtastic),
  configure and apply the managed firewall in the console.
- Region: this image ships **WIFI_COUNTRY=@WIFI_COUNTRY@**. Outside that country, set your
  regulatory domain before normal radio/Wi-Fi use.

## If you move the box onto your home Wi-Fi (AP → client)

The AP address @AP_ADDR@ and the AP-scoped console go away. **SSH stays reachable** on the box's
new IP (`ssh @OPERATOR_USER@@<pi-ip>`) — which is exactly why changing the default password first
matters. To get the console back on the new network, expose it deliberately (turn on the managed
firewall first). See the repo README.
