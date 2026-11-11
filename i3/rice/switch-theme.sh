#!/usr/bin/env bash
# Swap between the rice's presets: theme-purple.conf / theme-green.conf /
# theme-mono.conf (mono also switches the layout -- floating top bar + dock).
# theme.conf is a symlink to whichever preset is "active"; this script
# repoints that symlink, regenerates every consumer via apply-theme.sh,
# and reloads/restarts the running WM pieces so it takes effect immediately.
set -euo pipefail

THEME_DIR="$HOME/.config/rice"
NAME="${1:-}"

usage() {
    echo "Usage: $0 <purple|green|mono>"
    echo "Available presets:"
    for f in "$THEME_DIR"/theme-*.conf; do
        base="$(basename "$f")"
        echo "  ${base#theme-}" | sed 's/\.conf$//'
    done
    exit 1
}

[ -z "$NAME" ] && usage
PRESET="$THEME_DIR/theme-$NAME.conf"
[ -f "$PRESET" ] || { echo "No such preset: $PRESET"; usage; }

ln -sf "theme-$NAME.conf" "$THEME_DIR/theme.conf"
echo "theme.conf -> theme-$NAME.conf"

# fastfetch dragon logo follows the preset too, if a matching recolor
# exists (dragon-purple.png / dragon-green.png / dragon-mono.png) -- silently left alone for
# presets that don't have their own dragon variant yet.
FASTFETCH_DIR="$HOME/.config/fastfetch"
DRAGON_VARIANT="$FASTFETCH_DIR/dragon-$NAME.png"
if [ -f "$DRAGON_VARIANT" ]; then
    ln -sf "dragon-$NAME.png" "$FASTFETCH_DIR/dragon.png"
    echo "dragon.png -> dragon-$NAME.png"
fi

"$THEME_DIR/apply-theme.sh"

# Everything below this point (tmux/kitty signaling, polybar+dock relaunch,
# geometry daemons, wallpaper, picom/dunst restart) is shared with
# bar-selector.sh ($mod+Shift+t), which changes LAYOUT without touching any
# color -- factored out to reload-rice.sh so both stay in lockstep instead
# of two copies of the same ~60-line relaunch sequence drifting apart.
# reload-rice.sh owns the overlapping-runs lock itself.
"$THEME_DIR/reload-rice.sh"

echo "Switched to '$NAME'. If anything looks stale, Mod+Shift+r or a full logout/login will fully reset it."
