#!/usr/bin/env python3
"""Bottom taskbar for polybar: lists windows on the CURRENT workspace only
(plus anything minimized to the scratchpad, regardless of which workspace
it was minimized from, so it stays reachable) as a clickable entry, with
per-entry minimize / maximize / close buttons -- since i3 itself has no
titlebar button widgets (it's a keyboard-driven tiling WM, not an
architectural gap we can config our way around), these buttons live here
in the taskbar instead of on each window.

  click title   -> focus that window (un-hides it if it was scratchpad'd)
  click "_"     -> minimize: move window to the scratchpad (hidden)
  click "[]"    -> maximize: toggle fullscreen for that window
  click "x"     -> close the window

Run once at i3 startup (polybar module has tail=true); re-renders on every
window event (new/close/focus/title/move/fullscreen_mode/workspace switch).
"""
import glob
import i3ipc
import json
import os
import re
import subprocess

THEME_FILE = os.path.expanduser("~/.config/rice/theme.conf")
MAXIMIZE_STATE_FILE = os.path.expanduser("~/.cache/i3-maximize-state.json")

ICO_CLOSE = chr(0xF00D)     # fa-times, verified against installed font
ICO_MAXIMIZE = chr(0xF2D0)  # fa-window_maximize
ICO_RESTORE = chr(0xF2D2)   # fa-window_restore -- shown instead of
                             # ICO_MAXIMIZE once a window is maximized, so
                             # the button itself signals "click to undo"
                             # (same idea as Chrome's restore-down icon)
ICO_MINIMIZE = chr(0xF2D1)  # fa-window_minimize


def load_maximize_state():
    # Written by maximize-toggle.py: window id (str) -> saved pre-maximize
    # geometry, present only while that window IS currently maximized.
    try:
        with open(MAXIMIZE_STATE_FILE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}

TITLE_WIDTH = 12  # fixed width in characters, per-entry -- padded/truncated

# ---------------------------------------------------------------------
# App display names -- resolved from the system's installed .desktop
# files, the same source every real desktop environment's taskbar/app
# switcher uses. No per-app list to maintain by hand: any app with a
# normal .desktop entry is picked up automatically.
#
#   1. WM_CLASS/instance -> a .desktop's StartupWMClass (exact, case-
#      insensitive). Works for most apps.
#   2. Some apps (notably Java/Swing ones like Burp Suite) never set a
#      meaningful WM_CLASS at all -- X11 reports something generic like
#      "sun-awt-X11-XFramePeer" or just "java". For those, look up the
#      window's actual PID (_NET_WM_PID via xprop) and match its argv
#      against installed .desktop files' Exec= basenames instead.
#   3. Falls back to the raw WM_CLASS (or window title) if neither
#      source has anything.
# ---------------------------------------------------------------------


def _parse_desktop_file(path):
    name = None
    wm_class = None
    exec_line = None
    try:
        with open(path, encoding="utf-8", errors="ignore") as f:
            in_entry = False
            for line in f:
                line = line.strip()
                if line == "[Desktop Entry]":
                    in_entry = True
                    continue
                if line.startswith("[") and line != "[Desktop Entry]":
                    in_entry = False
                    continue
                if not in_entry:
                    continue
                if line.startswith("Name=") and name is None:
                    name = line[len("Name="):].strip()
                elif line.startswith("StartupWMClass="):
                    wm_class = line[len("StartupWMClass="):].strip()
                elif line.startswith("Exec=") and exec_line is None:
                    exec_line = line[len("Exec="):].strip()
    except OSError:
        return None
    if not name:
        return None
    return name, wm_class, exec_line


def build_desktop_index():
    wm_class_map = {}
    exec_map = {}
    paths = glob.glob("/usr/share/applications/*.desktop") + glob.glob(
        os.path.expanduser("~/.local/share/applications/*.desktop")
    )
    for path in paths:
        parsed = _parse_desktop_file(path)
        if not parsed:
            continue
        name, wm_class, exec_line = parsed
        if wm_class:
            wm_class_map[wm_class.lower()] = name
        if exec_line:
            token = exec_line.split()[0].strip('"')
            base = os.path.basename(token).lower()
            if base and base not in exec_map:
                exec_map[base] = name
    return wm_class_map, exec_map


WM_CLASS_MAP, EXEC_MAP = build_desktop_index()


def _window_pid(wid):
    try:
        out = subprocess.run(
            ["xprop", "-id", str(wid), "_NET_WM_PID"],
            capture_output=True, text=True, timeout=1,
        ).stdout
        m = re.search(r"=\s*(\d+)", out)
        return int(m.group(1)) if m else None
    except Exception:
        return None


def _pid_argv(pid):
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            raw = f.read().split(b"\x00")
        return [a.decode(errors="ignore").lower() for a in raw if a]
    except OSError:
        return []


