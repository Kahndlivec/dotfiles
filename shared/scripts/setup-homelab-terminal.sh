#!/usr/bin/env bash
# Fix the two things stopping a remote TUI Emacs from working:
#   1. Your terminal's terminfo may not exist on the remote box, so anything
#      TUI refuses to start with "missing or unsuitable terminal: <TERM>".
#   2. Your tmux config isn't there, and needs two Linux adaptations.
#
# RUN THIS FROM THE TERMINAL YOU ACTUALLY USE (it copies your live terminfo):
#   bash setup-homelab-terminal.sh            # asks which host
#   bash setup-homelab-terminal.sh <alias>    # or pass it in
set -euo pipefail

# ─── helpers ─────────────────────────────────────────────────────────
ask() {  # ask <varname> <prompt> [default]
  local __var=$1 __prompt=$2 __default=${3:-} __reply=""
  if [[ -n "$__default" ]]; then
    read -r -p "$__prompt [$__default]: " __reply </dev/tty || true
    __reply="${__reply:-$__default}"
  else
    while [[ -z "$__reply" ]]; do
      read -r -p "$__prompt: " __reply </dev/tty || true
    done
  fi
  printf -v "$__var" '%s' "$__reply"
}

confirm() {
  local __reply=""
  read -r -p "$1 [y/N]: " __reply </dev/tty || true
  [[ "$__reply" =~ ^[Yy] ]]
}

# ─── which host ──────────────────────────────────────────────────────
HOST="${1:-}"

