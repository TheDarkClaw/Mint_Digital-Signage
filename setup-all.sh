#!/bin/bash

set -e
read -t 10 -p "Debugging aktivieren (set -x)? (j/N) " DEBUGGING || \
    echo "Keine Eingabe nach 10 Sekunden – Debugging bleibt aus."

    [[ "$DEBUGGING" =~ ^[Jj]$ ]] && set -x  # set -x nur aktivieren, wenn explizit bestätigt


xset s off
xset s noblank
xset -dpms

KIOSK_USER="kiosk"
KIOSK_PASS="kiosk"
KIOSK_ADM="kiosk_admin"
KIOSK_HOME="/home/$KIOSK_USER"
KIOSK_SCRIPT="$KIOSK_HOME/start-kiosk.sh"
RELOAD_SCRIPT="$KIOSK_HOME/refresh-chromium.sh"
KIOSK_DESKTOP="$KIOSK_HOME/.config/autostart/kiosk.desktop"
KIOSK_VNC_PASS="$KIOSK_HOME/.vnc/passwd"
KIOSK_VNC_PORT=5900
ADMIN_KEYFILE="/home/$KIOSK_ADM/.ssh/id_ed25519"
ADMIN_AUTHKEYFILE="/home/$KIOSK_ADM/.ssh/authorized_keys"
LIGHTDM_CONF_DIR="/etc/lightdm/lightdm.conf.d"
LIGHTDM_AUTLOGIN_FILE="$LIGHTDM_CONF_DIR/50-autologin.conf"

sudo update-locale LANG=de_DE.UTF-8 LANGUAGE=de_DE

# Webadresse abfragen
KIOSK_URL=""
while [ -z "$KIOSK_URL" ]; do
  echo "Welche Webseite soll im Kiosk-Modus angezeigt werden (z.B. https://mein.board)?"
  read KIOSK_URL
  if [ -z "$KIOSK_URL" ]; then
    echo "Bitte eine gültige URL eingeben!"
  fi
done

# Intervall für Seiten-Reload abfragen
echo "Bitte Intervall für Seiten-Reload in Minuten angeben (z.B. 10 für alle 10 Minuten):"
read RELOAD_MINUTES
RELOAD_MINUTES=${RELOAD_MINUTES:-10}
RELOAD_INTERVAL=$((RELOAD_MINUTES * 60))

# Proxy abfragen
echo "Proxy (Format: http://benutzer:pass@proxyhost:port oder leer für keinen Proxy):"
read KIOSK_PROXY

echo "Proxy-Ausnahmen? Kommagetrennt (z.B. 127.0.0.1,localhost,.meinlan.net), leer lassen für keine Ausnahmen:"
read KIOSK_NOPROXY

echo "Welcher SSH-Port soll verwendet werden? (Standard: 22)"
read SSH_PORT
SSH_PORT=${SSH_PORT:-22}




# === Proxy-Abfrage in globalen Konfigurationsdateien ===
PROXY_FOUND=0
for file in /etc/environment /etc/profile /etc/bash.bashrc; do
    if grep -q -E "(_proxy|_PROXY)=" "$file" 2>/dev/null; then
        echo "Proxy-Eintrag gefunden in: $file"
        PROXY_FOUND=1
    fi
done

