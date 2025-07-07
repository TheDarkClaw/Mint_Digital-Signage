#!/bin/bash

LOGFILE="/tmp/kiosk-debug-$(date +%Y%m%d-%H%M%S).log"
KIOSK_USER="kiosk"
KIOSK_ADM="kiosk_admin"
KIOSK_HOME="/home/${KIOSK_USER}"
SSH_CONFIG="/etc/ssh/sshd_config"
LIGHTDM_CONFIG="/etc/lightdm/lightdm.conf"
VNC_SERVICE="/etc/systemd/system/x11vnc.service"
KIOSK_SCRIPT="${KIOSK_HOME}/start-kiosk.sh"
AUTOSTART="${KIOSK_HOME}/.config/autostart/kiosk.desktop"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

exec > >(tee -a "${LOGFILE}") 2>&1

headline() {
    echo -e "\n==== $1 ===="
}

check_and_log() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}OK:${NC} $2"
    else
        echo -e "${RED}FEHLER/WARNUNG:${NC} $3"
    fi
}

headline "Allgemeines"
date
echo "Hostname: $(hostname)"
echo "IP-Adressen:"
ip -4 -o addr show up scope global | awk '{printf "  %-8s %s\n", $2 ":", $4}'

headline "Benutzer"
id $KIOSK_USER &>/dev/null
check_and_log $? "User '$KIOSK_USER' existiert" "User '$KIOSK_USER' fehlt!"
id $KIOSK_ADM &>/dev/null
check_and_log $? "Admin-User '$KIOSK_ADM' existiert" "Admin-User '$KIOSK_ADM' fehlt!"

headline "Bereiche & Berechtigungen"
ls -ld "${KIOSK_HOME}" 2>/dev/null
if [ -d "${KIOSK_HOME}/.ssh" ]; then ls -l "${KIOSK_HOME}/.ssh"; fi

headline "Webseite/Startskript"
grep -i "^chromium " "${KIOSK_SCRIPT}" 2>/dev/null
if [ $? -ne 0 ]; then echo -e "${YELLOW}Keine Kiosk-Startseite gefunden!${NC}"; fi

headline "Proxy & no_proxy"
for file in ${KIOSK_HOME}/.profile ${KIOSK_HOME}/.bashrc; do
    echo -n "$file:"
    grep -A2 'KIOSK Proxy Einstellungen' $file 2>/dev/null | grep -v '#' || echo " (kein Proxy-Block gesetzt)"
done

headline "SSH-Konfiguration"
grep -Ei '^PasswordAuthentication|^PermitRootLogin|^PubkeyAuthentication|^AllowUsers|^Port' $SSH_CONFIG
sudo ss -ntlp | grep sshd && echo "sshd läuft" || echo "sshd läuft NICHT!"
sudo systemctl status ssh --no-pager

# AllowUsers
grep "^AllowUsers" $SSH_CONFIG | grep -w $KIOSK_ADM &>/dev/null && \
  echo -e "${GREEN}SSH-Zugang für $KIOSK_ADM erlaubt${NC}" || \
  echo -e "${RED}Warnung: SSH login ist evtl. (noch) nicht ausschließlich für $KIOSK_ADM erlaubt!${NC}"

headline "UFW-Firewall Status"
sudo ufw status verbose

headline "Letzte automatische System-Updates"
sudo grep upgrade /var/log/apt/history.log | tail -n 10

headline "Keyring & Welcome"
dpkg -l | grep gnome-keyring && echo -e "${YELLOW}Keyring noch installiert!${NC}" || echo -e "${GREEN}Keyring entfernt${NC}"
ls $KIOSK_HOME/.config/linuxmint/mintwelcome.donotshow > /dev/null 2>&1 && echo "Welcome-Sperre vorhanden" || echo -e "${YELLOW}Willkommensnachricht könnte erscheinen!${NC}"

