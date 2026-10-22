# Powerlevel10k colors per i3 rice preset -- sourced by ~/.zshrc right after
# ~/.p10k.zsh. ~/.p10k.zsh itself stays the purple/green ("classic") prompt;
# the mono preset recolors it to black & white on top. Only colors change --
# segments, icons and layout are whatever ~/.p10k.zsh says.
#
# ~/.config/rice/terminal-style (one word, written by apply-theme.sh) says
# which look is wanted. It's re-checked before every prompt, so shells that
# are already open follow a theme switch at their next prompt.

typeset -g _rice_style_file=$HOME/.config/rice/terminal-style
typeset -g _rice_style_applied=classic   # what ~/.p10k.zsh alone gives

_rice_p10k_mono() {
  local p
  # Every segment: dark grey surface, white text. Errors (and merge
  # conflicts) keep their red, like URGENT stays red in every preset.
  for p in ${(k)parameters[(I)POWERLEVEL9K_*_BACKGROUND]}; do
    [[ -n ${(P)p} ]] && typeset -g $p=236
  done
  for p in ${(k)parameters[(I)POWERLEVEL9K_*_FOREGROUND]}; do
    [[ $p == *(ERROR|CRITICAL|CONFLICTED|GAP)* ]] && continue
    typeset -g $p=255
  done
  # Left prompt goes white -> dark -> light so the segments stay apart.
  typeset -g POWERLEVEL9K_OS_ICON_BACKGROUND=255
  typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=232
  typeset -g POWERLEVEL9K_DIR_BACKGROUND=238
  typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND=250
  # git: black text (from the formatter in ~/.p10k.zsh) on grey; a dirty
  # tree is a lighter grey than a clean one.
  typeset -g POWERLEVEL9K_VCS_{CLEAN,UNTRACKED}_BACKGROUND=245
  typeset -g POWERLEVEL9K_VCS_{MODIFIED,CONFLICTED}_BACKGROUND=250
  typeset -g POWERLEVEL9K_VCS_LOADING_BACKGROUND=240
  typeset -g POWERLEVEL9K_VCS_{CLEAN,MODIFIED,UNTRACKED}_FOREGROUND=232
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_FOREGROUND=240
}

# Bring the prompt to style $1. Re-sourcing ~/.p10k.zsh first resets every
# POWERLEVEL9K_* option (it unsets them all and reloads p10k), so going back
# to classic needs nothing else.
_rice_apply_style() {
  [[ $1 == $_rice_style_applied ]] && return
  [[ -r ~/.p10k.zsh ]] && source ~/.p10k.zsh
  if [[ $1 == mono ]]; then
    _rice_p10k_mono
    (( ! $+functions[p10k] )) || p10k reload
  fi
  _rice_style_applied=$1
}

_rice_style_precmd() {
  local want=classic
  [[ -r $_rice_style_file ]] && want=$(<$_rice_style_file)
  _rice_apply_style ${want:-classic}
}

# Run ahead of p10k's own precmd so a switch shows on the very next prompt.
precmd_functions=(_rice_style_precmd ${precmd_functions:#_rice_style_precmd})
_rice_style_precmd
