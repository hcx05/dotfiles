#!/usr/bin/env bash
# Pinned quick-launch icons for mainbar inside a rounded pill (...),
# using Material Design Nerd Font icons matching hcx05/ArchDotfiles bar05.

source "$HOME/.config/rice/theme.conf"

PILL_L=$(python3 -c "print(chr(0xE0B6))")
PILL_R=$(python3 -c "print(chr(0xE0B4))")

APPS=(
  "F0239|firefox-esr"                                          # 󰈹 Firefox
  "F018D|kitty --config $HOME/.config/kitty/kitty.conf"        # 󰆍 Terminal
  "F00E4|burpsuite"                                            # 󰃤 Burp Suite
  "F140B|$HOME/Arsenal/ZAP_2.17.0/zap.sh"                      # 󱐋 ZAP
  "F1673|/usr/share/kali-menu/helper-scripts/wireshark.sh"     # 󱙳 Wireshark
  "F0DCF|thunar"                                               # 󰷏 Files
  "F0493|xfce4-settings-manager"                               # 󰒓 Settings
)

out="%{T4}%{F${BACKGROUND_ALT}}${PILL_L}%{F-}%{T-}%{B${BACKGROUND_ALT}}"
for entry in "${APPS[@]}"; do
    icon_hex="${entry%%|*}"
    cmd="${entry#*|}"
    icon=$(python3 -c "print(chr(0x$icon_hex))")
    out+="%{A1:$cmd & disown:}%{T3}%{F${FOREGROUND}} ${icon} %{F-}%{T-}%{A}"
done
out+="%{B-}%{T4}%{F${BACKGROUND_ALT}}${PILL_R}%{F-}%{T-}"
echo "$out"
