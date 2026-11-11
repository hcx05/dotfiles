#!/usr/bin/env bash
# Interactive Calendar & Schedule/Agenda in Rofi with EN / ZH toggle (Alt+l).
# Shares language state with ~/.config/i3/help.sh via ~/.cache/i3-help-lang.

set -u

# If Rofi is already open and no args were passed, toggle it closed
if [ $# -eq 0 ] && pgrep -x rofi >/dev/null 2>&1; then
    pkill -x rofi
    exit 0
fi

source "$HOME/.config/rice/theme.conf" 2>/dev/null
ACCENT="${ACCENT:-#FFFFFF}"
FG="${FOREGROUND:-#E8E8E8}"
FG_ALT="${FOREGROUND_ALT:-#8A8A8A}"
URGENT="${URGENT:-#FF1855}"

EVENTS_FILE="$HOME/.config/rice/calendar-events.txt"
LANG_STATE="$HOME/.cache/i3-help-lang"
mkdir -p "$(dirname "$EVENTS_FILE")" "$(dirname "$LANG_STATE")"
touch "$EVENTS_FILE"

OFFSET="${1:-0}"

get_lang() {
    local l
    l=$(cat "$LANG_STATE" 2>/dev/null || true)
    case "$l" in
        zh) echo "zh" ;;
        *)  echo "en" ;;
    esac
}

toggle_lang() {
    if [ "$(get_lang)" = "zh" ]; then
        echo "en" > "$LANG_STATE"
    else
        echo "zh" > "$LANG_STATE"
    fi
}

