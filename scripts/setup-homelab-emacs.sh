#!/usr/bin/env bash
# Install Doom Emacs on the homelab with your exact config, running as a
# persistent daemon. The real equivalent of VS Code Remote-SSH: the editor
# runs where the code is, so LSP, git and search never cross the network.
#
# Terminal-only on that box by design — no org, no PDFs, no images. Code.
#
# Run this FROM YOUR MAC:
#   bash setup-homelab-emacs.sh [ssh-alias]
set -euo pipefail

HOST="${1:-homelab}"

echo "== Checking $HOST is reachable"
ssh -o ConnectTimeout=10 "$HOST" 'echo "  ok: $(hostname), $(lsb_release -ds 2>/dev/null || uname -sr)"'

echo
echo "== Silencing the login banner"
# Ubuntu's MOTD is the classic reason TRAMP hangs: it parses the remote
# shell's output to work out what it's talking to, and 20 lines of Canonical
# advertising confuse it. Harmless for the daemon, and it may well fix TRAMP.
ssh "$HOST" 'touch ~/.hushlogin'

echo
echo "== Installing Emacs and build dependencies"
# -t allocates a TTY so sudo can prompt for your password.
ssh -t "$HOST" 'sudo apt-get update -qq && sudo apt-get install -y \
  emacs-nox git ripgrep fd-find build-essential cmake clangd shellcheck'

echo
echo "== Fixing fd's name"
# Debian/Ubuntu ship the binary as fdfind (a name clash). Doom looks for fd.
ssh "$HOST" 'mkdir -p ~/.local/bin && ln -sf "$(command -v fdfind)" ~/.local/bin/fd 2>/dev/null || true'

echo
echo "== Cloning Doom"
ssh "$HOST" '[ -d ~/.config/emacs ] || git clone --depth 1 \
  https://github.com/doomemacs/doomemacs ~/.config/emacs'

echo
echo "== Copying your config across"
# rsync, not git, so this works before the dotfiles repo is pushed.
# Build artefacts are compiled for Apple Silicon and useless here.
rsync -az --delete \
  --exclude '.local/' --exclude 'eln-cache/' \
  --exclude '*.elc' --exclude '*.eln' --exclude 'custom.el' \
  --exclude '+local.el' \
  ~/.config/doom/ "$HOST":~/.config/doom/

echo
echo "== Machine-local overrides"
# The macOS section of config.el is guarded by system-type so it just doesn't
# run here. The compiler name is the one thing that genuinely differs.
ssh "$HOST" 'cat > ~/.config/doom/+local.el <<EOF
;;; +local.el -*- lexical-binding: t; -*-
;; Homelab-only. Excluded from the rsync, so the Mac never overwrites it.
(setq +cp-compiler "g++"
      +cp-debug-compiler "clang++")
EOF
grep -q "load! \"+local\"" ~/.config/doom/config.el || \
  echo "(load! \"+local\" nil t)" >> ~/.config/doom/config.el'

echo
echo "== doom install (several minutes)"
ssh -t "$HOST" 'export PATH="$HOME/.local/bin:$PATH"; ~/.config/emacs/bin/doom install --force'

echo
echo "== Daemon as a systemd user service"
ssh "$HOST" 'mkdir -p ~/.config/systemd/user && cat > ~/.config/systemd/user/emacs.service <<EOF
[Unit]
Description=Emacs daemon

[Service]
Type=simple
ExecStart=/usr/bin/emacs --fg-daemon
ExecStop=/usr/bin/emacsclient --eval "(kill-emacs)"
Restart=on-failure

[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now emacs.service'

echo
echo "== Keeping it alive after logout"
ssh -t "$HOST" "sudo loginctl enable-linger \$(whoami)"

sleep 3
ssh "$HOST" 'systemctl --user --no-pager status emacs.service | head -6'

echo
echo "== doom doctor"
ssh -t "$HOST" 'export PATH="$HOME/.local/bin:$PATH"; ~/.config/emacs/bin/doom doctor 2>&1 | tail -30'

cat <<EOF

== Done

Connect:

    ssh -t $HOST 'emacsclient -t -a ""'

Add to ~/.zshrc on the Mac:

    eh() { ssh -t $HOST 'emacsclient -t -a ""'; }

The session persists — disconnect, reconnect tomorrow, same buffers and
window layout. Re-run this script to push config changes; every step is
idempotent.
EOF