headline "Bildschirmsperre & DPMS"
echo "desktop.screensaver:"
echo ">lock-enabled:"; sudo -u $KIOSK_USER dbus-launch gsettings get org.cinnamon.desktop.screensaver lock-enabled 2>/dev/null
echo ">dle-activation-enabled:"; sudo -u $KIOSK_USER dbus-launch gsettings get org.cinnamon.desktop.screensaver idle-activation-enabled 2>/dev/null
echo "settings-daemon.plugins.power:"
echo ">sleep-display-ac:"; sudo -u $KIOSK_USER dbus-launch gsettings get org.cinnamon.settings-daemon.plugins.power sleep-display-ac 2>/dev/null
echo ">sleep-inactive-ac-type :"; sudo -u $KIOSK_USER dbus-launch gsettings get org.cinnamon.settings-daemon.plugins.power sleep-inactive-ac-type 2>/dev/null
echo ">sleep-inactive-battery-type:"; sudo -u $KIOSK_USER dbus-launch gsettings get org.cinnamon.settings-daemon.plugins.power sleep-inactive-battery-type 2>/dev/null

headline "Chromium & unclutter installiert?"
which chromium && chromium --version || echo -e "${RED}chromium fehlt!${NC}"
which unclutter && echo "unclutter OK" || echo -e "${RED}unclutter fehlt!${NC}"

headline "VNC"
systemctl is-active x11vnc.service && echo "x11vnc.service läuft" || echo -e "${RED}x11vnc.service läuft nicht!${NC}"
ls -l "${KIOSK_HOME}/.vnc/passwd" 2>/dev/null
[ -f "$VNC_SERVICE" ] && grep ExecStart $VNC_SERVICE
ss -lntp | grep 5900 && echo "VNC Port offen (5900)" || echo -e "${YELLOW}VNC Port 5900 nicht sichtbar/listening${NC}"

headline "LightDM Autologin"
grep -A2 'autologin-user' $LIGHTDM_CONFIG 2>/dev/null

headline "Autostart Kiosk"
ls -l "$AUTOSTART" 2>/dev/null
cat "$AUTOSTART" 2>/dev/null

headline "Update-Manager Autostart für Kiosk-User"

if sudo -u $KIOSK_USER [ -f "$KIOSK_HOME/.config/autostart/mintupdate.desktop" ]; then
    if grep -q 'Hidden=true' "$KIOSK_HOME/.config/autostart/mintupdate.desktop"; then
        echo -e "${GREEN}Update-Manager Autostart ist für $KIOSK_USER wie gewünscht deaktiviert.${NC}"
    else
        echo -e "${YELLOW}Achtung: mintupdate.desktop existiert, aber 'Hidden=true' fehlt.${NC}"
        grep . "$KIOSK_HOME/.config/autostart/mintupdate.desktop"
    fi
else
    echo -e "${YELLOW}Warnung: mintupdate.desktop existiert nicht in Autostart!${NC}"
fi

headline "Cronjob Shutdown"
sudo -u $KIOSK_USER crontab -l 2>/dev/null | grep shutdown && echo "Shutdown-Cronjob vorhanden" || echo -e "${YELLOW}Kein Shutdown-Cronjob beim User!${NC}"

headline "VNC-Logins: Letzte 30 Tage (x11vnc)"

if systemctl is-active --quiet x11vnc.service; then
  sudo journalctl -u x11vnc.service --since "30 days ago" | \
    grep -Ei 'connection from|auth failed|auth ok|password' | tail -n 50
  RC=$?
  if [ $RC -ne 0 ]; then
    echo -e "${YELLOW}Keine VNC-Logins gefunden in den letzten 30 Tagen.${NC}"
  fi
else
  echo -e "${YELLOW}x11vnc.service aktuell nicht aktiv.${NC}"
fi

headline "SSH-Logins: Letzte 30 Tage"

# Erfolgreiche Logins:
echo -e "${GREEN}Erfolgreiche SSH-Logins:${NC}"
sudo journalctl -u ssh --since "30 days ago" | grep 'Accepted' | tail -n 50

# Fehlgeschlagene SSH-Logins:
echo -e "${RED}Fehlgeschlagene SSH-Logins:${NC}"
sudo journalctl -u ssh --since "30 days ago" | grep 'reset' | tail -n 50

headline "Letzte erfolgreichen System-Logins (alle Benutzer)"


echo -e "${GREEN}==== Fertig. Log: ${LOGFILE} ====${NC}"