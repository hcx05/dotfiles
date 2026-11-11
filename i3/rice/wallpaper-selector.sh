#!/usr/bin/env bash
# Wallpaper picker -- lighter-weight cousin of gh0stzk's WallSelect: picks
# any image under ~/Pictures and applies it immediately, independent of
# the desktop (rice-selector.sh) / taskbar (bar-selector.sh) choices.
# Persists into the CURRENTLY ACTIVE preset's own WALLPAPER= line (so it
# survives an i3 restart/login, and stays that preset's wallpaper until
# changed again) rather than a separate state file -- same "edit the one
# source of truth" pattern apply-theme.sh already uses everywhere else.
set -euo pipefail

THEME_DIR="$HOME/.config/rice"
PRESET_FILE="$THEME_DIR/$(basename "$(readlink -f "$THEME_DIR/theme.conf")")"
PICTURES_DIR="$HOME/Pictures"

mapfile -t IMAGES < <(find "$PICTURES_DIR" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
    2>/dev/null | sort)

if [ "${#IMAGES[@]}" -eq 0 ]; then
    notify-send "Wallpaper" "No images found in $PICTURES_DIR" 2>/dev/null || true
    exit 0
fi

selected=$(
    # Piped straight into rofi, NOT built up in a shell variable first --
    # see bar-selector.sh's comment: the \000 here is a literal NUL byte,
    # which a shell variable/command-substitution can't hold (silently
    # mangled -- observed live as the icon path leaking into the visible
    # row text). A pipe carries it through untouched.
    for img in "${IMAGES[@]}"; do
        printf '%s\000icon\037%s\n' "$(basename "$img")" "$img"
    done | rofi -dmenu -p "Wallpaper" \
    -config "$HOME/.config/rofi/config.rasi" \
    -theme-str 'window {width: 70%;} listview {columns: 4; lines: 2; fixed-height: true;} element {orientation: vertical;} element-icon {size: 160px; vertical-align: 0;} element-text {horizontal-align: 0.5;}')

[ -z "$selected" ] && exit 0

target=""
for img in "${IMAGES[@]}"; do
    [ "$(basename "$img")" = "$selected" ] && target="$img"
done
[ -z "$target" ] && exit 0

feh --bg-fill "$target"

# Write back using the "$HOME/..." literal-string convention the preset
# files already use (see theme-*.conf's own WALLPAPER= lines), not an
# expanded absolute path.
WPATH="$target"
case "$WPATH" in
    "$HOME"/*) WPATH="\$HOME/${WPATH#"$HOME"/}" ;;
esac
sed -i "s|^WALLPAPER=.*|WALLPAPER=\"$WPATH\"  # set by wallpaper-selector.sh|" "$PRESET_FILE"
