#!/usr/bin/env bash
# ok() always succeeds, so `a && ok || fail` is safe; "~" in messages is display text.
# shellcheck disable=SC2015,SC2088
# ═══════════════════════════════════════════════════════════════════════════
#  install.sh — set up an Ubuntu (26.04, GNOME) machine from this repo.
#
#      gh repo clone Kahndlivec/dotfiles ~/dotfiles
#      ~/dotfiles/install.sh
#
#  Re-runnable: everything checks before it acts. Run it as yourself (not
#  root) from a terminal inside GNOME. It asks for sudo once.
#
#      ./install.sh              everything
#      ./install.sh links        only re-link configs
#      ./install.sh gnome        only GNOME keybindings/settings
#      ./install.sh check        report what's installed, change nothing
#
#  Configs are SYMLINKED, so ~/.zshrc, ~/.config/doom, ~/.config/nvim … are
#  the repo. Edit them in place, then `dotsync "message"` to commit + push.
#  Anything a link would replace is moved to ~/dotfiles-backup-<timestamp>/.
# ═══════════════════════════════════════════════════════════════════════════
set -uo pipefail

D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
MODE="${1:-all}"
ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
FAILED=()

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
sk()   { printf '  \033[2m–\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAILED+=("$1"); }
hdr()  { printf '\n\033[1;44m %s \033[0m\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

# Read a package list: strip comments and blank lines.
list() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$1"; }

# ─── guards ────────────────────────────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
  echo "Run as your normal user, not root/sudo. It will ask for sudo itself."; exit 1
fi
if ! grep -qi ubuntu /etc/os-release 2>/dev/null; then
  warn "This targets Ubuntu. Continuing, but package names may differ."
fi

start_sudo() {
  sudo -v || { echo "sudo is required."; exit 1; }
  # Keep the sudo timestamp fresh until this script exits.
  ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &
}

# ═══════════════════════════════════════════════════════════════════════════
#  1. apt
# ═══════════════════════════════════════════════════════════════════════════
install_apt() {
  hdr "1  apt packages"
  sudo apt-get update -qq
  local want=() missing=() p
  while read -r p; do
    if apt-cache show "$p" >/dev/null 2>&1; then want+=("$p"); else missing+=("$p"); fi
  done < <(list "$D/packages/apt.txt")
  ((${#missing[@]})) && warn "not in this release's archive, skipped: ${missing[*]}"
  if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${want[@]}"; then
    ok "${#want[@]} packages"
  else
    fail "apt install (scroll up for the package that broke it)"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
#  2. Apps from their vendors: VS Code, Brave, Ghostty, Spotify, Tailscale
# ═══════════════════════════════════════════════════════════════════════════
add_keyring() { # add_keyring <url> <dest.gpg> [dearmor]
  [[ -f "$2" ]] && return 0
  if [[ "${3:-}" == dearmor ]]; then
    curl -fsSL "$1" | gpg --dearmor | sudo tee "$2" >/dev/null
  else
    sudo curl -fsSLo "$2" "$1"
  fi
  sudo chmod 644 "$2"
}

install_apps() {
  hdr "2  Apps"
  local changed=0

  # VS Code — Microsoft's apt repo, so it updates with the system.
  if ! have code; then
    add_keyring https://packages.microsoft.com/keys/microsoft.asc /usr/share/keyrings/microsoft.gpg dearmor
    sudo tee /etc/apt/sources.list.d/vscode.sources >/dev/null <<EOF
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF
    # Tell the code package not to add a duplicate repo entry of its own.
    echo "code code/add-microsoft-repo boolean false" | sudo debconf-set-selections
    changed=1
  fi

  # Brave — official apt repo.
  if ! have brave-browser; then
    add_keyring https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
      /usr/share/keyrings/brave-browser-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
      | sudo tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null
    changed=1
  fi

  if ((changed)); then
    sudo apt-get update -qq
    have code          || { sudo DEBIAN_FRONTEND=noninteractive apt-get install -y code || fail "VS Code"; }
    have brave-browser || { sudo DEBIAN_FRONTEND=noninteractive apt-get install -y brave-browser || fail "Brave"; }
  fi
  have code && ok "VS Code"
  have brave-browser && ok "Brave"

  # Ghostty — no official Ubuntu package. Prefer a real .deb (clean GNOME
  # integration), fall back to the snap.
  if ! have ghostty; then
    if apt-cache show ghostty >/dev/null 2>&1; then
      sudo apt-get install -y ghostty
    else
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)" \
        || sudo snap install ghostty --classic
    fi
  fi
  have ghostty && ok "Ghostty" || fail "Ghostty"

  # Spotify — the snap is the one Spotify keeps working; their apt key breaks.
  if ! snap list spotify >/dev/null 2>&1; then
    sudo snap install spotify || fail "Spotify"
  fi
  snap list spotify >/dev/null 2>&1 && ok "Spotify"

  # Tailscale.
  if ! have tailscale; then
    curl -fsSL https://tailscale.com/install.sh | sh || fail "Tailscale"
  fi
  have tailscale && ok "Tailscale (run: sudo tailscale up)"
}

# ═══════════════════════════════════════════════════════════════════════════
#  3. User-level tools: Neovim, starship, fonts, npm, pipx
# ═══════════════════════════════════════════════════════════════════════════
version_ge() { [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" == "$2" ]]; }

install_user_tools() {
  hdr "3  User tools"
  mkdir -p "$HOME/.local/bin" "$HOME/.local/opt"
  export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

  # fd: Ubuntu ships it as fdfind.
  if have fdfind && ! have fd; then ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"; fi
  have fd && ok "fd"

  # Neovim — the config needs 0.11+, so take the official release build.
  local nv=""
  have nvim && nv="$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
  if [[ -z "$nv" ]] || ! version_ge "$nv" 0.11.0; then
    local asset=nvim-linux-x86_64
    [[ "$ARCH" == arm64 ]] && asset=nvim-linux-arm64
    rm -rf "$HOME/.local/opt/$asset"
    if curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/$asset.tar.gz" \
         | tar -xz -C "$HOME/.local/opt"; then
      ln -sf "$HOME/.local/opt/$asset/bin/nvim" "$HOME/.local/bin/nvim"
    else
      fail "Neovim download"
    fi
  fi
  have nvim && ok "Neovim $(nvim --version | head -1 | awk '{print $2}')"

  # starship
  if ! have starship; then
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin" >/dev/null || fail "starship"
  fi
  have starship && ok "starship"

  # Fonts: JetBrainsMono Nerd Font (editors, terminal) + Nerd symbols (Doom icons).
  local fdir="$HOME/.local/share/fonts" f
  mkdir -p "$fdir"
  for f in JetBrainsMono NerdFontsSymbolsOnly; do
    if [[ ! -d "$fdir/$f" ]]; then
      mkdir -p "$fdir/$f"
      curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$f.tar.xz" \
        | tar -xJ -C "$fdir/$f" || fail "font $f"
    fi
  done
  fc-cache -f >/dev/null 2>&1
  fc-list | grep "JetBrainsMono Nerd Font" >/dev/null && ok "JetBrainsMono Nerd Font + symbols"

  # npm globals, without sudo.
  if have npm; then
    npm config set prefix "$HOME/.npm-global"
    local pkgs
    mapfile -t pkgs < <(list "$D/packages/npm.txt")
    npm install -g "${pkgs[@]}" >/dev/null 2>&1 && ok "npm: ${pkgs[*]}" || fail "npm globals"
  else
    fail "npm missing"
  fi

  # pipx tools.
  if have pipx; then
    local p
    while read -r p; do
      pipx list --short 2>/dev/null | grep "^$p " >/dev/null || pipx install "$p" >/dev/null 2>&1 || fail "pipx $p"
    done < <(list "$D/packages/pipx.txt")
    ok "pipx: $(list "$D/packages/pipx.txt" | tr '\n' ' ')"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
#  4. Configs
# ═══════════════════════════════════════════════════════════════════════════
link() { # link <repo-relative> <destination>
  local src="$D/$1" dst="$2"
  [[ -e "$src" ]] || { warn "$1 not in repo"; return; }
  if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
    sk "$1"; return
  fi
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" || -L "$dst" ]]; then
    mkdir -p "$BACKUP"
    mv "$dst" "$BACKUP/" && warn "backed up existing $(basename "$dst") → $BACKUP/"
  fi
  ln -s "$src" "$dst" && ok "$1 → ${dst/#$HOME/\~}"
}

install_links() {
  hdr "4  Configs (symlinks)"
  link zsh/.zshrc                 "$HOME/.zshrc"
  link git/.gitconfig             "$HOME/.gitconfig"
  link ghostty/config             "$HOME/.config/ghostty/config"
  link tmux/.tmux.conf            "$HOME/.tmux.conf"
  link starship/starship.toml     "$HOME/.config/starship.toml"
  link nvim                       "$HOME/.config/nvim"
  link doom                       "$HOME/.config/doom"
  link vscode/settings.json       "$HOME/.config/Code/User/settings.json"
  link vscode/keybindings.json    "$HOME/.config/Code/User/keybindings.json"
  link clang-format/.clang-format "$HOME/.clang-format"
  link env/10-path.conf           "$HOME/.config/environment.d/10-path.conf"

  # gh rewrites its config on `gh config set`, which would replace a symlink —
  # so it's copied once instead.
  if [[ ! -f "$HOME/.config/gh/config.yml" ]]; then
    mkdir -p "$HOME/.config/gh" && cp "$D/gh/config.yml" "$HOME/.config/gh/config.yml" && ok "gh/config.yml (copied)"
  fi

  # SSH: copied, because ssh is strict about permissions and ownership.
  mkdir -p "$HOME/.ssh/cm" && chmod 700 "$HOME/.ssh"
  local f
  for f in config known_hosts; do
    if [[ -f "$D/ssh/$f" ]] && ! cmp -s "$D/ssh/$f" "$HOME/.ssh/$f"; then
      [[ -f "$HOME/.ssh/$f" ]] && { mkdir -p "$BACKUP"; cp "$HOME/.ssh/$f" "$BACKUP/ssh_$f"; }
      cp "$D/ssh/$f" "$HOME/.ssh/$f" && chmod 600 "$HOME/.ssh/$f" && ok "ssh/$f (copied)"
    fi
  done
}

# ═══════════════════════════════════════════════════════════════════════════
#  5. Shell, SSH key, editors
# ═══════════════════════════════════════════════════════════════════════════
install_shell_and_editors() {
  hdr "5  Shell, SSH key, editors"
  export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.config/emacs/bin:$PATH"

  # zsh as login shell.
  if have zsh && [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v zsh)" ]]; then
    sudo chsh -s "$(command -v zsh)" "$USER" && ok "login shell → zsh (log out and back in)"
  else
    sk "zsh already the login shell"
  fi

  # One SSH key per machine. Never copied between machines, never in git.
  if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
    echo "  Generating this machine's SSH key (a passphrase is recommended):"
    ssh-keygen -t ed25519 -C "$USER@$(hostname)" -f "$HOME/.ssh/id_ed25519" && ok "SSH key created"
  else
    sk "SSH key exists"
  fi

  # Doom Emacs.
  if [[ ! -d "$HOME/.config/emacs" ]]; then
    git clone -q --depth 1 https://github.com/doomemacs/doomemacs "$HOME/.config/emacs" && ok "cloned Doom"
    echo "  doom install — several minutes"
    "$HOME/.config/emacs/bin/doom" install --force && ok "doom install" || fail "doom install"
  else
    echo "  doom sync"
    "$HOME/.config/emacs/bin/doom" sync && ok "doom sync" || fail "doom sync"
  fi

  # Neovim plugins, headless.
  if have nvim; then
    nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 && ok "Neovim plugins (lazy-lock.json)" \
      || warn "nvim plugin restore had errors — open nvim once and run :Lazy"
  fi

  # VS Code extensions.
  if have code; then
    local ext installed
    installed="$(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    while read -r ext; do
      grep -qx "${ext,,}" <<<"$installed" || code --install-extension "$ext" >/dev/null 2>&1 || warn "extension $ext"
    done < <(list "$D/packages/vscode-extensions.txt")
    ok "VS Code extensions"
  fi

  git lfs install --skip-repo >/dev/null 2>&1 && ok "git lfs"
}

# ═══════════════════════════════════════════════════════════════════════════
#  6. GNOME
# ═══════════════════════════════════════════════════════════════════════════
install_gnome() {
  hdr "6  GNOME keybindings and settings"
  bash "$D/gnome/settings.sh"
}

# ═══════════════════════════════════════════════════════════════════════════
#  check
# ═══════════════════════════════════════════════════════════════════════════
check() {
  hdr "Check"
  export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.config/emacs/bin:$PATH"
  local c
  for c in zsh tmux git gh rg fd g++ gdb clangd cmake emacs nvim code brave-browser \
           ghostty starship node npm pyright claude ruff direnv wl-copy tailscale doom; do
    have "$c" && ok "$c" || fail "$c missing"
  done
  snap list spotify >/dev/null 2>&1 && ok "spotify" || fail "spotify missing"
  fc-list | grep "JetBrainsMono Nerd Font" >/dev/null && ok "JetBrainsMono Nerd Font" || fail "Nerd Font missing"
  [[ -L "$HOME/.config/doom" ]] && ok "~/.config/doom linked" || fail "~/.config/doom not linked"
  [[ -f "$HOME/.ssh/id_ed25519.pub" ]] && ok "SSH key" || fail "no SSH key"
}

# ═══════════════════════════════════════════════════════════════════════════
case "$MODE" in
  all)
    start_sudo
    install_apt
    install_apps
    install_user_tools
    install_links
    install_shell_and_editors
    install_gnome
    check
    ;;
  links) install_links ;;
  gnome) install_gnome ;;
  check) check ;;
  *) echo "usage: $0 [all|links|gnome|check]"; exit 1 ;;
esac

hdr "Done"
if ((${#FAILED[@]})); then
  printf '  \033[31m%d problem(s):\033[0m\n' "${#FAILED[@]}"
  printf '    - %s\n' "${FAILED[@]}"
fi
[[ -d "$BACKUP" ]] && echo "  Replaced files were backed up to: $BACKUP"
if [[ "$MODE" == all ]]; then
  cat <<'EOF'

  Once, by hand:
    1. Log out and back in   (zsh, PATH for GNOME apps, keybindings)
    2. gh auth status || gh auth login, then: gh ssh-key add ~/.ssh/id_ed25519.pub
    3. sudo tailscale up
    4. In Emacs:             M-x pdf-tools-install
    5. In Brave:             Settings → Sync, to pull bookmarks and extensions
EOF
fi
