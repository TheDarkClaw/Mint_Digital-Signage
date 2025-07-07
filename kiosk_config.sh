#!/bin/bash
set -e

KIOSK_USER="kiosk"
KIOSK_HOME="/home/$KIOSK_USER"
KIOSK_SCRIPT="$KIOSK_HOME/start-kiosk.sh"
RELOAD_SCRIPT="$KIOSK_HOME/refresh-chromium.sh"

### --- 1. Webseite neu setzen ---
echo "Bitte neue Webseite für den Kiosk-Modus eingeben (z.B. https://beispiel.de):"
read NEW_URL
if [ -n "$NEW_URL" ]; then
    sudo sed -i "s|chromium .* --no-default-browser-check .*|chromium --kiosk --noerrdialogs --disable-infobars --incognito --lang=de --accept-lang=de-DE,de --disable-translate --disable-features=TranslateUI,Translate --no-first-run --fast --disable-software-rasterizer --disable-pinch --overscroll-history-navigation=0 --no-default-browser-check $NEW_URL \&|" "$KIOSK_SCRIPT"
    echo "Webseite aktualisiert."
fi

### --- 2. Reload-Intervall neu setzen ---
echo "Bitte neues Reload-Intervall in Minuten angeben (z.B. 10):"
read NEW_INTERVAL_MIN
if [ -n "$NEW_INTERVAL_MIN" ]; then
    NEW_INTERVAL_SEC=$((NEW_INTERVAL_MIN * 60))
    sudo sed -i "s/^ *sleep [0-9]\+ */    sleep $NEW_INTERVAL_SEC/" "$RELOAD_SCRIPT"
    echo "Reload-Intervall aktualisiert."
fi

### --- 3. Shutdown-Zeit anpassen ---
echo "Bitte neue Uhrzeit für täglichen Shutdown im Format HH:MM angeben (leer = kein Shutdown):"
read NEW_SHUTDOWN
if [ -n "$NEW_SHUTDOWN" ]; then
    SHUT_HOUR=$(echo "$NEW_SHUTDOWN" | cut -d: -f1)
    SHUT_MIN=$(echo "$NEW_SHUTDOWN" | cut -d: -f2)
    TMP_CRON=$(mktemp)
    sudo -u $KIOSK_USER crontab -l 2>/dev/null | grep -v '/sbin/shutdown -h now' > "$TMP_CRON" || true
    echo "$SHUT_MIN $SHUT_HOUR * * * /usr/bin/sudo /sbin/shutdown -h now" >> "$TMP_CRON"
    sudo chown $KIOSK_USER:$KIOSK_USER "$TMP_CRON"
    sudo -u $KIOSK_USER crontab "$TMP_CRON"
    rm "$TMP_CRON"
    echo "Shutdown-Zeit aktualisiert."
else
    # Shutdown aus crontab entfernen
    TMP_CRON=$(mktemp)
    sudo -u $KIOSK_USER crontab -l 2>/dev/null | grep -v '/sbin/shutdown -h now' > "$TMP_CRON" || true
    sudo chown $KIOSK_USER:$KIOSK_USER "$TMP_CRON"
    sudo -u $KIOSK_USER crontab "$TMP_CRON"
    rm "$TMP_CRON"
    echo "Shutdown-Zeit deaktiviert."
fi

echo "Anpassungen erfolgt. Bitte ggf. Kiosk neu starten, damit Änderungen wirksam werden."