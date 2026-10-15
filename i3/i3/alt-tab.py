#!/usr/bin/env python3
"""MRU (most-recently-used) Alt-Tab window switching for i3.

i3 has no built-in "hold Alt, tap Tab to cycle, release Alt to select"
behavior -- this implements it using i3ipc:

  daemon  Run persistently (started via exec_always, so it also survives an
          i3 reload/restart -- see the flock guard at the top of daemon()).
          Subscribes to window::focus events and maintains an MRU-ordered
          history of window ids in a state file.
  step    Called from the "altTab" i3 mode each time Tab is pressed while
          Alt is held. Advances a cycle position and focuses that window.
  reset   Called when Alt is released (mode exits back to "default"). Moves
          whatever window ended up focused to the front of the MRU history
          and clears the cycle position.

IMPORTANT: while cycling (CYCLE_FILE exists), the daemon's window::focus
handler does NOT touch the MRU history -- each `step` call focuses a
window, which fires window::focus, which would otherwise immediately
reorder the very history `step` is reading from, scrambling the cycle
(observed: second Tab press jumped to the 3rd-most-recent window instead
of continuing to the 4th, because the 1st step's focus had already been
spliced to the front). MRU order is only committed for real in `reset`,
once the user has actually landed on their final choice.
"""
import sys
import os
import json
import fcntl
import i3ipc

STATE_FILE = os.path.expanduser("~/.cache/i3-alttab-history.json")
CYCLE_FILE = os.path.expanduser("~/.cache/i3-alttab-cycle")
TARGET_FILE = os.path.expanduser("~/.cache/i3-alttab-target")
LOCK_FILE = os.path.expanduser("~/.cache/i3-alttab-daemon.lock")
MAX_HISTORY = 20


def daemon():
    # Single-instance guard (same pattern as clipd.py): started via
    # exec_always, so i3 re-runs this line on every reload/restart, not
    # just the first startup -- without this, each one would stack another
    # daemon on top instead of replacing it.
    lock_fd = open(LOCK_FILE, "w")
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit(0)  # another instance is already running -- quietly exit

    i3 = i3ipc.Connection()
    history = []
    if os.path.exists(STATE_FILE):
        try:
            history = json.load(open(STATE_FILE))
        except Exception:
            history = []

    def on_focus(i3conn, event):
        if os.path.exists(CYCLE_FILE):
            # mid-cycle: this focus was caused by our own `step`, not a
            # real user selection yet -- don't reorder history on it.
            return
        win = event.container.window
        if win is None:
            return
        if win in history:
            history.remove(win)
        history.insert(0, win)
        del history[MAX_HISTORY:]
        with open(STATE_FILE, "w") as f:
            json.dump(history, f)

    def on_close(i3conn, event):
        win = event.container.window
        if win is not None and win in history:
            history.remove(win)
            with open(STATE_FILE, "w") as f:
                json.dump(history, f)

    i3.on("window::focus", on_focus)
    i3.on("window::close", on_close)
    i3.main()


def step():
    if not os.path.exists(STATE_FILE):
        return
    try:
        history = json.load(open(STATE_FILE))
    except Exception:
        return
    if len(history) < 2:
        return

    cycle = 1
    if os.path.exists(CYCLE_FILE):
        try:
            cycle = int(open(CYCLE_FILE).read().strip()) + 1
        except Exception:
            cycle = 1
    if cycle >= len(history):
        cycle = 1

    # skip windows that no longer exist (closed since last recorded)
    i3 = i3ipc.Connection()
    tree = i3.get_tree()
    live_ids = {w.window for w in tree.leaves() if w.window is not None}
    tried = 0
    while history[cycle] not in live_ids and tried < len(history):
        cycle += 1
        if cycle >= len(history):
            cycle = 1
        tried += 1
    if tried >= len(history):
        return

    with open(CYCLE_FILE, "w") as f:
        f.write(str(cycle))

    target = history[cycle]
    with open(TARGET_FILE, "w") as f:
        f.write(str(target))
    i3.command(f'[id={target}] focus')


def reset_cycle():
    # Commit the final choice to MRU history now, since window::focus
    # events were ignored by the daemon for every step taken during the
    # cycle (see on_focus above) -- history still reflects pre-cycle order.
    # Read the last `step` target directly rather than re-querying i3 for
    # "current focus" here: that query races with focus_follows_mouse and
    # can observe whatever window the mouse happens to be over instead of
    # the one the cycle actually landed on.
    if os.path.exists(TARGET_FILE):
        try:
            win = int(open(TARGET_FILE).read().strip())
            history = []
            if os.path.exists(STATE_FILE):
                try:
                    history = json.load(open(STATE_FILE))
                except Exception:
                    history = []
            if win in history:
                history.remove(win)
            history.insert(0, win)
            del history[MAX_HISTORY:]
            with open(STATE_FILE, "w") as f:
                json.dump(history, f)
        except Exception:
            pass
        os.remove(TARGET_FILE)
    if os.path.exists(CYCLE_FILE):
        os.remove(CYCLE_FILE)


if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else ""
    if action == "daemon":
        daemon()
    elif action == "step":
        step()
    elif action == "reset":
        reset_cycle()
    else:
        print("usage: alt-tab.py {daemon|step|reset}", file=sys.stderr)
        sys.exit(1)
