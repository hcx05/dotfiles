#!/usr/bin/env bash
# Themed Rofi Input Method Switcher with EN / ZH toggle (Alt+l).
# Shares language state with ~/.config/i3/help.sh via ~/.cache/i3-help-lang.

set -u
MODE="${1:-menu}"

gsettings set org.freedesktop.ibus.panel show-icon-on-systray false 2>/dev/null || true

if [ "$MODE" = "toggle" ]; then
    "$HOME/.config/i3/toggle-ibus.sh"
    exit 0
fi

if [ $# -le 1 ] && pgrep -x rofi >/dev/null 2>&1; then
    pkill -x rofi
    exit 0
fi

source "$HOME/.config/rice/theme.conf" 2>/dev/null
ACCENT="${ACCENT:-#FFFFFF}"
LANG_STATE="$HOME/.cache/i3-help-lang"
mkdir -p "$(dirname "$LANG_STATE")"

while true; do
    LANG_NOW=$(cat "$LANG_STATE" 2>/dev/null || true)
    [ "$LANG_NOW" = "zh" ] || LANG_NOW="en"

    CURRENT=$(ibus engine 2>/dev/null)
    CJK_ENGINE=$(gsettings get org.freedesktop.ibus.general preload-engines 2>/dev/null \
        | tr -d "[]'" | tr ',' '\n' | sed 's/^ *//' | grep -v '^xkb:' | head -1)
    [ -z "$CJK_ENGINE" ] && CJK_ENGINE="chewing"

    if [ "$LANG_NOW" = "zh" ]; then
        PROMPT="  輸入法 (Alt+l 切換 EN)"
        OPT_EN="     English (US)  —  英文輸入"
        OPT_ZH="     中文 (新酷音 Chewing)  —  注音輸入"
        OPT_LANG="  🌐   切換選單為英文 (Alt+l)"
        if [ "$CURRENT" = "$CJK_ENGINE" ]; then
            STATUS_TEXT="目前輸入法：<span foreground=\"${ACCENT}\" weight=\"bold\">中文 (新酷音 注音)</span>   │   快捷鍵：Mod+I / 右 Shift"
            PRE_SELECT=0
        else
            STATUS_TEXT="目前輸入法：<span foreground=\"${ACCENT}\" weight=\"bold\">English (US)</span>   │   快捷鍵：Mod+I / 右 Shift"
            PRE_SELECT=1
        fi
    else
        PROMPT="  Input Method (Alt+l 切中文)"
        OPT_EN="     English (US)  —  US Keyboard"
        OPT_ZH="     Chinese (Chewing)  —  Zhuyin / 注音"
        OPT_LANG="  🌐   Switch Menu to 中文 (Alt+l)"
        if [ "$CURRENT" = "$CJK_ENGINE" ]; then
            STATUS_TEXT="Current: <span foreground=\"${ACCENT}\" weight=\"bold\">Chinese (Chewing / 注音)</span>   │   Hotkey: Mod+I / Right Shift"
            PRE_SELECT=0
        else
            STATUS_TEXT="Current: <span foreground=\"${ACCENT}\" weight=\"bold\">English (US)</span>   │   Hotkey: Mod+I / Right Shift"
            PRE_SELECT=1
        fi
    fi

    CHOICE=$(printf '%s\n%s\n%s\n' "$OPT_EN" "$OPT_ZH" "$OPT_LANG" | rofi -dmenu -i \
        -p "$PROMPT" \
        -mesg "$STATUS_TEXT" \
        -selected-row "$PRE_SELECT" \
        -kb-custom-1 "Alt+l" \
        -config "$HOME/.config/rofi/config.rasi" \
        -theme-str 'window {width: 440px;} inputbar {enabled: false;} listview {lines: 3; scrollbar: false;}')
    rc=$?

    if [ "$rc" -eq 10 ] || [ "$CHOICE" = "$OPT_LANG" ]; then
        if [ "$LANG_NOW" = "zh" ]; then
            echo "en" > "$LANG_STATE"
        else
            echo "zh" > "$LANG_STATE"
        fi
        continue
    fi

    [ -z "$CHOICE" ] && exit 0

    case "$CHOICE" in
        "$OPT_EN")
            ibus engine xkb:us::eng
            dunstify -a "osd" -r 99105 -u low -t 1200 "  Input Method" "English (EN)" 2>/dev/null || true
            exit 0
            ;;
        "$OPT_ZH")
            ibus engine "$CJK_ENGINE"
            if [ "$LANG_NOW" = "zh" ]; then
                dunstify -a "osd" -r 99105 -u low -t 1200 "  輸入法" "中文 (新酷音 注音)" 2>/dev/null || true
            else
                dunstify -a "osd" -r 99105 -u low -t 1200 "  Input Method" "Chinese (Chewing / 注音)" 2>/dev/null || true
            fi
            exit 0
            ;;
    esac
done
