#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  linux/packages/manual.sh
#
#  Everything that isn't apt or Flathub: third-party apt repos, the
#  install-script tools, npm globals, the Nerd Font.
#
#  Idempotent. Safe to re-run.
# ═══════════════════════════════════════════════════════════════════
set -euo pipefail

ok(){ printf '  \033[32m✓\033[0m %s\n' "$1"; }
sk(){ printf '  \033[33m–\033[0m %s\n' "$1"; }
hdr(){ printf '\n\033[1;44m %s \033[0m\n' "$1"; }

KEYRINGS=/usr/share/keyrings
SRC=/etc/apt/sources.list.d
ARCH="$(dpkg --print-architecture)"

# add_repo <name> <key-url> <repo-line>
add_repo() {
  local name=$1 key=$2 line=$3
  if [[ -f "$SRC/$name.list" ]]; then sk "$name repo"; return; fi
  curl -fsSL "$key" | sudo gpg --dearmor -o "$KEYRINGS/$name.gpg"
  echo "$line" | sudo tee "$SRC/$name.list" >/dev/null
  ok "$name repo"
}

# ─── third-party apt repos ─────────────────────────────────────────
hdr "apt repos"

add_repo vscode \
  https://packages.microsoft.com/keys/microsoft.asc \
  "deb [arch=$ARCH signed-by=$KEYRINGS/vscode.gpg] https://packages.microsoft.com/repos/code stable main"

add_repo google-chrome \
  https://dl.google.com/linux/linux_signing_key.pub \
  "deb [arch=amd64 signed-by=$KEYRINGS/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main"

add_repo brave-browser \
  https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
  "deb [arch=$ARCH signed-by=$KEYRINGS/brave-browser.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"

sudo apt-get update -qq
sudo apt-get install -y code google-chrome-stable brave-browser
ok "vscode, chrome, brave"

# ─── Claude Desktop ────────────────────────────────────────────────
# Official Linux beta, Ubuntu 22.04+, from Anthropic's own apt repo.
# The key/repo line changes; take it from the docs rather than pinning
# a stale URL here:  https://code.claude.com/docs/en/desktop-linux
hdr "claude desktop"
if command -v claude-desktop >/dev/null; then
  sk "claude-desktop already installed"
else
  echo "  Follow https://code.claude.com/docs/en/desktop-linux (adds an apt repo),"
  echo "  then: sudo apt install claude-desktop"
fi

# ─── Tailscale & Docker ────────────────────────────────────────────
hdr "tailscale + docker"
command -v tailscale >/dev/null || curl -fsSL https://tailscale.com/install.sh | sh
ok "tailscale"

if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"
  ok "docker (log out and back in for the group to apply)"
else
  sk "docker"
fi

# ─── install-script tools ──────────────────────────────────────────
hdr "toolchain managers"
command -v starship >/dev/null || curl -sS https://starship.rs/install.sh | sh -s -- -y
ok "starship"

command -v mise >/dev/null || curl -fsSL https://mise.run | sh
ok "mise"

command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh
ok "uv"

# Node via mise, so it's version-pinned per project rather than system-wide.
MISE="$HOME/.local/bin/mise"
"$MISE" use -g node@lts >/dev/null 2>&1 || true
ok "node (mise, lts)"

# ─── python + npm globals ──────────────────────────────────────────
hdr "globals"
# Absolute paths: these were installed seconds ago in this same script,
# so they are not on PATH in this shell yet.
UV="$HOME/.local/bin/uv"
pipx install diceware 2>/dev/null || sk "diceware"
"$UV" tool install ruff  || sk "ruff"
"$UV" tool install black || sk "black"

# Same problem: mise put node behind its shim dir, not on PATH yet.
"$MISE" exec node@lts -- npm i -g --allow-scripts=@anthropic-ai/claude-code,tree-sitter-cli \
  @anthropic-ai/claude-code bash-language-server pyright tree-sitter-cli
ok "npm globals"

# ─── JetBrainsMono Nerd Font ───────────────────────────────────────
hdr "fonts"
FONTDIR="$HOME/.local/share/fonts"
if fc-list | grep -qi "JetBrainsMono Nerd Font"; then
  sk "JetBrainsMono Nerd Font"
else
  mkdir -p "$FONTDIR"
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/jbm.zip" \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
  unzip -qo "$tmp/jbm.zip" -d "$FONTDIR/JetBrainsMono"
  rm -rf "$tmp"
  fc-cache -f "$FONTDIR" >/dev/null
  ok "JetBrainsMono Nerd Font"
fi

# Rambla is Google Fonts only — grab it if you still want it in Emacs.
if ! fc-list | grep -qi Rambla; then
  sk "Rambla (manual: fonts.google.com/specimen/Rambla)"
fi

# ─── flatpak ───────────────────────────────────────────────────────
hdr "flatpak"
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
grep -vE '^\s*(#|$)' "$(dirname "$0")/flatpak.txt" | xargs -r flatpak install -y --noninteractive flathub
ok "flathub apps"

printf '\n\033[1;42m done \033[0m\n'
