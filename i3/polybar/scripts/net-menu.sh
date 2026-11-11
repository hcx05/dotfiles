#!/usr/bin/env bash
# Themed Rofi Network & VPN menu with EN / ZH toggle (Alt+l).
# Shares language state with ~/.config/i3/help.sh via ~/.cache/i3-help-lang.

set -u

if [ $# -eq 0 ] && pgrep -x rofi >/dev/null 2>&1; then
    pkill -x rofi
    exit 0
fi

source "$HOME/.config/rice/theme.conf" 2>/dev/null
ACCENT="${ACCENT:-#FFFFFF}"
FG_ALT="${FOREGROUND_ALT:-#8A8A8A}"
LANG_STATE="$HOME/.cache/i3-help-lang"
mkdir -p "$(dirname "$LANG_STATE")"

while true; do
    LANG_NOW=$(cat "$LANG_STATE" 2>/dev/null || true)
    [ "$LANG_NOW" = "zh" ] || LANG_NOW="en"

    DEF_IFACE=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
    LOCAL_IP="--"
    GW_IP="--"
    if [ -n "$DEF_IFACE" ]; then
        LOCAL_IP=$(ip -4 -o addr show dev "$DEF_IFACE" 2>/dev/null | awk '{sub(/\/.*/, "", $4); print $4; exit}')
        GW_IP=$(ip route show default 2>/dev/null | awk '{print $3; exit}')
    fi

    VPN_IFACE=$(ip -o link show up 2>/dev/null | awk -F': ' '$2 ~ /^(tun|tap|wg|ppp)/{print $2; exit}')
    VPN_IP="--"
    if [ -n "$VPN_IFACE" ]; then
        VPN_IP=$(ip -4 -o addr show dev "$VPN_IFACE" 2>/dev/null | awk '{sub(/\/.*/, "", $4); print $4; exit}')
        VPN_STATUS="<span foreground=\"${ACCENT}\" weight=\"bold\">  Connected (${VPN_IFACE}: ${VPN_IP})</span>"
    else
        VPN_STATUS="<span foreground=\"${FG_ALT}\">  Disconnected</span>"
    fi

    if [ "$LANG_NOW" = "zh" ]; then
        PROMPT="󰈀  網路中心 (Alt+l 切換 EN)"
        MESG="<span foreground=\"${ACCENT}\" weight=\"bold\">󰈀  網路與 VPN 狀態</span>
<span foreground=\"${FG_ALT}\">────────────────────────────────────────</span>
介面 (Interface):  <b>${DEF_IFACE:-未連線}</b>
內網 IP (LAN IP):  <span foreground=\"${ACCENT}\" weight=\"bold\">${LOCAL_IP:-N/A}</span>   (Gateway: ${GW_IP:-N/A})
VPN 狀態 (VPN):    ${VPN_STATUS}"
        OPT_COPY_LAN="  複製內網 IP (${LOCAL_IP:-N/A}) 到剪貼簿"
        OPT_COPY_VPN="  複製 VPN IP (${VPN_IP:-N/A}) 到剪貼簿"
        OPT_NMTUI="  開啟終端機網路管理 (nmtui)"
        OPT_RECONNECT="  重新連線目前網路 (${DEF_IFACE:-eth0})"
        OPT_PING="󰓅  測試外部網路連線 (Ping 1.1.1.1)"
        OPT_LANG="🌐  切換為英文 (Alt+l)"
    else
        PROMPT="󰈀  Network (Alt+l 切中文)"
        MESG="<span foreground=\"${ACCENT}\" weight=\"bold\">󰈀  Network &amp; VPN Status</span>
<span foreground=\"${FG_ALT}\">────────────────────────────────────────</span>
Interface:   <b>${DEF_IFACE:-Disconnected}</b>
LAN IP:      <span foreground=\"${ACCENT}\" weight=\"bold\">${LOCAL_IP:-N/A}</span>   (Gateway: ${GW_IP:-N/A})
VPN Status:  ${VPN_STATUS}"
        OPT_COPY_LAN="  Copy LAN IP (${LOCAL_IP:-N/A}) to Clipboard"
        OPT_COPY_VPN="  Copy VPN IP (${VPN_IP:-N/A}) to Clipboard"
        OPT_NMTUI="  Open Network Manager TUI (nmtui)"
        OPT_RECONNECT="  Reconnect Interface (${DEF_IFACE:-eth0})"
        OPT_PING="󰓅  Ping External Network (1.1.1.1)"
        OPT_LANG="🌐  Switch to 中文 (Alt+l)"
    fi

    CHOICE=$(printf '%s\n%s\n%s\n%s\n%s\n%s\n' \
        "$OPT_COPY_LAN" \
        "$OPT_COPY_VPN" \
        "$OPT_NMTUI" \
        "$OPT_RECONNECT" \
        "$OPT_PING" \
        "$OPT_LANG" | rofi -dmenu -i \
        -p "$PROMPT" \
        -mesg "$MESG" \
        -kb-custom-1 "Alt+l" \
        -config "$HOME/.config/rofi/config.rasi" \
        -theme-str 'window {width: 480px;} inputbar {enabled: false;} listview {lines: 6; spacing: 4px;}')
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
        "$OPT_COPY_LAN")
            if [ -n "$LOCAL_IP" ] && [ "$LOCAL_IP" != "--" ]; then
                printf '%s' "$LOCAL_IP" | xclip -selection clipboard
                if [ "$LANG_NOW" = "zh" ]; then
                    dunstify -a "network" -r 99107 -u low -t 1500 "  已複製內網 IP" "$LOCAL_IP" 2>/dev/null || true
                else
                    dunstify -a "network" -r 99107 -u low -t 1500 "  Copied LAN IP" "$LOCAL_IP" 2>/dev/null || true
                fi
            fi
            exit 0
            ;;
        "$OPT_COPY_VPN")
            if [ -n "$VPN_IP" ] && [ "$VPN_IP" != "--" ]; then
                printf '%s' "$VPN_IP" | xclip -selection clipboard
                if [ "$LANG_NOW" = "zh" ]; then
                    dunstify -a "network" -r 99107 -u low -t 1500 "  已複製 VPN IP" "$VPN_IP" 2>/dev/null || true
                else
                    dunstify -a "network" -r 99107 -u low -t 1500 "  Copied VPN IP" "$VPN_IP" 2>/dev/null || true
                fi
            else
                if [ "$LANG_NOW" = "zh" ]; then
                    dunstify -a "network" -r 99107 -u low -t 1500 "  VPN 未連線" "目前沒有啟用的 tun/wg 介面" 2>/dev/null || true
                else
                    dunstify -a "network" -r 99107 -u low -t 1500 "  VPN Disconnected" "No active tun/wg interface" 2>/dev/null || true
                fi
            fi
            exit 0
            ;;
        "$OPT_NMTUI")
            kitty --title "Network Manager (nmtui)" -e nmtui &
            exit 0
            ;;
        "$OPT_RECONNECT")
            if [ -n "$DEF_IFACE" ]; then
                nmcli device reapply "$DEF_IFACE" 2>/dev/null || nmcli device connect "$DEF_IFACE" 2>/dev/null || true
                if [ "$LANG_NOW" = "zh" ]; then
                    dunstify -a "network" -r 99107 -u low -t 1500 "  已重新整理網路" "介面：$DEF_IFACE" 2>/dev/null || true
                else
                    dunstify -a "network" -r 99107 -u low -t 1500 "  Network Reconnected" "Interface: $DEF_IFACE" 2>/dev/null || true
                fi
            fi
            exit 0
            ;;
        "$OPT_PING")
            if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
                RTT=$(ping -c 1 -W 2 1.1.1.1 | awk -F'time=' '/time=/{print $2}')
                if [ "$LANG_NOW" = "zh" ]; then
                    dunstify -a "network" -r 99107 -u low -t 2000 "󰓅  外部網路連線正常" "1.1.1.1 回應時間：${RTT}" 2>/dev/null || true
                else
                    dunstify -a "network" -r 99107 -u low -t 2000 "󰓅  External Network OK" "1.1.1.1 latency: ${RTT}" 2>/dev/null || true
                fi
            else
                if [ "$LANG_NOW" = "zh" ]; then
                    dunstify -a "network" -r 99107 -u critical -t 2000 "󰖪  無法連上外部網路" "Ping 1.1.1.1 失敗" 2>/dev/null || true
                else
                    dunstify -a "network" -r 99107 -u critical -t 2000 "󰖪  Network Unreachable" "Ping 1.1.1.1 failed" 2>/dev/null || true
                fi
            fi
            exit 0
            ;;
    esac
done
