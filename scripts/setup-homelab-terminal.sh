#!/usr/bin/env bash
# Fix the two things stopping the remote Emacs from working:
#   1. Ghostty's terminfo doesn't exist on Ubuntu, so anything TUI refuses
#      to start with "missing or unsuitable terminal: xterm-ghostty".
#   2. Your tmux config isn't there, and needs two Linux adaptations.
#
# RUN THIS FROM A GHOSTTY WINDOW ON YOUR MAC (it copies your live terminfo):
#   bash setup-homelab-terminal.sh [ssh-alias]
set -euo pipefail
HOST="${1:-homelab}"

echo "== Terminfo"
echo "   local TERM=$TERM"
ssh "$HOST" 'sudo apt-get install -y -qq ncurses-term' </dev/null || true
# Ghostty's own documented fix: ship your terminfo entry to the remote host.
infocmp -x xterm-ghostty | ssh "$HOST" -- tic -x - && echo "   xterm-ghostty installed on $HOST"
ssh "$HOST" 'infocmp tmux-256color >/dev/null 2>&1 && echo "   tmux-256color ok"'

echo
echo "== tmux config"
ssh "$HOST" 'cat > ~/.tmux.conf' <<'TMUX'
# ~/.tmux.conf — homelab. Mirrors the Mac config, with two changes:
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

# OSC 52: tmux hands the copied text to Ghostty over the SSH connection,
# and Ghostty puts it on the macOS clipboard. This is the remote equivalent
# of pbcopy, and it needs no X server.
set -g set-clipboard on
setw -g mode-keys vi
bind Enter copy-mode
bind -T copy-mode-vi v send -X begin-selection
bind -T copy-mode-vi C-v send -X rectangle-toggle
bind -T copy-mode-vi y send -X copy-selection-and-cancel
bind -T copy-mode-vi MouseDragEnd1Pane send -X copy-selection-no-clear

set -g default-terminal "tmux-256color"
set -as terminal-features ",xterm-ghostty:RGB"
set -as terminal-features ",xterm-ghostty:usstyle"
set -as terminal-overrides ',*:Smulx=\E[4::%p1%dm'
set -as terminal-overrides ',*:Setulc=\E[58::2::%p1%{65536}%/%d::%p1%{256}%/%{255}%&%d::%p1%{255}%&%d%;m'

bind r source-file ~/.tmux.conf \; display "tmux.conf reloaded"
TMUX
echo "   written"

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
echo "== Testing"
ssh -t "$HOST" 'tmux kill-server 2>/dev/null; echo "   tmux server reset"' || true

cat <<EOF

Now on the Mac:

    sed -i '' '/^eh()/d;/^alias eh=/d' ~/.zshrc
    echo "alias eh='ssh -t $HOST ~/.local/bin/e'" >> ~/.zshrc
    exec zsh
    eh

Detach with your usual prefix then d. \`eh\` again to come back.
EOF
