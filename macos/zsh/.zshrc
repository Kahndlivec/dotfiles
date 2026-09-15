# ═══════════════════════════════════════════════════════════════════
#  ~/.zshrc
# ═══════════════════════════════════════════════════════════════════

# ─── History ───────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS HIST_IGNORE_SPACE
setopt SHARE_HISTORY
# SHARE_HISTORY means every tmux pane sees every other pane's commands
# live. If ↑ in one pane starts showing things you ran somewhere else and
# that annoys you, swap the line above for:
#   setopt INC_APPEND_HISTORY   # write immediately, but don't read back

# ─── Completion ────────────────────────────────────────────────────
FPATH="$(brew --prefix)/share/zsh/site-functions:$FPATH"
autoload -Uz compinit && compinit -C
# -C skips the completion-dir security check. Costs ~150ms per shell to
# do it properly; on a single-user machine it buys nothing.

# ─── Keys ──────────────────────────────────────────────────────────
# Emacs keys in the shell, deliberately — and now doubly so, since the
# same ⌃a/⌃e/⌃r work inside emacsclient. Vi mode in zsh has no visual
# mode indicator and the modal switch isn't worth it for one-liners.
bindkey -e

# ─── PATH ──────────────────────────────────────────────────────────
typeset -U path PATH          # dedupe on re-source

path=(
  "$HOME/.config/emacs/bin"   # doom CLI: doom sync / doom doctor
  "$HOME/.local/bin"
  $path
  "/opt/homebrew/opt/llvm/bin"  # clangd + lldb-dap. LAST on purpose so
                                # brew's clang doesn't shadow Xcode's.
)
# Uncomment if you ever install MacTeX:
# path+=("/Library/TeX/texbin")

# ─── Editor ────────────────────────────────────────────────────────
# No daemon: config.el starts the server inside the GUI Emacs you launch
# from the Dock, so emacsclient talks to THAT window.
#
# -a nvim is the fallback when Emacs isn't open. Deliberately nvim and not
# '' — an empty alternate spawns a background DAEMON, which is exactly the
# second-Emacs problem we're avoiding. A commit message in nvim is fine.
export EDITOR="emacsclient -t -a nvim"
export VISUAL="$EDITOR"

# Open a file in the running Emacs; launch the app if it isn't up yet.
e() {
  emacsclient -n -c "$@" 2>/dev/null || open -a Emacs "$@"
}

# Terminal frame — SSH, or inside tmux. Falls back to a fresh terminal
# Emacs (slow, but it works) if no server is listening.
et() {
  emacsclient -t "$@" 2>/dev/null || emacs -nw "$@"
}

alias doomsync='doom sync && doom doctor'

# Emacs on the homelab: attaches to the tmux session holding it, or starts one.
# The session persists across disconnects — same buffers when you come back.
# XDG_RUNTIME_DIR and $HOME are single-quoted so they resolve THERE, not here.
eh() { ssh -t homelab '$HOME/.local/bin/e'; }

# nvim stays for remote boxes and quick root edits.
alias v=nvim

# ─── Plugins (syntax-highlighting must be sourced last) ────────────
source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
eval "$(starship init zsh)"

# Per-project envs. Emacs' direnv module reads the same .envrc files, so the
# shell and the editor agree on which venv/toolchain is active.
eval "$(direnv hook zsh)"

# ═══════════════════════════════════════════════════════════════════
#  Competitive programming
#
#  These are the shell fallback. The real loop now lives in Emacs:
#    SPC m b   build          SPC m t   run every sample and diff
#    SPC m B   sanitizers     SPC m r   run interactively
#
#  Flags below are copied from `+cp-fast-flags' and `+cp-debug-flags'
#  in ~/.config/doom/+cp.el. THEY ARE NOT LINKED — if you change one,
#  change the other, or you'll get the c++17-vs-c++20 divergence you
#  already got bitten by once.
#
#  Both take an optional second argument for a different input file.
# ═══════════════════════════════════════════════════════════════════

_cp_input() { [[ -f tests/01.in ]] && echo tests/01.in || echo in.txt; }

# Sanitizers, no optimisation — for finding UB and out-of-bounds.
cprun() {
  clang++ -std=c++23 -g -O1 -DLOCAL \
    -fsanitize=address,undefined -fno-sanitize-recover=all \
    -fno-omit-frame-pointer \
    -Wall -Wextra -Wshadow "$1" -o /tmp/sol \
    && /tmp/sol < "${2:-$(_cp_input)}"
}

# What the judge actually runs. No _GLIBCXX_DEBUG: Codeforces doesn't
# use it, it changes container ABI and it's slow, so a build with it is
# not the build you're submitting. Bounds checking is cprun's job.
cpjudge() {
  g++-16 -std=c++23 -O2 -Wall -Wextra -Wshadow "$1" -o /tmp/sol \
    && /tmp/sol < "${2:-$(_cp_input)}"
}

# ─── Git ───────────────────────────────────────────────────────────
cpush() { git add -A && git commit -m "$1" && git push; }

# ─── Shortcuts ─────────────────────────────────────────────────────
alias ta='tmux attach || tmux new'
alias wake-khandlab='wakeonlan b4:2e:99:88:8e:d8'
