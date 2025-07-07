# Digital Signage Kiosk-Skript für Linux Mint

## Zweck

Dieses Setup automatisiert die Einrichtung eines sicheren, wartungsarmen Digital-Signage-PCs (z.B. als Anzeige/Infoboard im Foyer):

- **Zeigt automatisch eine definierte Webseite im Vollbild an (Chromium Kiosk Mode)**
- **Wartung ausschließlich per SSH (nur Admin, Key-basiert, über einstellbaren Port)**
- **Alle Popups, System- und Update-Meldungen, Energiesparfunktionen und Standby sind abgeschaltet**
- **Optionaler Proxy-Support (inkl. no_proxy-Ausnahmen)**
- **Automatischer täglicher oder wöchentlicher System-Update (per Cron)**
- **Planbares, automatisches Herunterfahren zur gewünschten Uhrzeit**
- **VNC-Fernwartung als Option (nur via SSH-Tunnel erreichbar, Port 5900, Passwort geschützt)**
- **Webseiten-Reload im gewünschten Intervall (via xdotool/F5)**
- **Komfortable Anpassung aller relevanten Einstellungen über nachträgliches Anpassungsskript**
- **Erweiterte Debug-/ Diagnosefunktionen inkl. Übersicht aller System-, User- und Netz-Konfigurationen**

---

## Bedienungsablauf (Setup)

Beim Ausführen des Skripts werden folgende Informationen abgefragt:

1. **Kiosk-Webseite** (z.B. `https://www.meinedomain.de/anzeige`)
2. **Reload-Intervall** in Minuten (z.B. 10, Standard: 10)
3. **Proxy-Adresse** (optional, z.B. `http://user:pw@proxy:3128`)
4. **Proxy no_proxy-Ausnahmen** (optional, z.B. 127.0.0.1,localhost)
5. **SSH-Port** (Standard: 22, kann z.B. auf 2222 gesetzt werden)
6. **VNC-Passwort** (für Fernwartung, wird lokal gespeichert)
7. **Uhrzeit für automatischen täglichen Shutdown** (Format HH:MM oder leer für kein Shutdown)

---

## Nach dem Setup

- Das System zeigt nach dem automatischen Login die gewünschte Webseite im Vollbild an (Chromium, mit deutscher Oberfläche und ohne Übersetzungshinweise).
- Fernwartung ausschließlich für den `kiosk_admin` via SSH (Key-basiert, kein Passwort, root ist gesperrt, lediglich der gewählte Port ist offen).
- Kiosk-Nutzer (`kiosk`) hat zum System keinen Shell-/SSH-Zugang. Die Shell steht auf `/usr/sbin/nologin`. Kein Sudo, keine Mitgliedschaft in sicherheitsrelevanten Gruppen.
- Automatische (tägliche oder wöchentliche) Systemupdates über Cron, unauffällig im Hintergrund.
- Optionaler täglicher Shutdown (Uhrzeit frei einstellbar). Das Skript trägt nötige Rechte per sudoers automatisch ein.
- Update- und Welcome-Benachrichtigungen (alle System-/ Mint- und GNOME-Komponenten) sind für den Kiosk-Nutzer deaktiviert.
- Gnome Keyring ist deinstalliert, keine Schlüsselbund-/Passwort-Popups.
- Energiesparfunktionen (Bildschirmsperre, Sleep, Display-Off etc.) und Willkommensbildschirm werden abgeschaltet.
- Autostart und Reload-Mechanismus für Chromium sind automatisch eingerichtet.
- VNC wird als Service (x11vnc) installiert, ist nur über SSH-Tunnel (localhost) mit Passwort erreichbar.
- Proxy-Einstellungen (inkl. Ausnahmen) werden systemweit für den Kiosk-Nutzer gesetzt.

---

## Nachträgliche Anpassungen / Wartung

Du kannst nachträglich folgende Einstellungen komfortabel per Skript (`anpassen-kioskconfig.sh`) ändern:

- **Anzuzeigende Webseite**
- **Seiten-Reload-Intervall (in Minuten)**
- **Uhrzeit für automatischen Shutdown (HH:MM oder entfernt)**

> Nach Änderungen empfiehlt sich ein Kiosk-Neustart, damit alles wirksam wird.

---

## Diagnose & Kontrolle

Für Support und Fehlerdiagnose gibt es ein umfangreiches **Debug-Skript** (`debug-kiosk.sh`).  
Dieses prüft User, Berechtigungen, Systemzustände, Proxy, SSH, Firewall (UFW), Autostart, Cronjobs, aktuelle Updates, VNC-Status, Chromium-Installation, Welcome-Meldungen, Energiestatus, Logins (SSH/VNC) etc.

Ausführung via:

```bash
sudo bash debug-kiosk.sh
```

---

## Besonderheiten / Sicherheit

- **SSH**: Nach Einrichtung ist ausschließlich ein login per SSH-Key für `kiosk_admin` auf dem gewählten Port erlaubt, Login von root und per Passwort ist deaktiviert. Der private SSH-Key kann während des Setups auf einen sicheren Client-Rechner heruntergeladen werden; zum Schutz bleibt er nur temporär auf dem System und wird auf Wunsch gelöscht.
- **Firewall**: UFW blockt alle eingehenden Verbindungen außer dem gewählten SSH-Port.
- **Sprachlokalisierung**: Systemweite deutsche Sprache (de_DE.UTF-8). Chromium verwendet zusätzliche Flags, um sämtliche Übersetzungshinweise zu unterdrücken:  
  `--lang=de --accept-lang=de-DE,de --disable-translate --disable-features=TranslateUI,Translate --disable-component-extensions-with-background-pages`
- **Autostart & Hardening**: Chromium mit Hardening- und Kiosk-Parameter, keine störenden Dialoge/Popups.
- **Kommunikation via Proxy**: Unterstützung für Firmen-/Unternehmensfirewalls.
- **Reload**: Automatischer Seitenrefresh im eigenen Desktopprozess, störungsfreier Dauerbetrieb, keine Session-Abbrüche.

---

## Dateien

- `setup-kiosk.sh` – Haupt-Setup-Skript (als root ausführen!)
- `anpassen-kioskconfig.sh` – Nachträgliche Anpassung von Webseite, Reload-Intervall, Shutdown-Zeit
- `debug-kiosk.sh` – Systemanalyse und Status-Check

---
