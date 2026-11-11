#!/usr/bin/env python3
"""Windows-style MRU Alt-Tab switcher with visual popup menu for i3.

Combines both behaviors on Alt+Tab:
  1. Visual popup menu in the center of the screen showing open windows in
     MRU (most-recently-used) order, styled dynamically from
     ~/.config/rice/layout.json.
  2. Hold Alt + tap Tab (or Shift+Tab) to step through windows in the menu;
     release Alt (detected via X11 XQueryKeymap) to close the menu and
     commit the selected window to the front of MRU history.
  3. Clicking any row in the popup with the mouse also selects that window.

IMPORTANT: i3 stays in "default" mode the entire time -- no i3 submode is
ever entered, so it is impossible for Alt+Tab to trap or disable other
keybindings.
"""
import ctypes
import fcntl
import json
import os
import re
import socket
import subprocess
import sys
import threading
import time

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("Pango", "1.0")
from gi.repository import Gdk, GLib, Gtk, Pango  # noqa: E402

import i3ipc  # noqa: E402

STATE_FILE = os.path.expanduser("~/.cache/i3-alttab-history.json")
CYCLE_FILE = os.path.expanduser("~/.cache/i3-alttab-cycle")
TARGET_FILE = os.path.expanduser("~/.cache/i3-alttab-target")
LOCK_FILE = os.path.expanduser("~/.cache/i3-alttab-daemon.lock")
SOCK_FILE = os.path.expanduser("~/.cache/i3-alttab.sock")
LAYOUT_FILE = os.path.expanduser("~/.config/rice/layout.json")
MAX_HISTORY = 25

APP_ICONS = [
    (r"firefox", "\U000f0239"),                # 󰈹 Firefox
    (r"kitty|alacritty|term", "\U000f018d"),   # 󰆍 Terminal
    (r"burp", "\U000f00e4"),                   # 󰃤 Burp Suite
    (r"zap", "\U000f140b"),                    # 󱐋 OWASP ZAP
    (r"wireshark", "\U000f1673"),              # 󱙳 Wireshark
    (r"thunar|nautilus|pcmanfm", "\U000f0dcf"),  # 󰷏 Files
    (r"code|nvim|vim|geany", "\U000f0a1e"),    # 󰨞 Editor
    (r"xfce4-settings|lxappearance", "\U000f0493"),  # 󰒓 Settings
]
DEFAULT_ICON = "\uf2d0"  # 


def app_icon(cls_name):
    for pattern, glyph in APP_ICONS:
        if re.search(pattern, cls_name or "", re.I):
            return glyph
    return DEFAULT_ICON


def rgba(hex_color, alpha):
    h = (hex_color or "#0A0A0A").lstrip("#")
    if len(h) != 6:
        return f"rgba(10, 10, 10, {alpha})"
    return f"rgba({int(h[0:2], 16)}, {int(h[2:4], 16)}, {int(h[4:6], 16)}, {alpha})"


