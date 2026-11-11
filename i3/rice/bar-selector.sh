#!/usr/bin/env bash
# Bar/taskbar style selector -- "taskbar選擇" -- ported from gh0stzk's
# BarSelector idea, adapted to this rice's two-bar-style setup (mainbar vs
# monobar+dock) instead of 18 fully separate bar packages. Deliberately
# independent of the color theme (see apply-theme.sh's BAR STYLE OVERRIDE
# comment): pick any bar style with any color theme. Bound to $mod+Shift+t
# and reachable from the top bar's own bar-style icon button.
set -euo pipefail

THEME_DIR="$HOME/.config/rice"
PREVIEWS="$THEME_DIR/previews"
OVERRIDE_FILE="$THEME_DIR/.barstyle"

# Effective current style: override file wins, else the active theme's own
# LAYOUT (same precedence apply-theme.sh and polybar/launch.sh use).
source "$THEME_DIR/theme.conf"
CURRENT="${LAYOUT:-classic}"
if [ -s "$OVERRIDE_FILE" ]; then
    CURRENT="$(tr -d ' \t\n\r' < "$OVERRIDE_FILE")"
fi

declare -A LABELS=(
    [classic]="Classic — full-width top bar"
    [dock]="Dock — floating bar + right-side app dock"
)
ORDER=(classic dock)

selected_index=-1
for i in "${!ORDER[@]}"; do
    [ "${ORDER[$i]}" = "$CURRENT" ] && selected_index=$i
done

selected_label=$(
    # Piped straight into rofi, NOT built up in a shell variable first: the
    # \000 separating label from icon-path is a literal NUL byte, and shell
    # variables/command substitution can't hold NUL -- `-- entries+=$(...)`
    # silently truncates/mangles it, which was observed live as the raw
    # icon path leaking into the visible row text instead of becoming an
    # icon. A pipe carries the NUL through untouched.
    for name in "${ORDER[@]}"; do
        printf '%s\000icon\037%s/bar-%s.png\n' "${LABELS[$name]}" "$PREVIEWS" "$name"
    done | rofi -dmenu -p "Taskbar Style" \
    -config "$HOME/.config/rofi/config.rasi" \
    -theme-str 'window {width: 480px;} listview {columns: 2; lines: 1; fixed-height: true;} element {orientation: vertical;} element-icon {size: 220px; vertical-align: 0;} element-text {horizontal-align: 0.5;}' \
    -selected-row "$selected_index")

target=""
for name in "${ORDER[@]}"; do
    [ "${LABELS[$name]}" = "$selected_label" ] && target="$name"
done

if [ -n "$target" ] && [ "$target" != "$CURRENT" ]; then
    echo "$target" > "$OVERRIDE_FILE"
    "$THEME_DIR/apply-theme.sh"
    "$THEME_DIR/reload-rice.sh"
    notify-send -i "$PREVIEWS/bar-$target.png" "Taskbar" "Switched to: ${LABELS[$target]}" 2>/dev/null || true
fi
