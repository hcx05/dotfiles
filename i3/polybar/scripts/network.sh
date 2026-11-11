#!/usr/bin/env bash
# Network connection indicator styled after hcx05/ArchDotfiles:
# wifi icon + SSID, ethernet icon + connection, or Offline.
source "$HOME/.config/rice/theme.conf" 2>/dev/null

ICON_WIFI=$(python3 -c "print(chr(0xF1EB))")      #  fa-wifi
ICON_WIRED=$(python3 -c "print(chr(0xF0200))")    # 󰈀 md-ethernet
ICON_OFFLINE=$(python3 -c "print(chr(0xF05AA))")  # 󰖪 md-wifi_off

line=$(nmcli -t -f TYPE,STATE,CONNECTION device 2>/dev/null \
    | awk -F: '$2=="connected" && ($1=="wifi" || $1=="ethernet") {print; exit}')

type="${line%%:*}"
name="${line#*:*:}"
name="${name//\\:/:}"

case "$type" in
    wifi)     echo "%{F${ACCENT:-#FFFFFF}}${ICON_WIFI}%{F-} ${name}" ;;
    ethernet) echo "%{F${ACCENT:-#FFFFFF}}${ICON_WIRED}%{F-} ${name}" ;;
    *)        echo "%{F${URGENT:-#FF1855}}${ICON_OFFLINE} Offline%{F-}" ;;
esac
