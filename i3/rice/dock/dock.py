#!/usr/bin/env python3
"""Ubuntu-style app dock on the right screen edge -- the mono theme's
(theme.conf LAYOUT="dock") replacement for polybar's quicklaunch module.

  - pinned apps (APPS below), then any other running apps after a
    separator, centered vertically; "Show Applications" (rofi drun) at
    the bottom -- all drawn as flat white Nerd Font glyphs
  - a dot per open window (up to 3) on the screen-edge side of each icon,
    and a highlight on the app that has focus
  - left click: launch if not running; focus it if it is (switching
    workspace if needed, or bringing it back from the scratchpad); cycle
    through its windows if it's already focused; with a single focused
    window, minimize it to the scratchpad (same as $mod+Shift+minus)
  - middle click: always open a new window; right click: small menu

Why a custom GTK window and not plank/tint2: those set
_NET_WM_WINDOW_TYPE_DOCK and i3 force-places every dock-type window into
its top/bottom dock area -- a vertical right-side dock is impossible that
way. This is an override-redirect (POPUP) window instead, which i3 doesn't
manage at all: nothing reserves space for it automatically, which is why
apply-theme.sh writes the reserved strip into ~/.config/rice/layout.json
(read here for geometry/colors, and by the maximize/default-size scripts
so maximized windows stop at the dock) and into i3's gaps (tiled windows).

Started/stopped by ~/.config/polybar/launch.sh (exec_always), so an i3
reload -- including the one switch-theme.sh does -- restarts it with the
new colors, and switching to a classic preset stops it.
"""
import collections
import fcntl
import json
import os
import re
import subprocess
import sys
import threading

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

import i3ipc  # noqa: E402

LAYOUT_FILE = os.path.expanduser("~/.config/rice/layout.json")
LOCK_FILE = os.path.expanduser("~/.cache/rice-dock.lock")
HOME = os.path.expanduser("~")
GLYPH_FONT = "JetBrainsMono Nerd Font"

# Pinned apps, top to bottom -- same set as polybar's quicklaunch.sh. Icons
# are flat white Nerd Font glyphs (same style as the top bar's), not icon-
# theme images. To pin another one, add a line:
#   (tooltip name, WM_CLASS regex (matched case-insensitively against class
#    and instance), Nerd Font codepoint, shell command)
# Check a new codepoint against the installed font first, e.g.
#   fc-list ":charset=f1673" family | grep "JetBrainsMono Nerd Font"
# -- a missing glyph silently renders as nothing.
APPS = [
    ("Firefox", r"firefox", 0xF269, "firefox-esr"),                        # fa-firefox
    ("Terminal", r"^kitty$", 0xF120, f"kitty --config {HOME}/.config/kitty/kitty.conf"),  # fa-terminal
    ("Burp Suite", r"burp", 0xF188, "burpsuite"),                          # fa-bug
    ("ZAP", r"zap", 0xF0E7, f"{HOME}/Arsenal/ZAP_2.17.0/zap.sh"),          # fa-bolt
    ("Wireshark", r"wireshark", 0xF1673,                                   # md-shark_fin
     "/usr/share/kali-menu/helper-scripts/wireshark.sh"),
    ("Files", r"^thunar$", 0xF07B, "thunar"),                              # fa-folder
    ("Settings", r"xfce4-settings-manager", 0xF013, "xfce4-settings-manager"),  # fa-cog
]
OTHER_APP_GLYPH = 0xF2D0   # fa-window_maximize -- running apps that aren't pinned
SHOW_APPS_GLYPH = 0xF003B  # md-apps (3x3 dots, like Ubuntu's Show Applications)
SHOW_APPS_CMD = f"rofi -show drun -config {HOME}/.config/rofi/config.rasi"
MORE_GLYPH = 0xF141        # fa-ellipsis_h -- "more windows" when the dock is full
MORE_CMD = f"rofi -show window -config {HOME}/.config/rofi/config.rasi"
MORE_KEY = "__more__"
MAX_DOTS = 3
MIN_ICON = 12    # icons never shrink below this when the dock gets crowded
Rect = collections.namedtuple("Rect", "x y width height")


def load_layout():
    with open(LAYOUT_FILE) as f:
        return json.load(f)


