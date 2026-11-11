#!/usr/bin/env bash
# Grouped taskbar action icons inside a rounded pill (...), using
# hcx05/ArchDotfiles icon language:
#   - 󰏘 (0xF03D8) Rice / Theme selector (colorpicker/palette)
#   - 󰕰 (0xF0570) Bar / Layout style selector
#   - 󰸉 (0xF0E09) Wallpaper selector
#   -  (0xF2BD)  User profile card
#   -  (0xF059)  Keybindings help
source "$HOME/.config/rice/theme.conf"

PILL_L=$(python3 -c "print(chr(0xE0B6))")
PILL_R=$(python3 -c "print(chr(0xE0B4))")

btn() { # btn <index> <hex> <color> <command>
    local glyph
    glyph=$(python3 -c "print(chr(0x$2))")
    # "_B=<index> " prefix: a harmless unused env-var assignment, NOT a
    # real argument -- its only job is to make this action's command
    # STRING start differently from the other btn() calls' strings.
    # Without it, polybar silently fails to register ANY of this module's
    # click regions whenever 2+ of its %{A1:cmd:} blocks share a long
    # identical prefix (verified live: all 4 rice/-prefixed icons here
    # went completely dead to clicks -- not a coordinate or font issue,
    # not reproducible with a single icon or with icons from different
    # directories -- only when 2+ commands in the same module share a
    # long common prefix like "$HOME/.config/rice/"). <index> must be
    # passed in by the caller, NOT a shared counter incremented inside
    # this function -- each `$(btn ...)` call below runs in its own
    # subshell, so a counter local to btn() would reset to the same
    # value every time instead of advancing.
    printf '%%{A1:_B=%s %s &:}%%{T3}%%{F%s} %s %%{F-}%%{T-}%%{A}' "$1" "$4" "$3" "$glyph"
}

printf '%%{T4}%%{F%s}%s%%{F-}%%{T-}%%{B%s}%s%s%s%s%s%%{B-}%%{T4}%%{F%s}%s%%{F-}%%{T-}\n' \
    "$BACKGROUND_ALT" "$PILL_L" \
    "$BACKGROUND_ALT" \
    "$(btn 1 F03D8 "$ACCENT"     "$HOME/.config/rice/rice-selector.sh")" \
    "$(btn 2 F0570 "$ACCENT_ALT" "$HOME/.config/rice/bar-selector.sh")" \
    "$(btn 3 F0E09 "$FOREGROUND" "$HOME/.config/rice/wallpaper-selector.sh")" \
    "$(btn 4 F2BD  "$ACCENT_ALT" "$HOME/.config/rice/usercard.sh")" \
    "$(btn 5 F059  "$FOREGROUND_ALT" "$HOME/.config/i3/help.sh")" \
    "$BACKGROUND_ALT" "$PILL_R"
