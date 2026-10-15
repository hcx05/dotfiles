#!/usr/bin/env python3
# ============================================================================
# clipmenu.py -- clipboard history picker for the i3 rice (bound to $mod+c).
#
# Shows a rofi menu, styled via ~/.config/rofi/config.rasi so it follows the
# active theme automatically (no regen needed). The list unifies BOTH
# clipboard sources this setup uses:
#   - X CLIPBOARD history recorded by clipd.py (kitty ctrl+shift+c, flameshot,
#     tmux-yank all push here)
#   - current tmux buffers (prefix+], tmux-yank history) not already seen
#
# Picking an entry loads it into the X CLIPBOARD + PRIMARY selections (and a
# tmux buffer), then PASTES it straight into the window you were in when you
# opened the menu -- select-and-paste, not just copy. It re-focuses that
# window and sends its paste shortcut: ctrl+shift+v for terminals (kitty,
# etc.), ctrl+v for everything else.
#
# The clipboard load happens first and stays, so if the auto-paste keystroke
# ever misses (unknown window class, xdotool missing), a manual paste still
# works and nothing is lost.
#
# Glyph codepoints below are all verified present in JetBrainsMono Nerd Font
# (see the rice memory: raw PUA glyphs pasted by hand silently vanish, so
# they're built from chr() instead).
# ============================================================================
import base64
import os
import subprocess

HOME = os.path.expanduser("~")
HISTORY = os.path.join(HOME, ".cache", "cliprice", "history")
ROFI_CONFIG = os.path.join(HOME, ".config", "rofi", "config.rasi")

MAX_TMUX_BUFFERS = 40     # how many recent tmux buffers to fold in
PREVIEW_LEN = 90          # chars shown per row before truncation

ICO_CLIP = chr(0xF0C5)    # copy pages -- an X-clipboard history entry
ICO_TMUX = chr(0xEBC8)    # tmux logo    -- a tmux buffer entry
ICO_CLEAR = chr(0xF1F8)   # trash        -- clear history action
ICO_PROMPT = chr(0xF0EA)  # clipboard    -- rofi prompt


