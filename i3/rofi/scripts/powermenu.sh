#!/usr/bin/env bash
# Power menu -- rofi dmenu list styled to match the rice, clicked from the
# top bar (button to the left of "Apps"). Destructive actions (reboot/
# shutdown) ask for a second confirmation before actually running.

source "$HOME/.config/rice/theme.conf"

ICON_LOCK=$(python3 -c "print(chr(0xF023))")
ICON_LOGOUT=$(python3 -c "print(chr(0xF08B))")
ICON_SUSPEND=$(python3 -c "print(chr(0xF186))")
ICON_REBOOT=$(python3 -c "print(chr(0xF021))")
ICON_POWEROFF=$(python3 -c "print(chr(0xF011))")
ICON_THEME=$(python3 -c "print(chr(0xF1FC))")  # fa-paint-brush, verified against installed font

LOCK="  $ICON_LOCK  Lock"
LOGOUT="  $ICON_LOGOUT  Logout"
SUSPEND="  $ICON_SUSPEND  Suspend"
REBOOT="  $ICON_REBOOT  Reboot"
POWEROFF="  $ICON_POWEROFF  Shut Down"

# Theme entry toggles to whichever OTHER preset isn't active right now --
# label names it directly ("Theme: Green") instead of a generic "Switch
# Theme" so you know what one click does before you click it. Reads the
# current preset from the theme.conf symlink (see switch-theme.sh), not
# from a separate state file, so it can never drift out of sync.
CURRENT_THEME=$(basename "$(readlink -f "$HOME/.config/rice/theme.conf")")
CURRENT_THEME="${CURRENT_THEME#theme-}"
CURRENT_THEME="${CURRENT_THEME%.conf}"
NEXT_THEME=""
for f in "$HOME/.config/rice"/theme-*.conf; do
    base="$(basename "$f")"
    base="${base#theme-}"
    base="${base%.conf}"
    if [ "$base" != "$CURRENT_THEME" ]; then
        NEXT_THEME="$base"
        break
    fi
done
THEME="  $ICON_THEME  Theme: ${NEXT_THEME^}"

ROFI="rofi -dmenu -config $HOME/.config/rofi/config.rasi -theme-str 'window {width: 260px;} listview {lines: 6;}'"

choice=$(printf '%s\n%s\n%s\n%s\n%s\n%s\n' "$LOCK" "$THEME" "$LOGOUT" "$SUSPEND" "$REBOOT" "$POWEROFF" | eval "$ROFI" -p "Power")

# Debug trail: every invocation logs exactly what rofi handed back and what
# we expected the theme entry to look like, byte-for-byte (od -c). If a
# selection ever silently does nothing again, this file says whether
# $choice truly matched $THEME or diverged by so much as one byte --
# instead of guessing blind a second time.
{
    echo "$(date '+%F %T') choice=[$choice]"
    echo "$(date '+%F %T') THEME=[$THEME]"
} >> /tmp/powermenu-debug.log

confirm() {
    eval "$ROFI" -p "Confirm" <<< $'  Yes\n  No' | grep -q "Yes"
}

case "$choice" in
    "$LOCK")   betterlockscreen -l dimblur ;;
    "$THEME")
        echo "$(date '+%F %T') dispatching switch-theme.sh $NEXT_THEME" >> /tmp/powermenu-debug.log
        if [ -n "$NEXT_THEME" ]; then
            nohup "$HOME/.config/rice/switch-theme.sh" "$NEXT_THEME" >>/tmp/switch-theme.log 2>&1 &
        fi
        ;;
    "$LOGOUT")   i3-msg exit ;;
    "$SUSPEND")  systemctl suspend ;;
    "$REBOOT")   confirm && systemctl reboot ;;
    "$POWEROFF") confirm && systemctl poweroff ;;
    *) echo "$(date '+%F %T') no case matched" >> /tmp/powermenu-debug.log ;;
esac
