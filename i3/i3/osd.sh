#!/usr/bin/env bash
# Volume / mic / brightness control with an on-screen notification (dunst
# progress bar). Pattern borrowed from gh0stzk/dotfiles (bin/Volume,
# bin/Brightness), but driving this setup's own tools: wpctl (PipeWire) and
# brightnessctl.
#
# Usage: osd.sh vol-up | vol-down | vol-mute | mic-mute | bright-up | bright-down
#
# Notifications share one stack tag, so repeated key presses update the same
# bubble instead of piling up. The matching [osd] rule in dunstrc keeps them
# out of the history and short-lived.

SINK=@DEFAULT_AUDIO_SINK@
SOURCE=@DEFAULT_AUDIO_SOURCE@
STEP=5
MIN_BRIGHTNESS=2   # never let the screen go fully dark

osd() {  # osd <text> <0-100 value> <icon-name>
    if command -v dunstify >/dev/null 2>&1; then
        dunstify -u low -a osd \
            -h string:x-dunst-stack-tag:osd \
            -h "int:value:$2" \
            -i "$3" "$1"
    else
        notify-send -u low -a osd -i "$3" "$1"
    fi
}

# "Volume: 0.45" or "Volume: 0.45 [MUTED]"
volume_state() {  # volume_state <wpctl-target> -> "<percent> <muted|on>"
    local line pct
    line=$(wpctl get-volume "$1" 2>/dev/null) || return 1
    pct=$(awk '{printf "%d", $2 * 100 + 0.5}' <<<"$line")
    if [[ $line == *MUTED* ]]; then echo "$pct muted"; else echo "$pct on"; fi
}

show_volume() {
    local pct state icon
    read -r pct state < <(volume_state "$SINK") || return
    if [ "$state" = muted ] || [ "$pct" -eq 0 ]; then
        icon=audio-volume-muted
        osd "Volume: muted" 0 "$icon"
        return
    fi
    if   [ "$pct" -lt 34 ]; then icon=audio-volume-low
    elif [ "$pct" -lt 67 ]; then icon=audio-volume-medium
    else                         icon=audio-volume-high
    fi
    osd "Volume: ${pct}%" "$(( pct > 100 ? 100 : pct ))" "$icon"
}

show_mic() {
    local pct state
    read -r pct state < <(volume_state "$SOURCE") || return
    if [ "$state" = muted ]; then
        osd "Microphone: muted" 0 microphone-sensitivity-muted
    else
        osd "Microphone: on" 100 microphone-sensitivity-high
    fi
}

brightness_pct() {  # brightnessctl -m -> dev,class,cur,pct%,max
    brightnessctl -m 2>/dev/null | head -n1 | cut -d, -f4 | tr -d '%'
}

adjust_brightness() {  # adjust_brightness up|down
    local cur
    cur=$(brightness_pct)
    [ -n "$cur" ] || return
    if [ "$1" = up ]; then
        if [ "$cur" -lt "$MIN_BRIGHTNESS" ]; then
            brightnessctl -q set "${MIN_BRIGHTNESS}%"
        else
            brightnessctl -q set "${STEP}%+"
        fi
    else
        if [ "$cur" -le $(( MIN_BRIGHTNESS + STEP )) ]; then
            brightnessctl -q set "${MIN_BRIGHTNESS}%"
        else
            brightnessctl -q set "${STEP}%-"
        fi
    fi
    cur=$(brightness_pct)
    osd "Brightness: ${cur}%" "$cur" display-brightness-symbolic
}

case "${1:-}" in
    vol-up)      wpctl set-mute "$SINK" 0; wpctl set-volume -l 1.0 "$SINK" "${STEP}%+"; show_volume ;;
    vol-down)    wpctl set-mute "$SINK" 0; wpctl set-volume "$SINK" "${STEP}%-";        show_volume ;;
    vol-mute)    wpctl set-mute "$SINK" toggle;               show_volume ;;
    mic-mute)    wpctl set-mute "$SOURCE" toggle;             show_mic ;;
    bright-up)   adjust_brightness up ;;
    bright-down) adjust_brightness down ;;
    *) echo "usage: ${0##*/} vol-up|vol-down|vol-mute|mic-mute|bright-up|bright-down" >&2
       exit 2 ;;
esac
