Clipboard history menu for the i3 rice
======================================

  $mod+c   open the clipboard history picker (rofi, themed via rofi/config.rasi)

Pieces:
  clipd.py    background daemon (autostarted from i3). Polls the X CLIPBOARD
              selection every 1s and records history to ~/.cache/cliprice/history
              (base64, newest first, capped 100). flock single-instance guard.
  clipmenu.py the rofi picker. Merges clipd history + current tmux buffers,
              deduped. Selecting an entry reloads it into X clipboard + primary
              + a tmux buffer, so every existing paste path works:
                kitty  ctrl+v / ctrl+shift+v
                tmux   prefix + ]
                GUI    ctrl+v / middle-click
              Bottom row clears the history.

Why a daemon: nothing else on this box records clipboard history (no clipman/
greenclip/copyq/cliphist). tmux only kept history for things copied inside tmux.