def friendly_name(w):
    cls = (w.window_class or "").strip()
    inst = (w.window_instance or "").strip()

    for key in (cls.lower(), inst.lower()):
        if key and key in WM_CLASS_MAP:
            return WM_CLASS_MAP[key]

    pid = _window_pid(w.window)
    if pid:
        argv = _pid_argv(pid)
        for exe_base, name in EXEC_MAP.items():
            for a in argv:
                if exe_base in a:
                    return name

    return cls or (w.name or "?").strip()


def load_theme():
    theme = {}
    with open(THEME_FILE) as f:
        for line in f:
            # values are always double-quoted in theme.conf, e.g.
            # BACKGROUND="#0B0014"  -- match inside the quotes so a literal
            # '#' in a hex color isn't mistaken for a trailing comment.
            m = re.match(r'^([A-Z_]+)="([^"]*)"', line.strip())
            if m:
                theme[m.group(1)] = m.group(2).strip()
    return theme


THEME = load_theme()
BACKGROUND = THEME.get("BACKGROUND", "#0B0014")
BACKGROUND_ALT = THEME.get("BACKGROUND_ALT", "#170225")
FOREGROUND = THEME.get("FOREGROUND", "#E8D5FF")
FOREGROUND_ALT = THEME.get("FOREGROUND_ALT", "#8C6FA8")
ACCENT = THEME.get("ACCENT", "#C724F5")
URGENT = THEME.get("URGENT", "#FF1855")

ICO_WINDOW = chr(0xF2D2)  # fa-window_restore, generic per-entry icon
ICO_MINIMIZED_DOT = chr(0xF111)  # fa-circle, small state indicator


def esc(cmd):
    # polybar %{A...} action commands: escape characters that would break
    # out of the action block. Our commands are all simple i3-msg
    # invocations with a numeric window id, so this is a narrow guard.
    return cmd.replace(":", "\\:")


# Persistent slot order, independent of i3's own tree/stacking order.
# i3ipc's tree.leaves() (and floating_nodes) are returned in i3's internal
# stacking order, which changes when a window gets focus (it moves toward
# the front) -- rendering directly in that order was what caused entries
# to visibly swap places whenever you clicked a different window. This
# assigns each window id a fixed position the first time it's seen and
# never reorders it after that; only closing removes it from the list.
_WINDOW_ORDER = []


def _update_window_order(all_windows):
    # IMPORTANT: called with the FULL, unfiltered window list (every
    # workspace), not just the ones currently displayed -- if this only
    # saw the current workspace's subset, switching workspaces would look
    # like every other workspace's windows "disappeared", prune them from
    # the order, and then re-append them at the end (out of their original
    # slots) the next time that workspace became visible again.
    ids_present = {w.window for w in all_windows}
    for wid in ids_present:
        if wid not in _WINDOW_ORDER:
            _WINDOW_ORDER.append(wid)
    for wid in list(_WINDOW_ORDER):
        if wid not in ids_present:
            _WINDOW_ORDER.remove(wid)


