#!/bin/sh
# help.sh -- rofi-rendered keybinding cheatsheet ("快捷鍵一覽"), parsed from
# keybinds.conf. Ported from gh0stzk's bin/Help (same awk-based parser,
# same bilingual Alt+l toggle), pointed at this rice's own data file instead
# of sxhkdrc. Section headers use this rice's accent color (from
# rofi/colors.rasi); keybind names are bold. Press Alt+l to toggle
# English / Traditional Chinese. Bound to $mod+F1.

KEYBINDS="$HOME/.config/i3/keybinds.conf"
I18N="$HOME/.config/i3/keybinds-i18n.tsv"
COLORS_RASI="$HOME/.config/rofi/colors.rasi"
LANG_STATE="$HOME/.cache/i3-help-lang"

[ -r "$KEYBINDS" ] || { notify-send "help" "keybinds.conf not found: $KEYBINDS"; exit 1; }

mkdir -p "$(dirname "$LANG_STATE")"
LANG_NOW=$(cat "$LANG_STATE" 2>/dev/null)
case "$LANG_NOW" in
    zh) ;;
    *) LANG_NOW="en" ;;
esac

# Accent color, straight from this rice's generated rofi palette (falls
# back if missing/not-yet-generated).
ACCENT=$(sed -n 's/^[[:space:]]*accent:[[:space:]]*\(#[0-9a-fA-F]\{6\}\).*/\1/p' "$COLORS_RASI" 2>/dev/null | head -n 1)

if [ "$LANG_NOW" = "zh" ]; then
    PROMPT="快捷鍵 (Alt+l 切換 EN)"
else
    PROMPT="Keybindings (Alt+l 切中文)"
fi

LIST=$(awk -v accent="${ACCENT:-#7aa2f7}" -v lang="$LANG_NOW" -v i18n="$I18N" '
    BEGIN {
        if (lang == "zh" && i18n != "") {
            while ((getline line < i18n) > 0) {
                n = index(line, "\t")
                if (n > 0) {
                    en = substr(line, 1, n - 1)
                    zh = substr(line, n + 1)
                    tr[en] = zh
                }
            }
            close(i18n)
        }
    }

    function xmlesc(s) {
        gsub(/&/, "\\&amp;", s)
        gsub(/</, "\\&lt;", s)
        gsub(/>/, "\\&gt;", s)
        return s
    }

    function tl(s) {
        if (lang == "zh" && (s in tr)) return tr[s]
        return s
    }

    # Section marker: # -- NAME -- #
    /^#[[:space:]]*--[[:space:]]+.+[[:space:]]+-- #[[:space:]]*$/ {
        sub(/^#[[:space:]]*--[[:space:]]+/, "")
        sub(/[[:space:]]+-- #[[:space:]]*$/, "")
        printf "<span size=\"110%%\" weight=\"bold\" foreground=\"%s\">── %s ──</span>\n", accent, xmlesc(tl($0))
        last = ""
        next
    }

    # Regular comment -> buffer as description
    /^#/ { sub(/^#[[:space:]]*/, ""); last = $0; next }

    # Keybind line (starts with a letter or a digit, e.g. XF86.../ Button3)
    /^[[:alnum:]]/ && last != "" { printf "<b>%-38s</b>  %s\n", xmlesc($0), xmlesc(tl(last)) }

    # Anything else (including a keybind just printed, or a blank line)
    # clears the buffer so a stray line never gets attached to the next one.
    { last = "" }
' "$KEYBINDS")

printf "%s\n" "$LIST" | rofi -dmenu -markup-rows -i -p "$PROMPT" \
    -config "$HOME/.config/rofi/config.rasi" \
    -theme-str 'window {width: 780px;} listview {lines: 16;} element {padding: 3px 10px;}' \
    -kb-custom-1 "Alt+l"
rc=$?

if [ "$rc" -eq 10 ]; then
    if [ "$LANG_NOW" = "zh" ]; then
        echo "en" > "$LANG_STATE"
    else
        echo "zh" > "$LANG_STATE"
    fi
    exec "$0"
fi
