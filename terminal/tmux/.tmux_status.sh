#!/bin/bash

# ===== 1) CPU =====
read cpu a b c idle rest < /proc/stat
prev_idle=$idle
prev_total=$((a+b+c+idle))
sleep 0.2
read cpu a b c idle rest < /proc/stat
total=$((a+b+c+idle))
diff_idle=$((idle-prev_idle))
diff_total=$((total-prev_total))
cpu=$((100*(diff_total-diff_idle)/diff_total))

# ===== 2) RAM =====
ram_used=$(free | awk '/Mem:/ {print $3}')
ram_total=$(free | awk '/Mem:/ {print $2}')
ram=$((100*ram_used/ram_total))

# ===== 3) LOAD =====
load=$(awk '{print $1}' /proc/loadavg)

# ===== 4) IP =====
ip=$(hostname -I | awk '{print $1}')
[ -z "$ip" ] && ip="offline"

# ===== 5) TIME =====
time=$(date +%H:%M)

# ===== mono 主題：沒有底色，白字用 | 隔開 =====
# 目前主題的終端機風格由 ~/.config/rice/apply-theme.sh 寫入，切換主題後
# 下一次刷新 (status-interval 1) 就會換過來。
style=$(cat "$HOME/.config/rice/terminal-style" 2>/dev/null)
if [ "$style" = "mono" ]; then
    printf "#[fg=white,bg=default] %s | CPU %s%% | RAM %s%% | LOAD %s | %s | %s " \
        "$(whoami)" "$cpu" "$ram" "$load" "$time" "$ip"
    exit 0
fi

# ===== Powerline 分隔符 =====
SEP=""

# ===== 科技深色（藍 → 紫 漸層）=====
U_BG="10"    ; U_FG="232"
CPU_BG="87"    ; CPU_FG="232"
RAM_BG="81"    ; RAM_FG="232"
LOAD_BG="147"   ; LOAD_FG="232"
TIME_BG="183"   ; TIME_FG="232"
IP_BG="141"     ; IP_FG="232"
BASE_BG="black"
BASE_FG="white"

printf "#[bg=colour%s,fg=colour%s] %s \
#[fg=colour%s,bg=colour%s]%s\
#[bg=colour%s,fg=colour%s] CPU %s%% \
#[fg=colour%s,bg=colour%s]%s\
#[bg=colour%s,fg=colour%s] RAM %s%% \
#[fg=colour%s,bg=colour%s]%s\
#[bg=colour%s,fg=colour%s] LOAD %s \
#[fg=colour%s,bg=colour%s]%s\
#[bg=colour%s,fg=colour%s] %s \
#[fg=colour%s,bg=colour%s]%s\
#[bg=colour%s,fg=colour%s] %s \
#[bg=%s,fg=%s] \
" \
"$U_BG" "$U_FG" "$(whoami)" \
"$U_BG" "$CPU_BG" "$SEP" \
"$CPU_BG" "$CPU_FG" "$cpu" \
"$CPU_BG" "$RAM_BG" "$SEP" \
"$RAM_BG" "$RAM_FG" "$ram" \
"$RAM_BG" "$LOAD_BG" "$SEP" \
"$LOAD_BG" "$LOAD_FG" "$load" \
"$LOAD_BG" "$TIME_BG" "$SEP" \
"$TIME_BG" "$TIME_FG" "$time" \
"$TIME_BG" "$IP_BG" "$SEP" \
"$IP_BG" "$IP_FG" "$ip" \
"$BASE_BG" "$BASE_FG"