if [[ -z "$HOST" ]]; then
  mapfile -t HOSTS < <(awk '/^[[:space:]]*Host[[:space:]]/ {
      for (i = 2; i <= NF; i++) if ($i !~ /[*?]/) print $i
    }' ~/.ssh/config 2>/dev/null | sort -u || true)

  if (( ${#HOSTS[@]} > 0 )); then
    echo "Hosts in ~/.ssh/config:"
    for i in "${!HOSTS[@]}"; do printf "  %2d) %s\n" "$((i+1))" "${HOSTS[$i]}"; done
    echo "   0) type one by hand"
    echo
    ask PICK "Which one" "1"
    if [[ "$PICK" =~ ^[0-9]+$ ]] && (( PICK >= 1 && PICK <= ${#HOSTS[@]} )); then
      HOST="${HOSTS[$((PICK-1))]}"
    fi
  fi
  [[ -n "$HOST" ]] || ask HOST "SSH alias or user@hostname"
fi

echo "== Checking $HOST is reachable"
ssh -o ConnectTimeout=10 "$HOST" 'echo "   ok: $(hostname)"'

# ─── terminfo ────────────────────────────────────────────────────────
LOCAL_TERM="${TERM:-xterm-256color}"
echo
echo "== Terminfo"
echo "   local TERM=$LOCAL_TERM"

# ncurses-term carries the tmux-256color entry. Needs root, so it is NOT
# done here -- an interactive sudo prompt inside a script is a reliable way
# to produce something that looks like a freeze. If the check below says it
# is missing, run this yourself in a normal ssh session:
#
#   ssh HOST
#   sudo apt-get install -y ncurses-term
#
# Everything else in this script needs no root at all.

if ssh "$HOST" "infocmp $LOCAL_TERM >/dev/null 2>&1"; then
  echo "   $LOCAL_TERM already present on $HOST"
elif infocmp -x "$LOCAL_TERM" >/dev/null 2>&1; then
  # Ship your local terminfo entry to the remote host — the documented fix.
  infocmp -x "$LOCAL_TERM" | ssh "$HOST" -- tic -x - \
    && echo "   $LOCAL_TERM installed on $HOST"
else
  echo "   ! no local terminfo for $LOCAL_TERM — skipping"
fi

ssh "$HOST" 'infocmp tmux-256color >/dev/null 2>&1 && echo "   tmux-256color ok" || echo "   ! tmux-256color missing"'

# ─── tmux config ─────────────────────────────────────────────────────
echo
echo "== tmux config"

if ssh "$HOST" 'test -f ~/.tmux.conf'; then
  if ! confirm "   ~/.tmux.conf already exists on $HOST. Overwrite?"; then
    echo "   left alone"
    SKIP_TMUX=1
  fi
fi

if [[ -z "${SKIP_TMUX:-}" ]]; then
  TMPCONF=$(mktemp)
  trap 'rm -f "$TMPCONF"' EXIT

  # Quoted heredoc: nothing below is expanded locally. __TERM__ is replaced
  # afterwards, which is why it isn't written as a shell variable.
  cat > "$TMPCONF" <<'TMUX'
# ~/.tmux.conf — remote. Mirrors the Mac config, with two changes:
#   - clipboard goes through OSC 52 instead of pbcopy, so a yank here lands
#     in your Mac's clipboard over SSH. There's no X server on this box.
#   - the is_vim test also matches emacs, so C-hjkl inside remote Emacs
#     moves Emacs windows instead of tmux panes.

unbind C-b
set -g prefix C-Space
bind C-Space send-prefix

bind v split-window -h -c "#{pane_current_path}"
bind s split-window -v -c "#{pane_current_path}"
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# NOTE the added |emacs — without it tmux swallows C-hjkl in Emacs.
is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
    | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?\\.?(view|l?n?vim?x?|emacs|fzf)(diff)?$'"

bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h' 'select-pane -L'
bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j' 'select-pane -D'
bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k' 'select-pane -U'
bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l' 'select-pane -R'
bind C-l send-keys 'C-l'

bind-key -T copy-mode-vi 'C-h' select-pane -L
bind-key -T copy-mode-vi 'C-j' select-pane -D
bind-key -T copy-mode-vi 'C-k' select-pane -U
bind-key -T copy-mode-vi 'C-l' select-pane -R

bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

bind c new-window -c "#{pane_current_path}"
bind -r n next-window
bind -r p previous-window
bind w choose-tree -Zs

set -sg escape-time 10
set -g mouse on
set -g history-limit 50000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g focus-events on
set -g detach-on-destroy off

# OSC 52: tmux hands the copied text to your terminal over the SSH
# connection, and the terminal puts it on the macOS clipboard. This is the
# remote equivalent of pbcopy, and it needs no X server.
set -g set-clipboard on
setw -g mode-keys vi
bind Enter copy-mode
bind -T copy-mode-vi v send -X begin-selection
bind -T copy-mode-vi C-v send -X rectangle-toggle
bind -T copy-mode-vi y send -X copy-selection-and-cancel
bind -T copy-mode-vi MouseDragEnd1Pane send -X copy-selection-no-clear

set -g default-terminal "tmux-256color"
set -as terminal-features ",__TERM__:RGB"
set -as terminal-features ",__TERM__:usstyle"
set -as terminal-overrides ',*:Smulx=\E[4::%p1%dm'
set -as terminal-overrides ',*:Setulc=\E[58::2::%p1%{65536}%/%d::%p1%{256}%/%{255}%&%d::%p1%{255}%&%d%;m'

bind r source-file ~/.tmux.conf \; display "tmux.conf reloaded"
TMUX

  sed -i.bak "s/__TERM__/$LOCAL_TERM/g" "$TMPCONF" && rm -f "$TMPCONF.bak"
  ssh "$HOST" 'cat > ~/.tmux.conf' < "$TMPCONF"
  echo "   written (terminal-features set for $LOCAL_TERM)"
fi

# ─── launcher ────────────────────────────────────────────────────────
echo
echo "== Launcher on the remote side"
# A script on the far side avoids three levels of shell quoting in the alias,
# which is its own source of silent breakage.
ssh "$HOST" 'mkdir -p ~/.local/bin && cat > ~/.local/bin/e && chmod +x ~/.local/bin/e' <<'LAUNCH'
#!/usr/bin/env bash
# Attach to the emacs tmux session, or create it. Session persists across
# disconnects, so you come back to the same buffers and window layout.
exec tmux new -A -s emacs emacs -nw "$@"
LAUNCH
echo "   ~/.local/bin/e"

echo
echo "== Resetting the tmux server so the new config is picked up"
ssh "$HOST" 'tmux kill-server 2>/dev/null; true' || true
echo "   done"

# ─── local alias ─────────────────────────────────────────────────────
ALIAS_LINE="alias eh='ssh -t $HOST ~/.local/bin/e'"
echo
if grep -qF "$ALIAS_LINE" ~/.zshrc 2>/dev/null; then
  echo "== 'eh' alias already in ~/.zshrc"
elif confirm "== Add the 'eh' alias to ~/.zshrc for you?"; then
  cp ~/.zshrc ~/.zshrc.bak.$(date +%s) 2>/dev/null || true
  # drop any previous eh definition, function or alias
  sed -i.tmp '/^eh()/d;/^alias eh=/d' ~/.zshrc && rm -f ~/.zshrc.tmp
  printf '%s\n' "$ALIAS_LINE" >> ~/.zshrc
  echo "   added — run 'exec zsh' then 'eh'"
else
  cat <<EOF

   Add it yourself:

     sed -i '' '/^eh()/d;/^alias eh=/d' ~/.zshrc
     echo "$ALIAS_LINE" >> ~/.zshrc
     exec zsh
EOF
fi

echo
echo "Detach with your prefix (C-Space) then d. 'eh' again to come back."
