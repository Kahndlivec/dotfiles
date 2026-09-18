#!/usr/bin/env bash
# ok() always succeeds, so `a && ok || fail` is safe; "~" in messages is display text.
# shellcheck disable=SC2015,SC2088,SC1091
# ═══════════════════════════════════════════════════════════════════════════
#  install.sh — set up an Ubuntu (26.04, GNOME) machine from this repo.
#
#      gh repo clone Kahndlivec/dotfiles ~/Documents/dotfiles
#      ln -s ~/Documents/dotfiles ~/dotfiles
#      ~/dotfiles/install.sh audit      # first, on a machine with an older setup
#      ~/dotfiles/install.sh
#
#  Re-runnable: everything checks before it acts. Run it as yourself (not
#  root) from a terminal inside GNOME. It asks for sudo once.
#
#      ./install.sh              everything
#      ./install.sh links        only re-link configs
#      ./install.sh gnome        only GNOME keybindings/settings
#      ./install.sh drive        only (re)enable the Google Drive mount
#      ./install.sh check        report what's installed, change nothing
#      ./install.sh audit        find leftovers from older setups, change nothing
#      ./install.sh prune        remove what this setup replaces (shows it, asks first)
#
#  Shared by more than one person: everything personal (git name/email, SSH
#  hosts, aliases, Emacs identity) lives in people/<name>/. The first run asks
#  who uses the machine and links ~/.config/dotfiles/person to that folder.
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
#  2. Apps from their vendors: VS Code, Brave, Ghostty, Spotify, Telegram,
#     Tailscale
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

  # Telegram — the official snap tracks Telegram's releases; apt's lags.
  if ! snap list telegram-desktop >/dev/null 2>&1; then
    sudo snap install telegram-desktop || fail "Telegram"
  fi
  snap list telegram-desktop >/dev/null 2>&1 && ok "Telegram"

  # Tailscale — its apt repo, for this Ubuntu release's codename.
  if ! have tailscale; then
    local code key=/usr/share/keyrings/tailscale-archive-keyring.gpg tmp
    code="$(. /etc/os-release; echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
    tmp="$(mktemp)"
    if curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/$code.noarmor.gpg" -o "$tmp" \
       && curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/$code.tailscale-keyring.list" \
            | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null; then
      sudo install -m 644 "$tmp" "$key"
      sudo apt-get update -qq
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y tailscale || fail "Tailscale install"
    else
      fail "Tailscale repo for Ubuntu '$code' not found"
    fi
    rm -f "$tmp"
  fi
  if have tailscale; then
    sudo systemctl enable --now tailscaled >/dev/null 2>&1
    ok "Tailscale (then: sudo tailscale up)"
  fi
}

# Docker from Docker's own repo; on machines with an NVIDIA GPU, also the
# NVIDIA container toolkit so containers can use CUDA.
install_docker() {
  hdr "2b Docker"
  local code
  code="$(. /etc/os-release; echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
  if ! have docker; then
    if ! grep -rsE "^[^#]*download\.docker\.com" /etc/apt/sources.list /etc/apt/sources.list.d >/dev/null; then
      if ! curl -fsI "https://download.docker.com/linux/ubuntu/dists/$code/Release" >/dev/null; then
        warn "Docker has no repo for Ubuntu '$code' yet — using noble's"; code=noble
      fi
      sudo install -m 0755 -d /etc/apt/keyrings
      sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
      sudo chmod a+r /etc/apt/keyrings/docker.asc
      sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $code
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
      sudo apt-get update -qq
    fi
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io \
      docker-buildx-plugin docker-compose-plugin || fail "Docker install"
  fi
  have docker && ok "Docker"
  if have docker && ! id -nG "$USER" | tr ' ' '\n' | grep -x docker >/dev/null; then
    sudo usermod -aG docker "$USER" && ok "added you to the docker group (takes effect at next login)"
  fi

  if have nvidia-smi && have docker; then
    if ! have nvidia-ctk; then
      curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
        | sudo gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
      curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
        | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
        | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
      sudo apt-get update -qq
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nvidia-container-toolkit || fail "NVIDIA container toolkit"
    fi
    if have nvidia-ctk && ! grep -s nvidia /etc/docker/daemon.json >/dev/null; then
      sudo nvidia-ctk runtime configure --runtime=docker >/dev/null && sudo systemctl restart docker
    fi
    have nvidia-ctk && ok "NVIDIA GPUs available to containers"
  fi
}

