#!/usr/bin/env bash
# Custom Polybar volume module (replaces internal/pulseaudio because
# internal/pulseaudio hardcodes left-click to mute and ignores click-left).
# Left-click: open volume slider popup (audio-menu.sh)
# Right-click: toggle mute (osd.sh vol-mute)
# Scroll up/down: adjust volume (osd.sh vol-up / vol-down)

source "$HOME/.config/rice/theme.conf" 2>/dev/null
ACCENT="${ACCENT:-#FFFFFF}"
FG="${FOREGROUND:-#E8E8E8}"
URGENT="${URGENT:-#FF1855}"

VOL_RAW=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo "Volume: 0.50")
VOL_PCT=$(awk '/Volume:/ {printf "%d", $2 * 100}' <<<"$VOL_RAW")

if grep -q '\[MUTED\]' <<<"$VOL_RAW"; then
    OUT="%{F${URGENT}}%{T2}󰝟 %{T-}Muted%{F-}"
else
    if [ "${VOL_PCT:-0}" -lt 30 ]; then
        ICON=""
    elif [ "${VOL_PCT:-0}" -lt 70 ]; then
        ICON=""
    else
        ICON=""
    fi
    OUT="%{F${ACCENT}}%{T2}${ICON} %{T-}%{F${FG}}${VOL_PCT}%%{F-}"
fi

ACT_L="$HOME/.config/polybar/scripts/audio-menu.sh &"
ACT_R="$HOME/.config/i3/osd.sh vol-mute &"
ACT_U="$HOME/.config/i3/osd.sh vol-up &"
ACT_D="$HOME/.config/i3/osd.sh vol-down &"

printf '%%{A1:%s:}%%{A3:%s:}%%{A4:%s:}%%{A5:%s:}%s%%{A}%%{A}%%{A}%%{A}\n' \
    "$ACT_L" "$ACT_R" "$ACT_U" "$ACT_D" "$OUT"
