#!/usr/bin/env bash
# Polybar Input Method indicator & controller (replaces ugly ibus-ui-gtk3 tray icon).
# Respects ~/.cache/i3-help-lang (shows ZH in English mode, 注音 in Chinese mode).

source "$HOME/.config/rice/theme.conf" 2>/dev/null
ACCENT="${ACCENT:-#FFFFFF}"
FG="${FOREGROUND:-#E8E8E8}"

LANG_NOW=$(cat "$HOME/.cache/i3-help-lang" 2>/dev/null || true)
ENGINE=$(ibus engine 2>/dev/null)
ACTION_L="$HOME/.config/polybar/scripts/ime-menu.sh menu &"
ACTION_R="$HOME/.config/polybar/scripts/ime-menu.sh toggle &"

case "$ENGINE" in
    *chewing*)
        if [ "$LANG_NOW" = "zh" ]; then
            LABEL="%{F${ACCENT}}%{T2} %{T-}注音%{F-}"
        else
            LABEL="%{F${ACCENT}}%{T2} %{T-}ZH%{F-}"
        fi
        ;;
    xkb:*|"")
        LABEL="%{F${ACCENT}}%{T2} %{T-}%{F${FG}}EN%{F-}"
        ;;
    *)
        SHORT="${ENGINE##*:}"
        LABEL="%{F${ACCENT}}%{T2} %{T-}%{F${FG}}${SHORT^^}%{F-}"
        ;;
esac

printf '%%{A1:%s:}%%{A3:%s:}%s%%{A}%%{A}\n' "$ACTION_L" "$ACTION_R" "$LABEL"
