#!/bin/bash
# bootstrap.sh — set up a fresh Mac from this repo.
#
#     git clone <this repo> ~/dotfiles && cd ~/dotfiles && bash bootstrap.sh
#
# Backs up anything it overwrites to ~/dotfiles-backup-<stamp>/.
set -u

D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HOME/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
ok(){ printf '  \033[32m✓\033[0m %s\n' "$1"; }
sk(){ printf '  \033[33m–\033[0m %s\n' "$1"; }
hdr(){ printf '\n\033[1;44m %s \033[0m\n' "$1"; }
mkdir -p "$B"

put(){ # put <repo-relative> <destination>
  [ -e "$D/$1" ] || { sk "$1 not in repo"; return; }
  mkdir -p "$(dirname "$2")"
  [ -e "$2" ] && cp -R "$2" "$B/" 2>/dev/null
  if [ -d "$D/$1" ]; then
    # Same cp -R trap as in the collector: copy CONTENTS, not the directory,
    # or a re-run nests it one level deeper each time.
    mkdir -p "$2"
    cp -R "$D/$1/." "$2/" && ok "$1/ → $2/"
  else
    cp "$D/$1" "$2" && ok "$1 → $2"
  fi
}

hdr "1  Homebrew"
if ! command -v brew >/dev/null; then
  echo "  Installing Homebrew…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
if [ -f "$D/Brewfile" ]; then
  echo "  brew bundle install — this is the long one, go make coffee."
  brew bundle install --file="$D/Brewfile" || sk "some formulae failed; see above"
else
  sk "no Brewfile"
fi

hdr "2  Shell"
put zsh/.zshrc    "$HOME/.zshrc"
put zsh/.zprofile "$HOME/.zprofile"
put zsh/.zshenv   "$HOME/.zshenv"
put zsh/.p10k.zsh "$HOME/.p10k.zsh"

hdr "3  Git"
put git/.gitconfig        "$HOME/.gitconfig"
put git/.gitignore_global "$HOME/.gitignore_global"

hdr "4  Ghostty + tmux"
put ghostty/config "$HOME/.config/ghostty/config"
put tmux/tmux.conf  "$HOME/.config/tmux/tmux.conf"
put tmux/.tmux.conf "$HOME/.tmux.conf"
if [ -f "$HOME/.config/tmux/tmux.conf" ] || [ -f "$HOME/.tmux.conf" ]; then
  if grep -qs "tpm" "$HOME/.config/tmux/tmux.conf" "$HOME/.tmux.conf" 2>/dev/null; then
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
      git clone -q https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" \
        && ok "cloned TPM — start tmux and press prefix + I to install plugins"
    else ok "TPM already present"; fi
  fi
fi

hdr "4b  SSH"
# Public material only. Private keys were never committed — see below.
if [ -d "$D/ssh" ]; then
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  for f in config known_hosts allowed_signers; do
    [ -f "$D/ssh/$f" ] && { cp "$D/ssh/$f" "$HOME/.ssh/$f"; chmod 600 "$HOME/.ssh/$f"; ok ".ssh/$f"; }
  done
  cp "$D"/ssh/*.pub "$HOME/.ssh/" 2>/dev/null && chmod 644 "$HOME"/.ssh/*.pub 2>/dev/null && ok ".ssh/*.pub"
  echo
  echo "  No private key was restored — none is in this repo, by design."
  echo "  Generate a fresh one and register it, it takes half a minute:"
  echo "      ssh-keygen -t ed25519 -C \"\$(whoami)@\$(hostname)\""
  echo "      gh auth login          # or: gh ssh-key add ~/.ssh/id_ed25519.pub"
else
  sk "no ssh/ in repo"
fi

hdr "5  VSCode"
VC="$HOME/Library/Application Support/Code/User"
put vscode/settings.json    "$VC/settings.json"
put vscode/keybindings.json "$VC/keybindings.json"
put vscode/snippets         "$VC/snippets"
if command -v code >/dev/null && [ -f "$D/vscode/extensions.txt" ]; then
  echo "  installing $(wc -l <"$D/vscode/extensions.txt" | tr -d ' ') extensions…"
  xargs -n1 code --install-extension < "$D/vscode/extensions.txt" >/dev/null 2>&1
  ok "extensions"
else
  sk "extensions — install the 'code' shell command first"
fi

hdr "5b  Editors and CLI tools"
put nvim              "$HOME/.config/nvim"
put clang-format/.clang-format "$HOME/.clang-format"
put gh/config.yml     "$HOME/.config/gh/config.yml"
put ripgrep/.ripgreprc "$HOME/.ripgreprc"
put editorconfig/.editorconfig "$HOME/.editorconfig"
put starship/starship.toml "$HOME/.config/starship.toml"
put bat/config        "$HOME/.config/bat/config"
put lazygit/config.yml "$HOME/Library/Application Support/lazygit/config.yml"
put misc/.hushlogin   "$HOME/.hushlogin"

hdr "5c  Karabiner"
# Karabiner-Elements rewrites karabiner.json from memory when it is running,
# so restoring underneath a live process silently loses the file.
if [ -f "$D/karabiner/karabiner.json" ]; then
  if pgrep -qx "karabiner_console_user_server" 2>/dev/null || pgrep -qf "Karabiner-Elements" 2>/dev/null; then
    sk "Karabiner is RUNNING — quit it fully (menu bar → Quit), then re-run this script"
    echo "      Copying now would be overwritten from memory within seconds."
  else
    put karabiner/karabiner.json "$HOME/.config/karabiner/karabiner.json"
    echo "      Open Karabiner-Elements and confirm the profile loaded."
  fi
else
  sk "no karabiner.json in repo"
fi

hdr "6  Sublime CP setup"
if [ -f "$D/sublime/install.sh" ]; then
  echo "  Sublime must have been launched once already (creates Packages/User)."
  ( cd "$D/sublime" && bash install.sh )
else
  sk "no sublime/install.sh"
fi

hdr "7  macOS defaults"
[ -f "$D/macos/defaults.sh" ] && bash "$D/macos/defaults.sh" || sk "no defaults.sh"

hdr "DONE"
echo "  Overwritten files were backed up to: $B"
echo "  Restart your terminal, then log out and back in for key repeat."
