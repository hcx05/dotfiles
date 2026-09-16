#!/usr/bin/env bash
# Pinned quick-launch icons for the top bar (browser, terminal, Burp, ...).
# Static list -- to pin more apps later, just add another line to APPS
# below: "verified_nerd_font_codepoint_hex|shell command to launch"
# (codepoints must be checked against the installed font first -- see
# ~/.config/rice/apply-theme.sh and the icon lesson in i3_rice_setup.md;
# don't paste raw glyphs by hand, they silently vanish).

source "$HOME/.config/rice/theme.conf"

APPS=(
  "F269|firefox-esr"                                          # fa-firefox
  "F120|kitty --config $HOME/.config/kitty/kitty.conf"          # fa-terminal
  "F188|burpsuite"                                              # fa-bug
  "F0E7|$HOME/Arsenal/ZAP_2.17.0/zap.sh"                        # fa-bolt (ZAP)
  "F002|/usr/share/kali-menu/helper-scripts/wireshark.sh"       # fa-search (Wireshark, via Kali's own launcher -- handles dumpcap perms)
  "F07B|thunar"                                                 # fa-folder (file manager)
  "F013|xfce4-settings-manager"                                 # fa-cog (Settings)
)

out=""
for entry in "${APPS[@]}"; do
    icon_hex="${entry%%|*}"
    cmd="${entry#*|}"
    icon=$(python3 -c "print(chr(0x$icon_hex))")
    out+="%{A1:$cmd & disown:}%{B${BACKGROUND_ALT}}%{F${FOREGROUND}}  ${icon}  %{F-}%{B-}%{A} "
done
echo "$out"