if [[ "$PROXY_FOUND" == "1" ]]; then
    # === Benutzerabfrage ===
    while true; do
        read -p "Bereits Proxy-Einträge gefunden.Trozdem überschreiben? (j/n): " antwort
        case "$antwort" in
            [jJ])
                if [ -n "$KIOSK_PROXY" ]; then
                    echo "==== Proxy global konfigurieren ===="
                    
                    # 1. Systemweite Umgebungsvariablen in /etc/environment
                    # Erst alte Einträge entfernen
                    sudo sed -i '/^http_proxy=/d' /etc/environment
                    sudo sed -i '/^https_proxy=/d' /etc/environment
                    sudo sed -i '/^no_proxy=/d' /etc/environment
                    sudo sed -i '/^HTTP_PROXY=/d' /etc/environment
                    sudo sed -i '/^HTTPS_PROXY=/d' /etc/environment
                    sudo sed -i '/^NO_PROXY=/d' /etc/environment
                    
                    # Dann neue hinzufügen (beide Schreibweisen für Kompatibilität)
                    {
                        echo "http_proxy=\"$KIOSK_PROXY\""
                        echo "https_proxy=\"$KIOSK_PROXY\""
                        echo "HTTP_PROXY=\"$KIOSK_PROXY\""
                        echo "HTTPS_PROXY=\"$KIOSK_PROXY\""
                        [ -n "$KIOSK_NOPROXY" ] && echo "no_proxy=\"$KIOSK_NOPROXY\""
                        [ -n "$KIOSK_NOPROXY" ] && echo "NO_PROXY=\"$KIOSK_NOPROXY\""
                    } | sudo tee -a /etc/environment > /dev/null
                    
                    # 2. APT-spezifische Proxy-Konfiguration
                    sudo tee /etc/apt/apt.conf.d/95proxy > /dev/null <<EOF
Acquire::http::Proxy "$KIOSK_PROXY";
Acquire::https::Proxy "$KIOSK_PROXY";
EOF

                    # Proxy für aktuelle Session aktivieren

                    # Für diese Shell-Session
                    export http_proxy="$KIOSK_PROXY"
                    export https_proxy="$KIOSK_PROXY"
                    export HTTP_PROXY="$KIOSK_PROXY"
                    export HTTPS_PROXY="$KIOSK_PROXY"
                    if [ -n "$KIOSK_NOPROXY" ]; then
                        export no_proxy="$KIOSK_NOPROXY"
                        export NO_PROXY="$KIOSK_NOPROXY"
                    fi
                    
                    echo "Proxy für diese Installation aktiviert: $KIOSK_PROXY"

                    echo "==== Teste Proxy-Verbindung ===="
                    if sudo apt update; then
                        echo "Proxy funktioniert für APT!"
                    else
                        echo "WARNUNG: APT update fehlgeschlagen - Proxy-Einstellungen prüfen!"
                        echo "Trotzdem fortfahren? (j/N)"
                        read CONTINUE
                        if [[ ! "$CONTINUE" =~ ^[Jj]$ ]]; then
                            exit 1
                        fi
                    fi
                fi
                break
                ;;
            [nN])
                echo "Proxy-Einträge bleiben erhalten."
                break
                ;;
            *)
                echo "Bitte 'j' für Ja oder 'n' für Nein eingeben."
                ;;
        esac
    done
fi



# HIER: System aktualisieren
echo "==== System aktualisieren ===="
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y
sudo apt clean

echo "==== Kiosk-Benutzer anlegen (falls nicht existierend) ===="
if ! id "$KIOSK_USER" &>/dev/null; then
    sudo adduser --disabled-password --gecos "" $KIOSK_USER
    echo "$KIOSK_USER:$KIOSK_PASS" | sudo chpasswd
fi
sudo usermod -s /bin/bash $KIOSK_USER
sudo deluser $KIOSK_USER sudo || true
sudo deluser $KIOSK_USER adm || true
sudo chmod 700 $KIOSK_HOME

echo "==== Richtigen SSH-Server installieren und konfigurieren ===="
sudo apt update
sudo apt install -y openssh-server

sudo systemctl enable ssh
sudo systemctl restart ssh
sudo systemctl reload ssh || true

# SSH-Konfiguration

sudo sed -i '/^Port /d' /etc/ssh/sshd_config
echo "Port $SSH_PORT" | sudo tee -a /etc/ssh/sshd_config > /dev/null

sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

