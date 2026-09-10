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

- **Amateurfunk** — LoRaHAM **Chat**, **Voice**, den **KISS-Adapter**, **Graywolf** (LoRa-APRS)
  und **MeshCom**.
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

> [!WARNING]
> **Die Voreinstellungen sind öffentlich — und auf jedem Image dieselben.** Login `lhpc` / `lhpc`,
> WLAN-Schlüssel `lorahampi`, und SSH antwortet in jedem Netz, in dem der Pi hängt. So ist eine
> frisch geflashte Karte überhaupt benutzbar — wer sie kennt, dem gehört die Box. **Ändere beides in
> [Schritt 8](#8--die-zwei-ausgelieferten-voreinstellungen-ändern), bevor die Box deinen Schreibtisch
> verlässt** und bevor sie in ein Netz kommt, das du mit anderen teilst.

## Inhalt

- [Was auf dem Image ist](#was-auf-dem-image-ist)
- [Installation](#installation)
  - [1 · Herunterladen](#1--herunterladen)
  - [2 · Flashen](#2--flashen)
  - [3 · Verbinden](#3--verbinden)
  - [4 · WebGUI öffnen](#4--webgui-öffnen)
  - [5 · Hardware + Rufzeichen](#5--hardware--rufzeichen)
  - [6 · Einen Stack einmal starten — sein Passwort steht dann auf seiner Seite](#6--einen-stack-einmal-starten--sein-passwort-steht-dann-auf-seiner-seite)
  - [7 · Die Web-Oberflächen von anderen Rechnern erreichbar machen](#7--die-web-oberflächen-von-anderen-rechnern-erreichbar-machen)
    - [7.1 · Authentifizierung — Zertifikat ausstellen und installieren](#71--authentifizierung--zertifikat-ausstellen-und-installieren)
    - [7.2 · Freigeben — erst die Stack-Oberflächen, dann die Konsole](#72--freigeben--erst-die-stack-oberflächen-dann-die-konsole)
    - [7.3 · Aktivieren — auf der Box, per SSH](#73--aktivieren--auf-der-box-per-ssh)
  - [8 · Die zwei ausgelieferten Voreinstellungen ändern](#8--die-zwei-ausgelieferten-voreinstellungen-ändern)
  - [9 · Neu verbinden (Lite)](#9--neu-verbinden-lite)
  - [10 · Ins Heim-WLAN (Lite)](#10--ins-heim-wlan-lite)
  - [11 · Aktualisieren](#11--aktualisieren)
  - [12 · Auf Sendung](#12--auf-sendung)
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
**→ [aktuellen Release](https://github.com/makrohard/loraham-images/releases/latest)**

<details><summary><em>Download prüfen (optional)</em></summary>

Lade die `.sha256`-Datei zu **deinem** Image aus demselben Release, leg sie neben das Image, dann:

```bash
sha256sum -c loraham-lhpc-lite.img.xz.sha256
```
Es sollte `loraham-lhpc-lite.img.xz: OK` erscheinen.
</details>

### 2 · Flashen

- **[Raspberry Pi Imager](https://www.raspberrypi.com/software/) → Choose OS → Use custom → deine `.img.xz` → Choose Storage → deine SD-Karte → Write**

Die Frage nach der „OS customisation" einfach überspringen — dieses Image richtet sich selbst ein.
Karte in den Pi, Strom dran; der erste Start dauert etwa 1–2 Minuten.

<details><summary><em>Optional: vor dem ersten Start vorkonfigurieren</em></summary>

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

Nach einem erfolgreichen ersten Start überschreibt die Box `PASSWORD=` und `AP_PSK=` in dieser Datei
mit `REDACTED`, damit die Geheimnisse nicht auf der Boot-Partition liegen bleiben — findet ein
späterer Start dort noch `REDACTED`, bricht er mit einer Fehlermeldung ab; also diese Zeilen
anpassen oder die Datei löschen, bevor du mit ihr neu startest.

Mit `PASSWORD` und `AP_PSK` wird Schritt 8 später zur reinen Kontrolle, und `CALL` trägt dein
Rufzeichen schon einmal ein — das **blanke Basisrufzeichen**, ohne SSID und ohne `/P`
(stackeigene Varianten kommen später). `AP_PSK` gilt nur für **Lite** — Desktop baut kein eigenes WLAN auf,
sondern kommt in deins. Alles andere gilt für beide.

Bricht der erste Start unterwegs ab: Datei korrigieren und neu booten — der Pi merkt die
Änderung und wiederholt den gesamten ersten Start (die Geräte-PKI bleibt erhalten), deine
Korrektur greift also wirklich.

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

Beides sind die öffentlichen Werksvoreinstellungen — geändert werden sie in
[Schritt 8](#8--die-zwei-ausgelieferten-voreinstellungen-ändern). Mach das, bevor die Box irgendwo
hinkommt.

**Hinweis für Lite:** Dein Gerät wird bei diesem WLAN **„kein Internet"** melden — das ist so
gewollt, der AP des Pi hat keinen Uplink; bleib trotzdem verbunden. Und wann immer die Box neu
startet oder ihr Netz verliert, kommt ihr AP von selbst wieder — dein Handy/Laptop verbindet sich
aber nicht immer von allein neu. Wenn die Konsole nicht mehr antwortet: zuerst am eigenen Gerät
wieder das WLAN `lhpc-XXXX` auswählen. (Schritt 10 ist die Ausnahme: Solange die Box in deinem
WLAN ist, bleibt ihr AP aus.)

<details><summary><em>Was der erste Start alles einrichtet</em></summary>

| | Lite (headless) | Desktop (Bildschirm) |
|---|---|---|
| Login | `lhpc` / `lhpc` | `lhpc` / `lhpc` |
| Hostname | `lhpc-XXXX` | `lhpc-XXXX` |
| Region | `Europe/Berlin` · `DE` · Tastatur `de,us` | `Europe/Berlin` · `DE` · Tastatur `de,us` |
| WLAN | **eigener AP** `lhpc-XXXX` / `lorahampi` auf `10.42.0.1` | **kommt in deins** (WLAN-Menü oder Ethernet) |
| Web-Konsole | `https://10.42.0.1:8443` — nur im AP, ohne Passwort | `https://127.0.0.1:8443` — nur auf dem Pi |
| MeshCom-UI | `https://10.42.0.1:8444` — nur im AP | `https://127.0.0.1:8444` — nur auf dem Pi |
| Meshtastic-UI | `https://10.42.0.1:8445` — nur im AP | `https://127.0.0.1:8445` — nur auf dem Pi |
| Graywolf-APRS-UI | `https://10.42.0.1:8446` — nur im AP, **eigener Login** | `https://127.0.0.1:8446` — nur auf dem Pi |
| MeshCore-UIs | nicht bereitgestellt — per `lhpc webserver proxy` oder SSH-Tunnel erreichbar | ebenso |
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

<details><summary><em>Stattdessen <code>lhpc-recovery-XXXX</code> zu sehen?</em></summary>

Der Pi hat gebootet, aber der erste Start ist nicht durchgelaufen. Verbinde dich damit
(Schlüssel `lorahampi` — das Rettungsnetz nutzt immer den Werksschlüssel), dann
`ssh lhpc@10.42.0.1`, und lies `/var/log/lhpc-firstboot.log` sowie
`systemctl status lhpc-growroot`. Beim nächsten Boot versucht er es erneut. Gar kein
`lhpc-XXXX`-WLAN nach ~2 Minuten: Karte neu stecken/neu flashen, Netzteil prüfen.
</details>

### 4 · WebGUI öffnen

- **Lite:** **`https://10.42.0.1:8443`** — vom Handy/Laptop im AP.
- **Desktop:** **`https://127.0.0.1:8443`** — im Browser auf dem Pi.

**Lite:** Die Zertifikatswarnung kannst du bestätigen — die Box signiert ihr Zertifikat selbst. Wer
die Warnung dauerhaft loswerden will, installiert die CA der Box im Browser:
[Schritt 7.1](#71--authentifizierung--zertifikat-ausstellen-und-installieren), Punkte 2–3.
**Desktop:** normalerweise keine Warnung — der erste Start hinterlegt die CA der Box im
vorinstallierten
Browser. Ein Passwort gibt es in beiden Fällen nicht: Die Konsole ist nur aus dem AP (Lite) bzw.
nur auf dem Pi selbst (Desktop) erreichbar.

### 5 · Hardware + Rufzeichen

- **Apps → LoRaHAM daemon → Configure → Hardware**<br>
  Dein Board unter Hardware setup wählen und speichern. Unsicher, welches? Detect prüft ein Band,
  dabei leuchtet die LED des Boards. Diese Auswahl gibt es nur auf der Seite des Daemons, auf keinem
  anderen Stack. Fertig, wenn der Hinweis „No radio hardware is configured" im Dashboard
  verschwunden ist.

- **Apps → LoRaHAM Pi Control → Global operator callsign**<br>
  Dein blankes Basisrufzeichen eintragen (z. B. `G0ABC` — ohne SSID, ohne `/P`). Es liegt auf der
  Zeile der Konsole selbst, nicht auf einer Stack-Seite. Lizenzpflichtige Stacks (Chat, Voice,
  Graywolf, MeshCom) erben es, solange ihr eigenes Rufzeichenfeld leer ist; Graywolfs eigenes Feld
  trägt die APRS-Variante mit `-SSID` (z. B. `G0ABC-10`) und überschreibt es. Ein Stack ohne
  auflösbare Identität startet nicht; die Ablehnung bringt dich direkt zur betroffenen Zeile in den
  Settings des Stacks.

- **Apps → *Stack* → Configure**<br>
  Nur für Meshtastic und MeshCore, die nie ein Rufzeichen erben: jedem Knoten hier seinen eigenen
  Namen geben.

Gesendet wird noch nichts — und auch später erst, wenn du einen Stack startest.

<details><summary><em>CLI</em></summary>

```bash
lhpc hardware                        # list the boards
lhpc hardware uputronics             # e.g. a dual Uputronics rig
lhpc config operator --callsign G0ABC        # dein EIGENES Basisrufzeichen

# Meshtastic und MeshCore erben es nie — jeden Knoten vor dem Start benennen:
lhpc config meshtastic node_name "G0ABC node"
lhpc config meshtastic node_short GABC       # maximal 4 Bytes
lhpc config meshcore node_name "G0ABC node"
```
Das Operator-Rufzeichen ist global — lizenzpflichtige Stacks erben es, solange ihr eigenes
Rufzeichenfeld leer ist. Ohne auflösbare Identität startet ein Stack nicht, also vor Schritt 6
setzen.
</details>

<details><summary><em>Funkmodule & SPI</em></summary>

| `lhpc hardware` | Board | Bänder |
|---|---|---|
| `loraham` | LoRaHAM-Doppelmodul (SX1278 + RFM95) | 433 + 868 |
| `uputronics` | Uputronics dual (CE0 433 + CE1 868) | 433 + 868 |
| `uputronics-x` | Uputronics dual, Module gekreuzt (CE0 868 + CE1 433) | 433 + 868 |
| `uputronics-433` / `uputronics-868` | Uputronics 433 (CE0) / Uputronics 868 (CE1) | 433 / 868 |
| `waveshare-433` / `waveshare-868` | Waveshare SX1262 | 433 / 868 |

Beide Images liefern SPI als **`soft-cs`** aus (`dtparam=spi=on` + `dtoverlay=spi0-0cs`) — genau
das, was jedes Board oben braucht: Die Funkmodule steuern ihre Chip-Selects selbst als GPIOs.
Ändere das nur, wenn dein Board wirklich Kernel-Chip-Selects verwendet — entferne dafür zuerst die
Zeile `dtoverlay=spi0-0cs` aus `/boot/firmware/config.txt`, sonst verweigert das Skript den Dienst
und sagt dir das auch:
```bash
sudo bash ~/loraham-pi-control/src/loraham-pi-control/bootstrap-deps.sh --spi-mode hardware-cs
```
</details>

### 6 · Einen Stack einmal starten — sein Passwort steht dann auf seiner Seite

Ein Stack mit eigenem Login legt es beim **ersten Start** an, danach zeigt die Konsole den Wert.
Einmal starten genügt; einloggen musst du dich jetzt noch nicht. Ab Werk gilt das für Graywolf —
MeshCore legt sein Dashboard-Passwort erst in einem Repeater-Modus an, und MeshComs HMAC braucht
eine Quellinstallation (beides steht in der Tabelle und darunter).

- **Apps → *Stack* → Start**<br>
  Mit Graywolf starten auch der LoRaHAM KISS TNC und der LoRaHAM-Daemon, von denen er abhängt; dass
  drei Dinge hochkommen, ist normal und kein Fehler. Abgelehnt wegen fehlendem Rufzeichen oder
  Knotennamen? Du landest in den Settings des Stacks, die betroffene Zeile ist markiert — ausfüllen
  und erneut starten.

- **Apps → *Stack* → Password**<br>
  Konto und Passwort, mit Kopierknopf.

| Stack | Login | Wo es liegt |
|---|---|---|
| **Graywolf APRS** | `admin` | `state/graywolf/graywolf-admin.txt` — Graywolf legt es beim ersten Start selbst an |
| **MeshCore**, Repeater-Dashboard | `admin` | `config/secrets/openhop_repeater_admin.txt` — entsteht, sobald **Mode** auf `chat+repeater` oder `repeater` steht; vorher sagt der Abschnitt Password genau das |
| **MeshCom** | HMAC-Passwort, kein Web-Login | `config/secrets/xr_pw` — nur über die HMAC-Aktionen des Stacks änderbar, nie durch Bearbeiten der Datei |

<details><summary><em>CLI</em></summary>

```bash
lhpc stack start graywolf
```
Kein Befehl gibt ein Passwort aus — der Wert landet bewusst weder im Log noch in einer API. Im
Terminal liest du die Datei direkt:
```bash
cat ~/loraham-pi-control/state/graywolf/graywolf-admin.txt
```
</details>

<details><summary><em>MeshComs HMAC · was auf Lite fehlt</em></summary>

Das Image installiert MeshCom über den **Binary**-Kanal, und diese veröffentlichte Firmware ist mit
**leerem** HMAC-Passwort gebaut — die HMAC-Aktionen werden deshalb abgelehnt, bis du MeshCom aus den
Quellen neu installierst.

Auf **Lite** sind die zwei Teile, die einen Desktop brauchen, bewusst nicht gebaut — die GTK-App von
LoRaHAM Voice und Reticulums Sideband. Sie melden `not-applicable`; das ist kein Fehler. Desktop hat
beide.
</details>

### 7 · Die Web-Oberflächen von anderen Rechnern erreichbar machen

**Headless-Boxen brauchen das, Boxen mit Bildschirm oft nicht.** Auf **Lite** gibt es kein Display,
ein Browser auf einem anderen Rechner ist also der einzige Weg hinein — und ab Werk liegen die
Oberflächen ohne Passwort im AP, genau das schließt dieser Schritt. Auf **Desktop** kannst du ihn
komplett überspringen und im Browser auf dem Pi arbeiten: lokal bleiben ist eine völlig gute
Antwort, und außerhalb des Pi lauscht nichts, solange du nichts änderst.

Der Weg nach draußen besteht aus drei Teilen: dich per Zertifikat ausweisen, die Freigabe-Richtlinie
setzen, sie auf der Box aktivieren. In dieser Reihenfolge — das Zertifikat muss auf deinem Rechner
sein, **bevor** du die Richtlinie umstellst, sonst sperrst du dich aus.

#### 7.1 · Authentifizierung — Zertifikat ausstellen und installieren

- **Apps → LoRaHAM Pi Control → Webserver (HTTPS / mTLS) → Certificates → Issue client cert**<br>
  Ein Label vergeben, etwa `lhpc-laptop`, und auf Issue drücken. **Die Einmal-Passphrase jetzt
  kopieren** — sie wird genau einmal angezeigt, ist danach nicht wiederherstellbar, und du brauchst
  sie beim Import der `.p12`. Verloren, oder die Datei ist irgendwo gelandet, wo sie nicht
  hingehört? Dann das Zertifikat widerrufen und ein neues ausstellen; sonst ändert sich nichts.

Derselbe Certificates-Abschnitt zeigt danach zwei Kopierboxen, mit deiner Adresse und den fertigen
Pfaden. Beide auf deinem eigenen Rechner einfügen — im AP lauten sie:

```bash
scp lhpc@10.42.0.1:/home/lhpc/loraham-pi-control/config/tls/exports/lhpc-laptop.p12 .
scp lhpc@10.42.0.1:/home/lhpc/loraham-pi-control/config/tls/server-ca/ca.crt lhpc-server-ca.crt
```

Am Handy bekommst du die CA über den **Download-ca.crt**-Link im selben Abschnitt. Die `.p12` hat
abseits des Pi absichtlich keinen Download-Link, weil sie einen privaten Schlüssel enthält — hol sie
mit einer SFTP-fähigen App (gleiche Adresse, gleicher Benutzer und Pfad wie im `scp`-Befehl oben),
oder erst auf einen Rechner und von dort aufs Handy per AirDrop, Mail oder USB, und behandle sie wie
eine Schlüsseldatei.

Beide im Browser installieren, mit den Anleitungen unten: die CA als Zertifizierungsstelle und die
`.p12` als dein eigenes Zertifikat — nach dessen Passphrase wird gefragt.

#### 7.2 · Freigeben — erst die Stack-Oberflächen, dann die Konsole

- **Apps → LoRaHAM Pi Control → Webserver (HTTPS / mTLS) → Stacks WebGUIs**<br>
  Fünf Felder, dann Apply: **Access** `lan` (wer die Proxys erreichen darf), **Scheme** `https`
  (http erzwingt no-auth, https hält die Zertifikats-Anmeldung offen), **Access mode**
  `local-open-remote-auth`, **Allowed CIDRs** das Netz, aus dem du kommst — z. B. `192.168.1.0/24`,
  für lan und public Pflicht — und **Confirm** `enable-remote`. Eine Richtlinie deckt jede
  Stack-Oberfläche ab, die Ports bleiben pro Seite; die Einzel-Panels bleiben für Ausnahmen.
  (`enable-remote-danger` ist die Phrase für die riskanteren Fälle — öffentlicher Listener, gar
  keine Anmeldung oder unverschlüsseltes HTTP.)

- **Apps → LoRaHAM Pi Control → Webserver (HTTPS / mTLS) → LHPC WebGUI**<br>
  Dieselben Werte für Scheme, Access mode, Allowed CIDRs und Confirm, dazu **Bind** `0.0.0.0`, damit
  sie über Loopback hinaus lauscht. Die Konsole zuletzt: Es ist die Seite, auf der du gerade
  arbeitest.

#### 7.3 · Aktivieren — auf der Box, per SSH

Das Image liefert die verwaltete Firewall bereits angewendet aus, die Freigabe hängt also daran:
Neue Ports hinterlassen **ausstehende Änderungen**, und bis die angewendet sind, kommen die Listener
nicht hoch. `ssh lhpc@10.42.0.1`, dann:

1. **Die verwaltete Firewall anwenden.** Die Konsole zeigt denselben Befehl:

   ```bash
   sudo bash ~/loraham-pi-control/config/files/firewall/firewall-apply.sh
   ```
2. **Das Apply zu Ende bringen.** Ein Apply, das vorher wegen der ausstehenden Firewall abgelehnt
   wurde, wird gemerkt und läuft von selbst zu Ende, sobald die Firewall angewendet ist; nur wenn das
   Panel es weiter als ausstehend zeigt, drück es erneut — oder hier `lhpc webserver apply`.
3. **Die Konsole nur neu starten, falls sie nicht zurückkommt.** Apply startet das Frontend
   normalerweise selbst über den verwalteten Restart-Watcher:

   ```bash
   systemctl --user restart lhpc-nginx lhpc-web
   ```

LHPC fasst deine eigene Firewall nie an, und ein Port am Router bleibt deine Sache —
[`docs/firewall.md`](https://github.com/makrohard/loraham-pi-control/blob/main/docs/firewall.md)
(englisch).

Seite neu laden — der Browser fragt jetzt, welches Zertifikat er vorzeigen soll; wer keins hat, wird
abgewiesen. **Auf dem Pi selbst** bleibt die Konsole in beiden Fällen offen.

*Nur zum Debuggen, oder gar nichts freigeben?* Ein SSH-Tunnel erreicht die Konsole und jede
Stack-Oberfläche, ohne auf der Box etwas zu ändern:
[`docs/ssh-tunnel.md`](https://github.com/makrohard/loraham-pi-control/blob/main/docs/ssh-tunnel.md)
(englisch).

<details><summary><em>Zertifikat installieren — Linux</em></summary>

- **Firefox → about:preferences#privacy → Zertifikate anzeigen → Ihre Zertifikate → Importieren**<br>
  Die `.p12`
- **Firefox → about:preferences#privacy → Zertifikate anzeigen → Zertifizierungsstellen → Importieren**<br>
  `ca.crt`, mit Haken bei „Dieser CA vertrauen, um Websites zu identifizieren"

**Chrome/Chromium** (NSS-Speicher — Chrome und ältere Chromium nutzen `~/.pki/nssdb`,
Chromium ab 150 `~/.local/share/pki/nssdb`; nimm den, den dein Browser hat):
```bash
certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n lhpc-ca -i ca.crt
pk12util -d sql:$HOME/.pki/nssdb -i lhpc-laptop.p12
```
</details>

<details><summary><em>Zertifikat installieren — Windows</em></summary>

- **Doppelklick auf `ca.crt` → Zertifikat installieren → Vertrauenswürdige Stammzertifizierungsstellen**
- **Doppelklick auf die `.p12` → Eigene Zertifikate**<br>
  Die Passphrase wird abgefragt

Firefox-Nutzer importieren beides stattdessen in Firefox' eigener Zertifikatsverwaltung.
</details>

<details><summary><em>Zertifikat installieren — Android</em></summary>

- **Einstellungen → Sicherheit → Verschlüsselung & Anmeldedaten → Zertifikat installieren → CA-Zertifikat**<br>
  `ca.crt`
- **Einstellungen → Sicherheit → Verschlüsselung & Anmeldedaten → Zertifikat installieren → VPN- & App-Nutzerzertifikat**<br>
  Die `.p12`
</details>

<details><summary><em>Zertifikat installieren — iPhone / iPad</em></summary>

Beide Dateien aufs Gerät schicken (AirDrop oder Mail), dann:

- **Einstellungen → Profil geladen**<br>
  Jedes Profil installieren
- **Einstellungen → Allgemein → VPN & Geräteverwaltung**<br>
  Installation abschließen
- **Einstellungen → Allgemein → Info → Zertifikatsvertrauenseinstellungen**<br>
  Volles Vertrauen für die CA
</details>

<details><summary><em>CLI</em></summary>

Auf dem Pi (`ssh lhpc@10.42.0.1`). Die Richtlinie für alle Stacks auf einmal ist eine Funktion der
Konsole; aus der Shell setzt du jede Seite einzeln, die Liste entspricht `PROXY_STACKS`:
```bash
lhpc webserver cert issue lhpc-laptop        # prints a ONE-TIME passphrase — record it now
lhpc webserver cert export lhpc-laptop ~/lhpc-laptop.p12
lhpc webserver proxy meshcom    --auth local-open-remote-auth --confirm-phrase enable-remote
lhpc webserver proxy meshtastic --auth local-open-remote-auth --confirm-phrase enable-remote
lhpc webserver proxy graywolf   --auth local-open-remote-auth --confirm-phrase enable-remote
lhpc webserver expose --cidr 10.42.0.0/24 --access-mode local-open-remote-auth --confirm-phrase enable-remote
sudo bash ~/loraham-pi-control/config/files/firewall/firewall-apply.sh   # Gate: ohne das keine Freigabe
lhpc webserver apply                                                     # prüfen + aktivieren
systemctl --user restart lhpc-nginx lhpc-web                             # nur falls sie nicht zurückkommt
```
Auf deinem Rechner — eine Datei pro Befehl, **niemals** zu einem `scp` zusammenfassen:
```bash
scp lhpc@10.42.0.1:lhpc-laptop.p12 .
scp lhpc@10.42.0.1:loraham-pi-control/config/tls/server-ca/ca.crt .
```
</details>

<details><summary><em>Konsole aus einem anderen Netz erreichen (LAN)</em></summary>

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

### 8 · Die zwei ausgelieferten Voreinstellungen ändern

> [!IMPORTANT]
> Das ist der eine Schritt, den du nicht überspringen solltest. Bis dahin weiß jeder, der dieses
> Projekt kennt, wie er sich auf deiner Box anmeldet.

Beide sind öffentlich und auf jedem Image gleich, und SSH antwortet in jedem Netz, in dem der Pi
hängt:

```bash
ssh lhpc@10.42.0.1                                                 # Passwort: lhpc
passwd                                                             # neues Benutzerpasswort
sudo nmcli connection modify lhpc-ap wifi-sec.psk 'your-new-key'   # nur Lite: neuer WLAN-Schlüssel, 8+ Zeichen
sudo nmcli connection up lhpc-ap                                   # trennt deine Verbindung — so gewollt
```

`sudo` fragt nach dem Passwort, das du gerade gesetzt hast. Die Stack-Logins aus Schritt 6 bleiben
davon unberührt.

- **Desktop:** statt `ssh` die **Terminal**-App öffnen und die beiden `nmcli`-Zeilen weglassen.

### 9 · Neu verbinden *(Lite)*

Verbinde dich wieder mit `lhpc-XXXX`, jetzt mit dem **neuen** Schlüssel. Schritt 7 gemacht? Dann
fragt die Konsole jetzt nach deinem Zertifikat.

### 10 · Ins Heim-WLAN *(Lite)*

- **Apps → LoRaHAM Pi Control → Network**<br>
  Den Namen deines WLANs eintippen (solange der eigene AP des Pi läuft, gibt es keinen Scan, das ist
  normal und kein Defekt) und auf Join drücken.

Nach dem WLAN-Passwort fragt die Bestätigungsseite; sie warnt auch, dass der AP in dem Moment
weggeht, in dem die Box beitritt: Handy oder Laptop bleiben am toten AP, bis *du* selbst ins eigene
Netz wechselst. Den Haken **„allow console from that network"** nur gesetzt lassen, **wenn du
Schritt 7 gemacht hast** — ohne Zertifikat stünde die Konsole sonst jedem in deinem Netz offen.
Zeigt das Panel danach einen kopierbaren `sudo`-Befehl, führe ihn per SSH aus (Port 22 ist dort
offen); im Normalfall gibt es keinen.

Der Pi meldet sich unter **`https://lhpc-XXXX.local:8443`** zurück. Sobald das funktioniert, bei
diesem Netz auf **Prefer** klicken — sonst fällt die Box bei jedem Neustart auf ihren eigenen AP
zurück. Ein bevorzugtes Netz wird automatisch wieder verbunden; geht es verloren, ist der AP das
Sicherheitsnetz und die Box versucht es alle 10 Minuten erneut.

- **Desktop:** nichts zu tun — seit Schritt 3 schon in deinem Netz.

### 11 · Aktualisieren

Jetzt hat die Box Internet.

- **Lite:** erst ab jetzt — der eigene AP hat keins, früher aktualisieren konnte nicht
  funktionieren.

```bash
ssh lhpc@lhpc-XXXX.local
sudo apt update && sudo apt full-upgrade -y
```

<details><summary><em>LHPC und Stacks aktualisieren</em></summary>

- LHPC: `lhpc self-update --apply` (`lhpc self-update` allein prüft nur), oder der
  Ein-Klick-Updater in der Konsole.
- Ein einzelner Stack, nur wenn du eine neuere Version willst als das Image mitbringt:
  `lhpc update <stack>`. Die Stacks sind bereits installiert und gebaut — Aktualisieren ist
  optional, kein Teil der Einrichtung.
- Zu jedem LHPC-Release entsteht ein neues Image, auf der jeweils aktuellen offiziellen Basis;
  **Kernel, Bootloader und Firmware folgen dieser Basis**. Aktualisiere einfach an Ort und Stelle
  — neu flashen musst du nicht. Maintainer-Notizen: [`docs/maintenance.md`](docs/maintenance.md).
</details>

### 12 · Auf Sendung

Weitere Stacks starten: **Apps → *Stack* → Start** (oder pro Band über **Home**, das Dashboard).
Ein Band gehört immer nur einem Stack — ein kollidierender Start geht nicht stillschweigend durch:
Die Konsole nennt den Besitzer und bietet **Stop owner(s) & start** an. Was beim Neustart lief,
läuft danach von selbst wieder (**Autostart**, ab Werk an).

<details><summary><em>CLI</em></summary>

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

Jeder Stack, der eine Position nutzen kann, hat `use_gps` standardmäßig **an** — für eine normale
Box ist hier also nichts zu tun. Zum Ab- oder Wiedereinschalten für einen Stack:
**Apps → *Stack* → Configure → `use_gps`** — der Stack muss dafür **gestoppt** sein, danach wieder
starten.

<details><summary><em>CLI</em></summary>

```bash
lhpc gps                                        # show the source (and what auto resolved to)
lhpc gps --source gpsd                          # explicit: gpsd on this box
lhpc gps --source nmea --device /dev/ttyACM0    # receiver direct, no gpsd
lhpc config meshtastic use_gps on               # pro Stack; der Stack muss gestoppt sein
```
</details>

<details><summary><em>u-blox-Hinweis: einmal gpsd, immer binär</em></summary>

gpsd schaltet u-blox-Empfänger in den binären UBX-Modus — und dort **bleiben** sie auch, wenn
gpsd stoppt. Eine `nmea`-Quelle verweigert dann mit *„device is sending binary, not NMEA"*.
Einfachste Lösung: bei `--source gpsd` bleiben. (Liest Meshtastic den Empfänger *direkt*, ist
das egal — meshtasticd spricht selbst UBX.) Ein kalter Empfänger braucht draußen einige Minuten
bis zum ersten Fix; „reachable but no fix" ist eine Warnung, kein Fehler.
</details>

## Fehlerbehebung

<details><summary><em>Typische Probleme am ersten Tag</em></summary>

- **Kein `lhpc-XXXX`-WLAN nach ~2 Minuten** — Karte neu stecken/neu flashen, Netzteil prüfen.
  Stattdessen ein **`lhpc-recovery-XXXX`**-Netz: siehe Schritt 3.
- **Web-Konsole geht nicht auf** — *Lite:* Du musst im AP sein, und die Adresse ist
  `https://10.42.0.1:8443`. *Desktop:* Sie ist nur lokal — `https://127.0.0.1:8443` **auf dem
  Pi** öffnen. Die Warnung zum selbstsignierten Zertifikat bestätigen.
- **Box ins Heim-WLAN umgezogen?** `10.42.0.1` und die AP-Konsole verschwinden; **SSH bleibt**
  unter der neuen IP **erreichbar** — genau deshalb kommt das Passwortändern so früh. Die Box ist
  dann unter `https://lhpc-XXXX.local:8443` erreichbar; mit gesetztem Haken *„allow console from
  that network"* folgt die Konsole dem neuen Subnetz von selbst.
- **Nach einem Neustart wieder auf `lhpc-XXXX`?** So gewollt, solange du bei deinem Netz nicht auf
  **Prefer** geklickt hast (Schritt 10): ohne das verbindet sich die Box nicht von allein wieder.
  Neu verbinden, dann Prefer setzen.
- **`lhpc-XXXX.local` löst nicht auf?** Häufig unter Android, das `.local` gar nicht auflöst — nimm
  die Adresse, die dein Router der Box gibt, oder geh von einem Rechner aus ran.
</details>

## Standardwerte

Nur für die Inbetriebnahme vor Ort. Login und WLAN-Schlüssel änderst du in **Schritt 8**; die
regionalen Werte nur in `lhpc-config.txt` vor dem ersten Start (**Schritt 2**) oder später von Hand:

- Benutzer **`lhpc`** / Passwort **`lhpc`**
- AP **`lhpc-XXXX`** / Schlüssel **`lorahampi`**
- Rettungs-AP **`lhpc-recovery-XXXX`** / Schlüssel **`lorahampi`** (nur Lite; immer der
  Werksschlüssel)
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
