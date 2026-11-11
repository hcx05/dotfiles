#!/usr/bin/env bash
# Desktop (rice) selector -- "桌面選擇" -- ported from gh0stzk's RiceSelector:
# a rofi icon grid to flip between full desktop presets (colors + wallpaper
# + layout), each one previewed by its own wallpaper. Bound to $mod+Shift+d
# and reachable from the top bar's paint-brush icon button; the power menu's
# "Theme" entry also calls this instead of its own inline list.
set -euo pipefail

THEME_DIR="$HOME/.config/rice"
CURRENT="$(basename "$(readlink -f "$THEME_DIR/theme.conf")")"
CURRENT="${CURRENT#theme-}"
CURRENT="${CURRENT%.conf}"

NAMES=()
for f in "$THEME_DIR"/theme-*.conf; do
    base="$(basename "$f")"
    base="${base#theme-}"
    NAMES+=("${base%.conf}")
done

selected_index=-1
for i in "${!NAMES[@]}"; do
    [ "${NAMES[$i]}" = "$CURRENT" ] && selected_index=$i
done

selected_label=$(
    # Piped straight into rofi, NOT built up in a shell variable first --
    # see bar-selector.sh's comment on the same issue: the \000 here is a
    # literal NUL byte, which a shell variable/command-substitution can't
    # hold (silently mangled -- observed live as the icon path leaking
    # into the visible row text). A pipe carries it through untouched.
    for name in "${NAMES[@]}"; do
        # shellcheck disable=SC1090 -- each preset's own WALLPAPER path,
        # used as this entry's preview icon (no separate preview.webp to
        # maintain).
        # Match up to the closing quote only, not end-of-line -- every
        # preset's WALLPAPER= line has a trailing `# comment`, which an
        # end-anchored pattern never matches (discovered live: every
        # preview came back blank, $wall was empty for all three presets).
        wall=$(sed -n 's/^WALLPAPER="\([^"]*\)".*/\1/p' "$THEME_DIR/theme-$name.conf" | head -n1)
        wall="${wall/#\$HOME/$HOME}"
        label="${name^}"
        [ "$name" = "$CURRENT" ] && label="$label (current)"
        printf '%s\000icon\037%s\n' "$label" "$wall"
    done | rofi -dmenu -p "Desktop" \
    -config "$HOME/.config/rofi/config.rasi" \
    -theme-str 'window {width: 640px;} listview {columns: 3; lines: 1; fixed-height: true;} element {orientation: vertical;} element-icon {size: 180px; vertical-align: 0;} element-text {horizontal-align: 0.5;}' \
    -selected-row "$selected_index")

target=""
for name in "${NAMES[@]}"; do
    label="${name^}"
    [ "$name" = "$CURRENT" ] && label="$label (current)"
    [ "$label" = "$selected_label" ] && target="$name"
done

if [ -n "$target" ] && [ "$target" != "$CURRENT" ]; then
    nohup "$THEME_DIR/switch-theme.sh" "$target" >>/tmp/switch-theme.log 2>&1 &
fi
