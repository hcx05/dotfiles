#!/usr/bin/env bash
# Toggles ibus between English (xkb) and the first non-xkb engine in your
# preload-engines list (e.g. chewing/pinyin). Respects ~/.cache/i3-help-lang.

CURRENT=$(ibus engine 2>/dev/null)
LANG_NOW=$(cat "$HOME/.cache/i3-help-lang" 2>/dev/null || true)

CJK_ENGINE=$(gsettings get org.freedesktop.ibus.general preload-engines 2>/dev/null \
    | tr -d "[]'" | tr ',' '\n' | sed 's/^ *//' | grep -v '^xkb:' | head -1)
[ -z "$CJK_ENGINE" ] && CJK_ENGINE="chewing"

if [ "$CURRENT" = "$CJK_ENGINE" ]; then
    ibus engine xkb:us::eng
    if [ "$LANG_NOW" = "zh" ]; then
        dunstify -a "osd" -r 99105 -u low -t 1200 "  輸入法" "English (EN)" 2>/dev/null || true
    else
        dunstify -a "osd" -r 99105 -u low -t 1200 "  Input Method" "English (EN)" 2>/dev/null || true
    fi
else
    ibus engine "$CJK_ENGINE"
    if [ "$LANG_NOW" = "zh" ]; then
        dunstify -a "osd" -r 99105 -u low -t 1200 "  輸入法" "中文 (新酷音 注音)" 2>/dev/null || true
    else
        dunstify -a "osd" -r 99105 -u low -t 1200 "  Input Method" "Chinese (Chewing / 注音)" 2>/dev/null || true
    fi
fi
