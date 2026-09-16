#!/usr/bin/env bash
# Prints download/upload rate for the default route interface.
# Icon tokens (@ICO_*@) are substituted with real glyphs by
# ~/.config/rice/apply-theme.sh -- do not paste raw icon glyphs here.

IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}')
if [ -z "$IFACE" ]; then
    IFACE=$(ip -o link show up 2>/dev/null | awk -F': ' '$2!="lo"{print $2; exit}')
fi

if [ -z "$IFACE" ] || [ ! -d "/sys/class/net/$IFACE" ]; then
    echo "󰖪 --"
    exit 0
fi

STATE_FILE="/tmp/polybar-netspeed-${IFACE}.state"
RX_NOW=$(cat "/sys/class/net/$IFACE/statistics/rx_bytes" 2>/dev/null || echo 0)
TX_NOW=$(cat "/sys/class/net/$IFACE/statistics/tx_bytes" 2>/dev/null || echo 0)
NOW_TS=$(date +%s)

if [ -f "$STATE_FILE" ]; then
    read -r RX_OLD TX_OLD TS_OLD < "$STATE_FILE"
else
    RX_OLD=$RX_NOW; TX_OLD=$TX_NOW; TS_OLD=$NOW_TS
fi

DT=$((NOW_TS - TS_OLD))
[ "$DT" -le 0 ] && DT=1
RX_RATE=$(( (RX_NOW - RX_OLD) / DT ))
TX_RATE=$(( (TX_NOW - TX_OLD) / DT ))
echo "$RX_NOW $TX_NOW $NOW_TS" > "$STATE_FILE"

human() {
    local bytes=$1
    if [ "$bytes" -ge 1048576 ]; then
        awk -v b="$bytes" 'BEGIN{printf "%.1fM", b/1048576}'
    elif [ "$bytes" -ge 1024 ]; then
        awk -v b="$bytes" 'BEGIN{printf "%.0fK", b/1024}'
    else
        echo "${bytes}B"
    fi
}

echo " $(human "$RX_RATE")/s   $(human "$TX_RATE")/s"