def rgba(hex_color, alpha):
    h = hex_color.lstrip("#")
    return f"rgba({int(h[0:2], 16)}, {int(h[2:4], 16)}, {int(h[4:6], 16)}, {alpha})"


def launch(cmd):
    subprocess.Popen(cmd, shell=True, cwd=HOME, start_new_session=True,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def css(layout):
    c = layout["colors"]
    # Dock outline 1px + button margin 2px + icon margin 3px on each side is
    # what apply-theme.sh's DOCK_WIDTH (= icon + 12) assumes -- keep in sync.
    return f"""
    window {{ background-color: transparent; }}
    .dock {{
        background-color: {rgba(c["background"], layout["bar_transparency"])};
        border: 1px solid {c["accent_alt"]};
        border-radius: 8px;
        padding: 6px 0;
    }}
    .app {{
        background: none; background-color: transparent; background-image: none;
        border: none; box-shadow: none; outline: none; text-shadow: none;
        border-radius: 6px; padding: 3px 0; margin: 2px 2px;
        min-width: 0; min-height: 0;
    }}
    .app:hover {{ background-color: {c["background_alt"]}; }}
    .app.focused {{
        background-color: {c["background_alt"]};
        box-shadow: inset 0 0 0 1px {c["foreground_alt"]};
    }}
    .dot {{ background-color: {c["foreground_alt"]}; border-radius: 2px; min-width: 3px; min-height: 3px; }}
    .app.focused .dot {{ background-color: {c["accent"]}; }}
    .glyph {{ color: {c["foreground"]}; }}
    separator {{ background-color: {c["border_inactive"]}; min-height: 1px; margin: 4px 6px; }}
    tooltip, tooltip.background {{
        background-color: {c["background"]}; border: 1px solid {c["accent_alt"]}; border-radius: 6px;
    }}
    tooltip label {{ color: {c["foreground"]}; }}
    menu, .menu {{ background-color: {c["background"]}; border: 1px solid {c["accent_alt"]}; padding: 4px; }}
    menuitem {{ color: {c["foreground"]}; padding: 6px 12px; border-radius: 6px; }}
    menuitem:hover {{ background-color: {c["accent"]}; }}
    menuitem:hover label {{ color: {c["background"]}; }}
    menuitem:disabled label {{ color: {c["foreground_alt"]}; }}
    """


def icon_widget(glyph, size):
    """A Nerd Font glyph in the theme's foreground color, sized to the icon."""
    label = Gtk.Label(label=chr(glyph))
    label.get_style_context().add_class("glyph")
    font = Gtk.CssProvider()  # per-label: the size follows the (shrinkable) icon size
    font.load_from_data(f'label {{ font-family: "{GLYPH_FONT}"; font-size: {int(size * 0.8)}px; }}'.encode())
    label.get_style_context().add_provider(font, Gtk.STYLE_PROVIDER_PRIORITY_USER)
    label.set_size_request(size, size)
    return label


class AppButton(Gtk.Button):
    """One dock entry: icon + window dots, click handling via the Dock."""

    def __init__(self, dock, key, name, icon, cmd):
        super().__init__()
        self.dock, self.key, self.name, self.cmd = dock, key, name, cmd
        self.windows = []
        self.set_relief(Gtk.ReliefStyle.NONE)
        self.set_can_focus(False)
        self.set_tooltip_text(name)
        self.get_style_context().add_class("app")

        icon.set_margin_start(3)
        icon.set_margin_end(3)
        overlay = Gtk.Overlay()
        overlay.add(icon)
        # dots sit in the 3px margin on the screen-edge (right) side
        self.dots = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.dots.set_halign(Gtk.Align.END)
        self.dots.set_valign(Gtk.Align.CENTER)
        overlay.add_overlay(self.dots)
        self.add(overlay)
        self.connect("button-release-event", self.on_release)

    def set_windows(self, windows):
        self.windows = windows
        for child in self.dots.get_children():
            self.dots.remove(child)
        for _ in range(min(len(windows), MAX_DOTS)):
            dot = Gtk.Box()
            dot.set_size_request(3, 3)
            dot.get_style_context().add_class("dot")
            self.dots.pack_start(dot, False, False, 0)
        self.dots.show_all()
        ctx = self.get_style_context()
        if any(w.focused for w in windows):
            ctx.add_class("focused")
        else:
            ctx.remove_class("focused")

    def on_release(self, _widget, event):
        if event.button == 1:
            self.dock.activate(self)
        elif event.button == 2 and self.cmd:
            launch(self.cmd)
        elif event.button == 3:
            self.dock.show_menu(self, event)
        return True


def measure_slot_extra(sizes):
    """Height one dock entry takes beyond its icon size, measured under the
    live GTK theme/CSS (stack two entries, subtract one) rather than assumed:
    the glyph's line height and the GTK theme's own button borders add a few
    px that a hand-computed constant missed (the crowded dock then ran
    15px off the screen)."""
    extra = 0
    for size in sizes:
        heights = []
        for n in (1, 2):
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            for _ in range(n):
                box.pack_start(AppButton(None, None, "", icon_widget(OTHER_APP_GLYPH, size), None),
                               False, False, 0)
            holder = Gtk.OffscreenWindow()
            holder.add(box)
            holder.show_all()
            heights.append(box.get_preferred_height()[1])
            holder.destroy()
        extra = max(extra, heights[1] - heights[0] - size)
    return extra


class DockWindow(Gtk.Window):
    """The dock on one monitor."""

    def __init__(self, dock, monitor_rect):
        super().__init__(type=Gtk.WindowType.POPUP)
        self.dock = dock
        self.rect = monitor_rect
        self.buttons = {}

        self.set_app_paintable(True)
        visual = self.get_screen().get_rgba_visual()
        if visual is not None:
            self.set_visual(visual)
        # DOCK type: picom skips its shadow/rounded-corner handling for it
        # (see picom.conf.template); i3 never sees it (override-redirect).
        self.set_type_hint(Gdk.WindowTypeHint.DOCK)

        layout = dock.layout
        top = layout["reserved"]["top"]
        gap = layout["edge_gap"]
        width = layout["dock"]["width"]
        x = monitor_rect.x + monitor_rect.width - gap - width
        # "length": fraction of the free height below the top bar the dock
        # spans, centered in it (theme.conf DOCK_LENGTH)
        full = monitor_rect.height - top - 2 * gap
        height = round(full * min(1.0, max(0.1, layout["dock"].get("length", 1.0))))
        y = monitor_rect.y + top + gap + (full - height) // 2
        self.width, self.height = width, height
        self.icon_size = None
        self.set_size_request(width, height)
        self.move(x, y)

        frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        frame.get_style_context().add_class("dock")
        self.add(frame)

        # pinned + running apps as one group, vertically centered in the
        # dock (set_center_widget centers on the whole frame, independent of
        # the Show Applications button packed at the bottom)
        apps_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.pinned_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        apps_box.pack_start(self.pinned_box, False, False, 0)

        self.separator = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        apps_box.pack_start(self.separator, False, False, 0)
        self.running_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        apps_box.pack_start(self.running_box, False, False, 0)
        frame.set_center_widget(apps_box)

        self.show_apps_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        frame.pack_end(self.show_apps_box, False, False, 0)

        self.set_icon_size(self.fit_icon_size(len(APPS)))
        self.show_all()
        self.separator.hide()

    def fit_icon_size(self, n_apps):
        """Largest icon size (up to the theme's) at which n_apps entries fit.

        Like Ubuntu's dock, icons shrink instead of the dock growing past
        the bottom of the screen. Room is reserved for Show Applications at
        BOTH ends, so the centered app group can never run into it; 23 =
        2*1 outline + 2*6 padding + separator (1 + 2*4 margin).
        """
        fit = (self.height - 23) // (n_apps + 2) - self.dock.slot_extra
        return max(MIN_ICON, min(self.dock.layout["dock"]["icon_size"], fit))

    def set_icon_size(self, size):
        """(Re)build every button at this icon size."""
        self.icon_size = size
        for box in (self.pinned_box, self.running_box, self.show_apps_box):
            for child in box.get_children():
                box.remove(child)
                child.destroy()
        self.buttons = {}
        for name, _regex, glyph, cmd in APPS:
            btn = AppButton(self.dock, name, name, icon_widget(glyph, size), cmd)
            self.buttons[name] = btn
            self.pinned_box.pack_start(btn, False, False, 0)
        show_apps = AppButton(self.dock, None, "Show Applications",
                              icon_widget(SHOW_APPS_GLYPH, size),
                              SHOW_APPS_CMD)
        self.show_apps_box.pack_start(show_apps, False, False, 0)
        self.pinned_box.show_all()
        self.show_apps_box.show_all()

    def update(self, pinned, running):
        # Even at MIN_ICON there's a hard limit: past it, show the running
        # apps that fit and turn the last slot into "more windows" (rofi's
        # window switcher) instead of letting the dock run off the screen.
        max_entries = (self.height - 23) // (MIN_ICON + self.dock.slot_extra) - 2
        overflow = len(APPS) + len(running) > max_entries
        if overflow:
            running = dict(list(running.items())[:max(0, max_entries - len(APPS) - 1)])
        keys = list(running) + ([MORE_KEY] if overflow else [])

        size = self.fit_icon_size(len(APPS) + len(keys))
        if size != self.icon_size:
            self.set_icon_size(size)  # also empties running_box -> rebuilt below
        for name, btn in self.buttons.items():
            if name in pinned:
                btn.set_windows(pinned[name])
        # rebuild the running (non-pinned) section only when its set changes
        current = [b.key for b in self.running_box.get_children()]
        if current != keys:
            for child in self.running_box.get_children():
                self.running_box.remove(child)
                child.destroy()
            for key, (name, windows) in running.items():
                btn = AppButton(self.dock, key, name, icon_widget(OTHER_APP_GLYPH, size), None)
                self.running_box.pack_start(btn, False, False, 0)
            if overflow:
                btn = AppButton(self.dock, MORE_KEY, "More windows", icon_widget(MORE_GLYPH, size), MORE_CMD)
                self.running_box.pack_start(btn, False, False, 0)
            self.running_box.show_all()
        for btn in self.running_box.get_children():
            if btn.key in running:
                btn.set_windows(running[btn.key][1])
        self.separator.set_visible(bool(keys))
        # GTK grows a window to fit its content but never shrinks it back on
        # its own -- pin it to the dock's size after every rebuild.
        self.resize(self.width, self.height)


class Dock:
    def __init__(self, layout):
        self.layout = layout
        self.i3 = i3ipc.Connection(auto_reconnect=True)
        self.windows = []
        self.refresh_pending = False

        provider = Gtk.CssProvider()
        provider.load_from_data(css(layout).encode())
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_USER)
        self.slot_extra = measure_slot_extra({MIN_ICON, layout["dock"]["icon_size"]})

        Gdk.Screen.get_default().connect("monitors-changed", lambda *_: self.rebuild())
        self.rebuild()
        threading.Thread(target=self.listen, daemon=True).start()

    # ---- windows per monitor --------------------------------------------
    def monitor_rects(self):
        # i3's active outputs, not GDK's monitor list: i3 is what places the
        # windows (and what reserved_area.py measures against), and a
        # running GTK process was observed keeping a stale monitor list
        # after a RandR change that i3 had already picked up.
        try:
            return [Rect(o.rect.x, o.rect.y, o.rect.width, o.rect.height)
                    for o in self.i3.get_outputs() if o.active]
        except Exception:
            return [w.rect for w in self.windows]  # i3 restarting -- keep as is

    def rebuild(self):
        for w in self.windows:
            w.destroy()
        self.windows = [DockWindow(self, rect) for rect in self.monitor_rects()]
        self.queue_refresh()

    # ---- i3 state -> dots / focus highlight / running apps --------------
    def listen(self):
        # i3ipc's event loop blocks, so it gets its own thread + connection;
        # every event just schedules a refresh on the GTK main thread.
        conn = i3ipc.Connection(auto_reconnect=True)
        for event in (i3ipc.Event.WINDOW, i3ipc.Event.WORKSPACE, i3ipc.Event.OUTPUT):
            conn.on(event, lambda *_: GLib.idle_add(self.queue_refresh))
        conn.main()

    def queue_refresh(self):
        # coalesce bursts of events (one focus change is several of them)
        if not self.refresh_pending:
            self.refresh_pending = True
            GLib.timeout_add(60, self.refresh)
        return False

    def refresh(self):
        self.refresh_pending = False
        # Monitor layout changed under us (VM resume re-probing the display,
        # a screen plugged in/out)? monitors-changed doesn't always arrive,
        # but i3's output event does -- re-place the dock from scratch.
        if self.monitor_rects() != [w.rect for w in self.windows]:
            self.rebuild()
            return False
        try:
            tree = self.i3.get_tree()
            outputs = self.i3.get_outputs()
        except Exception:
            return False

        pinned = {name: [] for name, *_ in APPS}
        running = {}
        for con in tree.leaves():
            if con.window is None:
                continue
            cls, inst = con.window_class or "", con.window_instance or ""
            for name, regex, _glyph, _cmd in APPS:
                if re.search(regex, cls, re.I) or re.search(regex, inst, re.I):
                    pinned[name].append(con)
                    break
            else:
                key = cls or inst or "?"
                running.setdefault(key, (cls or inst or "Window", []))[1].append(con)

        for win in self.windows:
            win.update(pinned, running)
            self.restack(win, tree, outputs)
        return False

    def restack(self, win, tree, outputs):
        # Hide under a fullscreen window ($mod+f), otherwise keep above
        # everything -- i3 raises floating windows over override-redirect
        # ones when they get focus, so re-raise after every event.
        ws_name = None
        for o in outputs:
            r = o.rect
            if o.active and Rect(r.x, r.y, r.width, r.height) == win.rect:
                ws_name = o.current_workspace
                break
        fullscreen = False
        if ws_name is not None:
            ws = next((w for w in tree.workspaces() if w.name == ws_name), None)
            fullscreen = ws is not None and any(
                c.fullscreen_mode == 1 for c in ws.descendants())
        if fullscreen:
            win.hide()
        else:
            win.show()
            if win.get_window() is not None:
                win.get_window().raise_()

    # ---- clicks ---------------------------------------------------------
    def focus(self, con):
        if con.workspace() is not None and con.workspace().name == "__i3_scratch":
            self.i3.command(f"[con_id={con.id}] scratchpad show")
        else:
            self.i3.command(f"[con_id={con.id}] focus")

    def activate(self, btn):
        wins = btn.windows
        if not wins:
            if btn.cmd:
                launch(btn.cmd)
            return
        focused = [i for i, w in enumerate(wins) if w.focused]
        if not focused:
            visible = [w for w in wins if w.workspace() and w.workspace().name != "__i3_scratch"]
            self.focus((visible or wins)[0])
        elif len(wins) == 1:
            self.i3.command(f"[con_id={wins[0].id}] move scratchpad")
        else:
            self.focus(wins[(focused[0] + 1) % len(wins)])

    def show_menu(self, btn, event):
        menu = Gtk.Menu()
        title = Gtk.MenuItem(label=btn.name)
        title.set_sensitive(False)
        menu.append(title)
        if btn.cmd:
            item = Gtk.MenuItem(label="New Window")
            item.connect("activate", lambda *_: launch(btn.cmd))
            menu.append(item)
        if btn.windows:
            label = "Close" if len(btn.windows) == 1 else f"Close {len(btn.windows)} Windows"
            item = Gtk.MenuItem(label=label)
            ids = [w.id for w in btn.windows]
            item.connect("activate", lambda *_: [self.i3.command(f"[con_id={i}] kill") for i in ids])
            menu.append(item)
        menu.show_all()
        menu.attach_to_widget(btn, None)
        menu.popup_at_widget(btn, Gdk.Gravity.WEST, Gdk.Gravity.EAST, event)


def main():
    # Single-instance guard (same pattern as clipd.py/alt-tab.py) -- launch.sh
    # already kills the old dock before starting one, this just makes a
    # stray double start harmless.
    os.makedirs(os.path.dirname(LOCK_FILE), exist_ok=True)
    lock_fd = open(LOCK_FILE, "w")
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit(0)

    try:
        layout = load_layout()
    except (OSError, ValueError, KeyError) as e:
        sys.exit(f"dock: can't read {LAYOUT_FILE} ({e}) -- run ~/.config/rice/apply-theme.sh")
    if layout.get("layout") != "dock":
        sys.exit(0)  # active preset uses the classic layout -- no dock

    GLib.set_prgname("rice-dock")
    Dock(layout)
    Gtk.main()


if __name__ == "__main__":
    main()
