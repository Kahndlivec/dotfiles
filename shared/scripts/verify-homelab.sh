#!/usr/bin/env bash
# Check the remote half of the setup: connection, terminfo, tmux, the
# launcher, the Emacs daemon, and the tools Doom expects to find there.
# Read-only — changes nothing.
#
#   bash verify-homelab.sh [ssh-alias]

HOST="${1:-homelab}"
PASS=0; FAIL=0; WARN=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; WARN=$((WARN+1)); }

echo "Connection"
if ssh -o ConnectTimeout=10 -o BatchMode=yes "$HOST" true 2>/dev/null; then
  ok "ssh $HOST (key auth, no password)"
else
  bad "ssh $HOST — everything below will fail"
  echo; echo "  Try: ssh -v $HOST"; exit 1
fi

REMOTE_NAME=$(ssh "$HOST" 'hostname' 2>/dev/null)
ok "reached $REMOTE_NAME as $(ssh "$HOST" 'whoami' 2>/dev/null)"

# A second connection should reuse the ControlMaster socket and be instant.
START=$(date +%s%N)
ssh "$HOST" true 2>/dev/null
ELAPSED=$(( ($(date +%s%N) - START) / 1000000 ))
if (( ELAPSED < 300 )); then
  ok "connection reuse working (${ELAPSED}ms)"
else
  warn "second connection took ${ELAPSED}ms — ControlMaster may not be active"
fi

# An interactive login needs a pty. RequestTTY no breaks this.
if ssh -t "$HOST" 'test -t 0 && echo yes' 2>/dev/null | grep -q yes; then
  ok "interactive tty (ssh $HOST gives a usable shell)"
else
  bad "no tty — check for 'RequestTTY no' in ~/.ssh/config"
fi

echo
echo "Terminal"
LOCAL_TERM="${TERM:-unknown}"
if ssh "$HOST" "infocmp $LOCAL_TERM >/dev/null 2>&1"; then
  ok "terminfo for $LOCAL_TERM present"
else
  bad "no terminfo for $LOCAL_TERM — TUI apps will refuse to start"
fi
ssh "$HOST" 'infocmp tmux-256color >/dev/null 2>&1' \
  && ok "tmux-256color present" || warn "tmux-256color missing (apt install ncurses-term)"

echo
echo "Remote tooling"
for b in tmux git emacs emacsclient rg fd clangd g++ make; do
  ssh "$HOST" "command -v $b >/dev/null 2>&1" \
    && ok "$b" || bad "$b missing"
done
for b in clang-format direnv black shfmt shellcheck; do
  ssh "$HOST" "command -v $b >/dev/null 2>&1" \
    && ok "$b" || warn "$b missing (doom doctor will complain)"
done

echo
echo "Config on $REMOTE_NAME"
ssh "$HOST" 'test -f ~/.tmux.conf' && ok "~/.tmux.conf" || bad "~/.tmux.conf missing"
ssh "$HOST" 'grep -q emacs ~/.tmux.conf 2>/dev/null' \
  && ok "tmux is_vim matches emacs (C-hjkl works inside it)" \
  || warn "tmux config has no emacs in is_vim — C-hjkl will move panes, not windows"
ssh "$HOST" 'test -x ~/.local/bin/e' && ok "~/.local/bin/e launcher" || bad "~/.local/bin/e missing"
ssh "$HOST" 'test -d ~/.config/emacs' && ok "Doom cloned" || bad "Doom not installed"
ssh "$HOST" 'test -f ~/.config/doom/config.el' && ok "config.el synced" || bad "config.el missing"
ssh "$HOST" 'test -f ~/.config/doom/+local.el' \
  && ok "+local.el ($(ssh "$HOST" 'grep -o "\"[^\"]*\"" ~/.config/doom/+local.el | head -1' 2>/dev/null))" \
  || warn "+local.el missing — remote will use the Mac compiler names"
ssh "$HOST" 'test -f ~/.hushlogin' && ok "login banner silenced (TRAMP)" || warn "no ~/.hushlogin — MOTD can confuse TRAMP"

echo
echo "Emacs daemon"
if ssh "$HOST" 'systemctl --user is-active emacs.service' 2>/dev/null | grep -q '^active'; then
  ok "emacs.service running"
else
  warn "emacs.service not active (fine if you use the tmux launcher instead)"
fi
if ssh "$HOST" 'loginctl show-user $(whoami) 2>/dev/null | grep -q Linger=yes'; then
  ok "linger enabled — daemon survives logout"
else
  warn "linger off — the daemon dies when you disconnect"
fi

# Does the launcher actually reach the daemon, or start a second Emacs?
if ssh "$HOST" 'grep -q emacsclient ~/.local/bin/e 2>/dev/null'; then
  ok "launcher uses the daemon"
elif ssh "$HOST" 'test -x ~/.local/bin/e'; then
  warn "launcher starts its own emacs -nw, ignoring the daemon"
fi

echo
echo "Local side"
grep -qE '^(eh\(\)|alias eh=)' ~/.zshrc 2>/dev/null && ok "eh defined in ~/.zshrc" || bad "no eh in ~/.zshrc"

# The wake alias is the classic leftover from someone else's dotfiles.
WAKE_MAC=$(grep -oE '([0-9a-f]{2}:){5}[0-9a-f]{2}' ~/.zshrc 2>/dev/null | head -1)
if [[ -n "$WAKE_MAC" ]]; then
  IFACE=$(ssh "$HOST" 'ip route show default 2>/dev/null | awk "{print \$5; exit}"')
  REAL_MAC=$(ssh "$HOST" "cat /sys/class/net/$IFACE/address 2>/dev/null")
  if [[ "$WAKE_MAC" == "$REAL_MAC" ]]; then
    ok "wake-on-LAN MAC matches $REMOTE_NAME"
  else
    bad "wake alias has $WAKE_MAC, $REMOTE_NAME is $REAL_MAC"
  fi
fi

# TRAMP uses the same ssh config, so if this fails remote editing fails.
if command -v emacs >/dev/null 2>&1; then
  if emacs --batch --eval "(let ((vc-handled-backends nil)) (with-current-buffer (find-file-noselect \"/ssh:$HOST:~/\") (kill-buffer)))" 2>/dev/null; then
    ok "TRAMP can open /ssh:$HOST:~/"
  else
    warn "TRAMP couldn't connect (try M-x tramp-cleanup-all-connections)"
  fi
fi

echo
printf '%d passed, %d failed, %d warnings\n' "$PASS" "$FAIL" "$WARN"
(( FAIL == 0 )) && echo "Try it:  eh" || echo "Fix the ✗ lines first."
