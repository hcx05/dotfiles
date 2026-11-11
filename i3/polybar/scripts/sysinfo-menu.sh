#!/usr/bin/env bash
# Themed Rofi System Telemetry & Disk menu with EN / ZH toggle (Alt+l).
# Shares language state with ~/.config/i3/help.sh via ~/.cache/i3-help-lang.

set -u

if [ $# -le 1 ] && pgrep -x rofi >/dev/null 2>&1; then
    pkill -x rofi
    exit 0
fi

source "$HOME/.config/rice/theme.conf" 2>/dev/null
ACCENT="${ACCENT:-#FFFFFF}"
FG_ALT="${FOREGROUND_ALT:-#8A8A8A}"
LANG_STATE="$HOME/.cache/i3-help-lang"
mkdir -p "$(dirname "$LANG_STATE")"

MODE="${1:-cpu}"

while true; do
    LANG_NOW=$(cat "$LANG_STATE" 2>/dev/null || true)
    [ "$LANG_NOW" = "zh" ] || LANG_NOW="en"

    if [ "$MODE" = "disk" ]; then
        DISK_INFO=$(df -h / /home 2>/dev/null | awk 'NR==1 || !seen[$1]++ {printf "%-14s %6s / %-6s (%s)\n", $6, $3, $2, $5}')
        if [ "$LANG_NOW" = "zh" ]; then
            PROMPT="  磁碟資訊 (Alt+l 切換 EN)"
            MESG="<span foreground=\"${ACCENT}\" weight=\"bold\">  磁碟空間狀態</span>
<span foreground=\"${FG_ALT}\">────────────────────────────────────────────</span>
<tt>${DISK_INFO}</tt>"
            OPT_BTOP="  開啟系統監控儀表板 (btop)"
            OPT_HOME="  開啟家目錄 (~)"
            OPT_ROOT="  開啟根目錄 (/)"
            OPT_CLEAN="🗑️  查看暫存目錄大小 (du -sh /tmp)"
            OPT_LANG="🌐  切換為英文 (Alt+l)"
        else
            PROMPT="  Disk Usage (Alt+l 切中文)"
            MESG="<span foreground=\"${ACCENT}\" weight=\"bold\">  Filesystem &amp; Disk Usage</span>
<span foreground=\"${FG_ALT}\">────────────────────────────────────────────</span>
<tt>${DISK_INFO}</tt>"
            OPT_BTOP="  Open System Monitor (btop)"
            OPT_HOME="  Open Home Directory (~)"
            OPT_ROOT="  Open Root Directory (/)"
            OPT_CLEAN="🗑️  Check Temp Directory Size (du -sh /tmp)"
            OPT_LANG="🌐  Switch to 中文 (Alt+l)"
        fi

        CHOICE=$(printf '%s\n%s\n%s\n%s\n%s\n' "$OPT_BTOP" "$OPT_HOME" "$OPT_ROOT" "$OPT_CLEAN" "$OPT_LANG" | rofi -dmenu -i \
            -p "$PROMPT" \
            -mesg "$MESG" \
            -kb-custom-1 "Alt+l" \
            -config "$HOME/.config/rofi/config.rasi" \
            -theme-str 'window {width: 480px;} inputbar {enabled: false;} listview {lines: 5; spacing: 4px;}')
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
            "$OPT_BTOP")  kitty --title "btop" -e btop & exit 0 ;;
            "$OPT_HOME")  thunar "$HOME" & exit 0 ;;
            "$OPT_ROOT")  thunar / & exit 0 ;;
            "$OPT_CLEAN")
                TMP_SIZE=$(du -sh /tmp 2>/dev/null | awk '{print $1}')
                if [ "$LANG_NOW" = "zh" ]; then
                    dunstify -a "sysinfo" -r 99108 -u low -t 2000 "  暫存空間" "/tmp 目前使用：${TMP_SIZE:-0B}" 2>/dev/null || true
                else
                    dunstify -a "sysinfo" -r 99108 -u low -t 2000 "  Temp Usage" "/tmp currently uses: ${TMP_SIZE:-0B}" 2>/dev/null || true
                fi
                exit 0
                ;;
        esac
    fi

    # CPU / RAM telemetry mode
    UPTIME_STR=$(uptime -p 2>/dev/null | sed 's/^up //')
    LOAD_STR=$(awk '{print $1, $2, $3}' /proc/loadavg 2>/dev/null)

    if [ "$LANG_NOW" = "zh" ]; then
        MEM_STR=$(free -h 2>/dev/null | awk '/^Mem:/ {printf "%s / %s (可用 %s)", $3, $2, $7}')
        PROMPT="  系統監控 (Alt+l 切換 EN)"
        if [ "$MODE" = "mem" ]; then
            SORT_KEY="-%mem"
            TITLE="󰍛  記憶體與高佔用程序"
        else
            SORT_KEY="-%cpu"
            TITLE="  處理器與高佔用程序"
        fi
        MESG="<span foreground=\"${ACCENT}\" weight=\"bold\">${TITLE}</span>
