# ═══════════════════════════════════════════════════════════════════
#  ~/.zshrc  —  Linux
#
#  Ported from macos/zsh/.zshrc. Every difference from that file is
#  marked LINUX so you can diff the two and see exactly what changed.
# ═══════════════════════════════════════════════════════════════════

# ─── History ───────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS HIST_IGNORE_SPACE
setopt SHARE_HISTORY

# ─── Completion ────────────────────────────────────────────────────
# LINUX: no `brew --prefix`. Ubuntu puts site-functions on the default
# FPATH already, so the whole line is gone.
autoload -Uz compinit && compinit -C

# ─── Keys ──────────────────────────────────────────────────────────
bindkey -e

# ─── PATH ──────────────────────────────────────────────────────────
typeset -U path PATH

path=(
  "$HOME/.config/emacs/bin"     # doom CLI
  "$HOME/.local/bin"            # LINUX: also where mise, uv, starship land
  $path
)
# LINUX: /opt/homebrew/opt/llvm/bin is gone — apt's clangd is /usr/bin/clangd
# and there's no Xcode toolchain to shadow.
# LINUX: no MacTeX line; texlive is on the default PATH.

# ─── GNU vs BSD binary names ───────────────────────────────────────
# LINUX: Debian ships these under different names to avoid collisions.
alias fd=fdfind
alias bat=batcat

# ─── Editor ────────────────────────────────────────────────────────
export EDITOR="emacsclient -t -a nvim"
export VISUAL="$EDITOR"

# LINUX: `open -a Emacs` doesn't exist. setsid detaches the GUI Emacs so
# it survives closing the terminal, same as launching from the Dock did.
e() {
  emacsclient -n -c "$@" 2>/dev/null || { setsid -f emacs "$@" >/dev/null 2>&1; }
}

et() {
  emacsclient -t "$@" 2>/dev/null || emacs -nw "$@"
}

alias doomsync='doom sync && doom doctor'

# LINUX: the tower is a workstation now, not a headless server. This is
# for the ThinkPads — heavy compiles and CUDA work go home. Terminal
# Emacs inside a tmux that survives the train losing signal.
# Needs linux/ssh/install.sh to have been run.
eh() { ssh -t tower 'tmux new -As org "emacsclient -t -a emacs"'; }

alias v=nvim

# ─── Plugins (syntax-highlighting must be sourced last) ────────────
# LINUX: apt paths instead of $(brew --prefix)/share.
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
eval "$(starship init zsh)"
eval "$(direnv hook zsh)"

# LINUX: new — mise replaces brew's node, zoxide replaces nothing you had.
eval "$(mise activate zsh)"
eval "$(zoxide init zsh)"

# ─── Clipboard ─────────────────────────────────────────────────────
# LINUX: pbcopy/pbpaste shims. Doom's org-download and yank-to-system
# both expect these to exist. wl-* on Wayland, xclip on X11.
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
  alias pbcopy='wl-copy'
  alias pbpaste='wl-paste'
else
  alias pbcopy='xclip -selection clipboard'
  alias pbpaste='xclip -selection clipboard -o'
fi

# ═══════════════════════════════════════════════════════════════════
#  Competitive programming
#
#  Flags copied from `+cp-fast-flags' / `+cp-debug-flags' in
#  ~/.config/doom/+cp.el. STILL NOT LINKED — change one, change both.
# ═══════════════════════════════════════════════════════════════════

_cp_input() { [[ -f tests/01.in ]] && echo tests/01.in || echo in.txt; }

cprun() {
  clang++ -std=c++23 -g -O1 -DLOCAL \
    -fsanitize=address,undefined -fno-sanitize-recover=all \
    -fno-omit-frame-pointer \
    -Wall -Wextra -Wshadow "$1" -o /tmp/sol \
    && /tmp/sol < "${2:-$(_cp_input)}"
}

# LINUX: g++-16 -> g++. Ubuntu 26.04's default g++ is new enough for
# -std=c++23; check with `g++ --version` if a feature goes missing.
cpjudge() {
  g++ -std=c++23 -O2 -Wall -Wextra -Wshadow "$1" -o /tmp/sol \
    && /tmp/sol < "${2:-$(_cp_input)}"
}

# ─── Git ───────────────────────────────────────────────────────────
cpush() { git add -A && git commit -m "$1" && git push; }

# ─── Shortcuts ─────────────────────────────────────────────────────
alias ta='tmux attach || tmux new'
alias wake-khandlab='wakeonlan b4:2e:99:88:8e:d8'
alias ls='eza --group-directories-first'
alias ll='eza -lah --git --group-directories-first'
