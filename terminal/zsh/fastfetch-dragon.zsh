# Replace the plain `neofetch` call in ~/.zshrc (line 117) with our cyan
# PNG-dragon fastfetch instead -- without touching .zshrc itself. Oh My Zsh
# sources every file in $ZSH_CUSTOM/*.zsh from inside oh-my-zsh.sh, which
# .zshrc calls *before* its own `neofetch` line, so by the time that line
# runs, this function shadows the real `neofetch` binary (zsh functions take
# priority over $PATH commands). Config: ~/.config/fastfetch/config.jsonc.
#
# Can't just run `command fastfetch` (or defer it to a `precmd` hook)
# synchronously from here: Powerlevel10k's instant-prompt feature redirects
# stdout/stderr into a capture log for the whole rest of .zshrc's execution,
# INCLUDING the first precmd cycle where it tears the redirect back down --
# a hook added here still lands inside that same first precmd_functions
# pass, so its output gets swallowed into the "console output produced
# during zsh initialization" replay instead of reaching the terminal live,
# and the kitty graphics-protocol escape sequences get corrupted by that
# capture/replay, so fastfetch silently falls back to its plain ASCII logo.
# `zsh/sched` schedules a real callback through the main event loop instead,
# which only fires once zsh is genuinely idle waiting for interactive input
# -- by definition after p10k has finished its handoff -- so it actually
# lands on the live terminal.
neofetch() {
    zmodload zsh/sched 2>/dev/null
    sched +1 fastfetch
}
