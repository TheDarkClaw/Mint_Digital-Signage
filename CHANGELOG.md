# Changelog – Kiosk Digital Signage Automation

## Version[0.01]

### Benutzer- und Rechteverwaltung

- Automatische Anlage des Users `kiosk` (ohne sudo).
- SSH-Admin-User: `kiosk_admin` ist für die Fernwartung vorgesehen und erhält ein SSH-Key-Login.
- Remotelogin/Geblockt: Kiosk-User darf sich nicht mehr manuell (SSH/Tty) einloggen, Shell ist `/usr/sbin/nologin`.

### SSH-Sicherheit

- Admin-Schlüssel wird beim Setup erzeugt (falls nicht vorhanden).
- SSH-Port kann beim Setup beliebig gesetzt werden.
- Nur der definierte Admin darf per SSH zugreifen (AllowUsers in sshd_config).
- Passwort- und Root-Login sind via SSH deaktiviert.

### Netzwerk/Firewall

- UFW-Firewall installiert & aktiviert.
- Per Default alle eingehenden Verbindungen blockiert, nur der eingestellte SSH-Port erlaubt.
- Proxy-Adresse und no_proxy-Ausnahmen werden beim Setup abgefragt und für den Kiosk-User als Umgebungsvariablen dauerhaft gesetzt.

### Kiosk-Betrieb

- Eingabe der anzuzeigenden Webseite (Pflichtfeld).
- Chromium wird mit Kiosk- und Hardening-Flags gestartet (kein Übersetzungspopup, keine Info-Bubbles etc.).
- Autostart für den Kiosk-User eingerichtet.

### Energiemanagement & Popups

- Cinnamon-/Xorg-Energiesparoptionen, Bildschirmsperre, Standby vollständig deaktiviert.
- Mint-Willkommensbildschirm und Update-Manager sind unterdrückt.
- GNOME-Keyring entfernt (kein Schlüsselbund/Popup).

### Updates und Wartung

- Automatische tägliche (bzw. wöchentliche) Systemupdates per Cron aktiviert.
- Update laufen unsichtbar im Hintergrund (kein Popup).
- Optional wird ein täglicher Shutdown per Cronjob (Zeit frei wählbar) eingerichtet und abgesichert über sudoers.

### Fernwartung und Monitoring

- VNC-Server (x11vnc) installiert, Zugriff nur über SSH-Tunnel (localhost).
- Shutdown-Cron mit explizitem sudoers-Recht für den Kiosk-User.
- Debug-Skript zeigt alle relevanten Logs, Cronjobs, Firewall, Updates, Desktop- und System-Einstellungen an.

---

## Version 0.02

### Chromium: Permanente Deaktivierung des Übersetzen-Popups

- Die Startparameter für Chromium wurden ergänzt um:
  - `--lang=de --accept-lang=de-DE,de`
  - `--disable-translate --disable-features=TranslateUI,Translate`
  - `--disable-component-extensions-with-background-pages`
- Chromium wird jetzt stets mit deutscher Sprache und ohne Übersetzungsangebot gestartet.

### Systemweite Locale-Umgebung auf Deutsch umgestellt

- Im Setup-Skript wird mit `sudo update-locale LANG=de_DE.UTF-8 LANGUAGE=de_DE` die Standardsprache für alle Nutzer gesetzt.
- Dadurch erscheinen auch Systemdialoge und Standardtexte deutsch.

### Reload-Intervall, Webseite und Shutdown-Zeit nachträglich per Anpassungsskript änderbar

- Neues Skript `anpassen-kioskconfig.sh` integriert, um die Kiosk-Webseite, den automatischen Refresh-Intervall (in Minuten) und die tägliche Shutdown-Zeit unkompliziert und mehrfachlauffest zu ändern.

### Automatischer F5-Reload via xdotool

- xdotool wird installiert und ein Autostart-Helper-Skript sorgt dafür, dass die Chromium-Anzeige im gewählten Intervall

## Verison 0.03

### Erweiterte Funktionen aus den Skripten (vollständig & dokumentiert)

- **Anpassungsskript `anpassen-kioskconfig.sh`**
  - Webseite, Reload-Intervall (in Minuten) und tägliche Shutdown-Zeit nachträglich und mehrfachlauffähig editierbar.
  - Entfernen des Shutdown-Jobs per Leereingabe jederzeit möglich.
- **Automatischer Reload der Kiosk-Webseite**
  - Via Hintergrundskript und xdotool wird die Seite im einstellbaren Intervall per F5 aktualisiert.
- **Chromium und System vollautomatisch auf Deutsch, Übersetzungspopups dauerhaft deaktiviert**
  - Startparameter: `--lang=de --accept-lang=de-DE,de --disable-translate --disable-features=TranslateUI,Translate --disable-component-extensions-with-background-pages`
  - Systemweite Locale wird via `update-locale` für alle Nutzer auf Deutsch gesetzt.
- **UFW-Firewall**
  - Noch restriktiver: Beim Setup werden alle bestehenden Allow-Regeln entfernt, nur SSH-Port bleibt erlaubt.
- **SSH Key Management**
  - Private Key wird ausschließlich temporär auf dem Server erzeugt und kann direkt heruntergeladen werden. Nach sicherem Download kann der Schlüssel (empfohlen!) serverseitig gelöscht werden.
  - Passwortöffneter Login für den SSH-Key-Download wird automatisch temporär aktiviert/deaktiviert.
- **Sicherheitsoptimierte Benutzerverwaltung**
  - Der Kiosk-Benutzer hat *keinen* SSH/Shell- oder Sudo-Zugang – das Shell-Login steht auf `/usr/sbin/nologin`.
- **Deinstallation aller welcome- und Schlüsselbund-Komponenten**
  - GNOME-Keyring, Mintwelcome, Mintupdate etc. werden explizit entfernt/deaktiviert (auch im Autostart).
- **Autostart Scripting & First-Login-Setup**
  - Energiespareinstellungen, Bildschirmsperre, Welcome-Dialoge etc. werden automatisiert und dauerhaft deaktiviert.
- **VNC-Fernwartung**
  - Passwort und Service werden konsequent (via systemd) gesichert und passwortgeschützt, VNC nur auf localhost sichtbar.
- **Umfangreiche Diagnosemöglichkeiten**
  - Siehe `debug-kiosk.sh`: Check von Logs, Cronjobs, Firewall, Update-Historie, Desktopsetting, Login-Versuchen etc.

---

### Changelog-Eintrag für die aktuellen Anpassungen

**[07.07.2025]**

- README umfassend erweitert und detailliert um alle realisierten Features aus den Setup-, Debug- und Anpassungsskripten ergänzt (insb. Nachkonfiguration Reload/Webseite/Shutdown, SSH-Key Management, Kiosk-Hardening).
- Changelog ergänzt: Detaillierte Auflistung aller Features und Sicherheitsmaßnahmen laut aktuellem Entwicklungsstand.
- Nachträgliche Konfigurierbarkeit (Seite, Reload, Shutdown) über eigenes Script (`anpassen-kioskconfig.sh`).
- Debug-Komplettscript (`debug-kiosk.sh`) dokumentiert.
- Doku zu Proxy-Unterstützung (inkl. no_proxy) und deutscher Sprache erweitert.

---