sudo sed -i '/^AllowUsers/d' /etc/ssh/sshd_config
echo "AllowUsers $KIOSK_ADM" | sudo tee -a /etc/ssh/sshd_config
sudo systemctl daemon-reload 
sudo systemctl restart ssh

echo "==== Firewall (UFW) aktivieren: Nur SSH-Port $SSH_PORT offen ===="
sudo apt-get install -y ufw

# Deaktiviere alle bestehenden Allow-Regeln und setze restriktiv alles auf "deny"
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow $SSH_PORT/tcp
sudo ufw enable
sudo ufw status verbose

echo "==== Admin SSH-Schlüssel erzeugen (falls noch nicht vorhanden) ===="
if [ ! -s "$ADMIN_AUTHKEYFILE" ]; then
    # SSH-Verzeichnis erstellen
    sudo -u $KIOSK_ADM mkdir -p "/home/$KIOSK_ADM/.ssh"
    
    # Passwort für den SSH-Key abfragen
    echo "Bitte Passwort für den SSH-Key eingeben:"
    read -s SSH_KEY_PASSWORD
    echo
    
    # SSH-Schlüssel mit Passwort generieren
    sudo -u $KIOSK_ADM ssh-keygen -t ed25519 -f "$ADMIN_KEYFILE" -N "$SSH_KEY_PASSWORD"
    
    # WICHTIG: Passwort-Variable sofort löschen
    unset SSH_KEY_PASSWORD
    
    # Public Key zu authorized_keys hinzufügen 
    if ! sudo -u $KIOSK_ADM grep -q "$(sudo cat "$ADMIN_KEYFILE.pub")" "$ADMIN_AUTHKEYFILE" 2>/dev/null; then
        sudo -u $KIOSK_ADM cat "$ADMIN_KEYFILE.pub" >> "$ADMIN_AUTHKEYFILE"
    fi
    
    # Berechtigungen setzen
    sudo -u $KIOSK_ADM chmod 600 "$ADMIN_AUTHKEYFILE" 2>/dev/null || true
    sudo -u $KIOSK_ADM chmod 600 "$ADMIN_KEYFILE"
    sudo -u $KIOSK_ADM chmod 644 "$ADMIN_KEYFILE.pub"
    sudo -u $KIOSK_ADM chmod 700 "/home/$KIOSK_ADM/.ssh"
    
    echo "SSH-Keys erfolgreich erstellt!"
    echo "Public Key:"
    sudo cat "$ADMIN_KEYFILE.pub"
    echo
    
    # SICHERE Download-Methode mit Pause
    sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config #Temp Download-Freigabe über UserPW
    sudo systemctl daemon-reload 
    sudo systemctl reload ssh || sudo systemctl restart ssh
    
    echo "==== Private Key Download ===="
    echo -e "${RED}WICHTIG: Führe den folgenden Befehl auf dem CLIENT-Computer aus:"
    echo
    echo "LINUX: scp -P $SSH_PORT $KIOSK_ADM@$(hostname -I | awk '{print $1}'):$ADMIN_KEYFILE ~/.ssh/$(hostname -s)_$KIOSK_ADM"
    echo "WINDOWS: scp -P $SSH_PORT $KIOSK_ADM@$(hostname -I | awk '{print $1}'):$ADMIN_KEYFILE \"\$env:USERPROFILE\.ssh\\$(hostname -s)_$KIOSK_ADM\""
    echo
    echo "LINUX: chmod 600 ~/.ssh/$(hostname -s)_$KIOSK_ADM"
    echo
    echo "Nach dem Setup kann man sich dann verbinden mit:"
    echo "LINUX: ssh -L $KIOSK_VNC_PORT:localhost:$KIOSK_VNC_PORT -p $SSH_PORT kiosk_admin@$(hostname -I | awk '{print $1}') -i ~/.ssh/$(hostname -s)_$KIOSK_ADM"
    echo "WINDOWS: ssh -L $KIOSK_VNC_PORT:localhost:$KIOSK_VNC_PORT -p $SSH_PORT kiosk_admin@$(hostname -I | awk '{print $1}') -i \"\$env:USERPROFILE\.ssh\\$(hostname -s)_$KIOSK_ADM\""
    echo
    echo "=========================================="
    echo "Führe den download Befehl JETZT aus und drücke dann ENTER um fortzufahren..."
    read -p "Drücke ENTER wenn der Key erfolgreich heruntergeladen wurde: "

    sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config #Temp Download-Freigabe über UserPW aufheben
    sudo systemctl daemon-reload 
    sudo systemctl reload ssh || sudo systemctl restart ssh
    
    # Frage nach dem Löschen des Private Keys
    echo
    echo "SICHERHEITSFRAGE:"
    echo "Soll der private Schlüssel vom Server gelöscht werden?"
    echo -e "${RED}WARNUNG: Nach dem Löschen ist keine SSH-Verbindung mit dem UserPW mehr möglich!"
    echo -e "${RED}WARNUNG: NUR löschen wenn der Private-Key sicher heruntergeladen wurde."
    echo
    while true; do
        read -p "Private Key vom Server löschen? [j/N]: " DELETE_KEY
        case $DELETE_KEY in
            [Jj]|[Jj][Aa])
                echo "Lösche private Key vom Server..."
                sudo rm -f "$ADMIN_KEYFILE"
                echo "Private Key wurde vom Server gelöscht."
                echo "WICHTIG: Sichere den lokalen Key!"
                break
                ;;
            [Nn]|[Nn][Ee][Ii][Nn]|"")
                echo "Private Key bleibt auf dem Server."
                echo -e "${RED}EMPFEHLUNG: NUR BEI TESTSTELLUNG ODER DEBUGGING NICHT LÖSCHEN."
                break
                ;;
            *)
                echo "Bitte antworte mit 'j' für Ja oder 'n' für Nein."
                ;;
        esac
    done
    
