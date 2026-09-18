# ═══════════════════════════════════════════════════════════════════
#  ~/.zshrc  →  symlink to dotfiles/zsh/.zshrc
# ═══════════════════════════════════════════════════════════════════

# ─── History ───────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS HIST_IGNORE_SPACE
setopt SHARE_HISTORY
# SHARE_HISTORY means every tmux pane sees every other pane's commands
# live. If that annoys you, swap it for:  setopt INC_APPEND_HISTORY

# ─── Completion ────────────────────────────────────────────────────
autoload -Uz compinit && compinit -C
# -C skips the completion-dir security check. Costs ~150ms per shell to
# do it properly; on a single-user machine it buys nothing.

# ─── Keys ──────────────────────────────────────────────────────────
# Emacs keys in the shell, deliberately: the same C-a/C-e/C-r work inside
# emacsclient, and vi mode in zsh has no visual mode indicator.
bindkey -e

# ─── PATH ──────────────────────────────────────────────────────────
# GNOME apps get the same list from ~/.config/environment.d/10-path.conf.
typeset -U path PATH
path=(
  "$HOME/.local/bin"
  "$HOME/.npm-global/bin"
  "$HOME/.config/emacs/bin"   # doom CLI: doom sync / doom doctor
  $path
)

# ─── Editor ────────────────────────────────────────────────────────
# config.el starts the server inside the GUI Emacs (Super+E), so
# emacsclient talks to THAT window. -a nvim is the fallback when Emacs
# isn't open — deliberately not '', which would spawn a second Emacs.
export EDITOR="emacsclient -t -a nvim"
export VISUAL="$EDITOR"

# Open files in the running Emacs; launch it if it isn't up yet.
e() {
  emacsclient -n -c "$@" 2>/dev/null || setsid -f emacs "$@" >/dev/null 2>&1
}

# Terminal frame — SSH, or inside tmux.
et() {
  emacsclient -t "$@" 2>/dev/null || emacs -nw "$@"
}

alias doomsync='doom sync && doom doctor'

# Save notes: commit + push to GitHub, then copy to Drive for the iPad.
# Same thing as SPC n p in Emacs. Nothing runs on a schedule.
alias notes-push="$HOME/dotfiles/bin/notes-sync"
alias v=nvim

# ─── Linux conveniences ────────────────────────────────────────────
alias open='xdg-open'
if command -v eza >/dev/null; then
  alias ls='eza --group-directories-first'
  alias ll='eza -la --git --group-directories-first'
else
  alias ls='ls --color=auto --group-directories-first'
  alias ll='ls -lah'
fi
command -v batcat >/dev/null && alias bat='batcat'   # Ubuntu names it batcat
alias grep='grep --color=auto'
alias update='sudo apt update && sudo apt full-upgrade -y && sudo snap refresh'

# ─── Dotfiles ──────────────────────────────────────────────────────
# Configs are symlinked into the repo, so editing ~/.zshrc IS editing the
# repo. This just commits and pushes.
export DOTFILES="${${(%):-%x}:A:h:h}"   # repo root, found via the symlink
dots() { git -C "$DOTFILES" "$@"; }
dotsync() { git -C "$DOTFILES" add -A && git -C "$DOTFILES" commit -m "${1:-update}" && git -C "$DOTFILES" push; }

# ═══════════════════════════════════════════════════════════════════
#  Competitive programming — shell fallback. The real loop is in Emacs:
#    SPC m b build   SPC m t run samples + diff   SPC m B sanitizers
#
#  Flags mirror `+cp-fast-flags' / `+cp-debug-flags' in doom/+cp.el.
#  THEY ARE NOT LINKED — change one, change the other.
#  Both take an optional second argument for a different input file.
# ═══════════════════════════════════════════════════════════════════
_cp_input() { [[ -f tests/01.in ]] && echo tests/01.in || echo in.txt; }

# Sanitizers, no optimisation — for finding UB and out-of-bounds.
cprun() {
  g++ -std=c++23 -g -O1 -DLOCAL \
    -fsanitize=address,undefined -fno-sanitize-recover=all \
    -fno-omit-frame-pointer \
    -Wall -Wextra -Wshadow "$1" -o /tmp/sol \
    && /tmp/sol < "${2:-$(_cp_input)}"
}

# What the judge actually runs.
cpjudge() {
  g++ -std=c++23 -O2 -Wall -Wextra -Wshadow "$1" -o /tmp/sol \
    && /tmp/sol < "${2:-$(_cp_input)}"
}

# ─── Git ───────────────────────────────────────────────────────────
cpush() { git add -A && git commit -m "$1" && git push; }

# ─── tmux ──────────────────────────────────────────────────────────
alias ta='tmux attach || tmux new'

# ─── Per person, then per machine ──────────────────────────────────
# people/<you>/zshrc (synced), then ~/.zshrc.local (this machine only).
[[ -r ~/.config/dotfiles/person/zshrc ]] && source ~/.config/dotfiles/person/zshrc
[[ -r ~/.zshrc.local ]] && source ~/.zshrc.local

# ─── Plugins (syntax-highlighting must be sourced last) ────────────
command -v starship >/dev/null && eval "$(starship init zsh)"
command -v direnv   >/dev/null && eval "$(direnv hook zsh)"
command -v zoxide   >/dev/null && eval "$(zoxide init zsh)"
[[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] \
  && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] \
  && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
