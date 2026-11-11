#!/usr/bin/env python3
"""Themed GTK3 Audio Control Popup with Volume & Mic Sliders (拉條).
Styled dynamically from ~/.config/rice/layout.json and supports live
English / Traditional Chinese switching via Alt+l or the header toggle button
(shared state: ~/.cache/i3-help-lang).
"""
import json
import os
import re
import subprocess
import sys
import time

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

LAYOUT_FILE = os.path.expanduser("~/.config/rice/layout.json")
LANG_STATE = os.path.expanduser("~/.cache/i3-help-lang")
POPUP_WIDTH = 360


def rgba(hex_color, alpha):
    h = hex_color.lstrip("#")
    if len(h) != 6:
        return "rgba(10, 10, 10, 0.92)"
    return f"rgba({int(h[0:2], 16)}, {int(h[2:4], 16)}, {int(h[4:6], 16)}, {alpha})"


def load_layout():
    try:
        with open(LAYOUT_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {
            "bar_transparency": 0.92,
            "reserved": {"top": 34, "right": 0},
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


def get_lang():
    try:
        with open(LANG_STATE, "r", encoding="utf-8") as f:
            val = f.read().strip()
            return "zh" if val == "zh" else "en"
    except Exception:
        return "en"


def set_lang(lang):
    os.makedirs(os.path.dirname(LANG_STATE), exist_ok=True)
    with open(LANG_STATE, "w", encoding="utf-8") as f:
        f.write(lang)


def get_audio_state(target="@DEFAULT_AUDIO_SINK@"):
    try:
        out = subprocess.check_output(
            ["wpctl", "get-volume", target],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
        m = re.search(r"Volume:\s*([0-9.]+)", out)
        vol = round(float(m.group(1)) * 100) if m else 50
        muted = "[MUTED]" in out
        return max(0, min(100, vol)), muted
    except Exception:
        return 50, False


def set_audio_volume(target, pct):
    pct = max(0, min(100, int(round(pct))))
    subprocess.Popen(
        ["wpctl", "set-volume", target, f"{pct}%"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def toggle_audio_mute(target):
    subprocess.run(
        ["wpctl", "set-mute", target, "toggle"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def build_css(layout):
    c = layout["colors"]
    border_col = c.get("border_active", c["accent"])
    bg_rgba = rgba(c["background"], layout.get("bar_transparency", 0.92))
    return f"""
    window {{
        background-color: transparent;
        font-family: "JetBrainsMono Nerd Font", "Droid Sans Fallback", sans-serif;
    }}
    .card {{
        background-color: {bg_rgba};
        border: 1.5px solid {border_col};
        border-radius: 10px;
        padding: 14px 16px;
    }}
    .title {{
        color: {c["accent"]};
        font-weight: bold;
        font-size: 11pt;
    }}
    .section-label {{
        color: {c["foreground"]};
        font-weight: bold;
        font-size: 10pt;
    }}
    .pct-label {{
        color: {c["accent"]};
        font-weight: bold;
        font-size: 10pt;
    }}
    .pct-label.muted {{
        color: {c["urgent"]};
    }}
    .hint-label {{
        color: {c["foreground_alt"]};
        font-size: 8.5pt;
    }}
    .divider {{
        background-color: {c["border_inactive"]};
        min-height: 1px;
        margin: 8px 0;
    }}
    button.pill-btn {{
        background: none;
        background-color: {c["background_alt"]};
        color: {c["foreground"]};
        border: 1px solid {c["border_inactive"]};
        border-radius: 6px;
        padding: 4px 9px;
        font-size: 9pt;
        box-shadow: none;
    }}
    button.pill-btn:hover {{
        background-color: {c["accent"]};
        color: {c["background"]};
        border-color: {c["accent"]};
    }}
    button.mute-btn.active {{
        background-color: {c["urgent"]};
        color: {c["background"]};
        border-color: {c["urgent"]};
    }}
    button.close-btn {{
        background: none;
        background-color: transparent;
        color: {c["foreground_alt"]};
        border: none;
        border-radius: 6px;
        padding: 2px 7px;
        font-size: 10pt;
    }}
    button.close-btn:hover {{
        background-color: {c["urgent"]};
        color: {c["background"]};
    }}
    scale {{
        padding: 6px 0;
    }}
    scale trough {{
        background-color: {c["background_alt"]};
        border: 1px solid {c["border_inactive"]};
        border-radius: 6px;
        min-height: 8px;
    }}
    scale highlight {{
        background-color: {c["accent"]};
        border-radius: 6px;
        min-height: 8px;
    }}
    scale slider {{
        background-color: {c["foreground"]};
        border: 2px solid {c["accent"]};
        border-radius: 10px;
        min-width: 16px;
        min-height: 16px;
        margin: -5px 0;
        box-shadow: none;
    }}
    scale slider:hover {{
        background-color: {c["accent"]};
    }}
    """


class AudioPopup(Gtk.Window):
    def __init__(self):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.layout = load_layout()
        self.lang = get_lang()
        self._updating = False
        self._start_time = time.monotonic()
        self._mouse_entered = False

        self.set_wmclass("RiceAudioPopup", "RiceAudioPopup")
        self.set_role("pop-up")
        self.set_title("Audio Control")
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_keep_above(True)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        self.set_app_paintable(True)

        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual is not None:
            self.set_visual(visual)

        provider = Gtk.CssProvider()
        provider.load_from_data(build_css(self.layout).encode("utf-8"))
        Gtk.StyleContext.add_provider_for_screen(
            screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        self.card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.card.get_style_context().add_class("card")
        self.card.set_size_request(POPUP_WIDTH, -1)
        self.add(self.card)

        # ---- Header ----
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.title_label = Gtk.Label(xalign=0)
        self.title_label.get_style_context().add_class("title")
        header.pack_start(self.title_label, True, True, 0)

        self.lang_btn = Gtk.Button()
        self.lang_btn.get_style_context().add_class("pill-btn")
        self.lang_btn.connect("clicked", self.on_toggle_lang)
        header.pack_end(self.lang_btn, False, False, 0)

        close_btn = Gtk.Button(label="✕")
        close_btn.get_style_context().add_class("close-btn")
        close_btn.connect("clicked", lambda *_: Gtk.main_quit())
        header.pack_end(close_btn, False, False, 0)

        self.card.pack_start(header, False, False, 0)

        div1 = Gtk.Box()
        div1.get_style_context().add_class("divider")
        self.card.pack_start(div1, False, False, 0)

        # ---- Speaker Section ----
        spk_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.spk_label = Gtk.Label(xalign=0)
        self.spk_label.get_style_context().add_class("section-label")
        spk_row.pack_start(self.spk_label, True, True, 0)

        self.spk_mute_btn = Gtk.Button()
        self.spk_mute_btn.get_style_context().add_class("pill-btn")
        self.spk_mute_btn.get_style_context().add_class("mute-btn")
        self.spk_mute_btn.connect("clicked", self.on_toggle_spk_mute)
        spk_row.pack_end(self.spk_mute_btn, False, False, 0)

        self.spk_pct_label = Gtk.Label(xalign=1)
        self.spk_pct_label.get_style_context().add_class("pct-label")
        spk_row.pack_end(self.spk_pct_label, False, False, 4)

        self.card.pack_start(spk_row, False, False, 0)

        self.spk_adj = Gtk.Adjustment(value=50, lower=0, upper=100, step_increment=1, page_increment=5)
        self.spk_scale = Gtk.Scale(orientation=Gtk.Orientation.HORIZONTAL, adjustment=self.spk_adj)
        self.spk_scale.set_draw_value(False)
        self.spk_scale.set_hexpand(True)
        self.spk_scale.connect("value-changed", self.on_spk_slider_changed)
        self.card.pack_start(self.spk_scale, False, False, 0)

        # Preset buttons row
        preset_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        for pct in (0, 25, 50, 75, 100):
            btn = Gtk.Button(label=f"{pct}%")
            btn.get_style_context().add_class("pill-btn")
            btn.connect("clicked", self.on_preset_clicked, pct)
            preset_row.pack_start(btn, True, True, 0)
        self.card.pack_start(preset_row, False, False, 2)

        div2 = Gtk.Box()
        div2.get_style_context().add_class("divider")
        self.card.pack_start(div2, False, False, 0)

        # ---- Microphone Section ----
        mic_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.mic_label = Gtk.Label(xalign=0)
        self.mic_label.get_style_context().add_class("section-label")
        mic_row.pack_start(self.mic_label, True, True, 0)

        self.mic_mute_btn = Gtk.Button()
        self.mic_mute_btn.get_style_context().add_class("pill-btn")
        self.mic_mute_btn.get_style_context().add_class("mute-btn")
        self.mic_mute_btn.connect("clicked", self.on_toggle_mic_mute)
        mic_row.pack_end(self.mic_mute_btn, False, False, 0)

        self.mic_pct_label = Gtk.Label(xalign=1)
        self.mic_pct_label.get_style_context().add_class("pct-label")
        mic_row.pack_end(self.mic_pct_label, False, False, 4)

        self.card.pack_start(mic_row, False, False, 0)

        self.mic_adj = Gtk.Adjustment(value=50, lower=0, upper=100, step_increment=1, page_increment=5)
        self.mic_scale = Gtk.Scale(orientation=Gtk.Orientation.HORIZONTAL, adjustment=self.mic_adj)
        self.mic_scale.set_draw_value(False)
        self.mic_scale.set_hexpand(True)
        self.mic_scale.connect("value-changed", self.on_mic_slider_changed)
        self.card.pack_start(self.mic_scale, False, False, 0)

        # Footer hint
        self.hint_label = Gtk.Label(xalign=0.5)
        self.hint_label.get_style_context().add_class("hint-label")
        self.card.pack_start(self.hint_label, False, False, 2)

        self.connect("key-press-event", self.on_key_press)
        self.connect("enter-notify-event", self.on_enter_notify)
        self.connect("focus-out-event", self.on_focus_out)
        self.connect("map-event", self.on_mapped)

        self.refresh_state()
        GLib.timeout_add(800, self.refresh_state)

    def on_enter_notify(self, *_args):
        self._mouse_entered = True
        return False

    def on_focus_out(self, *_args):
        if not self._mouse_entered or (time.monotonic() - self._start_time < 0.4):
            return False
        display = Gdk.Display.get_default()
        seat = display.get_default_seat()
        _, px, py = seat.get_pointer().get_position()
        wx, wy = self.get_position()
        alloc = self.get_allocation()
        if wx <= px <= wx + alloc.width and wy <= py <= wy + alloc.height:
            return False
        Gtk.main_quit()
        return False

    def on_mapped(self, *_args):
        display = Gdk.Display.get_default()
        seat = display.get_default_seat()
        pointer = seat.get_pointer()
        _, px, py = pointer.get_position()
        monitor = display.get_monitor_at_point(px, py)
        geom = monitor.get_geometry()

        top_reserved = self.layout.get("reserved", {}).get("top", 30)
        right_reserved = self.layout.get("reserved", {}).get("right", 0)
        alloc = self.get_allocation()
        w = max(alloc.width, POPUP_WIDTH)

        target_x = max(
            geom.x + 8,
            min(px - w // 2, geom.x + geom.width - right_reserved - w - 8),
        )
        target_y = geom.y + max(top_reserved + 4, 30)

        self.move(target_x, target_y)
        subprocess.Popen(
            [
                "i3-msg",
                f'[class="RiceAudioPopup"] move position {target_x} px {target_y} px, focus',
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return False

    def refresh_state(self):
        self._updating = True
        spk_vol, spk_muted = get_audio_state("@DEFAULT_AUDIO_SINK@")
        mic_vol, mic_muted = get_audio_state("@DEFAULT_AUDIO_SOURCE@")

        self.spk_adj.set_value(spk_vol)
        self.mic_adj.set_value(mic_vol)
        self.update_labels(spk_vol, spk_muted, mic_vol, mic_muted)
        self._updating = False
        return True

    def update_labels(self, spk_vol, spk_muted, mic_vol, mic_muted):
        if self.lang == "zh":
            self.title_label.set_text("  音效控制中心")
            self.lang_btn.set_label("🌐 EN")
            self.spk_label.set_text("  喇叭輸出 (Speaker)")
            self.mic_label.set_text("  麥克風 (Microphone)")
            self.spk_mute_btn.set_label("󰝟 已靜音" if spk_muted else " 靜音")
            self.mic_mute_btn.set_label(" 已靜音" if mic_muted else " 靜音")
            self.spk_pct_label.set_text(f"已靜音 ({spk_vol}%)" if spk_muted else f"{spk_vol}%")
            self.mic_pct_label.set_text(f"已靜音 ({mic_vol}%)" if mic_muted else f"{mic_vol}%")
            self.hint_label.set_text("拖曳拉條調整音量  ·  Alt+l 切換英文  ·  Esc 關閉")
        else:
            self.title_label.set_text("  Audio Control")
            self.lang_btn.set_label("🌐 中文")
            self.spk_label.set_text("  Speaker Output")
            self.mic_label.set_text("  Microphone Input")
            self.spk_mute_btn.set_label("󰝟 Muted" if spk_muted else " Mute")
            self.mic_mute_btn.set_label(" Muted" if mic_muted else " Mute")
            self.spk_pct_label.set_text(f"Muted ({spk_vol}%)" if spk_muted else f"{spk_vol}%")
            self.mic_pct_label.set_text(f"Muted ({mic_vol}%)" if mic_muted else f"{mic_vol}%")
            self.hint_label.set_text("Drag slider to adjust  ·  Alt+l 中文  ·  Esc to close")

        for ctx, is_muted in (
            (self.spk_pct_label.get_style_context(), spk_muted),
            (self.spk_mute_btn.get_style_context(), spk_muted),
            (self.mic_pct_label.get_style_context(), mic_muted),
            (self.mic_mute_btn.get_style_context(), mic_muted),
        ):
            if is_muted:
                ctx.add_class("muted")
                ctx.add_class("active")
            else:
                ctx.remove_class("muted")
                ctx.remove_class("active")

    def on_spk_slider_changed(self, scale):
        if self._updating:
            return
        val = int(round(scale.get_value()))
        set_audio_volume("@DEFAULT_AUDIO_SINK@", val)
        _, spk_muted = get_audio_state("@DEFAULT_AUDIO_SINK@")
        mic_vol, mic_muted = int(round(self.mic_scale.get_value())), False
        self.update_labels(val, spk_muted, mic_vol, mic_muted)

    def on_mic_slider_changed(self, scale):
        if self._updating:
            return
        val = int(round(scale.get_value()))
        set_audio_volume("@DEFAULT_AUDIO_SOURCE@", val)
        spk_vol = int(round(self.spk_scale.get_value()))
        _, spk_muted = get_audio_state("@DEFAULT_AUDIO_SINK@")
        _, mic_muted = get_audio_state("@DEFAULT_AUDIO_SOURCE@")
        self.update_labels(spk_vol, spk_muted, val, mic_muted)

    def on_preset_clicked(self, _btn, pct):
        subprocess.run(
            ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        set_audio_volume("@DEFAULT_AUDIO_SINK@", pct)
        self.spk_adj.set_value(pct)
        self.refresh_state()

    def on_toggle_spk_mute(self, _btn):
        toggle_audio_mute("@DEFAULT_AUDIO_SINK@")
        self.refresh_state()

    def on_toggle_mic_mute(self, _btn):
        toggle_audio_mute("@DEFAULT_AUDIO_SOURCE@")
        self.refresh_state()

    def on_toggle_lang(self, *_args):
        self.lang = "en" if self.lang == "zh" else "zh"
        set_lang(self.lang)
        self.refresh_state()

    def on_key_press(self, _widget, event):
        keyname = Gdk.keyval_name(event.keyval)
        state = event.state & Gtk.accelerator_get_default_mod_mask()
        if keyname in ("Escape", "q"):
            Gtk.main_quit()
            return True
        if (state & Gdk.ModifierType.MOD1_MASK) and keyname in ("l", "L"):
            self.on_toggle_lang()
            return True
        return False


if __name__ == "__main__":
    win = AudioPopup()
    win.show_all()
    Gtk.main()