else
    echo "Admin-Schlüssel existiert bereits:"
    sudo cat "$ADMIN_KEYFILE.pub"
    echo
    
    if [ -f "$ADMIN_KEYFILE" ]; then
        sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config #Temp Download-Freigabe über UserPW
        sudo systemctl daemon-reload 
        sudo systemctl reload ssh || sudo systemctl restart ssh
        echo "Private Key ist noch auf dem Server verfügbar."
        echo "Zum erneuten Download verwende:"
        echo "LINUX: scp -P $SSH_PORT $KIOSK_ADM@$(hostname -I | awk '{print $1}'):$ADMIN_KEYFILE ~/.ssh/$(hostname -s)_$KIOSK_ADM"
        echo "WINDOWS: scp -P $SSH_PORT $KIOSK_ADM@$(hostname -I | awk '{print $1}'):$ADMIN_KEYFILE \"\$env:USERPROFILE\.ssh\\$(hostname -s)_$KIOSK_ADM\""
        echo
        echo "=========================================="
        echo "Führe den download Befehl JETZT aus und drücke dann ENTER um fortzufahren..."
        read -p "Drücke ENTER wenn der Key erfolgreich heruntergeladen wurde: "
        sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config #Temp Download-Freigabe über UserPW aufheben
        sudo systemctl daemon-reload 
        sudo systemctl reload ssh || sudo systemctl restart ssh
        
        # Frage nach dem Löschen (auch bei existierenden Keys)
        echo
        echo "SICHERHEITSFRAGE:"
        echo "Soll der private Schlüssel vom Server gelöscht werden?"
        echo -e "${RED}WARNUNG: Nach dem Löschen ist keine SSH-Verbindung mit dem UserPW mehr möglich!"
        echo -e "${RED}WARNUNG: NUR löschen wenn der Private-Key sicher heruntergeladen wurde."
        echo -e "${RED}WARNUNG: NUR nicht Löschen auf Teststellungen oder beim Debugging!."
        echo
        while true; do
            read -p "Private Key vom Server löschen? [j/N]: " DELETE_KEY
            case $DELETE_KEY in
                [Jj]|[Jj][Aa])
                    echo "Lösche private Key vom Server..."
                    sudo rm -f "$ADMIN_KEYFILE"
                    echo "Private Key wurde vom Server gelöscht."
                    break
                    ;;
                [Nn]|[Nn][Ee][Ii][Nn]|"")
                    echo "Private Key bleibt auf dem Server."
                    break
                    ;;
                *)
                    echo "Bitte antworte mit 'j' für Ja oder 'n' für Nein."
                    ;;
            esac
        done
    else
        echo "Private Key wurde bereits vom Server gelöscht."
        echo "Verwende den lokalen Private-Key für die Verbindung."
    fi
