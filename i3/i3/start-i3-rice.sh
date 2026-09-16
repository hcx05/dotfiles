#!/usr/bin/env bash
# Session wrapper for the i3 rice. Sets environment needed for consistent
# GTK/Qt theming and starts i3. Referenced by the i3-rice.desktop xsession
# entry -- does not affect the XFCE session or its environment.

export XDG_CURRENT_DESKTOP=i3
export XDG_SESSION_DESKTOP=i3
export QT_QPA_PLATFORMTHEME=qt5ct
export GTK_THEME=Kali-Purple-Dark

# kitty (GLFW backend) disables ibus IME input on Linux by default -- it's
# an opt-in-only design choice by upstream (see kitty changelog 0.19.x:
# "Do not enable IME input via ibus unless the GLFW_IM_MODULE=ibus
# environment variable is set. IME causes key processing latency and even
# missed keystrokes for many people, so it is now off by default."). This
# is unrelated to GTK_IM_MODULE/QT_IM_MODULE (those are for GTK/Qt apps;
# kitty is neither). Safe to leave set even for non-kitty children.
export GLFW_IM_MODULE=ibus

# Do NOT export XMODIFIERS/GTK_IM_MODULE/QT_IM_MODULE/CLUTTER_IM_MODULE here --
# im-launch (Debian/Kali's im-config wrapper) only sets them up and starts
# ibus-daemon if they are still unset when it runs. Pre-setting them would
# make it skip that step, same as the stock i3.desktop entry which is why
# ibus/pinyin never worked there. im-launch is a no-op passthrough if
# im-config isn't installed.
if command -v im-launch >/dev/null 2>&1; then
    exec im-launch i3
else
    exec i3
fi