# Hide clutter launchers from the app grid (packages/hidden-launchers.txt).
hide_launchers() {
  local apps="$HOME/.local/share/applications" id src dir n=0
  mkdir -p "$apps"
  while read -r id; do
    src=""
    for dir in /usr/share/applications /usr/local/share/applications /var/lib/snapd/desktop/applications; do
      [[ -f "$dir/$id" ]] && { src="$dir/$id"; break; }
    done
    [[ -n "$src" ]] || continue
    [[ -f "$apps/$id" ]] && grep -x 'NoDisplay=true' "$apps/$id" >/dev/null && continue
    sed -e '/^NoDisplay=/d' -e 's/^\[Desktop Entry\]$/[Desktop Entry]\nNoDisplay=true/' "$src" > "$apps/$id" \
      && n=$((n + 1))
  done < <(list "$D/packages/hidden-launchers.txt")
  update-desktop-database "$apps" >/dev/null 2>&1 || true
  ok "app grid: hid $n more clutter launcher(s) — software stays installed"
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

  # Neovim — the config needs 0.11+, so always use our own release build in
  # ~/.local/bin. An apt `neovim` elsewhere on PATH doesn't count: prune
  # removes it, and the Neovim app points at ~/.local/bin/nvim.
  local nv="" mynvim="$HOME/.local/bin/nvim"
  [[ -x "$mynvim" ]] && nv="$("$mynvim" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
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
  [[ -x "$mynvim" ]] && ok "Neovim $("$mynvim" --version | head -1 | awk '{print $2}') in ~/.local/bin" || fail "Neovim not in ~/.local/bin"

  # "Neovim" app: the Neovim logo in the app grid and on Super+V. Opens nvim
  # straight away in its own Ghostty window — no tmux, no shell. The --class
  # gives that window its own identity, so GNOME shows it as Neovim (not as
  # another Ghostty) and Super+V / Super+T each raise the right window.
  local apps="$HOME/.local/share/applications" icons="$HOME/.local/share/icons/hicolor/128x128/apps"
  local nvim_dir="$HOME/.local/opt/nvim-linux-x86_64"
  [[ "$ARCH" == arm64 ]] && nvim_dir="$HOME/.local/opt/nvim-linux-arm64"
  mkdir -p "$apps" "$icons"
  [[ -f "$nvim_dir/share/icons/hicolor/128x128/apps/nvim.png" ]] \
    && cp "$nvim_dir/share/icons/hicolor/128x128/apps/nvim.png" "$icons/nvim.png"
  cat > "$apps/io.neovim.nvim.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Neovim
GenericName=Text Editor
Comment=Edit text files
Exec=ghostty --class=io.neovim.nvim -e $HOME/.local/bin/nvim %F
Icon=nvim
Terminal=false
Categories=Utility;TextEditor;Development;
MimeType=text/plain;text/x-c++src;text/x-csrc;text/x-chdr;text/x-c++hdr;text/x-python;text/markdown;application/x-shellscript;
StartupWMClass=io.neovim.nvim
StartupNotify=true
DESKTOP

  # Remove the Neovide install from the previous version of this script.
  if [[ -e "$HOME/.local/opt/neovide" || -e "$apps/neovide.desktop" ]]; then
    rm -rf "$HOME/.local/opt/neovide" "$HOME/.local/bin/neovide" "$apps/neovide.desktop" \
      "$HOME/.local/share/icons/hicolor/scalable/apps/neovide.svg"
    ok "removed Neovide"
  fi
  update-desktop-database "$apps" >/dev/null 2>&1 || true
  gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
  ok "Neovim app (app grid + Super+V)"

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

# ─── who uses this machine ─────────────────────────────────────────────────
PERSON_LINK="$HOME/.config/dotfiles/person"
choose_person() {
  if [[ -L "$PERSON_LINK" && -d "$PERSON_LINK" ]]; then
    PERSON="$(basename "$(readlink -f "$PERSON_LINK")")"
    sk "person: $PERSON"
    return 0
  fi
  if [[ ! -t 0 ]]; then
    fail "can't ask who uses this machine without a terminal — run ./install.sh links in one"
    return 1
  fi
  local known
  known="$(find "$D/people" -mindepth 1 -maxdepth 1 -type d -printf '%f ' 2>/dev/null)"
  echo
  echo "  Who uses this machine? Existing: ${known:-none}"
  read -rp "  Name (lowercase, e.g. matej): " PERSON
  PERSON="$(tr '[:upper:]' '[:lower:]' <<<"$PERSON" | tr -cd 'a-z0-9-')"
  [[ -n "$PERSON" ]] || { fail "no name given"; return 1; }
  local dir="$D/people/$PERSON"
  if [[ ! -d "$dir" ]]; then
    local full gname gmail
    echo "  New person — three questions, saved in people/$PERSON/:"
    read -rp "  Full name (Emacs/org author): " full
    read -rp "  Git name (shown on commits, e.g. your GitHub username): " gname
    read -rp "  Git email (the one on your GitHub account): " gmail
    mkdir -p "$dir"
    printf '# Git identity for %s.\n[user]\n\tname = %s\n\temail = %s\n' "$PERSON" "$gname" "$gmail" > "$dir/gitconfig"
    printf ';;; doom.el — identity for Emacs.  -*- lexical-binding: t; -*-\n(setq user-full-name "%s"\n      user-mail-address "%s")\n' "$full" "$gmail" > "$dir/doom.el"
    printf '# %s: aliases and functions for your machines — sourced at the end of zsh/.zshrc.\n' "$PERSON" > "$dir/zshrc"
    printf '# %s: your SSH hosts — copied to ~/.ssh/config.d/person.conf.\n' "$PERSON" > "$dir/ssh_config"
    ok "created people/$PERSON — commit it later: dotsync \"add $PERSON\""
  fi
  mkdir -p "$(dirname "$PERSON_LINK")"
  ln -sfn "$dir" "$PERSON_LINK" && ok "person: $PERSON"
}

install_links() {
  hdr "4  Configs (symlinks)"
  choose_person
  link zsh/.zshrc                 "$HOME/.zshrc"
  link zsh/.zprofile              "$HOME/.zprofile"
  link git/.gitconfig             "$HOME/.gitconfig"
  # Ghostty loads config.ghostty and then the legacy extensionless `config`,
  # which would override ours — so clear a stale link or old file under that name.
  local g="$HOME/.config/ghostty"
  if [[ -L "$g/config" && ! -e "$g/config" ]]; then rm -f "$g/config"; fi
  if [[ -e "$g/config" && "$(readlink -f "$g/config")" != "$D/ghostty/config.ghostty" ]]; then
    mkdir -p "$BACKUP" && mv "$g/config" "$BACKUP/ghostty-config" && warn "moved old ghostty/config → $BACKUP/"
  elif [[ -L "$g/config" ]]; then
    rm -f "$g/config"
  fi
  link ghostty/config.ghostty     "$g/config.ghostty"
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

  # SSH: copied, because ssh refuses config files other users could write —
  # and git checks files out group-writable on Ubuntu. known_hosts is never
  # touched: it's this machine's own record of servers.
  mkdir -p "$HOME/.ssh/cm" "$HOME/.ssh/config.d" && chmod 700 "$HOME/.ssh" "$HOME/.ssh/cm" "$HOME/.ssh/config.d"
  if ! cmp -s "$D/ssh/config" "$HOME/.ssh/config"; then
    [[ -f "$HOME/.ssh/config" ]] && { mkdir -p "$BACKUP"; cp "$HOME/.ssh/config" "$BACKUP/ssh_config"; \
      warn "old ~/.ssh/config saved to $BACKUP/ssh_config — move any hosts you need into people/${PERSON:-you}/ssh_config"; }
    cp "$D/ssh/config" "$HOME/.ssh/config" && chmod 600 "$HOME/.ssh/config" && ok "ssh/config (copied)"
  fi
  if [[ -n "${PERSON:-}" && -f "$D/people/$PERSON/ssh_config" ]] \
     && ! cmp -s "$D/people/$PERSON/ssh_config" "$HOME/.ssh/config.d/person.conf"; then
    cp "$D/people/$PERSON/ssh_config" "$HOME/.ssh/config.d/person.conf" \
      && chmod 600 "$HOME/.ssh/config.d/person.conf" && ok "people/$PERSON/ssh_config → ~/.ssh/config.d/person.conf"
  fi
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
#  6. Google Drive
# ═══════════════════════════════════════════════════════════════════════════
install_drive() {
  hdr "6  Google Drive (rclone mount at ~/GoogleDrive)"
  if ! have rclone; then fail "rclone missing"; return; fi
  local unit="$HOME/.config/systemd/user/rclone-gdrive.service"
  mkdir -p "$(dirname "$unit")"
  if ! cmp -s "$D/systemd/rclone-gdrive.service" "$unit"; then
    cp "$D/systemd/rclone-gdrive.service" "$unit" && systemctl --user daemon-reload && ok "service file installed"
  fi
  if rclone listremotes 2>/dev/null | grep -x "gdrive:" >/dev/null; then
    systemctl --user enable --now rclone-gdrive.service >/dev/null 2>&1 \
      && ok "mounted at ~/GoogleDrive (starts at every login)" \
      || fail "Drive mount — journalctl --user -u rclone-gdrive -e"
  else
    warn "no rclone remote named gdrive yet — run: rclone config  (then: ./install.sh drive)"
    return
  fi

  # Drive has exactly one job here: carrying GoodNotes exports in. The notes
  # themselves live in git. Drive/notes (GoodNotes' own backup) is left alone.
  rclone mkdir gdrive:Org-inbox >/dev/null 2>&1
  mkdir -p "$HOME/Documents/notes/assets"
  rm -f "$HOME/.config/systemd/user/notes-sync.service" "$HOME/.config/systemd/user/notes-sync.timer"
  systemctl --user disable --now notes-sync.timer >/dev/null 2>&1
  systemctl --user daemon-reload
  ok "iPad exports go to Drive/Org-inbox → SPC n i"
}

# ═══════════════════════════════════════════════════════════════════════════
#  notes — put ~/Documents/notes under git, with a private GitHub repo
# ═══════════════════════════════════════════════════════════════════════════
install_notes() {
  hdr "Notes repo"
  local N="$HOME/Documents/notes"
  mkdir -p "$N/assets"
  if [[ ! -d "$N/.git" ]]; then
    git -C "$N" init -q -b main
    printf '%s\n' '# Emacs scratch files' '.#*' '*~' '\#*\#' '.org-id-locations' > "$N/.gitignore"
    git -C "$N" add -A && git -C "$N" commit -qm "notes" && ok "git repo created in ~/Documents/notes"
  else
    sk "already a git repo"
  fi
  if git -C "$N" remote | grep -x origin >/dev/null; then
    sk "GitHub remote already set: $(git -C "$N" remote get-url origin)"
  elif have gh && gh auth status >/dev/null 2>&1; then
    if [[ -t 0 ]]; then
      local ans
      read -rp "  Create a PRIVATE GitHub repo for your notes and push? [y/N] " ans
      if [[ "$ans" == [Yy]* ]]; then
        gh repo create notes --private --source "$N" --remote origin --push \
          && ok "notes pushed to GitHub (private)" || fail "gh repo create"
      fi
    else
      warn "run ./install.sh notes in a terminal to create the GitHub repo"
    fi
  else
    warn "gh not logged in — run gh auth login, then ./install.sh notes"
  fi
  ok "save a checkpoint any time with: notes-push  (or SPC n p)"
}

# ═══════════════════════════════════════════════════════════════════════════
#  7. GNOME
# ═══════════════════════════════════════════════════════════════════════════
install_gnome() {
  hdr "7  GNOME keybindings and settings"
  hide_launchers
  bash "$D/gnome/settings.sh"
}

# ═══════════════════════════════════════════════════════════════════════════
#  check
# ═══════════════════════════════════════════════════════════════════════════
check() {
  hdr "Check"
  export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.config/emacs/bin:$PATH"
  local c nv

  echo "  ── programs"
  for c in zsh tmux git gh rg fd g++ gdb clangd cmake emacs nvim code brave-browser \
           ghostty starship node npm pyright claude ruff direnv wl-copy tailscale doom \
           rclone lualatex latexmk dvisvgm sioyek timeshift solaar batcat eza delta zoxide docker; do
    have "$c" && ok "$c" || fail "$c missing"
  done
  snap list spotify >/dev/null 2>&1 && ok "spotify" || fail "spotify missing"
  snap list telegram-desktop >/dev/null 2>&1 && ok "telegram" || fail "telegram missing"
  fc-list | grep "JetBrainsMono Nerd Font" >/dev/null && ok "JetBrainsMono Nerd Font" || fail "Nerd Font missing"
  if [[ -x "$HOME/.local/bin/nvim" ]]; then
    nv="$("$HOME/.local/bin/nvim" --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
    version_ge "$nv" 0.11.0 && ok "nvim $nv in ~/.local/bin (need ≥ 0.11)" || fail "nvim $nv too old"
  else
    fail "Neovim missing from ~/.local/bin (fix: ./install.sh)"
  fi
  [[ "$(command -v nvim)" == "$HOME/.local/bin/nvim" ]] || warn "\`nvim\` resolves to $(command -v nvim || echo nothing), not ~/.local/bin/nvim"
  local nexec; nexec="$(grep -m1 '^Exec=' "$HOME/.local/share/applications/io.neovim.nvim.desktop" 2>/dev/null | sed -E 's/.* -e ([^ ]+).*/\1/')"
  if [[ -n "$nexec" && -x "$nexec" && -f "$HOME/.local/share/icons/hicolor/128x128/apps/nvim.png" ]]; then
    ok "Neovim app (launches, has icon)"
  else
    fail "Neovim app broken: launcher target ${nexec:-none}, icon $([[ -f "$HOME/.local/share/icons/hicolor/128x128/apps/nvim.png" ]] && echo ok || echo missing) (fix: ./install.sh)"
  fi
  id -nG "$USER" | tr ' ' '\n' | grep -x docker >/dev/null && ok "in docker group" || warn "not in docker group yet (log out and in)"
  local leftover="" pk
  while read -r pk; do dpkg -s "$pk" >/dev/null 2>&1 && leftover+=" $pk"; done < <(list "$D/packages/remove-apt.txt")
  have flatpak && [[ -n "$(flatpak list --app --columns=application 2>/dev/null)" ]] && leftover+=" (flatpak apps)"
  [[ -z "$leftover" ]] && ok "nothing from remove-apt.txt installed" || warn "replaced software still installed:$leftover (./install.sh prune)"

  echo "  ── configs linked into the repo"
  local pair src dst
  for pair in "zsh/.zshrc:$HOME/.zshrc" "zsh/.zprofile:$HOME/.zprofile" "git/.gitconfig:$HOME/.gitconfig" \
              "ghostty/config.ghostty:$HOME/.config/ghostty/config.ghostty" \
              "tmux/.tmux.conf:$HOME/.tmux.conf" "starship/starship.toml:$HOME/.config/starship.toml" \
              "nvim:$HOME/.config/nvim" "doom:$HOME/.config/doom" \
              "vscode/settings.json:$HOME/.config/Code/User/settings.json" \
              "vscode/keybindings.json:$HOME/.config/Code/User/keybindings.json" \
              "env/10-path.conf:$HOME/.config/environment.d/10-path.conf"; do
    src="$D/${pair%%:*}"; dst="${pair#*:}"
    if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then ok "${pair%%:*}"
    else fail "${pair%%:*} not linked (fix: ./install.sh links)"; fi
  done

  echo "  ── person"
  if [[ -L "$PERSON_LINK" && -d "$PERSON_LINK" ]]; then
    ok "person: $(basename "$(readlink -f "$PERSON_LINK")")"
    local gu; gu="$(git config --global --includes user.name)"
    [[ -n "$gu" ]] && ok "git identity: $gu <$(git config --global --includes user.email)>" || fail "git has no user.name"
  else
    fail "no person chosen (fix: ./install.sh links)"
  fi

  echo "  ── Ghostty"
  if have ghostty; then
    ok "$(ghostty --version 2>/dev/null | head -1)"
    local gv; gv="$(ghostty +validate-config 2>&1)"
    [[ -z "$gv" ]] && ok "config valid" || fail "config errors: $(echo "$gv" | head -3 | tr '\n' ' ')"
    [[ -e "$HOME/.config/ghostty/config" ]] && fail "legacy ~/.config/ghostty/config exists and overrides ours"
  fi

  echo "  ── shell and session"
  [[ "$(getent passwd "$USER" | cut -d: -f7)" == *zsh ]] && ok "login shell zsh" || fail "login shell is not zsh"
  systemctl --user show-environment 2>/dev/null | grep '^PATH=' | grep "$HOME/.local/bin" >/dev/null \
    && ok "GNOME session PATH has ~/.local/bin" || fail "GNOME session PATH lacks ~/.local/bin (log out and in)"
  [[ "${XDG_SESSION_TYPE:-}" == wayland ]] && ok "Wayland session" || warn "session type: ${XDG_SESSION_TYPE:-unknown}"

  echo "  ── GNOME keys (live, compared with gnome/shortcuts.conf)"
  if have gsettings && [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]]; then
    bash "$D/gnome/settings.sh" verify \
      || fail "app keys don't match gnome/shortcuts.conf (fix: ./install.sh gnome)"
    [[ "$(gsettings get org.gnome.desktop.wm.keybindings switch-to-workspace-1)" == "['<Super>1']" ]] \
      && ok "Super+1..4 workspaces" || fail "workspace keys not set"
    [[ "$(gsettings get org.gnome.mutter dynamic-workspaces)" == false ]] && ok "4 fixed workspaces" || fail "workspaces still dynamic"
  else
    warn "not in GNOME — run check from a terminal inside GNOME to see keys"
  fi

  echo "  ── services and accounts"
  systemctl is-active tailscaled >/dev/null 2>&1 && ok "tailscaled running" || fail "tailscaled not running"
  if have tailscale; then
    tailscale status >/dev/null 2>&1 && ok "Tailscale logged in" || warn "Tailscale not logged in yet (sudo tailscale up)"
  fi
  rclone listremotes 2>/dev/null | grep -x "gdrive:" >/dev/null && ok "rclone remote gdrive" || warn "no rclone remote gdrive yet"
  systemctl --user is-active rclone-gdrive >/dev/null 2>&1 && ok "Google Drive mounted" || warn "Google Drive not mounted yet"
  [[ -d "$HOME/GoogleDrive/Org-inbox" ]] && ok "iPad inbox: ~/GoogleDrive/Org-inbox" || warn "no ~/GoogleDrive/Org-inbox yet"
  if [[ -d "$HOME/Documents/notes/.git" ]]; then
    git -C "$HOME/Documents/notes" remote | grep -x origin >/dev/null \
      && ok "notes in git, pushed to $(git -C "$HOME/Documents/notes" remote get-url origin)" \
      || warn "notes in git but no GitHub remote (./install.sh notes)"
  else
    warn "~/Documents/notes is not in git — nothing backs it up (./install.sh notes)"
  fi
  [[ -f "$HOME/.ssh/id_ed25519.pub" ]] && ok "SSH key" || fail "no SSH key"
  gh auth status >/dev/null 2>&1 && ok "gh logged in" || warn "gh not logged in yet"
  [[ -d "$HOME/.config/emacs" ]] && ok "Doom installed" || fail "Doom not installed"
  [[ -z "$(git -C "$D" status --porcelain)" ]] && ok "dotfiles repo clean" || warn "uncommitted changes: git -C $D status"
}

# ═══════════════════════════════════════════════════════════════════════════
#  prune — remove what this setup replaces. Shows everything, asks first.
# ═══════════════════════════════════════════════════════════════════════════
prune() {
  hdr "Prune — software this setup replaces"
  local pkgs=() apps=() p a sim ans missing=()
  while read -r p; do dpkg -s "$p" >/dev/null 2>&1 && pkgs+=("$p"); done < <(list "$D/packages/remove-apt.txt")
  have flatpak && mapfile -t apps < <(flatpak list --app --columns=application 2>/dev/null | sed '/^$/d')

  if ((${#pkgs[@]} == 0 && ${#apps[@]} == 0)); then
    ok "nothing to remove"; return 0
  fi
  echo "  apt packages:   ${pkgs[*]:-none}"
  echo "  flatpak apps:   ${apps[*]:-none}"

  if ((${#pkgs[@]})); then
    sim="$(apt-get -s purge "${pkgs[@]}" 2>/dev/null | awk '/^(Purg|Remv) /{print $2}')"
    echo "  apt would remove: $(tr '\n' ' ' <<<"$sim")"
    if grep -xE 'ubuntu-desktop(-minimal)?|ubuntu-minimal|ubuntu-standard|gnome-shell|gdm3|snapd|nautilus' <<<"$sim" >/dev/null; then
      fail "that would take part of the desktop with it — stopping, nothing removed"; return 1
    fi
  fi

  if ((${#apps[@]})); then
    local kdbx; kdbx="$(find "$HOME/.var/app" -name '*.kdbx' 2>/dev/null)"
    if [[ -n "$kdbx" ]]; then
      fail "a KeePassXC database is inside flatpak data — move it somewhere in ~/Documents first: $kdbx"; return 1
    fi
  fi
  if printf '%s\n' "${pkgs[@]}" | grep -x neovim >/dev/null && [[ ! -x "$HOME/.local/bin/nvim" ]]; then
    missing+=("Neovim in ~/.local/bin")
  fi
  if ((${#apps[@]})); then
    for a in "${apps[@]}"; do
      case "$a" in
        com.github.ahrm.sioyek)  have sioyek    || missing+=(sioyek) ;;
        org.keepassxc.KeePassXC) have keepassxc || missing+=(keepassxc) ;;
        com.spotify.Client)      snap list spotify >/dev/null 2>&1 || missing+=(spotify) ;;
        org.telegram.desktop)    snap list telegram-desktop >/dev/null 2>&1 || missing+=(telegram) ;;
      esac
    done
  fi
  if ((${#missing[@]})); then
    fail "replacements not installed yet: ${missing[*]} — run ./install.sh first"; return 1
  fi

  [[ -t 0 ]] || { fail "prune needs a terminal to confirm"; return 1; }
  read -rp "  Remove all of the above? Type yes: " ans
  [[ "$ans" == yes ]] || { warn "nothing removed"; return 0; }
  start_sudo

  if ((${#apps[@]})); then
    if [[ -d "$HOME/.var/app" ]]; then
      local bk; bk="$HOME/flatpak-data-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
      tar -czf "$bk" -C "$HOME/.var" app && ok "flatpak app data backed up → ${bk/#$HOME/\~}"
      local sdb; sdb="$(find "$HOME/.var/app/com.github.ahrm.sioyek" -name shared.db -printf '%h\n' 2>/dev/null | head -1)"
      if [[ -n "$sdb" && ! -e "$HOME/.local/share/sioyek" ]]; then
        mkdir -p "$HOME/.local/share" && cp -a "$sdb" "$HOME/.local/share/sioyek" && ok "Sioyek bookmarks and highlights carried over"
      fi
    fi
    flatpak uninstall -y --delete-data "${apps[@]}" >/dev/null && ok "removed flatpak apps: ${apps[*]}" || fail "flatpak uninstall"
    flatpak uninstall -y --unused >/dev/null 2>&1 || true
  fi

  if ((${#pkgs[@]})); then
    sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y "${pkgs[@]}" >/dev/null && ok "removed: ${pkgs[*]}" || fail "apt purge"
    sudo apt-get autoremove -y >/dev/null && ok "cleaned up unused dependencies"
    sudo rm -f /etc/apt/sources.list.d/google-chrome.list /etc/apt/sources.list.d/google-chrome.sources
  fi
  if ! have flatpak; then
    sudo rm -rf /var/lib/flatpak
    rmdir "$HOME/.var/app" "$HOME/.var" 2>/dev/null || true
  fi
  install_gnome
}

# ═══════════════════════════════════════════════════════════════════════════
#  audit — leftovers from older setups. Reports only; changes nothing.
# ═══════════════════════════════════════════════════════════════════════════
FOUND=0
found() { printf '  \033[33m•\033[0m %s\n' "$1"; FOUND=$((FOUND + 1)); }

audit() {
  hdr "Audit — leftovers from other setups (nothing is changed)"
  local realD l t f x
  realD="$(readlink -f "$D")"

  echo "  ── other dotfiles folders"
  while IFS= read -r x; do
    [[ "$(readlink -f "$x")" == "$realD" ]] && continue
    found "folder: ${x/#$HOME/\~}"
  done < <(find "$HOME" -maxdepth 4 \( -path "$HOME/.cache" -o -path "$HOME/.local/share/Trash" -o -path "$HOME/snap" \) -prune \
             -o -type d -iname '*dotfiles*' -print 2>/dev/null)

  echo "  ── symlinks that point nowhere or into another dotfiles copy"
  while IFS= read -r l; do
    [[ "$l" == "$HOME/dotfiles" ]] && continue
    t="$(readlink "$l")"
    if [[ ! -e "$l" ]]; then
      found "broken link: ${l/#$HOME/\~} → $t"
    elif [[ "$t" == *dotfiles* && "$(readlink -f "$l")" != "$realD"* ]]; then
      found "link into another dotfiles: ${l/#$HOME/\~} → $t"
    fi
  done < <(find "$HOME" -maxdepth 1 -type l 2>/dev/null
           find "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share/applications" -maxdepth 2 -type l 2>/dev/null)

  echo "  ── files that override or shadow this setup"
  for f in .emacs .emacs.el .emacs.d; do
    [[ -e "$HOME/$f" ]] && found "~/$f — Emacs loads this INSTEAD of Doom"
  done
  [[ -e "$HOME/.config/git/config" ]] && found "~/.config/git/config — git reads it on top of ~/.gitconfig"
  for f in .zshenv .zlogin .zlogout .bash_profile; do
    [[ -e "$HOME/$f" && ! -L "$HOME/$f" ]] && found "~/$f — also read at login; check what it adds"
  done
  [[ -e "$HOME/.config/tmux/tmux.conf" ]] && found "~/.config/tmux/tmux.conf — old tmux config (ours is ~/.tmux.conf)"
  [[ -e "$HOME/.config/ghostty/config" && ! -L "$HOME/.config/ghostty/config" ]] && found "~/.config/ghostty/config — legacy Ghostty config, overrides ours"
  for x in .oh-my-zsh .zinit .local/share/zinit .zim .zplug .antidote .p10k.zsh .tmux/plugins .local/share/nvim/site/pack/packer; do
    [[ -e "$HOME/$x" ]] && found "~/$x — plugin/framework from an older shell or editor setup"
  done
  for f in .profile .bashrc; do
    [[ -f "$HOME/$f" ]] && grep -nE 'linuxbrew|dotfiles|nvm|pyenv|asdf|mise|oh-my' "$HOME/$f" 2>/dev/null \
      | while IFS= read -r x; do found "~/$f:$x"; done
  done

  echo "  ── second copies of tools"
  [[ -d /home/linuxbrew/.linuxbrew || -d "$HOME/.linuxbrew" ]] && found "Homebrew on Linux — its tools can shadow the apt ones"
  for x in .nvm .volta .local/share/fnm .pyenv .asdf .local/share/mise; do
    [[ -d "$HOME/$x" ]] && found "~/$x — version manager; its node/python can shadow apt's"
  done
  dpkg -s neovim >/dev/null 2>&1 && found "apt neovim — old version next to ours in ~/.local/bin (sudo apt remove neovim)"
  local emacs_bin; emacs_bin="$(readlink -f /usr/bin/emacs 2>/dev/null)"
  [[ -n "$emacs_bin" && "$emacs_bin" != *pgtk* ]] && found "/usr/bin/emacs is $emacs_bin, not the Wayland build (emacs-pgtk)"
  snap list emacs >/dev/null 2>&1 && found "Emacs snap installed as well"
  local pair name deb snp flat n
  for pair in "VS Code:code:code:com.visualstudio.code" "Brave:brave-browser:brave:com.brave.Browser" \
              "Ghostty:ghostty:ghostty:com.mitchellh.ghostty" "Spotify:spotify-client:spotify:com.spotify.Client" \
              "Telegram:telegram-desktop:telegram-desktop:org.telegram.desktop"; do
    IFS=: read -r name deb snp flat <<<"$pair"
    n=0; x=""
    dpkg -s "$deb" >/dev/null 2>&1 && { n=$((n + 1)); x+=" apt"; }
    snap list "$snp" >/dev/null 2>&1 && { n=$((n + 1)); x+=" snap"; }
    have flatpak && flatpak info "$flat" >/dev/null 2>&1 && { n=$((n + 1)); x+=" flatpak"; }
    ((n > 1)) && found "$name installed $n times:$x — keep one"
  done

  echo "  ── apt"
  apt-cache policy 2>&1 >/dev/null | grep -E '^(E|W):' | sort -u | while IFS= read -r x; do found "apt: $x"; done
  for x in packages.microsoft.com/repos/code brave-browser-apt-release pkgs.tailscale.com; do
    n="$(grep -rlsE "^[^#]*$x" /etc/apt/sources.list /etc/apt/sources.list.d | wc -l)"
    ((n > 1)) && found "repo added $n times: $x — $(grep -rlsE "^[^#]*$x" /etc/apt/sources.list /etc/apt/sources.list.d | tr '\n' ' ')"
  done

  echo "  ── things that start by themselves"
  for f in "$HOME"/.config/autostart/*.desktop; do
    [[ -f "$f" ]] && found "autostart: $(basename "$f") → $(grep -m1 '^Exec=' "$f" | cut -d= -f2-)"
  done
  for f in "$HOME"/.config/systemd/user/*.service "$HOME"/.config/systemd/user/*.timer; do
    [[ -f "$f" && "$(basename "$f")" != rclone-gdrive.service ]] && found "systemd user unit: $(basename "$f")"
  done
  crontab -l 2>/dev/null | grep -vE '^\s*(#|$)' | while IFS= read -r x; do found "crontab: $x"; done

  if have gsettings && [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]]; then
    echo "  ── GNOME"
    local paths p
    paths="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null | tr -d "[]'@as" | tr ',' ' ')"
    for p in $paths; do
      found "custom shortcut: $(gsettings get "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$p" binding) → $(gsettings get "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$p" command)"
    done
    have gnome-extensions && gnome-extensions list --enabled 2>/dev/null \
      | grep -vE '^(ubuntu-dock@ubuntu.com|ding@rastersoft.com|ubuntu-appindicators@ubuntu.com|tiling-assistant@leleat-on-github|snapd-prompting@canonical.com)$' \
      | while IFS= read -r x; do found "GNOME extension enabled: $x"; done
  fi

  echo "  ── state an older config left behind (safe to rebuild)"
  if [[ -d "$HOME/.config/emacs" ]]; then
    [[ -x "$HOME/.config/emacs/bin/doom" ]] \
      && found "~/.config/emacs — existing Doom install, packages built for whatever config it had" \
      || found "~/.config/emacs — an Emacs config that isn't Doom"
  fi
  if [[ -d "$HOME/.local/share/nvim" && "$(readlink -f "$HOME/.config/nvim")" != "$realD/nvim" ]]; then
    found "~/.local/share/nvim — plugins from a different Neovim config"
  fi
  if [[ -f "$HOME/.ssh/config" ]] && ! cmp -s "$D/ssh/config" "$HOME/.ssh/config"; then
    found "~/.ssh/config differs — it will be replaced (backed up). Hosts in it: $(grep -iE '^\s*Host\s' "$HOME/.ssh/config" | awk '{$1=""; print}' | tr '\n' ' ')"
  fi
  if [[ -f "$HOME/.gitconfig" && ! -L "$HOME/.gitconfig" ]]; then
    found "~/.gitconfig is a plain file ($(git config --file "$HOME/.gitconfig" user.name) <$(git config --file "$HOME/.gitconfig" user.email)>) — it will be replaced (backed up)"
  fi

  echo
  if ((FOUND)); then
    printf '  \033[1m%d thing(s) to look at.\033[0m Nothing was changed. Paste this output to decide what to clean.\n' "$FOUND"
  else
    ok "nothing left over — safe to run ./install.sh"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
case "$MODE" in
  all)
    start_sudo
    install_apt
    install_apps
    install_docker
    install_user_tools
    install_links
    install_shell_and_editors
    install_drive
    install_gnome
    check
    ;;
  links) install_links ;;
  gnome) install_gnome ;;
  drive) install_drive ;;
  notes) install_notes ;;
  check) check ;;
  audit) audit ;;
  prune) prune ;;
  *) echo "usage: $0 [all|links|gnome|drive|notes|check|audit|prune]"; exit 1 ;;
esac

hdr "Done"
if ((${#FAILED[@]})); then
  printf '  \033[31m%d problem(s):\033[0m\n' "${#FAILED[@]}"
  printf '    - %s\n' "${FAILED[@]}"
fi
[[ -d "$BACKUP" ]] && echo "  Replaced files were backed up to: $BACKUP"
[[ "$MODE" == audit ]] && exit 0
[[ "$MODE" == prune ]] && exit 0
if [[ "$MODE" == all ]]; then
  cat <<'EOF'

  Once, by hand:
    1. Log out and back in   (zsh, PATH for GNOME apps, keybindings)
    2. gh auth status || gh auth login, then: gh ssh-key add ~/.ssh/id_ed25519.pub
    3. sudo tailscale up
    4. rclone config         (new remote "gdrive", type drive), then ./install.sh drive
    5. In Emacs:             M-x pdf-tools-install
    6. Brave Sync, and log in to Spotify and Telegram
EOF
fi