fi

# Sicherstellen, dass sensitive Variablen gelöscht sind
unset SSH_KEY_PASSWORD 2>/dev/null || true
unset DELETE_KEY 2>/dev/null || true


echo "==== Automatische tägliche System-Updates aktivieren ===="
# 1: Globale Updates
sudo apt-get update
sudo apt-get install -y unattended-upgrades apt-listchanges

# 2: unattended-upgrades aktivieren
sudo dpkg-reconfigure --priority=low unattended-upgrades

# 3: Updates und Security (falls auskommentiert) aktivieren
sudo sed -i 's#^//\(.*-updates";\)#\1#' /etc/apt/apt.conf.d/50unattended-upgrades
sudo sed -i 's#^//\(.*-security";\)#\1#' /etc/apt/apt.conf.d/50unattended-upgrades

# 4: Zeiten berechnen
UPDATE_TIME=$(date --date="${SHUTDOWN_TIME} 1 hour ago" +%H:%M)
UPDATE_HOUR=$(echo $UPDATE_TIME | cut -d: -f1)
UPDATE_MIN=$(echo $UPDATE_TIME | cut -d: -f2)

echo "Automatische Updates werden jetzt täglich um $UPDATE_TIME Uhr ausgelöst (1 Stunde vor Shutdown $SHUTDOWN_TIME)"

# 5: Systemd-Timer/Service einrichten (wird bei jedem Lauf überschrieben = mehrfachlauffähig!)
SERVICE_FILE=/etc/systemd/system/unattended-upgrades-manual.service
TIMER_FILE=/etc/systemd/system/unattended-upgrades-manual.timer

# Service für einmaligen Trigger
sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=Manuelles Auslösen von unattended-upgrades

[Service]
Type=oneshot
ExecStart=/usr/bin/flock -n /var/lock/unattended_upgrade_manual.lock /usr/bin/unattended-upgrade -d
EOF

# Timer (Zeit dynamisch per Skript gesetzt!)
sudo bash -c "cat > $TIMER_FILE" <<EOF
[Unit]
Description=Täglicher Trigger für unattended-upgrades (1 Stunde vor Shutdown)

[Timer]
OnCalendar=*-*-* ${UPDATE_HOUR}:${UPDATE_MIN}:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Schritt 6: Timer aktivieren/updaten (mehrfachlauffähig)
sudo systemctl daemon-reload
sudo systemctl enable --now unattended-upgrades-manual.timer

# Log-Hinweis
echo "Logs: /var/log/unattended-upgrades/ (oder /var/log/unattended-upgrades/manual-trigger.log für den flock-Job)"

echo "==== Willkommensnachricht für Kiosk-User abschalten ===="
sudo -u $KIOSK_USER mkdir -p $KIOSK_HOME/.config/linuxmint
sudo -u $KIOSK_USER touch $KIOSK_HOME/.config/linuxmint/mintwelcome.donotshow

echo "==== Gnome Schlüsselbund deinstallieren ===="
sudo apt purge -y gnome-keyring seahorse