<span foreground=\"${FG_ALT}\">────────────────────────────────────────────────</span>
系統負載 (Load): <b>${LOAD_STR}</b>   │   運行時間: <b>${UPTIME_STR}</b>
記憶體 (RAM):    <span foreground=\"${ACCENT}\" weight=\"bold\">${MEM_STR}</span>"
        OPT_BTOP="  開啟完整系統監控儀表板 (btop)"
        OPT_HTOP="  開啟程序管理器 (htop)"
        OPT_LANG="🌐  切換為英文 (Alt+l)"
    else
        MEM_STR=$(free -h 2>/dev/null | awk '/^Mem:/ {printf "%s / %s (Avail %s)", $3, $2, $7}')
        PROMPT="  System Monitor (Alt+l 切中文)"
        if [ "$MODE" = "mem" ]; then
            SORT_KEY="-%mem"
            TITLE="󰍛  Memory &amp; Top Processes"
        else
            SORT_KEY="-%cpu"
            TITLE="  CPU &amp; Top Processes"
        fi
        MESG="<span foreground=\"${ACCENT}\" weight=\"bold\">${TITLE}</span>
<span foreground=\"${FG_ALT}\">────────────────────────────────────────────────</span>
Load Avg: <b>${LOAD_STR}</b>   │   Uptime: <b>${UPTIME_STR}</b>
Memory:   <span foreground=\"${ACCENT}\" weight=\"bold\">${MEM_STR}</span>"
        OPT_BTOP="  Open Full System Monitor (btop)"
        OPT_HTOP="  Open Process Viewer (htop)"
        OPT_LANG="🌐  Switch to 中文 (Alt+l)"
    fi

    mapfile -t TOP_PROCS < <(ps -eo pid,comm,%cpu,%mem --sort="$SORT_KEY" 2>/dev/null | awk 'NR>1 && NR<=6 {printf "  PID %-6s  %-18s  CPU: %5s%%   MEM: %5s%%\n", $1, $2, $3, $4}')

    CHOICE=$(printf '%s\n%s\n%s\n%s\n' "$OPT_BTOP" "$OPT_HTOP" "$OPT_LANG" "$(printf '%s\n' "${TOP_PROCS[@]}")" | rofi -dmenu -i \
        -p "$PROMPT" \
        -mesg "$MESG" \
        -kb-custom-1 "Alt+l" \
        -config "$HOME/.config/rofi/config.rasi" \
        -theme-str 'window {width: 520px;} inputbar {enabled: false;} listview {lines: 8; spacing: 4px;}')
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
        "$OPT_BTOP") kitty --title "btop" -e btop & exit 0 ;;
        "$OPT_HTOP") kitty --title "htop" -e htop & exit 0 ;;
        "  PID "*)
            PID=$(awk '{print $3}' <<<"$CHOICE")
            PNAME=$(awk '{print $4}' <<<"$CHOICE")
            if [ "$LANG_NOW" = "zh" ]; then
                KILL_OPT="🗑️  強制結束程序 ${PNAME} (PID ${PID})"
                BACK_OPT="↩️  取消"
                KILL_PROMPT="  程序操作"
                NOTIFY_KILL="  已結束程序"
            else
                KILL_OPT="🗑️  Terminate Process ${PNAME} (PID ${PID})"
                BACK_OPT="↩️  Cancel"
                KILL_PROMPT="  Process Action"
                NOTIFY_KILL="  Process Terminated"
            fi
            CONFIRM=$(printf '%s\n%s\n' "$KILL_OPT" "$BACK_OPT" | rofi -dmenu -i \
                -p "$KILL_PROMPT" \
                -config "$HOME/.config/rofi/config.rasi" \
                -theme-str 'window {width: 420px;} inputbar {enabled: false;} listview {lines: 2;}')
            if [ "$CONFIRM" = "$KILL_OPT" ]; then
                kill -15 "$PID" 2>/dev/null || kill -9 "$PID" 2>/dev/null || true
                dunstify -a "sysinfo" -r 99108 -u low -t 1500 "$NOTIFY_KILL" "${PNAME} (PID ${PID})" 2>/dev/null || true
            fi
            exit 0
            ;;
    esac
done
