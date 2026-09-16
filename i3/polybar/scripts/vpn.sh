#!/usr/bin/env bash
# Shows a shield icon, accent-colored if a VPN tunnel interface (tun*/wg*/ppp*)
# is up, dim if not. Icon token substituted by ~/.config/rice/apply-theme.sh.

source "$HOME/.config/rice/theme.conf" 2>/dev/null

VPN_IFACE=$(ip -o link show up 2>/dev/null | awk -F': ' '$2 ~ /^(tun|tap|wg|ppp)/{print $2; exit}')

if [ -n "$VPN_IFACE" ]; then
    echo "%{F${ACCENT_ALT:-#7EE787}} VPN%{F-}"
else
    echo "%{F${FOREGROUND_ALT:-#6B7789}} --%{F-}"
fi
