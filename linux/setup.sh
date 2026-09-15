#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  linux/setup.sh
#
#      bash linux/setup.sh                  # auto-detect role
#      ROLE=thinkpad bash linux/setup.sh    # force
#      ROLE=desktop  bash linux/setup.sh
#
#  Idempotent. Overwritten files are backed up to ~/dotfiles-backup-*.
# ═══════════════════════════════════════════════════════════════════
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
B="$HOME/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

ok(){ printf '  \033[32m✓\033[0m %s\n' "$1"; }
sk(){ printf '  \033[33m–\033[0m %s\n' "$1"; }
hdr(){ printf '\n\033[1;44m %s \033[0m\n' "$1"; }

# put <repo-relative> <destination>
put() {
  local src="$REPO/$1" dst="${2/#\~/$HOME}"
  [[ -e "$src" ]] || { sk "missing $1"; return; }
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" ]] && ! diff -q "$src" "$dst" >/dev/null 2>&1; then
    mkdir -p "$B/$(dirname "${dst#$HOME/}")"
    cp -a "$dst" "$B/${dst#$HOME/}"
  fi
  # cp -a src dst NESTS when dst is an existing directory, so a second run
  # would create ~/.config/doom/doom. Copy the contents instead.
  if [[ -d "$src" ]]; then
    mkdir -p "$dst"; cp -a "$src/." "$dst/"
  else
    cp -a "$src" "$dst"
  fi
  ok "${dst/#$HOME/~}"
}

# ─── role ──────────────────────────────────────────────────────────
if [[ -z "${ROLE:-}" ]]; then
  if [[ -d /sys/class/power_supply/BAT0 ]]; then ROLE=thinkpad; else ROLE=desktop; fi
fi
hdr "role: $ROLE"

# ─── apt ───────────────────────────────────────────────────────────
hdr "apt"
mapfile -t PKGS < <(
  sed 's/#.*//' "$REPO/linux/packages/apt.txt" | grep -vE '^\s*$' | awk '{print $1}'
)
# thinkpad-only lines are tagged '# thinkpad' in apt.txt
if [[ $ROLE != thinkpad ]]; then
  mapfile -t TP < <(grep '# thinkpad' "$REPO/linux/packages/apt.txt" | awk '{print $1}')
  for t in "${TP[@]:-}"; do PKGS=("${PKGS[@]/$t}"); done
fi
sudo apt-get update -qq
sudo apt-get install -y "${PKGS[@]}"
ok "$(( ${#PKGS[@]} )) packages"

# ─── everything not in apt ─────────────────────────────────────────
bash "$REPO/linux/packages/manual.sh"

# ─── shared configs (identical on both OSes) ───────────────────────
hdr "shared configs"
put shared/doom            ~/.config/doom
put shared/nvim            ~/.config/nvim
put shared/tmux/.tmux.conf ~/.tmux.conf
put shared/git/.gitconfig  ~/.gitconfig
put shared/gh/config.yml   ~/.config/gh/config.yml
put shared/clang-format/.clang-format ~/.clang-format
put shared/starship/starship.toml     ~/.config/starship.toml
put shared/vscode/settings.json    ~/.config/Code/User/settings.json
put shared/vscode/keybindings.json ~/.config/Code/User/keybindings.json

# ─── linux-only configs ────────────────────────────────────────────
hdr "linux configs"
put linux/zsh/.zshrc       ~/.zshrc
put linux/ghostty/config   ~/.config/ghostty/config
# SSH is opt-in — see linux/ssh/install.sh for why.
if [[ "${WITH_SSH:-0}" == 1 ]]; then
  bash "$REPO/linux/ssh/install.sh"
else
  sk "ssh skipped (WITH_SSH=1 to include, or run linux/ssh/install.sh later)"
fi

# ─── git identity ──────────────────────────────────────────────────
# shared/git/.gitconfig carries no [user] block — one repo serves both
# of you. The identity lives here, per machine, and is never committed.
hdr "git identity"
if [[ -f ~/.gitconfig.local ]]; then
  sk "~/.gitconfig.local ($(git config -f ~/.gitconfig.local user.email))"
else
  read -rp "  git name:  " GN
  read -rp "  git email: " GE
  printf '[user]\n\tname = %s\n\temail = %s\n' "$GN" "$GE" > ~/.gitconfig.local
  ok "~/.gitconfig.local"
fi

# ─── org-sync ──────────────────────────────────────────────────────
hdr "org-sync"
put shared/bin/org-sync ~/bin/org-sync
chmod +x ~/bin/org-sync
put linux/systemd/org-sync.service ~/.config/systemd/user/org-sync.service
put linux/systemd/org-sync.timer   ~/.config/systemd/user/org-sync.timer
if [[ -d ~/Documents/notes/.git ]]; then
  systemctl --user daemon-reload
  systemctl --user enable --now org-sync.timer
  loginctl enable-linger "$USER" >/dev/null 2>&1 || true
  ok "timer enabled (every 10 min)"
else
  sk "~/Documents/notes isn't a repo yet — clone it, then:"
  echo "      systemctl --user daemon-reload"
  echo "      systemctl --user enable --now org-sync.timer"
fi

# ─── vscode extensions ─────────────────────────────────────────────
hdr "vscode extensions"
if command -v code >/dev/null; then
  while read -r ext; do
    [[ -z "$ext" ]] && continue
    code --install-extension "$ext" --force >/dev/null 2>&1 && ok "$ext"
  done < "$REPO/shared/vscode/extensions.txt"
else
  sk "code not on PATH"
fi

# ─── doom ──────────────────────────────────────────────────────────
hdr "doom emacs"
if [[ -d ~/.config/emacs ]]; then
  sk "doom already cloned — run 'doom sync' yourself"
else
  git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs
  ~/.config/emacs/bin/doom install --no-env
  ok "doom installed"
fi

# ─── tmux plugin manager ───────────────────────────────────────────
TPM=~/.tmux/plugins/tpm
[[ -d $TPM ]] || git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM"
ok "tpm (prefix + I to install plugins)"

# ─── shell ─────────────────────────────────────────────────────────
if [[ "$SHELL" != */zsh ]]; then
  chsh -s "$(command -v zsh)"
  ok "default shell -> zsh (takes effect on next login)"
fi

# ─── thinkpad only ─────────────────────────────────────────────────
if [[ $ROLE == thinkpad ]]; then
  hdr "thinkpad"

  sudo install -Dm644 "$REPO/linux/keyd/thinkpad.conf" /etc/keyd/thinkpad.conf
  sudo systemctl enable --now keyd
  ok "keyd — run 'sudo keyd monitor' and fix the [ids] line"

  # TLP and power-profiles-daemon fight. Pick TLP.
  sudo systemctl disable --now power-profiles-daemon 2>/dev/null || true
  sudo sed -i 's/^#*START_CHARGE_THRESH_BAT0=.*/START_CHARGE_THRESH_BAT0=75/' /etc/tlp.conf
  sudo sed -i 's/^#*STOP_CHARGE_THRESH_BAT0=.*/STOP_CHARGE_THRESH_BAT0=80/'  /etc/tlp.conf
  sudo systemctl enable --now tlp
  ok "tlp, battery capped at 80%"
fi

# ─── gnome ─────────────────────────────────────────────────────────
bash "$REPO/linux/gnome/setup.sh"

# ═══════════════════════════════════════════════════════════════════
cat <<EOF

  Backups: $B

  Left to do by hand:
    1. In Emacs:  M-x nerd-icons-install-fonts
                  M-x pdf-tools-install      (compiles epdfinfo)
    2. Extension Manager: Tiling Shell, Vitals
    3. ssh-keygen -t ed25519 && gh ssh-key add ~/.ssh/id_ed25519.pub
    4. tailscale up
$( [[ $ROLE == thinkpad ]] && echo "    5. BIOS: swap Fn/Ctrl. Then 'sudo keyd monitor' for the real ids." )
    6. Notes sync: docs/notes-sync.md
    7. SSH, when you're ready:  bash linux/ssh/install.sh

  Log out and back in.
EOF
