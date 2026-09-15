#!/usr/bin/env bash
# Install Doom Emacs on a remote box with your exact config, running as a
# persistent daemon. The real equivalent of VS Code Remote-SSH: the editor
# runs where the code is, so LSP, git and search never cross the network.
#
# Terminal-only on that box by design — no org, no PDFs, no images. Code.
#
# Run this FROM YOUR MAC:
#   bash setup-homelab-emacs.sh            # asks which host
#   bash setup-homelab-emacs.sh <alias>    # or pass it in
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

# ─── which config ────────────────────────────────────────────────────
DOOMDIR="${DOOMDIR:-$HOME/.config/doom}"
if [[ ! -d "$DOOMDIR" ]]; then
  echo "No Doom config at $DOOMDIR"
  ask DOOMDIR "Path to your Doom config directory" "$HOME/.config/doom"
  [[ -d "$DOOMDIR" ]] || { echo "Still not a directory. Stopping."; exit 1; }
fi

echo
echo "== Checking $HOST is reachable"
ssh -o ConnectTimeout=10 "$HOST" 'echo "  ok: $(hostname), $(lsb_release -ds 2>/dev/null || uname -sr)"'

echo
echo "  config source: $DOOMDIR"
echo "  destination:   $HOST:~/.config/doom/  (rsync --delete)"
confirm "Proceed?" || { echo "Nothing done."; exit 0; }

echo
echo "== Silencing the login banner"
# Ubuntu's MOTD is the classic reason TRAMP hangs: it parses the remote
# shell's output to work out what it's talking to, and 20 lines of Canonical
# advertising confuse it. Harmless for the daemon, and it may well fix TRAMP.
ssh "$HOST" 'touch ~/.hushlogin'

echo
echo "== Installing Emacs and build dependencies"
if ssh "$HOST" 'command -v apt-get >/dev/null'; then
  # -t allocates a TTY so sudo can prompt for your password.
  ssh -t "$HOST" 'sudo apt-get update -qq && sudo apt-get install -y \
    emacs-nox git ripgrep fd-find build-essential cmake clangd shellcheck'
elif ssh "$HOST" 'command -v dnf >/dev/null'; then
  ssh -t "$HOST" 'sudo dnf install -y emacs-nox git ripgrep fd-find gcc-c++ make cmake clang-tools-extra ShellCheck'
elif ssh "$HOST" 'command -v pacman >/dev/null'; then
  ssh -t "$HOST" 'sudo pacman -S --needed --noconfirm emacs-nox git ripgrep fd base-devel cmake clang shellcheck'
else
  echo "   ! unknown package manager — install emacs-nox, git, ripgrep, fd,"
  echo "     a C++ toolchain, cmake, clangd and shellcheck yourself, then re-run."
  confirm "   Carry on anyway?" || exit 1
fi

REMOTE_EMACS_VER=$(ssh "$HOST" 'emacs --version 2>/dev/null | head -1' || true)
echo "   remote: ${REMOTE_EMACS_VER:-not found}"

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
  "${DOOMDIR%/}/" "$HOST":~/.config/doom/

echo
echo "== Machine-local overrides"
# The macOS section of config.el is guarded by system-type so it just doesn't
# run here. The compiler name is the one thing that genuinely differs.
ask CXX "C++ compiler on $HOST" "g++"
ask CXX_DEBUG "Debug/sanitiser compiler on $HOST" "clang++"

# Built locally so the compiler names interpolate, then piped over.
# +local.el is excluded from the rsync, so the Mac never overwrites it.
ssh "$HOST" 'cat > ~/.config/doom/+local.el' <<EOF
;;; +local.el -*- lexical-binding: t; -*-
;; Machine-local. Excluded from the rsync, so the Mac never overwrites it.
(setq +cp-compiler "$CXX"
      +cp-debug-compiler "$CXX_DEBUG")
EOF

ssh "$HOST" 'grep -q "load! \"+local\"" ~/.config/doom/config.el || \
  echo "(load! \"+local\" nil t)" >> ~/.config/doom/config.el'
echo "   +cp-compiler = $CXX, +cp-debug-compiler = $CXX_DEBUG"

echo
echo "== doom install (several minutes)"
ssh -t "$HOST" 'export PATH="$HOME/.local/bin:$PATH"; ~/.config/emacs/bin/doom install --force'

echo
echo "== Daemon as a systemd user service"
if ssh "$HOST" 'command -v systemctl >/dev/null'; then
  REMOTE_EMACS=$(ssh "$HOST" 'command -v emacs' || echo /usr/bin/emacs)
  REMOTE_EMACSCLIENT=$(ssh "$HOST" 'command -v emacsclient' || echo /usr/bin/emacsclient)

  ssh "$HOST" 'mkdir -p ~/.config/systemd/user && cat > ~/.config/systemd/user/emacs.service' <<EOF
[Unit]
Description=Emacs daemon

[Service]
Type=simple
ExecStart=$REMOTE_EMACS --fg-daemon
ExecStop=$REMOTE_EMACSCLIENT --eval "(kill-emacs)"
Restart=on-failure

[Install]
WantedBy=default.target
EOF

  ssh "$HOST" 'systemctl --user daemon-reload && systemctl --user enable --now emacs.service'

  echo
  echo "== Keeping it alive after logout"
  ssh -t "$HOST" 'sudo loginctl enable-linger $(whoami)' || \
    echo "   ! enable-linger failed — the daemon will stop when you log out"

  sleep 3
  ssh "$HOST" 'systemctl --user --no-pager status emacs.service | head -6' || true
else
  echo "   ! no systemd — start the daemon by hand with: emacs --daemon"
fi

echo
echo "== doom doctor"
ssh -t "$HOST" 'export PATH="$HOME/.local/bin:$PATH"; ~/.config/emacs/bin/doom doctor 2>&1 | tail -30' || true

# ─── local alias ─────────────────────────────────────────────────────
ALIAS_LINE="eh() { ssh -t $HOST 'emacsclient -t -a \"\"'; }"
echo
if grep -qF "ssh -t $HOST" ~/.zshrc 2>/dev/null; then
  echo "== an 'eh' for $HOST is already in ~/.zshrc"
elif confirm "== Add an 'eh' shell function to ~/.zshrc for you?"; then
  cp ~/.zshrc ~/.zshrc.bak.$(date +%s) 2>/dev/null || true
  sed -i.tmp '/^eh()/d;/^alias eh=/d' ~/.zshrc && rm -f ~/.zshrc.tmp
  printf '%s\n' "$ALIAS_LINE" >> ~/.zshrc
  echo "   added — run 'exec zsh' then 'eh'"
fi

cat <<EOF

== Done

Connect:

    ssh -t $HOST 'emacsclient -t -a ""'

The session persists — disconnect, reconnect tomorrow, same buffers and
window layout. Re-run this script to push config changes; every step is
idempotent.

Note: this and setup-homelab-terminal.sh both define 'eh', two different
ways — emacsclient against the daemon here, tmux + emacs -nw there. Keep
whichever you prefer; the last one written to ~/.zshrc wins.
EOF
