#!/usr/bin/env bash
# Desktop right-click menu -- reproduces gh0stzk's jgmenu-on-background
# trick (sxhkd's `~button3` + a window-type check) using rofi instead of
# jgmenu, since this rice already uses rofi for every other menu and jgmenu
# isn't installed/themed here. Bound globally to button 3 via xbindkeys
# (~/.config/i3/xbindkeysrc, autostarted from i3/config); only actually
# shows the menu when the click landed on bare desktop background -- see
# the root-window check below -- so right-clicking inside any real window
# (Firefox, a terminal, Burp, ...) is completely unaffected: xbindkeys'
# grab never consumes/blocks the click (X replays it to the real target
# either way), this script just also fires and silently no-ops.
set -euo pipefail

# xwininfo prints the window id in hex ("0x324"), xdotool in decimal
# ("804") -- same window, different base. Both get normalized to decimal
# before comparing, otherwise this always falls through (discovered live:
# the raw string compare never matched even on bare background).
ROOT_ID=$(xwininfo -root 2>/dev/null | awk '/Window id/{print $4}')
CLICKED=$(xdotool getmouselocation --shell 2>/dev/null | sed -n 's/^WINDOW=//p')

[ -n "$ROOT_ID" ] && [ -n "$CLICKED" ] && [ "$((CLICKED))" -eq "$((ROOT_ID))" ] || exit 0

THEME_DIR="$HOME/.config/rice"
ICON_TERM=$(python3 -c "print(chr(0xF120))")     # fa-terminal
ICON_APPS=$(python3 -c "print(chr(0xF009))")     # fa-th-large
ICON_THEME=$(python3 -c "print(chr(0xF1FC))")    # fa-paint-brush
ICON_BAR=$(python3 -c "print(chr(0xF2D0))")      # fa-window-restore
ICON_WALL=$(python3 -c "print(chr(0xF03E))")     # fa-picture-o
ICON_HELP=$(python3 -c "print(chr(0xF059))")     # fa-question-circle
ICON_USER=$(python3 -c "print(chr(0xF007))")     # fa-user
ICON_LOCK=$(python3 -c "print(chr(0xF023))")     # fa-lock
ICON_RELOAD=$(python3 -c "print(chr(0xF021))")   # fa-refresh
ICON_POWER=$(python3 -c "print(chr(0xF011))")    # fa-power-off

ROW_TERM="  $ICON_TERM  Open Terminal"
ROW_APPS="  $ICON_APPS  App Launcher"
ROW_THEME="  $ICON_THEME  Desktop (Theme)"
ROW_BAR="  $ICON_BAR  Taskbar Style"
ROW_WALL="  $ICON_WALL  Wallpaper"
ROW_USER="  $ICON_USER  User Card"
ROW_HELP="  $ICON_HELP  Keybindings"
ROW_RELOAD="  $ICON_RELOAD  Reload i3"
ROW_POWER="  $ICON_POWER  Power Menu"

choice=$(printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
    "$ROW_TERM" "$ROW_APPS" "$ROW_THEME" "$ROW_BAR" "$ROW_WALL" \
    "$ROW_USER" "$ROW_HELP" "$ROW_RELOAD" "$ROW_POWER" | \
    rofi -dmenu -config "$HOME/.config/rofi/config.rasi" \
         -theme-str 'window {width: 260px; location: center; anchor: center;} listview {lines: 9;}' \
         -p "Desktop")

case "$choice" in
    "$ROW_TERM")   kitty & ;;
    "$ROW_APPS")   rofi -show drun -config "$HOME/.config/rofi/config.rasi" & ;;
    "$ROW_THEME")  "$THEME_DIR/rice-selector.sh" ;;
    "$ROW_BAR")    "$THEME_DIR/bar-selector.sh" ;;
    "$ROW_WALL")   "$THEME_DIR/wallpaper-selector.sh" ;;
    "$ROW_USER")   "$THEME_DIR/usercard.sh" ;;
    "$ROW_HELP")   "$HOME/.config/i3/help.sh" ;;
    "$ROW_RELOAD") i3-msg reload >/dev/null ;;
    "$ROW_POWER")  "$HOME/.config/rofi/scripts/powermenu.sh" ;;
esac
