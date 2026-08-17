# loraham-images — Anleitung (Deutsch)

Fertige **Raspberry-Pi-OS-Images (Trixie, 64-bit)** mit vorinstalliertem
[LHPC](https://github.com/makrohard/loraham-pi-control). Flashen, booten, und dann alles bequem
vom Handy oder Browser aus einrichten — ganz ohne Linux-Kenntnisse.

> Maßgeblich ist die englische [`README.md`](README.md); diese Übersetzung kann hinterherhinken.
> Die Weboberfläche (Konsole) und die übrige Dokumentation sind auf Englisch.

## Was auf dem Image ist

LHPC plus **neun Stacks, bereits installiert und gebaut** — acht Anwendungen und der gemeinsame
LoRaHAM-Funkdaemon. Die Anwendungen teilen sich in zwei Familien, und der Unterschied ist
rechtlich wichtig:

- **Amateurfunk** — LoRaHAM **Chat**, **iGate**, **Voice**, **KISS/APRS-TNC** und **MeshCom**.
  Sie senden auf Amateurfunkbändern, identifizieren sich mit deinem Rufzeichen und sind in der
  Regel **unverschlüsselt**. Dafür brauchst du eine Amateurfunklizenz.
- **Lizenzfrei / verschlüsselt** — **Meshtastic**, **MeshCore**, **Reticulum**. Sie sind für den
  lizenzfreien ISM-Betrieb gedacht und **verschlüsseln** ihren Funkverkehr normalerweise. Keine
  Lizenz nötig, aber Sendeleistung und Duty-Cycle sind begrenzt.

> **Deine Verantwortung.** Welche Bänder, Sendeleistungen, Duty-Cycles und Verschlüsselung
> erlaubt sind, hängt von deinem Land ab — und davon, ob du eine Lizenz hast. Dasselbe Funkmodul
> lässt sich in beide Richtungen benutzen, und LHPC nimmt dir diese Entscheidung nicht ab. Es
> wird nichts gesendet, bevor du deine Hardware wählst und einen Stack startest — prüfe also
> zuerst die Regeln, die für dich gelten.

> **Die Voreinstellungen sind öffentlich.** Login (`lhpc` / `lhpc`) und WLAN-Schlüssel
> (`lorahampi`) sind auf jedem Image gleich, und SSH antwortet in jedem Netz, in dem der Pi
> hängt. So ist eine frisch geflashte Karte überhaupt benutzbar — ändere beides, bevor die Box
> irgendwo hinkommt: [Installation](#installation), Schritte 7–8.

## Inhalt

- [Installation](#installation) — flashen → im Browser einrichten → auf Sendung, in 12 kurzen Schritten
- [GPS (optional)](#gps-optional)
- [Fehlerbehebung](#fehlerbehebung)
- [Standardwerte](#standardwerte)
- [Lizenzen & Attribution](#lizenzen--attribution)

## Installation

Browser zuerst: Jeder Schritt zeigt den Klickweg; dasselbe als Befehle steckt jeweils in einem
eingeklappten **CLI**-Block. **Lite** (headless — macht sein eigenes WLAN) und **Desktop**
(Bildschirm — kommt in dein Netz) unterscheiden sich nur dort, wo es dabeisteht.

Du brauchst: einen Pi (z. B. Zero 2 W), eine SD-Karte, ein Handy oder einen Laptop — und dein
**Funkmodul aufgesteckt**, bevor Schritt 5 kommt.

### 1 · Herunterladen

| Image | Wofür |
|-------|-------|
| **lite** | ein Pi ohne Bildschirm (z. B. Pi Zero 2 W). Er baut **sein eigenes WLAN** auf, damit du ihn vom Handy aus einrichten kannst. |
| **desktop** | ein Pi mit Bildschirm. Er kommt in **dein** WLAN/LAN und bootet auf einen Desktop. |

Hol dir `loraham-lhpc-lite.img.xz` **oder** `loraham-lhpc-desktop.img.xz` aus dem
### → [**aktuellen Release**](https://github.com/makrohard/loraham-images/releases/latest)

<details><summary>Download prüfen (optional)</summary>

Lade die `.sha256`-Datei zu **deinem** Image aus demselben Release, leg sie neben das Image, dann:

```bash
sha256sum -c loraham-lhpc-lite.img.xz.sha256
```
Es sollte `loraham-lhpc-lite.img.xz: OK` erscheinen.
</details>

### 2 · Flashen

**[Raspberry Pi Imager](https://www.raspberrypi.com/software/)** → *Choose OS → Use custom* →
deine `.img.xz` → *Choose Storage* → deine SD-Karte → **Write**. Die Frage nach der
„OS customisation" einfach überspringen — dieses Image richtet sich selbst ein. Karte in den Pi,
Strom dran; der erste Start dauert etwa 1–2 Minuten.

<details><summary>Optional: vor dem ersten Start vorkonfigurieren</summary>

Nach dem Flashen taucht ein kleines Laufwerk namens **`bootfs`** auf. **Lege** dort eine Datei
**`lhpc-config.txt`** an — das Image bringt keine mit; ohne sie gelten alle Standardwerte.
Schlichtes `KEY=VALUE`, eine Zeile pro Eintrag, **keine Kommentare in der Zeile**; was du
weglässt, behält seinen Standard:

```
HOSTNAME=lhpc-shack
PASSWORD=choose-a-password
AP_PSK=choose-a-wifi-key
WIFI_COUNTRY=DE
TIMEZONE=Europe/Berlin
KEYBOARD=de,us
CALL=N0CALL
```

Mit `PASSWORD` und `AP_PSK` wird Schritt 8 später zur reinen Kontrolle, und `CALL` trägt dein
Rufzeichen schon einmal ein. `AP_PSK` gilt nur für **Lite** — Desktop baut kein eigenes WLAN auf,
sondern kommt in deins. Alles andere gilt für beide.

Bricht der erste Start unterwegs ab: Datei korrigieren und neu booten — der Pi merkt die
Änderung und wiederholt die betroffenen Schritte, deine Korrektur greift also wirklich.

`AP_PSK` braucht 8–63 Zeichen, `WIFI_COUNTRY` deinen Zwei-Buchstaben-Ländercode (z. B. `DE`,
`US`, `GB`), `TIMEZONE` einen Zonennamen aus `/usr/share/zoneinfo` (z. B. `America/New_York`)
und `KEYBOARD` ein bis vier xkb-Layoutnamen, das erste ist das Hauptlayout (z. B. `us`, oder
`de,us` für Deutsch mit Englisch auf `Alt+Shift`). Eine ungültige Datei wird beim ersten Start
abgewiesen — die Begründung landet als `lhpc-config-error.txt` auf demselben Laufwerk.
</details>

### 3 · Verbinden

- **Lite:** verbinde Handy oder Laptop mit dem WLAN **`lhpc-XXXX`** (Schlüssel **`lorahampi`**).
- **Desktop:** am Pi anmelden (**`lhpc`** / **`lhpc`**) und dein Netz beitreten (WLAN-Menü oder
  Ethernet).

**Hinweis für Lite:** Dein Gerät wird bei diesem WLAN **„kein Internet"** melden — das ist so
gewollt, der AP des Pi hat keinen Uplink; bleib trotzdem verbunden. Und wann immer die Box neu
startet oder das Netz wechselt (Schritte 8–10), kommt ihr AP von selbst wieder — dein
Handy/Laptop verbindet sich aber nicht immer von allein neu. Wenn die Konsole nicht mehr
antwortet: zuerst am eigenen Gerät wieder das WLAN `lhpc-XXXX` auswählen.

<details><summary>Was der erste Start alles einrichtet</summary>

| | Lite (headless) | Desktop (Bildschirm) |
|---|---|---|
| Login | `lhpc` / `lhpc` | `lhpc` / `lhpc` |
| Hostname | `lhpc-XXXX` | `lhpc-XXXX` |
| Region | `Europe/Berlin` · `DE` · Tastatur `de,us` | `Europe/Berlin` · `DE` · Tastatur `de,us` |
| WLAN | **eigener AP** `lhpc-XXXX` / `lorahampi` auf `10.42.0.1` | **kommt in deins** (WLAN-Menü oder Ethernet) |
| Web-Konsole | `https://10.42.0.1:8443` — nur im AP, ohne Passwort | `https://127.0.0.1:8443` — nur auf dem Pi |
| MeshCom-UI | `10.42.0.1:8444` — nur im AP | `127.0.0.1:8444` — nur auf dem Pi |
| Meshtastic-UI | `10.42.0.1:8445` — nur im AP | `127.0.0.1:8445` — nur auf dem Pi |
| Graywolf-APRS-UI | `10.42.0.1:8446` — nur im AP, **eigener Login** | `127.0.0.1:8446` — nur auf dem Pi |
| SSH | an, in **jedem** Netz des Pi | an, in **jedem** Netz des Pi |
| Firewall | an; die nativen Ports der Stacks sind zu | an; die nativen Ports der Stacks sind zu |
| Stacks | installiert & gebaut, **ohne die Desktop-Teile**, keiner läuft | **alle** installiert & gebaut, keiner läuft |
| Autostart | **an** — was beim Herunterfahren lief, läuft nach dem Reboot wieder | ebenso |
| Funk | **nichts läuft, nichts sendet** | **nichts läuft, nichts sendet** |

`XXXX` ist eine gerätespezifische Endung.

**Die regionalen Voreinstellungen sind deutsch** — Zeitzone `Europe/Berlin`, WLAN-Land `DE`,
Tastatur `de,us` (Deutsch, Englisch auf `Alt+Shift`). Zum Ändern `TIMEZONE`, `WIFI_COUNTRY` und
`KEYBOARD` in `lhpc-config.txt` setzen (Schritt 2). **`WIFI_COUNTRY` ist eine regulatorische
Einstellung: Außerhalb Deutschlands musst du dein eigenes Land setzen, bevor du funkst.**
</details>

<details><summary>Stattdessen <code>lhpc-recovery-XXXX</code> zu sehen?</summary>

Der Pi hat gebootet, aber der erste Start ist nicht durchgelaufen. Verbinde dich damit
(Schlüssel `lorahampi` — das Rettungsnetz nutzt immer den Werksschlüssel), dann
`ssh lhpc@10.42.0.1`, und lies `/var/log/lhpc-firstboot.log` sowie
`systemctl status lhpc-growroot`. Beim nächsten Boot versucht er es erneut. Gar kein
`lhpc-XXXX`-WLAN nach ~2 Minuten: Karte neu stecken/neu flashen, Netzteil prüfen.
</details>

### 4 · Konsole öffnen

- **Lite:** **`https://10.42.0.1:8443`** — vom Handy/Laptop im AP.
- **Desktop:** **`https://127.0.0.1:8443`** — im Browser auf dem Pi.

Die Zertifikatswarnung kannst du bestätigen — die Box signiert ihr Zertifikat selbst. Wer die
Warnung dauerhaft loswerden will, installiert die CA der Box im Browser:
[Schritt 7](#7--optional-web-oberflächen-per-zertifikat-absichern), Punkte 2–3. Ein Passwort
gibt es nicht: Die Konsole ist nur aus dem AP (Lite) bzw. nur auf dem Pi selbst (Desktop)
erreichbar.

### 5 · Hardware + Rufzeichen

**Apps → Graywolf APRS → Configure**: dein **Funkmodul** im Dropdown wählen und dein
**Stationsrufzeichen** mit APRS-SSID eintragen (z. B. `N0CALL-10`) → Save. Das Rufzeichen ist
eine **globale Einstellung** — alle lizenzpflichtigen Stacks erben es; Graywolf trägt lediglich
die APRS-Variante mit `-SSID`. Gesendet wird noch nichts — und auch später erst, wenn du einen
Stack startest.

<details><summary>CLI</summary>

```bash
lhpc hardware                        # list the boards
lhpc hardware uputronics             # e.g. a dual Uputronics rig
lhpc config operator --callsign N0CALL
```
Das Operator-Rufzeichen ist global — jeder Stack ohne eigenes Rufzeichenfeld erbt es.
</details>

<details><summary>Funkmodule & SPI</summary>

| `lhpc hardware` | Board | Bänder |
|---|---|---|
| `loraham` | LoRaHAM-Doppelmodul (SX1278 + RFM95) | 433 + 868 |
| `uputronics` | Uputronics dual (CE0 + CE1) | 433 + 868 |
| `uputronics-433` / `uputronics-868` | Uputronics einzeln | 433 / 868 |
| `waveshare-433` / `waveshare-868` | Waveshare SX1262 | 433 / 868 |

Beide Images liefern SPI als **`soft-cs`** aus (`dtparam=spi=on` + `dtoverlay=spi0-0cs`) — genau
das, was jedes Board oben braucht: Die Funkmodule steuern ihre Chip-Selects selbst als GPIOs.
Ändere das nur, wenn dein Board wirklich Kernel-Chip-Selects verwendet:
```bash
sudo bash ~/loraham-pi-control/src/loraham-pi-control/bootstrap-deps.sh --spi-mode hardware-cs
```
</details>

### 6 · Graywolf einmal starten

**Apps → Graywolf APRS → Start.** Beim ersten Start erzeugt die App ihr **eigenes
Login-Passwort** — einloggen musst du dich jetzt **nicht**; einmal starten genügt.
**Apps → Graywolf APRS → Password** zeigt das Konto und einen kopierbaren Befehl, der das
Passwort ausgibt — den führst du in Schritt 8 aus. (Rufzeichen vergessen? Die
Start-Bestätigungsseite fragt danach.)

<details><summary>CLI</summary>

```bash
lhpc stack start graywolf
```
</details>

<details><summary>Warum Graywolf einen eigenen Login hat · was auf Lite fehlt</summary>

Graywolf ist die einzige der bereitgestellten Oberflächen mit eigenem Konto — das Passwort
entsteht beim ersten Start und liegt in `state/graywolf/graywolf-admin.txt` (nur auf dem Pi
lesbar). Konsole und die anderen Oberflächen haben keinen eigenen Login; die sichert erst
Schritt 7 ab.

Auf **Lite** sind die drei Teile, die einen Desktop brauchen, bewusst nicht gebaut — Voice,
MeshCores Node-Manager-GUI und Reticulums Sideband. Sie melden `not-applicable`; das ist kein
Fehler. Desktop hat alle drei.
</details>

### 7 · Optional: Web-Oberflächen per Zertifikat absichern

Mach das immer dann, wenn andere die Oberflächen erreichen können — auf **Lite** ist das ab Werk
so (jeder im AP), auf jeder Box, sobald du die Konsole ins LAN stellst. Aus „kein Passwort" wird
damit „nur Browser mit deinem Zertifikat".

1. **Apps → LoRaHAM Pi Control → Webserver (HTTPS / mTLS) → Certificates → Issue client cert**:
   Label `lhpc-laptop` → **Issue** → **die Einmal-Passphrase kopieren** — sie wird nur einmal
   angezeigt.
2. Derselbe **Certificates**-Abschnitt zeigt jetzt zwei Kopierboxen, Adresse und Pfade bereits
   eingesetzt — *„Fetch an issued client certificate (.p12) to your PC"* und *„Fetch the server
   trust (CA) to your PC"*. Beide auf **deinem Rechner** einfügen (im AP lauten sie):

   ```bash
   scp lhpc@10.42.0.1:/home/lhpc/loraham-pi-control/config/tls/exports/lhpc-laptop.p12 lhpc-laptop.p12
   scp lhpc@10.42.0.1:/home/lhpc/loraham-pi-control/config/tls/server-ca/ca.crt lhpc-server-ca.crt
   ```
   **Am Handy**: Die CA bekommst du über den **Download-ca.crt**-Link im selben Abschnitt. Die
   `.p12` hat abseits des Pi absichtlich keinen Download-Link (sie enthält einen privaten
   Schlüssel) — hol sie mit einer SFTP-fähigen App (gleiche Adresse, gleicher Benutzer und Pfad
   wie im `scp`-Befehl oben), oder erst auf einen Rechner und von dort aufs Handy (AirDrop,
   Mail, USB) — und behandle sie wie eine Schlüsseldatei.
3. Beide im Browser installieren (Anleitungen unten): die CA als *Zertifizierungsstelle*, die
   `.p12` als *dein* Zertifikat (sie fragt nach der Einmal-Passphrase aus Punkt 1).
4. Für jeden der Stacks **MeshCom**, **Meshtastic**, **Graywolf**:
   **Apps → *Stack* → Webserver (web UI proxy) → Settings**: **Access mode →
   `local-open-remote-auth`**, in **Confirm phrase** `enable-remote` eintippen → **Apply**.
5. Dasselbe für die Konsole selbst, **zuletzt**:
   **Apps → LoRaHAM Pi Control → Webserver (HTTPS / mTLS) → Settings**: **Access mode →
   `local-open-remote-auth`**, Confirm phrase `enable-remote` → **Apply**.
   Seite neu laden — der Browser fragt, welches Zertifikat er vorzeigen soll. Wer keins hat,
   wird abgewiesen.

<details><summary>Zertifikat installieren — Linux</summary>

**Firefox** (eigener Speicher): `about:preferences#privacy` → *Zertifikate anzeigen* → **Ihre
Zertifikate** → *Importieren* für die `.p12`; **Zertifizierungsstellen** → *Importieren* für
`ca.crt`, Haken bei „Dieser CA vertrauen, um Websites zu identifizieren".
**Chrome/Chromium** (NSS-Speicher):
```bash
certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n lhpc-ca -i ca.crt
pk12util -d sql:$HOME/.pki/nssdb -i lhpc-laptop.p12
```
</details>

<details><summary>Zertifikat installieren — Windows</summary>

Doppelklick auf `ca.crt` → *Zertifikat installieren* → **Vertrauenswürdige
Stammzertifizierungsstellen**. Doppelklick auf die `.p12` → in **Eigene Zertifikate**
importieren (Passphrase eingeben). Firefox-Nutzer importieren beides stattdessen in Firefox'
eigener Zertifikatsverwaltung.
</details>

<details><summary>Zertifikat installieren — Android</summary>

Einstellungen → Sicherheit → *Verschlüsselung & Anmeldedaten* → *Zertifikat installieren* —
`ca.crt` unter **CA-Zertifikat**, die `.p12` unter **VPN- & App-Nutzerzertifikat**.
</details>

<details><summary>Zertifikat installieren — iPhone / iPad</summary>

Beide Dateien aufs Gerät schicken (AirDrop/Mail), jedes Profil installieren (Einstellungen →
*Profil geladen*), abschließen unter Einstellungen → Allgemein → *VPN & Geräteverwaltung* — und
für die CA zusätzlich volles Vertrauen aktivieren unter Einstellungen → Allgemein → Info →
*Zertifikatsvertrauenseinstellungen*.
</details>

<details><summary>CLI</summary>

Auf dem Pi (`ssh lhpc@10.42.0.1`):
```bash
lhpc webserver cert issue lhpc-laptop        # prints a ONE-TIME passphrase — record it now
lhpc webserver cert export lhpc-laptop ~/lhpc-laptop.p12
lhpc webserver proxy meshcom    --auth local-open-remote-auth --confirm-phrase enable-remote
lhpc webserver proxy meshtastic --auth local-open-remote-auth --confirm-phrase enable-remote
lhpc webserver proxy graywolf   --auth local-open-remote-auth --confirm-phrase enable-remote
lhpc webserver expose --cidr 10.42.0.0/24 --access-mode local-open-remote-auth --confirm-phrase enable-remote
lhpc webserver apply
```
Auf deinem Rechner — eine Datei pro Befehl, **niemals** zu einem `scp` zusammenfassen:
```bash
scp lhpc@10.42.0.1:lhpc-laptop.p12 .
scp lhpc@10.42.0.1:loraham-pi-control/config/tls/server-ca/ca.crt .
```
</details>

<details><summary>Konsole aus einem anderen Netz erreichen (LAN)</summary>

Ist das Zertifikat installiert, ist ein weiteres Netz ein einziger Befehl auf dem Pi (`--cidr`
pro Bereich wiederholen) — auf **Lite** erledigt das Network-Panel das für dich, wenn du deinem
WLAN beitrittst (Schritt 10):

```bash
lhpc webserver expose --cidr 192.168.1.0/24 --access-mode local-open-remote-auth --confirm-phrase enable-remote
lhpc webserver apply
```
`local-open-remote-auth` lässt die Konsole **auf dem Pi selbst** offen und verlangt von überall
sonst das Zertifikat. `lhpc webserver cert list` zeigt, was ausgestellt ist; `revoke` zieht
eines zurück. Einen Port am Router öffnen bleibt deine Sache — LHPC fasst weder deinen Router
noch deine eigene Firewall an.
</details>

### 8 · Passwörter — einmal ins Terminal

Beide Voreinstellungen sind öffentlich und auf jedem Image gleich, und SSH antwortet in jedem
Netz, in dem der Pi hängt:

```bash
ssh lhpc@10.42.0.1                                                 # Passwort: lhpc
cat ~/loraham-pi-control/state/graywolf/graywolf-admin.txt         # dein Graywolf-Login — kopieren
passwd                                                             # neues Benutzerpasswort
sudo nmcli connection modify lhpc-ap wifi-sec.psk 'your-new-key'   # nur Lite: neuer WLAN-Schlüssel, 8+ Zeichen
sudo nmcli connection up lhpc-ap                                   # trennt deine Verbindung — so gewollt
```

- **Desktop:** statt `ssh` die **Terminal**-App öffnen und die beiden `nmcli`-Zeilen weglassen.

### 9 · Neu verbinden *(Lite)*

Verbinde dich wieder mit `lhpc-XXXX`, jetzt mit dem **neuen** Schlüssel. Schritt 7 gemacht? Dann
fragt die Konsole jetzt nach deinem Zertifikat.

### 10 · Ins Heim-WLAN *(Lite)*

**Apps → LoRaHAM Pi Control → Network**: Name und Passwort deines WLANs **eintippen** — solange
der eigene AP des Pi läuft, gibt es keinen Scan (normal, kein Defekt). Den Haken **„allow
console from that network"** nur gesetzt lassen, **wenn du Schritt 7 gemacht hast** — ohne
Zertifikat stünde die Konsole sonst jedem in deinem Netz offen. Den einen kopierbaren
`sudo`-Befehl, den das Panel zeigt, per SSH ausführen (Port 22 ist dort offen).

Der Pi meldet sich unter **`https://lhpc-XXXX.local:8443`** zurück, und sein eigener AP kommt
von selbst wieder, wann immer dein WLAN wegfällt.

- **Desktop:** nichts zu tun — seit Schritt 3 schon in deinem Netz.

### 11 · Aktualisieren

Jetzt hat die Box Internet.

- **Lite:** erst ab jetzt — der eigene AP hat keins, früher aktualisieren konnte nicht
  funktionieren.

```bash
ssh lhpc@lhpc-XXXX.local
sudo apt update && sudo apt full-upgrade -y
```

<details><summary>LHPC und Stacks aktualisieren</summary>

- LHPC: `lhpc self-update` (oder der Ein-Klick-Updater in der Konsole).
- Ein einzelner Stack, nur wenn du eine neuere Version willst als das Image mitbringt:
  `lhpc update <stack>`. Die Stacks sind bereits installiert und gebaut — Aktualisieren ist
  optional, kein Teil der Einrichtung.
- Die Images werden monatlich auf der jeweils aktuellen offiziellen Basis neu gebaut; **Kernel,
  Bootloader und Firmware folgen dieser Basis**. Aktualisiere einfach an Ort und Stelle — neu
  flashen musst du nicht. Maintainer-Notizen: [`docs/maintenance.md`](docs/maintenance.md).
</details>

### 12 · Auf Sendung

Weitere Stacks starten: **Apps → *Stack* → Start** (oder pro Band über **Home**, das Dashboard).
Ein Band gehört immer nur einem Stack — einen kollidierenden Start lehnt LHPC ab. Was beim
Neustart lief, läuft danach von selbst wieder (**Autostart**, ab Werk an).

<details><summary>CLI</summary>

```bash
lhpc status                      # what is installed and what is running
lhpc stack start meshtastic      # start one
lhpc stack stop meshtastic       # stop it again
lhpc autostart                   # see or change boot auto-restore
```
</details>

## GPS (optional)

Eine Positionsquelle versorgt alle Stacks; ohne Empfänger läuft trotzdem alles — nur eben ohne
Position.

- **Empfänger schon an Bord** (ein GPS-HAT oder einer auf deinem Funkmodul — er erscheint als
  serielles Gerät): **direkt** nutzbar, ganz ohne gpsd.
  **Apps → LoRaHAM Pi Control → Position (GPS)**: Quelle **nmea** + Gerätepfad (z. B.
  `/dev/ttyAMA0`) → Save. Der Direktmodus versorgt allerdings nur **einen** Stack.
- **Kein GPS an Bord**: einen **USB-Empfänger** anstecken (z. B. einen u-blox-Stick) und über
  **gpsd** laufen lassen — ein Systemdienst, den du einmal selbst einrichtest:

  ```bash
  sudo apt install -y gpsd gpsd-clients
  sudo systemctl enable --now gpsd
  cgps                                   # Kontrolle: Sätze laufen durch, draußen kommt ein Fix
  ```
  Debian erkennt USB-Empfänger automatisch (`USBAUTO`), und LHPCs Standardquelle (`auto`) findet
  einen lokalen gpsd von allein — mehr ist nicht zu konfigurieren.

Danach die Position pro Stack einschalten: **Apps → *Stack* → Configure → `use_gps`** → Save
(gilt ab dem nächsten Start des Stacks).

<details><summary>CLI</summary>

```bash
lhpc gps                                        # show the source (and what auto resolved to)
lhpc gps --source gpsd                          # explicit: gpsd on this box
lhpc gps --source nmea --device /dev/ttyACM0    # receiver direct, no gpsd
lhpc config meshtastic use_gps on               # per stack
```
</details>

<details><summary>u-blox-Hinweis: einmal gpsd, immer binär</summary>

gpsd schaltet u-blox-Empfänger in den binären UBX-Modus — und dort **bleiben** sie auch, wenn
gpsd stoppt. Eine `nmea`-Quelle verweigert dann mit *„device is sending binary, not NMEA"*.
Einfachste Lösung: bei `--source gpsd` bleiben. (Liest Meshtastic den Empfänger *direkt*, ist
das egal — meshtasticd spricht selbst UBX.) Ein kalter Empfänger braucht draußen einige Minuten
bis zum ersten Fix; „reachable but no fix" ist eine Warnung, kein Fehler.
</details>

## Fehlerbehebung

<details><summary>Typische Probleme am ersten Tag</summary>

- **Kein `lhpc-XXXX`-WLAN nach ~2 Minuten** — Karte neu stecken/neu flashen, Netzteil prüfen.
  Stattdessen ein **`lhpc-recovery-XXXX`**-Netz: siehe Schritt 3.
- **Web-Konsole geht nicht auf** — *Lite:* Du musst im AP sein, und die Adresse ist
  `https://10.42.0.1:8443`. *Desktop:* Sie ist nur lokal — `https://127.0.0.1:8443` **auf dem
  Pi** öffnen. Die Warnung zum selbstsignierten Zertifikat bestätigen.
- **Box ins Heim-WLAN umgezogen?** `10.42.0.1` und die AP-Konsole verschwinden; **SSH bleibt**
  unter der neuen IP **erreichbar** — genau deshalb kommt das Passwortändern so früh. Wie du die
  Konsole zurückbekommst: Schritte 7 und 10.
</details>

## Standardwerte

Nur für die Inbetriebnahme vor Ort — ändere sie (Schritte 7–8):

- Benutzer **`lhpc`** / Passwort **`lhpc`**
- AP **`lhpc-XXXX`** / Schlüssel **`lorahampi`**
- Rettungs-AP **`lhpc-recovery-XXXX`** / Schlüssel **`lorahampi`** (immer der Werksschlüssel)
- WLAN-Land **`DE`** · Zeitzone **`Europe/Berlin`** · Tastatur **`de,us`** (Deutsch; `Alt+Shift`
  für Englisch)
- `XXXX` ist eine gerätespezifische Endung

**Mehr Doku** — LHPC upstream: [README](https://github.com/makrohard/loraham-pi-control#readme)
(auch [auf Deutsch](https://github.com/makrohard/loraham-pi-control/blob/main/README.de.md)) ·
[docs](https://github.com/makrohard/loraham-pi-control/tree/main/docs). Dieselben Dateien liegen
auf dem Pi unter `~/loraham-pi-control/src/loraham-pi-control/`, dazu `lhpc --help`.

## Lizenzen & Attribution

Die Images sind frei und nicht-kommerziell. Welche Software sie enthalten, unter welcher Lizenz
und von wem: siehe [Licenses & attribution](README.md#licenses--attribution) in der englischen
README.
