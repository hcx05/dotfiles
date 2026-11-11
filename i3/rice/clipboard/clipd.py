#!/usr/bin/env python3
# ============================================================================
# clipd.py -- tiny X-clipboard history daemon for the i3 rice.
#
# Nothing on this system records clipboard history (no clipman/greenclip/
# copyq/cliphist). kitty's ctrl+shift+c, the screenshot tool and tmux-yank all push to
# the X CLIPBOARD selection via xclip, but once it's overwritten the old
# value is gone. This daemon polls the CLIPBOARD selection and keeps a
# rolling history on disk so clipmenu.py can offer it back.
#
# Why polling (not clipnotify): clipnotify isn't packaged on this Kali box.
# `xclip -o` is cheap, so a 1s poll is plenty and avoids a new dependency.
#
# Storage: ~/.cache/cliprice/history -- one entry per line, base64-encoded
# (newest first). base64 means multiline / odd content survives a plain
# line-based file with zero delimiter headaches. Capped at MAX_ENTRIES.
#
# Started from i3 (exec --no-startup-id). A flock guard makes a second
# launch a no-op, so `restart`/`reload` can't stack daemons.
# ============================================================================
import base64
import fcntl
import os
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
CACHE_DIR = os.path.join(HOME, ".cache", "cliprice")
HISTORY = os.path.join(CACHE_DIR, "history")
LOCK = os.path.join(CACHE_DIR, "clipd.lock")

MAX_ENTRIES = 100          # how many clips to remember
MAX_BYTES = 1_000_000      # skip giant clips (images-as-text, file dumps)
POLL_SECONDS = 1.0


def read_clipboard():
    """Current CLIPBOARD selection as text, or None if empty/unavailable."""
    try:
        out = subprocess.run(
            ["xclip", "-selection", "clipboard", "-o"],
            capture_output=True, timeout=2,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None
    if out.returncode != 0:
        return None
    data = out.stdout
    if not data or len(data) > MAX_BYTES:
        return None
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return None          # non-text (image target etc.) -- skip
    if not text.strip():
        return None
    return text


def load_history():
    if not os.path.exists(HISTORY):
        return []
    entries = []
    with open(HISTORY, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(base64.b64decode(line).decode("utf-8"))
            except Exception:
                continue
    return entries


def save_history(entries):
    tmp = HISTORY + ".tmp"
    with open(tmp, "w") as f:
        for e in entries[:MAX_ENTRIES]:
            f.write(base64.b64encode(e.encode("utf-8")).decode("ascii"))
            f.write("\n")
    os.replace(tmp, HISTORY)   # atomic -- clipmenu never sees a half file


def main():
    os.makedirs(CACHE_DIR, exist_ok=True)

    # Single-instance guard: hold an exclusive lock for the daemon's life.
    lock_fd = open(LOCK, "w")
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit(0)           # another clipd already running -- quietly exit

    last = None
    while True:
        text = read_clipboard()
        if text is not None and text != last:
            last = text
            entries = load_history()
            # Dedup: drop any existing identical entry, then push to front.
            entries = [e for e in entries if e != text]
            entries.insert(0, text)
            save_history(entries)
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