while true; do
    LANG_NOW=$(get_lang)

    CAL_MARKUP=$(python3 - "$OFFSET" "$ACCENT" "$FG" "$FG_ALT" "$URGENT" "$EVENTS_FILE" "$LANG_NOW" <<'PY'
import calendar
import datetime
import sys

offset = int(sys.argv[1])
accent = sys.argv[2]
fg = sys.argv[3]
fg_alt = sys.argv[4]
urgent = sys.argv[5]
events_file = sys.argv[6]
lang = sys.argv[7]

today = datetime.date.today()
total_months = (today.year * 12 + (today.month - 1)) + offset
year = total_months // 12
month = (total_months % 12) + 1

event_days = set()
try:
    with open(events_file, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("|", 1)
            try:
                dt = datetime.date.fromisoformat(parts[0].strip())
                if dt.year == year and dt.month == month:
                    event_days.add(dt.day)
            except ValueError:
                pass
except Exception:
    pass

cal = calendar.TextCalendar(calendar.MONDAY)
weekdays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
now_str = datetime.datetime.now().strftime("%Y-%m-%d (%a) %H:%M")

lines = []
if lang == "zh":
    title = f"{year} 年 {month:02d} 月"
else:
    title = f"{calendar.month_name[month]} {year}"

lines.append(f'<span foreground="{accent}" weight="bold" size="large">  {title}</span>   <span foreground="{fg_alt}" size="small">({now_str})</span>')
lines.append(f'<span foreground="{fg_alt}">───────────────────────────────────</span>')

header_cells = []
for i, wd in enumerate(weekdays):
    color = urgent if i >= 5 else accent
    header_cells.append(f'<span foreground="{color}" weight="bold"> {wd} </span>')
lines.append(" ".join(header_cells))

for week in cal.monthdayscalendar(year, month):
    row = []
    for i, day in enumerate(week):
        if day == 0:
            row.append("    ")
        else:
            is_today = (year == today.year and month == today.month and day == today.day)
            has_event = (day in event_days)
            marker = "•" if has_event else " "
            if is_today:
                cell = f'<span background="{accent}" foreground="#0A0A0A" weight="bold">[{day:2d}]</span>'
            elif has_event:
                cell = f'<span foreground="{accent}" weight="bold"> {day:2d}{marker}</span>'
            elif i >= 5:
                cell = f'<span foreground="{fg_alt}"> {day:2d} </span>'
            else:
                cell = f'<span foreground="{fg}"> {day:2d} </span>'
            row.append(cell)
    lines.append(" ".join(row))

print("\n".join(lines))
PY
)

    if [ "$LANG_NOW" = "zh" ]; then
        PROMPT="  日曆 (Alt+l 切換 EN)"
        OPT_ADD="  新增行事曆 / 備忘"
        OPT_PREV="◀  上個月"
        OPT_TODAY="●  回到本月"
        OPT_NEXT="▶  下個月"
        OPT_LANG="🌐  切換為英文 (Alt+l)"
        EMPTY_MSG="  (尚無行程 — 點擊上方「新增行事曆」建立備忘)"
    else
        PROMPT="  Calendar (Alt+l 切中文)"
        OPT_ADD="  Add Event / Reminder"
        OPT_PREV="◀  Previous Month"
        OPT_TODAY="●  Current Month"
        OPT_NEXT="▶  Next Month"
        OPT_LANG="🌐  Switch to 中文 (Alt+l)"
        EMPTY_MSG="  (No scheduled events — click 'Add Event' above)"
    fi

    mapfile -t EVENT_LINES < <(grep -v '^[[:space:]]*$' "$EVENTS_FILE" 2>/dev/null | sort)

    MENU_ITEMS=("$OPT_ADD" "$OPT_PREV" "$OPT_TODAY" "$OPT_NEXT" "$OPT_LANG")
    if [ "${#EVENT_LINES[@]}" -gt 0 ]; then
        for ev in "${EVENT_LINES[@]}"; do
            DATE_PART="${ev%%|*}"
            NOTE_PART="${ev#*|}"
            MENU_ITEMS+=("  ${DATE_PART}  │  ${NOTE_PART}")
        done
    else
        MENU_ITEMS+=("$EMPTY_MSG")
    fi

    CHOICE=$(printf '%s\n' "${MENU_ITEMS[@]}" | rofi -dmenu -i \
        -p "$PROMPT" \
        -mesg "$CAL_MARKUP" \
        -kb-custom-1 "Alt+l" \
        -config "$HOME/.config/rofi/config.rasi" \
        -theme-str 'window {width: 460px;} inputbar {enabled: false;} message {padding: 12px 16px;} listview {lines: 8; spacing: 4px;}')
    rc=$?

    if [ "$rc" -eq 10 ]; then
        toggle_lang
        continue
    fi

    [ -z "$CHOICE" ] && exit 0

    case "$CHOICE" in
        "$OPT_LANG")
            toggle_lang
            ;;
        "$OPT_PREV")
            OFFSET=$((OFFSET - 1))
            ;;
        "$OPT_TODAY")
            OFFSET=0
            ;;
        "$OPT_NEXT")
            OFFSET=$((OFFSET + 1))
            ;;
        "$OPT_ADD")
            DEFAULT_DATE=$(python3 - "$OFFSET" <<'PY'
import datetime, sys
offset = int(sys.argv[1])
today = datetime.date.today()
if offset == 0:
    print(today.isoformat())
else:
    total = (today.year * 12 + (today.month - 1)) + offset
    print(f"{total // 12}-{(total % 12) + 1:02d}-01")
PY
)
            if [ "$LANG_NOW" = "zh" ]; then
                ADD_PROMPT="  新增行程"
                ADD_MESG="輸入格式：<span foreground=\"${ACCENT}\">YYYY-MM-DD 行程內容</span>（預設日期：${DEFAULT_DATE}）"
                NOTIFY_ADD="  已新增行事曆"
            else
                ADD_PROMPT="  Add Event"
                ADD_MESG="Format: <span foreground=\"${ACCENT}\">YYYY-MM-DD Event note</span> (Default: ${DEFAULT_DATE})"
                NOTIFY_ADD="  Event Added"
            fi
            NEW_ENTRY=$(rofi -dmenu \
                -p "$ADD_PROMPT" \
                -mesg "$ADD_MESG" \
                -filter "${DEFAULT_DATE} " \
                -config "$HOME/.config/rofi/config.rasi" \
                -theme-str 'window {width: 480px;} listview {enabled: false;}')
            NEW_ENTRY="$(echo "$NEW_ENTRY" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            if [ -n "$NEW_ENTRY" ]; then
                if [[ "$NEW_ENTRY" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})[[:space:]]+(.+)$ ]]; then
                    EV_DATE="${BASH_REMATCH[1]}"
                    EV_NOTE="${BASH_REMATCH[2]}"
                else
                    EV_DATE="$DEFAULT_DATE"
                    EV_NOTE="$NEW_ENTRY"
                fi
                echo "${EV_DATE}|${EV_NOTE}" >> "$EVENTS_FILE"
                dunstify -a "calendar" -r 99106 -u low -t 1800 "$NOTIFY_ADD" "${EV_DATE} — ${EV_NOTE}" 2>/dev/null || true
            fi
            ;;
        "  "*)
            RAW_STR="${CHOICE#  }"
            EV_DATE="${RAW_STR%%  │  *}"
            EV_NOTE="${RAW_STR#*  │  }"
            if [ "$LANG_NOW" = "zh" ]; then
                DEL_OPT="🗑️  刪除此行程"
                BACK_OPT="↩️  返回日曆"
                DEL_PROMPT="  行程管理"
                DEL_MESG="行程：<span foreground=\"${ACCENT}\" weight=\"bold\">${EV_DATE}  ${EV_NOTE}</span>"
                NOTIFY_DEL="  已刪除行程"
            else
                DEL_OPT="🗑️  Delete Event"
                BACK_OPT="↩️  Back to Calendar"
                DEL_PROMPT="  Manage Event"
                DEL_MESG="Event: <span foreground=\"${ACCENT}\" weight=\"bold\">${EV_DATE}  ${EV_NOTE}</span>"
                NOTIFY_DEL="  Event Deleted"
            fi
            CONFIRM=$(printf '%s\n%s\n' "$DEL_OPT" "$BACK_OPT" | rofi -dmenu -i \
                -p "$DEL_PROMPT" \
                -mesg "$DEL_MESG" \
                -config "$HOME/.config/rofi/config.rasi" \
                -theme-str 'window {width: 420px;} inputbar {enabled: false;} listview {lines: 2;}')
            if [ "$CONFIRM" = "$DEL_OPT" ]; then
                TARGET="${EV_DATE}|${EV_NOTE}"
                grep -Fxv "$TARGET" "$EVENTS_FILE" > "${EVENTS_FILE}.tmp" 2>/dev/null || true
                mv "${EVENTS_FILE}.tmp" "$EVENTS_FILE"
                dunstify -a "calendar" -r 99106 -u low -t 1500 "$NOTIFY_DEL" "${EV_DATE} — ${EV_NOTE}" 2>/dev/null || true
            fi
            ;;
    esac
done