echo "==== Mint Update Manager für Kiosk-User abschalten ===="
# Für Linux Mint
sudo -u $KIOSK_USER mkdir -p $KIOSK_HOME/.config/linuxmint
sudo -u $KIOSK_USER touch $KIOSK_HOME/.config/linuxmint/mintwelcome.donotshow

# Für alle möglichen Welcome-Screens
sudo -u $KIOSK_USER mkdir -p $KIOSK_HOME/.config/autostart

# Deaktiviere verschiedene Welcome-Anwendungen
for app in "mintupdate" "mintupdate-launcher" "mintwelcome" "update-manager" "software-updater" "ubuntu-advantage-notification"; do
    sudo -u $KIOSK_USER tee "$KIOSK_HOME/.config/autostart/${app}.desktop" > /dev/null <<EOF
[Desktop Entry]
Type=Application
Name=${app}
Exec=/bin/true
Hidden=true
NoDisplay=true
X-GNOME-Autostart-enabled=false
EOF
done

echo "==== Bildschirmsperre und Anzeige-Timeouts für Kiosk-User deaktivieren ===="
# Erstelle ein einmaliges Setup-Skript das beim ersten Login ausgeführt wird
sudo tee "$KIOSK_HOME/first-login-setup.sh" > /dev/null <<'EOF'
#!/bin/bash
# Warten bis X11-Session bereit ist
sleep 5

# Bildschirmsperre deaktivieren
gsettings set org.cinnamon.desktop.screensaver lock-enabled false
gsettings set org.cinnamon.desktop.screensaver idle-activation-enabled false

# Anzeige-Timeouts deaktivieren
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-display-ac 0
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-ac-timeout 0

# Dieses Skript nach der Ausführung löschen
rm -f "$HOME/first-login-setup.sh"
rm -f "$HOME/.config/autostart/first-login-setup.desktop"
touch "$HOME/.kiosk_initialized"
EOF

sudo chmod +x "$KIOSK_HOME/first-login-setup.sh"
sudo chown $KIOSK_USER:$KIOSK_USER "$KIOSK_HOME/first-login-setup.sh"

# Autostart-Eintrag für einmaliges Setup
sudo tee "$KIOSK_HOME/.config/autostart/first-login-setup.desktop" > /dev/null <<EOF
[Desktop Entry]
Type=Application
Exec=$KIOSK_HOME/first-login-setup.sh
Hidden=false
X-GNOME-Autostart-enabled=true
Name=First Login Setup
Comment=Configure system settings on first login
EOF

sudo chown $KIOSK_USER:$KIOSK_USER "$KIOSK_HOME/.config/autostart/first-login-setup.desktop"

echo "==== Chromium und unclutter installieren ===="
sudo apt install -y chromium unclutter x11vnc xdotool
sudo rm -rf /home/kiosk/.config/chromium

echo "==== Kiosk-Startskript schreiben ===="
sudo tee "$KIOSK_SCRIPT" > /dev/null <<EOF
#!/bin/bash
for cmd in chromium unclutter; do
    if ! command -v \$cmd &>/dev/null; then
        echo "Error: \$cmd is not installed!" >&2
        exit 1
    fi
done
unclutter -idle 10 &
killall chromium &>/dev/null
sleep 2
chromium --kiosk --noerrdialogs --disable-infobars --incognito --lang=de --accept-lang=de-DE,de --disable-translate --disable-features=TranslateUI,Translate --no-first-run --fast --disable-software-rasterizer --disable-pinch --overscroll-history-navigation=0 --no-default-browser-check $KIOSK_URL &
EOF

sudo chown $KIOSK_USER:$KIOSK_USER "$KIOSK_SCRIPT"
sudo chmod +x "$KIOSK_SCRIPT"

sudo tee "$RELOAD_SCRIPT" > /dev/null <<EOF
#!/bin/bash
# Warte bis Chromium läuft
while ! pgrep -x "chromium" > /dev/null; do
    sleep 2