def render(i3):
    tree = i3.get_tree()

    # Which workspace is currently visible -- use get_workspaces() rather
    # than find_focused() so this is correct even when the workspace is
    # empty (no window to hold input focus).
    workspaces = i3.get_workspaces()
    focused_ws = next((w for w in workspaces if w.focused), None)
    ws_name = focused_ws.name if focused_ws else None

    all_leaves = [w for w in tree.leaves() if w.window is not None]
    _update_window_order(all_leaves)

    maximize_state = load_maximize_state()

    by_id = {w.window: w for w in all_leaves}
    visible_ids = [
        wid for wid in _WINDOW_ORDER
        if wid in by_id and by_id[wid].workspace() is not None and (
            by_id[wid].workspace().name == ws_name
            # minimized (scratchpad) windows stay reachable from any
            # workspace, not just the one they were minimized from
            or by_id[wid].workspace().name == "__i3_scratch"
        )
    ]
    windows = [by_id[wid] for wid in visible_ids]

    focused_id = None
    focused = tree.find_focused()
    if focused is not None:
        focused_id = focused.window

    if not windows:
        print("", flush=True)
        return

    parts = []
    for w in windows:
        title = friendly_name(w)
        if len(title) > TITLE_WIDTH:
            title = title[:TITLE_WIDTH - 1] + "…"
        else:
            title = title.ljust(TITLE_WIDTH)
        wid = w.window
        is_focused = wid == focused_id
        is_minimized = w.workspace() is not None and w.workspace().name == "__i3_scratch"
        is_maximized = str(wid) in maximize_state

        # IMPORTANT: never chain "focus" together with "scratchpad show" for
        # a window that's currently hidden in the scratchpad. i3's `focus`
        # already un-hides a scratchpad window as a side effect (confirmed
        # by testing directly against i3-msg), so a hidden window's
        # workspace changes to a normal one as soon as `focus` runs. The
        # following `scratchpad show` then sees an already-visible
        # scratchpad window and -- per i3's own toggle semantics -- hides
        # it right back. Net effect of "focus, scratchpad show" on a
        # hidden window: it flashes visible and immediately re-hides,
        # which looked like the minimize button was stuck / wouldn't
        # restore. Fix: use `scratchpad show` ALONE to un-hide (it already
        # focuses the window too), and plain `focus` alone for windows
        # that aren't in the scratchpad at all.
        show_cmd = f"[id={wid}] scratchpad show" if is_minimized else f"[id={wid}] focus"
        focus_cmd = esc(f"i3-msg {show_cmd}")
        # Toggle, like Chrome/Windows taskbar buttons: click again on an
        # already-minimized entry un-hides it instead of re-hiding a no-op.
        if is_minimized:
            min_cmd = esc(f"i3-msg [id={wid}] scratchpad show")
        else:
            min_cmd = esc(f"i3-msg [id={wid}] move scratchpad")
        # maximize-toggle.py acts on whatever window is currently focused,
        # so show/focus this one first, then run it. It already toggles on
        # its own (2nd run restores the saved geometry).
        max_cmd = esc(f"i3-msg {show_cmd}; python3 /home/kali/.config/i3/maximize-toggle.py")
        close_cmd = esc(f"i3-msg [id={wid}] kill")

        if is_focused:
            fg, bg = BACKGROUND, ACCENT
        else:
            # Minimized entries used to get their own dark BACKGROUND fill
            # here, but the minimize/maximize icons below are hardcoded
            # black (%{F#000000}) to read on the lighter pill colors --
            # black-on-BACKGROUND made them nearly invisible, which is
            # exactly the "can't see the button once minimized" complaint.
            # State is already shown via ICO_MINIMIZED_DOT below, so keep
            # the same pill color as a normal unfocused entry regardless
            # of is_minimized.
            fg, bg = FOREGROUND, BACKGROUND_ALT

        # NOTE: do NOT bump these to %{T2} (larger font) -- these icons sit
        # in a monospace font's fixed glyph cell, and at the bigger size
        # they're visually wider than that cell, so the renderer clips
        # their right edge (observed: fa-window_maximize's right vertical
        # stroke was cut off, turning the square into a "C"). Keep default
        # size; use a single space of padding each side for separation
        # without stretching them anywhere near the clipping threshold.
        # A generic per-entry window icon (same glyph for every app --
        # this is styling, not a per-app hardcoded lookup) gives each pill
        # a consistent visual anchor instead of starting cold on text.
        # Minimized entries get a small dot after the icon instead of
        # relying on color alone to signal state. A thin accent-alt
        # separator marks where the title ends and the control buttons
        # begin, echoing the cyan/purple pairing used elsewhere in the rice.
        icon_prefix = ICO_WINDOW + (f" {ICO_MINIMIZED_DOT}" if is_minimized else "")
        # Minimize/maximize icons used to be hardcoded #000000 (black).
        # That only has contrast on the bright ACCENT pill (focused
        # entries); BACKGROUND/BACKGROUND_ALT are both near-black
        # (#0B0014 / #170225), so on every unfocused entry -- minimized or
        # not -- the icons were black-on-near-black and effectively
        # invisible. Reuse the same `fg` already chosen above for the
        # title text (BACKGROUND when the pill is bright ACCENT,
        # FOREGROUND when the pill is dark) so these icons always have the
        # same contrast as the text sitting right next to them.
        entry = (
            f"%{{B{bg}}}%{{F{fg}}}"
            f"%{{A1:{focus_cmd}:}} {icon_prefix} {title} %{{A}}"
            f"%{{A1:{min_cmd}:}}%{{F{fg}}} {ICO_MINIMIZE} %{{F-}}%{{A}}"
            f"%{{A1:{max_cmd}:}}%{{F{fg}}} {ICO_RESTORE if is_maximized else ICO_MAXIMIZE} %{{F-}}%{{A}}"
            f"%{{A1:{close_cmd}:}} %{{F{URGENT}}}{ICO_CLOSE}%{{F-}} %{{A}}"
            f"%{{B-}}%{{F-}}"
        )
        parts.append(entry)

    print("  ".join(parts), flush=True)


def main():
    i3 = i3ipc.Connection()
    render(i3)

    def on_change(i3conn, _event):
        render(i3conn)

    i3.on("window::new", on_change)
    i3.on("window::close", on_change)
    i3.on("window::focus", on_change)
    i3.on("window::title", on_change)
    i3.on("window::move", on_change)
    i3.on("window::fullscreen_mode", on_change)
    i3.on("workspace::focus", on_change)
    i3.main()


if __name__ == "__main__":
    main()
