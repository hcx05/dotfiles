#!/usr/bin/env bash
# Connection indicator for bar/monobar: wifi icon + SSID, ethernet icon +
# connection name, or a dimmed "offline". Reads NetworkManager via nmcli
# (nm-applet/NM already run in this session -- see `dex -a` in i3/config).
# Icons are built from verified codepoints with chr(), same as the other
# scripts here -- don't paste raw glyphs.

source "$HOME/.config/rice/theme.conf" 2>/dev/null

ICON_WIFI=$(python3 -c "print(chr(0xF1EB))")      # fa-wifi
ICON_WIRED=$(python3 -c "print(chr(0xF0200))")    # md-ethernet
ICON_OFFLINE=$(python3 -c "print(chr(0xF05AA))")  # md-wifi_off (same as netspeed.sh)

# first connected device, e.g. "wifi:connected:Catus"
line=$(nmcli -t -f TYPE,STATE,CONNECTION device 2>/dev/null \
    | awk -F: '$2=="connected" && ($1=="wifi" || $1=="ethernet") {print; exit}')

type="${line%%:*}"
name="${line#*:*:}"
name="${name//\\:/:}"   # nmcli -t escapes ":" inside names as "\:"

case "$type" in
    wifi)     echo "%{F${FOREGROUND_ALT:-#8A8A8A}}${ICON_WIFI}%{F-} ${name}" ;;
    ethernet) echo "%{F${FOREGROUND_ALT:-#8A8A8A}}${ICON_WIRED}%{F-} ${name}" ;;
    *)        echo "%{F${FOREGROUND_ALT:-#8A8A8A}}${ICON_OFFLINE} offline%{F-}" ;;
esac