done

# Dann starte den Reload-Loop
while true; do
    sleep $RELOAD_INTERVAL
    WINID=\$(xdotool search --onlyvisible --class 'chromium' | head -n1)
    if [ -n "\$WINID" ]; then
        xdotool windowactivate "\$WINID"
        xdotool key --window "\$WINID" --clearmodifiers F5
    fi
done
EOF

sudo chmod +x "$RELOAD_SCRIPT"
sudo chown $KIOSK_USER:$KIOSK_USER "$RELOAD_SCRIPT"

echo "==== Kiosk-Launcher (intelligenter Starter) schreiben ===="
sudo tee "$KIOSK_HOME/kiosk-launcher.sh" > /dev/null <<'EOF'
#!/bin/bash

# Warte auf X11/Display
while ! xset q &>/dev/null; do
    sleep 0.5
done

# Warte auf Window Manager (Cinnamon)
while ! pgrep -x "cinnamon" > /dev/null; do
    sleep 0.5
done

# Kurze zusätzliche Stabilisierungszeit nur beim ersten Start
if [ ! -f "$HOME/.kiosk_initialized" ]; then
    sleep 2  # Nur 2 Sekunden für gsettings
    touch "$HOME/.kiosk_initialized"
fi

# Starte Kiosk
exec $HOME/start-kiosk.sh
EOF

sudo chmod +x "$KIOSK_HOME/kiosk-launcher.sh"
sudo chown $KIOSK_USER:$KIOSK_USER "$KIOSK_HOME/kiosk-launcher.sh"

echo "==== Autostart für Kiosk-User ===="
sudo -u $KIOSK_USER mkdir -p $KIOSK_HOME/.config/autostart

# 1. Zuerst das First-Login-Setup (wird automatisch gelöscht)
# (bereits oben erstellt)

# 2. Dann das Update-Manager-Deaktivierung
sudo -u $KIOSK_USER tee "$KIOSK_HOME/.config/autostart/mintupdate.desktop" > /dev/null <<EOF
[Desktop Entry]
Type=Application
Name=Update Manager
Comment=Update Manager
Exec=/usr/bin/mintupdate
Icon=mintupdate
Hidden=true
NoDisplay=true
X-GNOME-Autostart-enabled=false
EOF

# 3. Dann das Kiosk-Skript 
sudo tee "$KIOSK_DESKTOP" > /dev/null <<EOF
[Desktop Entry]
Type=Application
Exec=$KIOSK_HOME/kiosk-launcher.sh
Hidden=false
X-GNOME-Autostart-enabled=true
Name=Kiosk Mode
Comment=Start Kiosk Mode
EOF
sudo chown $KIOSK_USER:$KIOSK_USER "$KIOSK_DESKTOP"


# 4. Reload-Skript (wartet selbst auf Chromium)
sudo tee "$KIOSK_HOME/.config/autostart/refresh-chromium.desktop" > /dev/null <<EOF
[Desktop Entry]
Type=Application
Exec=$RELOAD_SCRIPT
Hidden=false
X-GNOME-Autostart-enabled=true
Name=Chromium Auto-Reload
Comment=Refresh Chromium periodically
EOF
sudo chown $KIOSK_USER:$KIOSK_USER "$KIOSK_HOME/.config/autostart/refresh-chromium.desktop"

echo "==== LightDM Autologin konfigurieren ===="

# Verzeichnis anlegen, falls es fehlt
if [ ! -d "$LIGHTDM_CONF_DIR" ]; then
    sudo mkdir -p "$LIGHTDM_CONF_DIR"
fi

# Autologin-Config mit der gewünschten Variable immer überschreiben
sudo bash -c "cat > '$LIGHTDM_AUTLOGIN_FILE' <<EOF
[Seat:*]
autologin-user=$KIOSK_USER
autologin-user-timeout=0
EOF"