def load_history():
    if not os.path.exists(HISTORY):
        return []
    out = []
    with open(HISTORY, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                out.append(base64.b64decode(line).decode("utf-8"))
            except Exception:
                continue
    return out


def load_tmux_buffers():
    """Recent tmux buffer contents, newest first; [] if no server."""
    try:
        names = subprocess.run(
            ["tmux", "list-buffers", "-F", "#{buffer_name}"],
            capture_output=True, text=True, timeout=2,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return []
    if names.returncode != 0:
        return []
    bufs = []
    for name in names.stdout.splitlines()[:MAX_TMUX_BUFFERS]:
        name = name.strip()
        if not name:
            continue
        try:
            content = subprocess.run(
                ["tmux", "show-buffer", "-b", name],
                capture_output=True, text=True, timeout=2,
            )
        except subprocess.TimeoutExpired:
            continue
        if content.returncode == 0 and content.stdout.strip():
            bufs.append(content.stdout)
    return bufs


def preview(text):
    """One-line, display-safe rendering of a clip for the rofi row."""
    flat = " ".join(text.split())        # collapse all whitespace/newlines
    multiline = "\n" in text.strip()
    if len(flat) > PREVIEW_LEN:
        flat = flat[:PREVIEW_LEN].rstrip() + "…"
    if multiline:
        flat = "⏎ " + flat                # hint that the real clip has newlines
    return flat or "(whitespace)"


# Window classes that paste with ctrl+shift+v instead of plain ctrl+v.
# Terminals almost universally reserve ctrl+v for other things and use
# ctrl+shift+v for paste (kitty here is configured for both, but other
# terminals aren't, so the shift form is the safe default for a terminal).
TERMINAL_CLASSES = {
    "kitty", "xterm", "uxterm", "alacritty", "st", "stterm",
    "urxvt", "rxvt", "qterminal", "xfce4-terminal", "gnome-terminal",
    "konsole", "terminator", "tilix", "wezterm", "foot",
}


def active_window_id():
    """ID of the currently focused window, or None."""
    try:
        r = subprocess.run(["xdotool", "getactivewindow"],
                           capture_output=True, text=True, timeout=2)
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None
    wid = r.stdout.strip()
    return wid if r.returncode == 0 and wid else None


def window_class(wid):
    try:
        r = subprocess.run(["xdotool", "getwindowclassname", wid],
                           capture_output=True, text=True, timeout=2)
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return ""
    return r.stdout.strip().lower() if r.returncode == 0 else ""


def push_clipboard(text):
    """Load the clip into both X selections (+ tmux buffer) so any paste
    path can reach it -- this is the source the auto-paste keystroke uses,
    and it stays available for a manual paste if the keystroke is missed."""
    data = text.encode("utf-8")
    for sel in ("clipboard", "primary"):
        subprocess.run(["xclip", "-selection", sel, "-i"], input=data)
    try:
        subprocess.run(["tmux", "load-buffer", "-"], input=data, timeout=2)
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass


def paste_into(wid):
    """Re-focus the window that was active when the menu opened and send its
    paste shortcut. Terminals -> ctrl+shift+v, everything else -> ctrl+v.
    If xdotool isn't available or the window is gone, we silently skip --
    the clip is already on the clipboard, so a manual paste still works."""
    if not wid:
        return False
    cls = window_class(wid)
    key = "ctrl+shift+v" if cls in TERMINAL_CLASSES else "ctrl+v"
    try:
        # --sync waits for the window to actually be active before we type,
        # so the keystroke can't race ahead of the focus change.
        subprocess.run(["xdotool", "windowactivate", "--sync", wid], timeout=3)
        subprocess.run(["xdotool", "key", "--clearmodifiers", key], timeout=3)
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False
    return True


def notify(msg):
    subprocess.run(["notify-send", "-t", "1500", "Clipboard", msg],
                   stderr=subprocess.DEVNULL)


def run_rofi(lines, prompt):
    """Return the 0-based index rofi selected, or None if cancelled."""
    proc = subprocess.run(
        ["rofi", "-dmenu", "-i", "-format", "i",
         "-config", ROFI_CONFIG,
         "-p", prompt,
         "-theme-str", "window {width: 760px;} listview {lines: 12;}"],
        input="\n".join(lines), capture_output=True, text=True,
    )
    sel = proc.stdout.strip()
    if proc.returncode != 0 or sel == "":
        return None
    try:
        return int(sel)
    except ValueError:
        return None


def main():
    # Grab the paste target NOW, before rofi steals focus -- this is the
    # window you were in when you pressed $mod+c, and where the clip goes.
    target_win = active_window_id()

    history = load_history()
    tmux_bufs = load_tmux_buffers()

    # Merge: history first (what clipd recorded), then tmux buffers that
    # aren't already represented. Dedup preserves order.
    seen = set()
    items = []   # list of (kind, text)
    for t in history:
        if t not in seen:
            seen.add(t)
            items.append(("clip", t))
    for t in tmux_bufs:
        if t not in seen:
            seen.add(t)
            items.append(("tmux", t))

    lines = []
    for kind, text in items:
        ico = ICO_CLIP if kind == "clip" else ICO_TMUX
        lines.append(f"  {ico}  {preview(text)}")

    clear_index = len(items)   # appended last
    if items:
        lines.append(f"  {ICO_CLEAR}  Clear clipboard history")
        prompt = f"{ICO_PROMPT} Clipboard"
    else:
        lines = [f"  {ICO_PROMPT}  (clipboard history empty)"]
        prompt = f"{ICO_PROMPT} Clipboard"

    idx = run_rofi(lines, prompt)
    if idx is None:
        return
    if not items:
        return
    if idx == clear_index:
        open(HISTORY, "w").close()
        notify(f"{ICO_CLEAR}  history cleared")
        return
    if 0 <= idx < len(items):
        _, text = items[idx]
        push_clipboard(text)
        pasted = paste_into(target_win)
        verb = "pasted" if pasted else "copied"
        notify(f"{verb}  {preview(text)}")


if __name__ == "__main__":
    main()
