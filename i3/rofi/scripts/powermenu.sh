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

LOCK="  $ICON_LOCK  Lock"
LOGOUT="  $ICON_LOGOUT  Logout"
SUSPEND="  $ICON_SUSPEND  Suspend"
REBOOT="  $ICON_REBOOT  Reboot"
POWEROFF="  $ICON_POWEROFF  Shut Down"

ROFI="rofi -dmenu -config $HOME/.config/rofi/config.rasi -theme-str 'window {width: 260px;} listview {lines: 5;}'"

choice=$(printf '%s\n%s\n%s\n%s\n%s\n' "$LOCK" "$LOGOUT" "$SUSPEND" "$REBOOT" "$POWEROFF" | eval "$ROFI" -p "Power")

confirm() {
    eval "$ROFI" -p "Confirm" <<< $'  Yes\n  No' | grep -q "Yes"
}

case "$choice" in
    "$LOCK")     betterlockscreen -l dimblur ;;
    "$LOGOUT")   i3-msg exit ;;
    "$SUSPEND")  systemctl suspend ;;
    "$REBOOT")   confirm && systemctl reboot ;;
    "$POWEROFF") confirm && systemctl poweroff ;;
esac