echo "==== VNC Passwort und Service ===="
# Interaktives Passwort setzen
echo "Bitte VNC-Passwort setzen (wird nicht angezeigt):"
read -s VNC_PASSWORD
sudo -u $KIOSK_USER mkdir -p $KIOSK_HOME/.vnc
sudo -u $KIOSK_USER x11vnc -storepasswd "$VNC_PASSWORD" "$KIOSK_VNC_PASS"
unset VNC_PASSWORD 2>/dev/null || true
sudo chmod 600 "$KIOSK_VNC_PASS"
sudo chown $KIOSK_USER:$KIOSK_USER "$KIOSK_VNC_PASS"

sudo tee /etc/systemd/system/x11vnc.service > /dev/null <<EOF
[Unit]
Description=VNC Server for Signage-Kiosk
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=$KIOSK_USER
ExecStart=/usr/bin/x11vnc -display :0 -auth guess -forever -rfbport $KIOSK_VNC_PORT -rfbauth $KIOSK_VNC_PASS -shared -localhost
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable x11vnc.service
sudo systemctl restart x11vnc.service

echo "==== Täglicher Shutdown per Cron ===="
echo "Bitte Uhrzeit für täglichen Shutdown im Format HH:MM angeben (z.B. 23:30):"
read SHUTDOWN_TIME

if [ -n "$SHUTDOWN_TIME" ]; then
  SHUTDOWN_HOUR=$(echo "$SHUTDOWN_TIME" | cut -d: -f1)
  SHUTDOWN_MIN=$(echo "$SHUTDOWN_TIME" | cut -d: -f2)

  sudo tee /etc/sudoers.d/kiosk_shutdown > /dev/null <<EOF
$KIOSK_USER ALL=NOPASSWD: /sbin/shutdown
EOF
  sudo chmod 440 /etc/sudoers.d/kiosk_shutdown

  TMP_CRON=$(mktemp)
  sudo -u $KIOSK_USER crontab -l 2>/dev/null | grep -v '/sbin/shutdown -h now' > "$TMP_CRON" || true
  echo "$SHUTDOWN_MIN $SHUTDOWN_HOUR * * * /usr/bin/sudo /sbin/shutdown -h now" >> "$TMP_CRON"
  sudo chown $KIOSK_USER:$KIOSK_USER "$TMP_CRON"
  sudo -u $KIOSK_USER crontab "$TMP_CRON"
  rm "$TMP_CRON"

  echo "Der PC fährt ab jetzt täglich um $SHUTDOWN_TIME automatisch herunter."
else
  echo "Der PC fährt nicht täglich automatisch herunter."
fi

# Remotelogins für den Kiosk User zu sperren
sudo usermod -s /usr/sbin/nologin $KIOSK_USER

echo "==== Einrichtung abgeschlossen! ====
- Kiosk-Modus aktiv. Benutzer: $KIOSK_USER
- Admin: $KIOSK_ADM (SSH-Key bereits erstellt und als Zugangsschlüssel hinterlegt)
- SSH-Zugang nur via Key!
- VNC läuft lokal (Port $KIOSK_VNC_PORT), erreichbar per SSH-Tunnel
 
Um dich remote zu verbinden:
1. Mit SSH als $KIOSK_ADM
   bzw. tunnele VNC so:
   ssh -L 5900:localhost:5900 -p $SSH_PORT $KIOSK_ADM@<hostname> -i [Pfad zum Private Keyfile]
   Dann:
   vncviewer localhost:5900

Öffentlicher SSH-Key für $KIOSK_ADM:
================================================
"
sudo cat "$ADMIN_KEYFILE.pub"
echo "
================================================

Jetzt bitte testen und gegebenenfalls den SSH-Key dort nachtragen, von wo aus du dich verbinden möchtest!
"

echo "Bitte 'sudo reboot' zum Test ausführen, damit alles wie gewünscht startet."
