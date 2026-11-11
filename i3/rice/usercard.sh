#!/usr/bin/env bash
# User card -- "用戶卡排" -- ported from gh0stzk's eww profilecard (eww
# itself isn't installed/packaged for this rice, so this reproduces the
# same information + quick actions as a rofi menu instead: a header "card"
# of user/system info via -mesg, with action rows below). Bound to $mod+u
# and reachable from the top bar's user icon button.
set -euo pipefail

THEME_DIR="$HOME/.config/rice"

# ---- gather info (best-effort; each falls back to "?" rather than erroring) ----
USERNAME=$(whoami)
HOSTNAME=$(cat /etc/hostname 2>/dev/null || hostname)
UPTIME=$(uptime -p 2>/dev/null | sed -E -e 's/^up //' -e 's/hours?/hr/g' -e 's/minutes?/min/g')
KERNEL=$(uname -r)
OS_NAME=$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-Linux}")
PKG_COUNT=$(dpkg -l 2>/dev/null | grep -c '^ii' || echo '?')

# CPU: two /proc/stat samples 150ms apart (no extra package needed).
read -r _ u1 n1 s1 i1 _ < <(awk '/^cpu /{print}' /proc/stat)
sleep 0.15
read -r _ u2 n2 s2 i2 _ < <(awk '/^cpu /{print}' /proc/stat)
total1=$((u1 + n1 + s1 + i1)); total2=$((u2 + n2 + s2 + i2))
idle_delta=$((i2 - i1)); total_delta=$((total2 - total1))
CPU_PCT=0
[ "$total_delta" -gt 0 ] && CPU_PCT=$(( (100 * (total_delta - idle_delta)) / total_delta ))

RAM_PCT=$(free -m | awk '/^Mem:/{printf "%d", $3*100/$2}')
DISK_PCT=$(df / | awk 'NR==2{gsub("%","",$5); print $5}')

NET_STATUS=$(nmcli -t -f STATE general status 2>/dev/null || echo "unknown")
case "$NET_STATUS" in
    connected*) NET_LABEL="Online" ;;
    *) NET_LABEL="Offline" ;;
esac

CURRENT_THEME=$(basename "$(readlink -f "$THEME_DIR/theme.conf")")
CURRENT_THEME="${CURRENT_THEME#theme-}"; CURRENT_THEME="${CURRENT_THEME%.conf}"

# rofi 2.0's -mesg renders plain pango text in its own internal default
# color (a dark teal, NOT this rasi's text-color) unless each run carries
# an explicit foreground= attribute -- the rasi `message { text-color }`
# setting is simply not consulted for -mesg content. So pull fg/fg-alt
# straight from the generated palette and wrap every span explicitly
# instead of relying on theming (discovered live: plain/bold/sized spans
# with no foreground= all rendered invisible-on-dark here).
COLORS_RASI="$HOME/.config/rofi/colors.rasi"
FG=$(sed -n 's/^[[:space:]]*fg:[[:space:]]*\(#[0-9a-fA-F]\{6\}\).*/\1/p' "$COLORS_RASI" 2>/dev/null | head -n1)
FG_ALT=$(sed -n 's/^[[:space:]]*fg-alt:[[:space:]]*\(#[0-9a-fA-F]\{6\}\).*/\1/p' "$COLORS_RASI" 2>/dev/null | head -n1)
FG="${FG:-#E8E8E8}"
FG_ALT="${FG_ALT:-#8A8A8A}"

CARD=$(cat <<EOF
<span foreground="$FG"><b>${USERNAME}@${HOSTNAME}</b></span>  <span foreground="$FG_ALT">·  up ${UPTIME}</span>
<span foreground="$FG_ALT" size="small">${OS_NAME}  ·  ${KERNEL}  ·  ${PKG_COUNT} pkgs</span>
<span foreground="$FG_ALT" size="small">CPU ${CPU_PCT}%   RAM ${RAM_PCT}%   Disk ${DISK_PCT}%   ·  Net: ${NET_LABEL}  ·  Theme: ${CURRENT_THEME^}</span>
EOF
)

ICON_LOCK=$(python3 -c "print(chr(0xF023))")
ICON_LOGOUT=$(python3 -c "print(chr(0xF08B))")
ICON_NET=$(python3 -c "print(chr(0xF1EB))")    # fa-wifi
ICON_BT=$(python3 -c "print(chr(0xF293))")     # fa-bluetooth-b
ICON_THEME=$(python3 -c "print(chr(0xF1FC))")  # fa-paint-brush
ICON_BAR=$(python3 -c "print(chr(0xF2D0))")    # fa-window-restore
ICON_HELP=$(python3 -c "print(chr(0xF059))")   # fa-question-circle

ROW_NET="  $ICON_NET  Network Manager"
ROW_BT="  $ICON_BT  Bluetooth Manager"
ROW_THEME="  $ICON_THEME  Desktop (Theme)"
ROW_BAR="  $ICON_BAR  Taskbar Style"
ROW_HELP="  $ICON_HELP  Keybindings"
ROW_LOCK="  $ICON_LOCK  Lock"
ROW_LOGOUT="  $ICON_LOGOUT  Logout"

choice=$(printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
    "$ROW_NET" "$ROW_BT" "$ROW_THEME" "$ROW_BAR" "$ROW_HELP" "$ROW_LOCK" "$ROW_LOGOUT" | \
    rofi -dmenu -config "$HOME/.config/rofi/config.rasi" \
         -theme-str 'window {width: 420px;} listview {lines: 7;}' \
         -mesg "$CARD" -p "User")

case "$choice" in
    "$ROW_NET")    nm-connection-editor & ;;
    "$ROW_BT")     command -v blueman-manager >/dev/null 2>&1 && blueman-manager & ;;
    "$ROW_THEME")  "$THEME_DIR/rice-selector.sh" ;;
    "$ROW_BAR")    "$THEME_DIR/bar-selector.sh" ;;
    "$ROW_HELP")   "$HOME/.config/i3/help.sh" ;;
    "$ROW_LOCK")   betterlockscreen -l dimblur ;;
    "$ROW_LOGOUT") i3-msg exit ;;
esac
