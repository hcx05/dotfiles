#!/usr/bin/env bash
# VPN status indicator styled after hcx05/ArchDotfiles bar08 ( lock icon).
source "$HOME/.config/rice/theme.conf" 2>/dev/null

ICON_LOCK=$(python3 -c "print(chr(0xF023))")
VPN_IFACE=$(ip -o link show up 2>/dev/null | awk -F': ' '$2 ~ /^(tun|tap|wg|ppp)/{print $2; exit}')

if [ -n "$VPN_IFACE" ]; then
    VPN_IP=$(ip -4 -o addr show dev "$VPN_IFACE" 2>/dev/null | awk '{sub(/\/.*/, "", $4); print $4; exit}')
    echo "%{F${ACCENT:-#FFFFFF}}${ICON_LOCK}%{F-} ${VPN_IP:-$VPN_IFACE}"
else
    echo "%{F${FOREGROUND_ALT:-#8A8A8A}}${ICON_LOCK} --%{F-}"
fi