def load_layout():
    try:
        with open(LAYOUT_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {
            "bar_transparency": 0.90,
            "colors": {
                "background": "#0A0A0A",
                "background_alt": "#1C1C1C",
                "foreground": "#E8E8E8",
                "foreground_alt": "#8A8A8A",
                "accent": "#FFFFFF",
                "accent_alt": "#BDBDBD",
                "border_active": "#FFFFFF",
                "border_inactive": "#2E2E2E",
                "urgent": "#FF1855",
            },
        }


def build_css(layout):
    c = layout.get("colors", {})
    bg = c.get("background", "#0A0A0A")
    bg_alt = c.get("background_alt", "#1C1C1C")
    fg = c.get("foreground", "#E8E8E8")
    fg_alt = c.get("foreground_alt", "#8A8A8A")
    accent = c.get("accent", "#FFFFFF")
    border = c.get("border_active", accent)
    alpha = min(0.96, max(0.85, float(layout.get("bar_transparency", 0.90))))
    return f"""
    window.alttab-popup {{
        background-color: transparent;
    }}
    .alttab-frame {{
        background-color: {rgba(bg, alpha)};
        border: 2px solid {border};
        border-radius: 0px;
        padding: 10px;
    }}
    .alttab-header {{
        color: {fg_alt};
        font-family: "JetBrainsMono Nerd Font", monospace;
        font-size: 9.5pt;
        font-weight: 700;
        padding: 2px 6px 8px 6px;
    }}
    .alttab-row {{
        background-color: {bg_alt};
        border: 1px solid transparent;
        padding: 8px 12px;
        margin: 3px 0px;
    }}
    .alttab-row.selected {{
        background-color: {accent};
        border: 1px solid {border};
    }}
    .alttab-icon {{
        font-family: "JetBrainsMono Nerd Font Propo", "JetBrainsMono Nerd Font", monospace;
        font-size: 15pt;
        color: {accent};
        padding-right: 10px;
    }}
    .alttab-row.selected .alttab-icon {{
        color: {bg};
    }}
    .alttab-ws {{
        font-family: "JetBrainsMono Nerd Font", monospace;
        font-size: 9pt;
        font-weight: 800;
        color: {fg_alt};
        padding-right: 8px;
    }}
    .alttab-row.selected .alttab-ws {{
        color: {bg};
    }}
    .alttab-app {{
        font-family: "JetBrainsMono Nerd Font", monospace;
        font-size: 10pt;
        font-weight: 800;
        color: {fg};
        padding-right: 10px;
    }}
    .alttab-row.selected .alttab-app {{
        color: {bg};
    }}
    .alttab-title {{
        font-family: "JetBrainsMono Nerd Font", sans-serif;
        font-size: 9.5pt;
        color: {fg_alt};
    }}
    .alttab-row.selected .alttab-title {{
        color: {bg};
    }}
    """


class AltTabDaemon:
    def __init__(self):
        self.i3 = i3ipc.Connection(auto_reconnect=True)
        self.history = self._load_history()
        self.cycling = False
        self.cycle_index = 0
        self.cycle_windows = []  # list of dicts: {id, con_id, cls, title, ws}
        self.last_step_time = 0.0
        self.poll_source = None

        # X11 connection for polling Alt key state via XQueryKeymap
        self.x11 = ctypes.cdll.LoadLibrary("libX11.so.6")
        self.x11.XOpenDisplay.restype = ctypes.c_void_p
        self.dpy = self.x11.XOpenDisplay(None)
        self.keymap_buf = (ctypes.c_char * 32)()

        # GTK3 Popup Window
        self.css_provider = Gtk.CssProvider()
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            self.css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_USER,
        )

        self.win = Gtk.Window(type=Gtk.WindowType.POPUP)
        self.win.get_style_context().add_class("alttab-popup")
        self.win.set_app_paintable(True)
        self.win.set_type_hint(Gdk.WindowTypeHint.DOCK)
        self.win.set_keep_above(True)
        visual = self.win.get_screen().get_rgba_visual()
        if visual is not None:
            self.win.set_visual(visual)

        self.frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.frame.get_style_context().add_class("alttab-frame")
        self.win.add(self.frame)

        self.rows_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.frame.pack_start(self.rows_box, True, True, 0)
        self.row_widgets = []

        # Seed initial history from current i3 tree if empty
        self._seed_from_tree()

        # Start i3 event listener thread
        threading.Thread(target=self._i3_listener, daemon=True).start()

        # Start Unix domain socket listener for instant step/step-back IPC
        self._setup_socket()

    def _load_history(self):
        if os.path.exists(STATE_FILE):
            try:
                with open(STATE_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, list):
                        return data
            except Exception:
                pass
        return []

    def _save_history(self):
        try:
            with open(STATE_FILE, "w", encoding="utf-8") as f:
                json.dump(self.history[:MAX_HISTORY], f)
        except Exception:
            pass

    def _seed_from_tree(self):
        try:
            tree = self.i3.get_tree()
            focused = tree.find_focused()
            if focused and focused.window:
                if focused.window in self.history:
                    self.history.remove(focused.window)
                self.history.insert(0, focused.window)
            for leaf in tree.leaves():
                if leaf.window and leaf.window not in self.history:
                    self.history.append(leaf.window)
            self._save_history()
        except Exception:
            pass

    def _i3_listener(self):
        conn = i3ipc.Connection(auto_reconnect=True)

        def on_focus(_i3, event):
            win_id = getattr(event.container, "window", None)
            if win_id is not None:
                GLib.idle_add(self._record_focus, win_id)

        def on_close(_i3, event):
            win_id = getattr(event.container, "window", None)
            if win_id is not None:
                GLib.idle_add(self._record_close, win_id)

        conn.on("window::focus", on_focus)
        conn.on("window::close", on_close)
        conn.main()

    def _record_focus(self, win_id):
        if self.cycling:
            return False
        if win_id in self.history:
            self.history.remove(win_id)
        self.history.insert(0, win_id)
        del self.history[MAX_HISTORY:]
        self._save_history()
        return False

    def _record_close(self, win_id):
        if win_id in self.history:
            self.history.remove(win_id)
            self._save_history()
        return False

    def _setup_socket(self):
        if os.path.exists(SOCK_FILE):
            try:
                os.remove(SOCK_FILE)
            except OSError:
                pass
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        self.sock.bind(SOCK_FILE)
        self.sock.setblocking(False)
        GLib.io_add_watch(
            self.sock.fileno(),
            GLib.IO_IN,
            self._on_sock_msg,
        )

    def _on_sock_msg(self, _fd, _cond):
        try:
            while True:
                data = self.sock.recv(256).decode("utf-8", errors="ignore").strip()
                if not data:
                    break
                if data == "step":
                    self.step(1)
                elif data == "step-back":
                    self.step(-1)
                elif data == "reset":
                    self.finish_cycle()
        except BlockingIOError:
            pass
        except Exception:
            pass
        return True

    def _collect_windows(self):
        try:
            tree = self.i3.get_tree()
        except Exception:
            return []

        by_id = {}
        focused_id = None
        for leaf in tree.leaves():
            if leaf.window is None:
                continue
            ws = leaf.workspace()
            ws_name = ws.name if ws else "?"
            if ws_name == "__i3_scratch":
                continue  # skip hidden scratchpad windows in normal Alt+Tab
            if leaf.focused:
                focused_id = leaf.window
            cls = leaf.window_class or leaf.window_instance or "Window"
            title = leaf.name or cls
            by_id[leaf.window] = {
                "id": leaf.window,
                "con_id": leaf.id,
                "cls": cls,
                "title": title,
                "ws": ws_name,
            }

        # Ensure the currently focused window is at index 0 before starting a cycle
        if focused_id and focused_id in by_id:
            if focused_id in self.history:
                self.history.remove(focused_id)
            self.history.insert(0, focused_id)

        ordered = []
        seen = set()
        for wid in self.history:
            if wid in by_id and wid not in seen:
                ordered.append(by_id[wid])
                seen.add(wid)
        for wid, info in by_id.items():
            if wid not in seen:
                ordered.append(info)
                seen.add(wid)
                self.history.append(wid)
        return ordered

    def step(self, direction=1):
        self.last_step_time = time.monotonic()

        if not self.cycling:
            self.cycle_windows = self._collect_windows()
            if not self.cycle_windows:
                return
            self.cycling = True
            if len(self.cycle_windows) >= 2:
                self.cycle_index = 1 if direction > 0 else len(self.cycle_windows) - 1
            else:
                self.cycle_index = 0
            self._build_popup()
            if self.poll_source is None:
                self.poll_source = GLib.timeout_add(25, self._poll_alt_release)
        else:
            n = len(self.cycle_windows)
            if n > 0:
                self.cycle_index = (self.cycle_index + direction) % n
            self._update_selection()

        # Focus the highlighted window immediately so user sees both the menu
        # and the target window
        self._focus_current()

    def _focus_current(self):
        if not self.cycle_windows:
            return
        target = self.cycle_windows[self.cycle_index]
        try:
            self.i3.command(f'[id={target["id"]}] focus')
            if self.win.get_visible() and self.win.get_window() is not None:
                self.win.get_window().raise_()
        except Exception:
            pass

    def _build_popup(self):
        layout = load_layout()
        self.css_provider.load_from_data(build_css(layout).encode("utf-8"))

        for child in self.rows_box.get_children():
            self.rows_box.remove(child)
            child.destroy()
        self.row_widgets = []

        popup_width = 580
        for idx, info in enumerate(self.cycle_windows):
            evbox = Gtk.EventBox()
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
            row.get_style_context().add_class("alttab-row")
            if idx == self.cycle_index:
                row.get_style_context().add_class("selected")

            icon_lbl = Gtk.Label(label=app_icon(info["cls"]))
            icon_lbl.get_style_context().add_class("alttab-icon")
            row.pack_start(icon_lbl, False, False, 0)

            ws_lbl = Gtk.Label(label=f'[{info["ws"]}]')
            ws_lbl.get_style_context().add_class("alttab-ws")
            row.pack_start(ws_lbl, False, False, 0)

            app_lbl = Gtk.Label(label=info["cls"])
            app_lbl.get_style_context().add_class("alttab-app")
            app_lbl.set_xalign(0.0)
            row.pack_start(app_lbl, False, False, 0)

            title_lbl = Gtk.Label(label=info["title"])
            title_lbl.get_style_context().add_class("alttab-title")
            title_lbl.set_xalign(0.0)
            title_lbl.set_ellipsize(Pango.EllipsizeMode.END)
            title_lbl.set_max_width_chars(42)
            row.pack_start(title_lbl, True, True, 0)

            evbox.add(row)
            evbox.connect("button-press-event", self._on_row_click, idx)
            self.rows_box.pack_start(evbox, False, False, 0)
            self.row_widgets.append(row)

        self.win.set_size_request(popup_width, -1)
        self.frame.show_all()

        # Center on active output
        nat_w, nat_h = self.frame.get_preferred_size()[1].width, self.frame.get_preferred_size()[1].height
        w = max(popup_width, nat_w)
        h = max(60, nat_h)
        mon_x, mon_y, mon_w, mon_h = 0, 0, 1920, 1080
        try:
            for o in self.i3.get_outputs():
                if o.active:
                    mon_x, mon_y, mon_w, mon_h = o.rect.x, o.rect.y, o.rect.width, o.rect.height
                    break
        except Exception:
            pass

        x = mon_x + (mon_w - w) // 2
        y = mon_y + (mon_h - h) // 2
        self.win.resize(w, h)
        self.win.move(x, y)
        self.win.show_all()
        if self.win.get_window() is not None:
            self.win.get_window().raise_()

    def _update_selection(self):
        for idx, row in enumerate(self.row_widgets):
            ctx = row.get_style_context()
            if idx == self.cycle_index:
                ctx.add_class("selected")
            else:
                ctx.remove_class("selected")
        if self.win.get_visible() and self.win.get_window() is not None:
            self.win.get_window().raise_()

    def _on_row_click(self, _widget, _event, idx):
        self.cycle_index = idx
        self._update_selection()
        self._focus_current()
        self.finish_cycle()
        return True

    def _is_alt_held(self):
        if not self.dpy:
            return False
        self.x11.XQueryKeymap(ctypes.c_void_p(self.dpy), self.keymap_buf)
        # X11 keycodes on Linux evdev: Alt_L = 64, Alt_R = 108, Meta_L = 205
        alt_l = bool(self.keymap_buf[64 >> 3][0] & (1 << (64 & 7)))
        alt_r = bool(self.keymap_buf[108 >> 3][0] & (1 << (108 & 7)))
        return alt_l or alt_r

    def _poll_alt_release(self):
        if not self.cycling:
            self.poll_source = None
            return False

        elapsed = time.monotonic() - self.last_step_time
        alt_held = self._is_alt_held()

        # Keep popup visible for at least 150ms on a quick tap so the user
        # sees the visual confirmation, then close as soon as Alt is up.
        if (not alt_held and elapsed >= 0.15) or elapsed > 4.0:
            self.finish_cycle()
            self.poll_source = None
            return False

        if self.win.get_visible() and self.win.get_window() is not None:
            self.win.get_window().raise_()
        return True

    def finish_cycle(self):
        if not self.cycling:
            return
        self.cycling = False
        self.win.hide()
        if self.cycle_windows and 0 <= self.cycle_index < len(self.cycle_windows):
            chosen = self.cycle_windows[self.cycle_index]["id"]
            if chosen in self.history:
                self.history.remove(chosen)
            self.history.insert(0, chosen)
            del self.history[MAX_HISTORY:]
            self._save_history()


def run_daemon():
    os.makedirs(os.path.dirname(LOCK_FILE), exist_ok=True)
    lock_fd = open(LOCK_FILE, "w")
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit(0)

    GLib.set_prgname("i3-alttab")
    AltTabDaemon()
    Gtk.main()


def send_cmd(cmd):
    if os.path.exists(SOCK_FILE):
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
            s.sendto(cmd.encode("utf-8"), SOCK_FILE)
            s.close()
            return
        except Exception:
            pass
    # Fallback: start daemon if not running, wait briefly, then send
    subprocess.Popen(
        [sys.executable, os.path.abspath(__file__), "daemon"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    for _ in range(15):
        time.sleep(0.03)
        if os.path.exists(SOCK_FILE):
            try:
                s = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
                s.sendto(cmd.encode("utf-8"), SOCK_FILE)
                s.close()
                return
            except Exception:
                pass


if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else ""
    if action == "daemon":
        run_daemon()
    elif action in ("step", "step-back", "reset"):
        send_cmd(action)
    else:
        print("usage: alt-tab.py {daemon|step|step-back|reset}", file=sys.stderr)
        sys.exit(1)
