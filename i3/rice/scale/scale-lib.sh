# shellcheck shell=sh
# Sourced (POSIX sh) by anything that needs a size in pixels.
#
#   . ~/.config/rice/scale/scale-lib.sh
#   gap=$(scale_px 14)        # 14px of design size -> px on this screen
#
# RICE_SCALE / RICE_DPI come from the state file `autoscale apply` writes;
# before the first run they are the neutral 1 / 96, so every caller keeps
# working (unscaled) on a machine where autoscale never ran.

RICE_SCALE=1
RICE_DPI=96
RICE_SCREEN=""
RICE_SCALE_SOURCE=""
RICE_SCALE_STATE="${XDG_CACHE_HOME:-$HOME/.cache}/rice/scale.env"
# shellcheck disable=SC1090
[ -r "$RICE_SCALE_STATE" ] && . "$RICE_SCALE_STATE"

# scale_px N [SCALE] -> N x scale, rounded to whole pixels. A non-zero size
# never rounds down to nothing (a 1px border stays a border), and the sign
# is kept (shadow offsets are negative).
scale_px() {
    awk -v v="$1" -v s="${2:-$RICE_SCALE}" 'BEGIN {
        a = (v < 0) ? -v : v
        r = int(a * s + 0.5)
        if (a > 0 && r < 1) r = 1
        print (v < 0) ? -r : r
    }'
}

# scale_div N [SCALE] -> N / scale, rounded: turns real pixels back into
# design units, for programs that multiply by the scale themselves (dunst).
scale_div() {
    awk -v v="$1" -v s="${2:-$RICE_SCALE}" 'BEGIN { printf "%d\n", v / s + 0.5 }'
}
