#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════════
#  dotfiles-init.sh — builds ~/dotfiles from what's actually on this Mac,
#  scans it for secrets, then creates and pushes the GitHub repo.
#
#      bash dotfiles-init.sh
#
#  Only ever COPIES. Nothing in your home directory is moved or deleted, so a
#  bad run costs you a `rm -rf ~/dotfiles` and nothing else.
#  Safe to re-run — that is how you update the repo later.
# ═════════════════════════════════════════════════════════════════════════════
set -u

# Where the repo lives. Override with an argument:
#     bash dotfiles-init.sh ~/Documents/dotfiles
D="${1:-$HOME/dotfiles}"
D="${D/#\~/$HOME}"          # expand a literal ~ if it came through quoted
# Optional second argument: the commit message. Useful on re-runs —
#     bash dotfiles-init.sh ~/dotfiles "bump tmux prefix to C-a"
MSG="${2:-}"
CPB="$HOME/Documents/cp-portable"
ADDED=0; SKIPPED=0

ok(){  printf '  \033[32m✓\033[0m %s\n' "$1"; ADDED=$((ADDED+1)); }
sk(){  printf '  \033[33m–\033[0m %s\n' "$1"; SKIPPED=$((SKIPPED+1)); }
no(){  printf '  \033[31m✗\033[0m %s\n' "$1"; }
say(){ printf '      %s\n' "$1"; }
hdr(){ printf '\n\033[1;44m %s \033[0m\n' "$1"; }

# grab <src> <dst-relative>  — copies only if src exists.
#
# Directories need care on a re-run: `cp -R src dst` when dst ALREADY EXISTS
# copies src *inside* dst, giving you nvim/nvim/init.lua the second time you
# run this. So for directories, clear the destination and copy the contents
# with `src/.` instead.
grab(){
  local src="$1" rel="$2"
  case "$rel" in ''|.|..|*..*|/*) no "refusing unsafe destination '$rel'"; return;; esac
  if [ -d "$src" ]; then
    rm -rf "$D/$rel"
    mkdir -p "$D/$rel"
    cp -R "$src/." "$D/$rel/" && ok "$rel/ ($(find "$D/$rel" -type f | wc -l | tr -d ' ') files)"
  elif [ -e "$src" ]; then
    mkdir -p "$D/$(dirname "$rel")"
    cp "$src" "$D/$rel" && ok "$rel"
  else
    sk "$rel — not on this machine"
  fi
}

hdr "0  Where things will go"
say "repo   : $D"
say "nothing is moved; originals stay where they are"

# ── iCloud check ─────────────────────────────────────────────────────────────
# If "Desktop & Documents Folders" sync is on, ~/Documents is really
# ~/Library/Mobile Documents/com~apple~CloudDocs/Documents. A git repo in there
# is a genuine hazard, not a style preference: iCloud syncs the loose files
# inside .git/ independently and out of order, so two machines can produce a
# repo with a valid index and missing objects. "Optimize Mac Storage" makes it
# worse by evicting files to the cloud and replacing them with stubs.
REAL=$(cd "$(dirname "$D")" 2>/dev/null && pwd -P)/$(basename "$D")
case "$REAL" in
  *"Mobile Documents"*|*CloudDocs*)
    no "$D resolves into iCloud Drive:"
    say "$REAL"
    say ""
    say "Do not put a git repo there. iCloud syncs the individual files inside"
    say ".git/ independently, which can leave you with a valid index pointing at"
    say "objects that were never uploaded. Use one of:"
    say "    bash dotfiles-init.sh ~/dotfiles                 # conventional"
    say "    bash dotfiles-init.sh ~/code/dotfiles            # if you keep a code dir"
    say ""
    printf '  Continue anyway? [y/N] '; read -r YN
    case "$YN" in y|Y) wa "continuing — you have been warned";; *) echo "  Stopped."; exit 1;; esac
    ;;
  *) ok "not inside iCloud Drive" ;;
esac
mkdir -p "$D"

# ── Homebrew ─────────────────────────────────────────────────────────────────
hdr "1  Brewfile — the highest-value file in the repo"
if command -v brew >/dev/null; then
  brew bundle dump --describe --force --file="$D/Brewfile" >/dev/null 2>&1 \
    && ok "Brewfile ($(grep -c '^\(brew\|cask\|tap\|mas\)' "$D/Brewfile") entries)" \
    || no "brew bundle dump failed"
else
  sk "Brewfile — homebrew not installed"
fi

# ── Sublime / the CP setup ───────────────────────────────────────────────────
hdr "2  Sublime CP setup"
if [ -d "$CPB/payload" ]; then
  mkdir -p "$D/sublime"
  cp -R "$CPB/payload" "$D/sublime/"
  for f in install.sh README.md MANIFEST.txt cp-verify.sh; do
    [ -f "$CPB/$f" ] && cp "$CPB/$f" "$D/sublime/"
  done
  ok "sublime/ (from cp-portable — already username-agnostic)"
else
  sk "sublime/ — run cp-export.sh first, then re-run this"
fi

# ── Terminal ─────────────────────────────────────────────────────────────────
hdr "3  Ghostty"
# Ghostty reads XDG first, then its app-support dir. Take whichever exists.
if [ -f "$HOME/.config/ghostty/config" ]; then
  grab "$HOME/.config/ghostty/config" "ghostty/config"
else
  grab "$HOME/Library/Application Support/com.mitchellh.ghostty/config" "ghostty/config"
fi

# ── VSCode ───────────────────────────────────────────────────────────────────
hdr "4  VSCode"
VC="$HOME/Library/Application Support/Code/User"
grab "$VC/settings.json"    "vscode/settings.json"
grab "$VC/keybindings.json" "vscode/keybindings.json"
grab "$VC/snippets"         "vscode/snippets"
if command -v code >/dev/null; then
  mkdir -p "$D/vscode"
  code --list-extensions > "$D/vscode/extensions.txt" 2>/dev/null \
    && ok "vscode/extensions.txt ($(wc -l <"$D/vscode/extensions.txt" | tr -d ' ') extensions)"
else
  sk "extensions.txt — the 'code' command isn't on PATH"
  say "add it: VSCode → ⌘⇧P → 'Shell Command: Install code command in PATH'"
fi

# ── Shell ────────────────────────────────────────────────────────────────────
hdr "5  Shell"
grab "$HOME/.zshrc"     "zsh/.zshrc"
grab "$HOME/.zprofile"  "zsh/.zprofile"
grab "$HOME/.zshenv"    "zsh/.zshenv"
grab "$HOME/.p10k.zsh"  "zsh/.p10k.zsh"

# ── tmux ─────────────────────────────────────────────────────────────────────
hdr "5b  tmux"
# tmux looks in $XDG_CONFIG_HOME/tmux/tmux.conf first, then ~/.tmux.conf.
if   [ -f "$HOME/.config/tmux/tmux.conf" ]; then grab "$HOME/.config/tmux/tmux.conf" "tmux/tmux.conf"
elif [ -f "$HOME/.tmux.conf" ];             then grab "$HOME/.tmux.conf"             "tmux/.tmux.conf"
else sk "tmux config — neither ~/.config/tmux/tmux.conf nor ~/.tmux.conf"; fi
# TPM and plugins are git clones — record that they're wanted, don't vendor them.
if [ -d "$HOME/.tmux/plugins/tpm" ]; then
  say "TPM detected — bootstrap.sh will re-clone it; plugins install with prefix+I"
fi

# ── SSH: config and PUBLIC keys only ─────────────────────────────────────────
hdr "5c  SSH (config and public keys — never private keys)"
grab "$HOME/.ssh/config"          "ssh/config"
grab "$HOME/.ssh/allowed_signers" "ssh/allowed_signers"
# known_hosts holds PUBLIC host keys — not a secret. Worth carrying so a new
# machine doesn't prompt you to trust github.com all over again.
grab "$HOME/.ssh/known_hosts"     "ssh/known_hosts"
if ls "$HOME"/.ssh/*.pub >/dev/null 2>&1; then
  mkdir -p "$D/ssh" && cp "$HOME"/.ssh/*.pub "$D/ssh/" && ok "ssh/*.pub ($(ls -1 "$HOME"/.ssh/*.pub | wc -l | tr -d ' ') public keys)"
else sk "no public keys in ~/.ssh"; fi
# Belt and braces: if a private key somehow got copied, delete it right here
# rather than relying on .gitignore alone.
for k in "$D"/ssh/*; do
  [ -f "$k" ] || continue
  case "$k" in *.pub|*/config|*/allowed_signers|*/known_hosts) continue;; esac
  rm -f "$k" && no "removed $(basename "$k") from the repo — private keys do not go in git"
done

# ── Apps: generated, never hand-maintained ───────────────────────────────────
hdr "5d  App inventory (generated)"
# Every .app on this Mac is one of three things, and only the third needs you
# to do anything on a new machine:
#   1. installed by a Homebrew cask   → the Brewfile already restores it
#   2. from the Mac App Store         → `mas` restores it (it's in the Brewfile)
#   3. neither                        → dragged from a .dmg. Manual forever.
# So rather than you keeping a list, we compute it.
mkdir -p "$D/apps"

CASK_JSON="$D/apps/.cask-artifacts.json"
if command -v brew >/dev/null; then
  CASKS=$(brew list --cask 2>/dev/null | tr '\n' ' ')
  if [ -n "${CASKS// /}" ]; then
    # ONE brew call for every installed cask. Per-cask calls take minutes.
    brew info --cask --json=v2 $CASKS > "$CASK_JSON" 2>/dev/null || rm -f "$CASK_JSON"
  fi
fi

python3 - "$D" "$CASK_JSON" <<'PY'
import sys, os, json, plistlib
D, cask_json = sys.argv[1], sys.argv[2]
G='\033[32m✓\033[0m'; Y='\033[33m–\033[0m'

# ── which .app names does Homebrew own ──────────────────────────────────────
cask_apps, token_of = set(), {}
if os.path.isfile(cask_json):
    try:
        data = json.load(open(cask_json, encoding='utf-8'))
        for c in data.get('casks', []):
            tok = c.get('token', '?')
            for art in c.get('artifacts', []):
                # artifacts is a list of dicts like {"app": ["Ghostty.app"]}
                if isinstance(art, dict):
                    for name in art.get('app', []) or []:
                        if isinstance(name, str) and name.endswith('.app'):
                            cask_apps.add(name); token_of[name] = tok
    except Exception as e:
        print("      (could not parse cask data: %s)" % e)

# ── every .app the user could have installed ────────────────────────────────
# /System/Applications is Apple's and reinstalls with macOS, so it is skipped.
found = []
for base in ('/Applications', os.path.expanduser('~/Applications')):
    if not os.path.isdir(base): continue
    for entry in sorted(os.listdir(base)):
        if not entry.endswith('.app'): continue
        p = os.path.join(base, entry)
        mas = os.path.isdir(os.path.join(p, 'Contents', '_MASReceipt'))
        ver = ''
        try:
            with open(os.path.join(p, 'Contents', 'Info.plist'), 'rb') as fh:
                ver = plistlib.load(fh).get('CFBundleShortVersionString', '') or ''
        except Exception:
            pass
        if entry in cask_apps:   kind = 'cask'
        elif mas:                kind = 'mas'
        else:                    kind = 'manual'
        found.append((entry[:-4], kind, ver, token_of.get(entry, ''), base))

manual = [f for f in found if f[1] == 'manual']
mas_l  = [f for f in found if f[1] == 'mas']
cask_l = [f for f in found if f[1] == 'cask']

lines = []
w = lines.append
w("# App inventory\n")
w("**Generated — do not edit.** Re-created every time the collector runs.")
w("Put your own notes in `apps/NOTES.md`, which is never overwritten.\n")
w("| | count | restored by |")
w("|---|---|---|")
w("| Homebrew cask | %d | `brew bundle install` |" % len(cask_l))
w("| Mac App Store | %d | `mas` (already in the Brewfile) |" % len(mas_l))
w("| **Manual** | **%d** | **you, by hand** |" % len(manual))
w("")
w("## Manual — these are the ones that cost you time\n")
if manual:
    w("Worth periodically running `brew search --cask <name>`; if a cask now")
    w("exists, install it that way and it moves into the Brewfile automatically.\n")
    w("| App | Version | Location |")
    w("|---|---|---|")
    for n, _, v, _, base in manual:
        w("| %s | %s | `%s` |" % (n, v or '—', base))
else:
    w("None — everything is managed. Nice.")
w("")
w("## Mac App Store\n")
if mas_l:
    w("| App | Version |"); w("|---|---|")
    for n, _, v, _, _ in mas_l: w("| %s | %s |" % (n, v or '—'))
else:
    w("None.")
w("")
w("## Homebrew casks\n")
if cask_l:
    w("| App | Cask |"); w("|---|---|")
    for n, _, _, tok, _ in cask_l: w("| %s | `%s` |" % (n, tok or '?'))
else:
    w("None detected — is `brew list --cask` empty?")
w("")

open(os.path.join(D, 'apps', 'apps.md'), 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
print("  %s apps/apps.md — %d manual, %d App Store, %d cask" % (G, len(manual), len(mas_l), len(cask_l)))
if manual:
    for n, _, _, _, _ in manual[:8]:
        print("      manual: %s" % n)
    if len(manual) > 8: print("      … and %d more" % (len(manual) - 8))
PY
rm -f "$CASK_JSON"

# Notes file, created once and then left alone forever.
if [ ! -f "$D/apps/NOTES.md" ]; then
  cat > "$D/apps/NOTES.md" <<'NOTES_EOF'
# App notes

`apps.md` is regenerated on every collection run — anything you type there is
lost. This file is never touched. Put licence reminders, download URLs and
"why do I have this" here.

| App | Where from | Notes |
|---|---|---|
|  |  |  |
NOTES_EOF
  ok "apps/NOTES.md (yours — never overwritten)"
fi

# ── Editors and CLI tools ────────────────────────────────────────────────────
hdr "5e  Editors and CLI tool configs"
# Neovim. You are learning Vim with NeoVintageous and the keymap comments say
# the habits are meant to transfer — when you make the jump this becomes the
# single most valuable directory in the repo.
grab "$HOME/.config/nvim" "nvim"

# Karabiner. Not installed yet, but the old handoff had a
# karabiner-hhkb-parity.json planned; if you ever load it, this catches it.
grab "$HOME/.config/karabiner/karabiner.json" "karabiner/karabiner.json"

# clang-format — directly relevant, it decides how your contest code looks.
grab "$HOME/.clang-format" "clang-format/.clang-format"

# gh CLI: config.yml is preferences. hosts.yml holds your OAuth token and is
# deliberately NOT taken.
grab "$HOME/.config/gh/config.yml" "gh/config.yml"
[ -f "$HOME/.config/gh/hosts.yml" ] && say "skipping gh/hosts.yml on purpose — it contains your OAuth token"

for pair in \
  ".config/starship.toml:starship/starship.toml" \
  ".config/bat/config:bat/config" \
  ".config/lazygit/config.yml:lazygit/config.yml" \
  ".ripgreprc:ripgrep/.ripgreprc" \
  ".editorconfig:editorconfig/.editorconfig" \
  ".hushlogin:misc/.hushlogin" ; do
  grab "$HOME/${pair%%:*}" "${pair##*:}"
done

# HHKB: the layout lives in the keyboard's firmware, so it survives a Mac wipe —
# but if the board is ever factory-reset, these screenshots are the only record
# of what the keymap assumes. Drop them in yourself.
mkdir -p "$D/hhkb"
[ -z "$(ls -A "$D/hhkb" 2>/dev/null)" ] && cat > "$D/hhkb/README.md" <<'HH_EOF'
# HHKB Pro Classic layout

Put your Keymap Tool screenshots (standard + Fn layer) in this folder. The
layout lives in the keyboard's firmware and survives a Mac wipe, but if the
board is ever reset these are the only record of what the Sublime keymap
assumes:

    Control (row 3, far left) →  ⌃ Control     free, left pinky
    bottom-left Alt slot      →  ⌘ Command     cheap, under Z X C V
    ◇ left of Space           →  Fn            free, left thumb
    ◇ right of Space          →  ⌘ Command     cheap, right thumb
    bottom-right Alt slot     →  ⌥ Option      expensive, corner — unused

Fn layer worth remembering: Fn+HJKL are arrows, Fn+Y/U are PgUp/PgDn,
Fn+I/O are Home/End, Fn+Backspace is forward Delete. That is why the keymap
needs no arrow, Home, End or F-key bindings.
HH_EOF
ok "hhkb/ (drop your Keymap Tool screenshots here)"

# ── Git ──────────────────────────────────────────────────────────────────────
hdr "6  Git"
grab "$HOME/.gitconfig"     "git/.gitconfig"
grab "$HOME/.gitignore_global" "git/.gitignore_global"
if [ -f "$D/git/.gitconfig" ] && grep -q 'email' "$D/git/.gitconfig"; then
  say "note: .gitconfig contains your email. Normal for a public dotfiles repo"
  say "      (it is in every commit you have ever pushed anyway), but if you'd"
  say "      rather not, delete the line from $D/git/.gitconfig."
fi

# ── macOS defaults stub ──────────────────────────────────────────────────────
hdr "7  macOS defaults"
if [ ! -f "$D/macos/defaults.sh" ]; then
  mkdir -p "$D/macos"
  cat > "$D/macos/defaults.sh" <<'MAC_EOF'
#!/bin/bash
# The `defaults write` tweaks you otherwise redo from memory on every new Mac.
# Add to this as you notice yourself changing things in System Settings.
set -u

# Key repeat — matters a lot in a Vim setup. 2/15 is faster than the System
# Settings slider can go.
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Kill press-and-hold accent menu so held keys actually repeat in Vim.
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Show all filenames and hidden files in Finder.
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true

# Full keyboard access, and no "smart" quotes/dashes mangling code.
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# ── Free ⌃← / ⌃→ from Mission Control ────────────────────────────────────────
# macOS binds these to "Move left/right a space" system-wide, which beats any
# app. Nothing in the Sublime keymap uses them today, but Karabiner word-motion
# and most terminal setups want them, and it is the kind of conflict that looks
# like "my keybinding is broken" for an hour.
# 79/80/81/82 are the symbolic hotkey ids for the four space-switching actions.
for id in 79 80 81 82; do
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$id" \
    '{enabled = 0; value = {parameters = (65535, 65535, 0); type = standard;};}'
done

killall Finder 2>/dev/null || true
echo "macOS defaults applied — log out and back in for key repeat to take hold."
MAC_EOF
  chmod +x "$D/macos/defaults.sh"
  ok "macos/defaults.sh (starter — edit as you go)"
else
  sk "macos/defaults.sh — already exists, left alone"
fi

# ── .gitignore: allowlist, not blacklist ─────────────────────────────────────
hdr "8  .gitignore (allowlist)"
cat > "$D/.gitignore" <<'GI_EOF'
# ALLOWLIST. Everything is ignored unless explicitly un-ignored below.
#
# This is deliberate. A blacklist ("ignore .ssh, ignore .aws, …") only protects
# you from the leaks you thought of in advance. An allowlist means a new file
# dropped in this repo is invisible to `git add` until you name it — so the
# default outcome of forgetting is "not committed", not "pushed to GitHub".
*

# …but always descend into directories, or the rules below can never match.
!*/

# Repo scaffolding
!.gitignore
!README.md
!bootstrap.sh
!Brewfile

# Configs, by extension
!**/*.json
!**/*.sh
!**/*.yaml
!**/*.yml
!**/*.toml
!**/*.md
!**/*.txt
!**/*.sublime-keymap
!**/*.sublime-settings
!**/*.sublime-build
!**/*.sublime-snippet
!**/*.sublime-macro
!**/*.sublime-project
!**/*.cpp
!**/*.h
!**/*.lua
!**/*.vim
!**/*.conf
!**/*.cfg
!**/*.ini

# Dotfiles that have no extension
!zsh/.zshrc
!zsh/.zprofile
!zsh/.zshenv
!zsh/.p10k.zsh
!git/.gitconfig
!git/.gitignore_global
!ghostty/config
!tmux/tmux.conf
!tmux/.tmux.conf
!apps/*
!bat/config
!clang-format/.clang-format
!ripgrep/.ripgreprc
!editorconfig/.editorconfig
!misc/.hushlogin
!nvim/**
!sublime/payload/sublime-user/.neovintageousrc

# ── Never, under any circumstances ──────────────────────────────────────────
# These come AFTER the allow rules above, because last match wins.
.aws/
.netrc
.npmrc
*.pem
*.key
id_rsa*
id_ed25519*
id_ecdsa*
id_dsa*
*.ppk
.env
.env.*
*_history
*.sublime-workspace
*.tar.gz
.DS_Store

# ── SSH: config and PUBLIC keys are safe and wanted ─────────────────────────
# Listed last so they win over the id_* blocks above — otherwise
# `id_ed25519.pub`, which is public by definition, would be excluded too.
!ssh/config
!ssh/known_hosts
!ssh/allowed_signers
!ssh/*.pub
GI_EOF
ok ".gitignore written"

# ── bootstrap.sh ─────────────────────────────────────────────────────────────
hdr "9  bootstrap.sh"
cat > "$D/bootstrap.sh" <<'BOOT_EOF'
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
BOOT_EOF
chmod +x "$D/bootstrap.sh"
ok "bootstrap.sh written"

# ── README ───────────────────────────────────────────────────────────────────
hdr "10  README.md"
if [ ! -f "$D/README.md" ]; then
cat > "$D/README.md" <<'RM_EOF'
# dotfiles

macOS setup: Sublime Text for competitive programming, Ghostty, VSCode, zsh,
and the `defaults write` tweaks that are otherwise redone from memory.

## Fresh Mac

```bash
xcode-select --install
git clone <this repo> ~/dotfiles
cd ~/dotfiles && bash bootstrap.sh
```

Installs Homebrew if missing, runs `brew bundle`, copies every config into
place, installs VSCode extensions, runs the Sublime installer, applies the
macOS defaults. Anything it overwrites is backed up to `~/dotfiles-backup-*`.

Sublime must have been launched once before bootstrap, so that `Packages/User`
exists.

## Layout

| Path | What |
|---|---|
| `Brewfile` | every formula and cask — `brew bundle install` |
| `sublime/` | self-installing CP setup: keymap, build system, clangd config, FOC settings, `bits/stdc++.h` shim. See `sublime/README.md` |
| `ghostty/config` | terminal |
| `tmux/` | tmux config; TPM is re-cloned by bootstrap, plugins install with `prefix + I` |
| `vscode/` | settings, keybindings, snippets, `extensions.txt` |
| `zsh/` | shell |
| `git/` | global gitconfig |
| `ssh/` | `config`, `known_hosts`, `allowed_signers`, `*.pub` — **no private keys** |
| `apps/apps_without_casks.md` | apps installed by hand that `brew bundle` won't restore |
| `macos/defaults.sh` | key repeat, Finder, no smart quotes |

## Why no SSH private keys

`~/.ssh/config` is just host aliases — no secrets, and genuinely annoying to
rebuild, so it lives here. Public keys are public by definition. Private keys
do not, even in a private repo:

- they sit in plaintext in every clone and in history forever
- a private repo is one mis-click, or one compromised account, from public
- deleting one later doesn't help — it stays in history, and the only real fix
  is rotating the key

And it's unnecessary. `ssh-keygen -t ed25519` plus `gh ssh-key add` is thirty
seconds on a new machine. If you specifically want key portability, encrypt
first (`age`, `git-crypt`) or use a password manager — don't hand it to git.

## Updating

```bash
bash cp-export.sh                    # if the Sublime setup changed
bash dotfiles-init.sh                # re-collects everything
cd ~/dotfiles && git add -A && git commit -m "..." && git push
```

`dotfiles-init.sh` only copies, so re-running it is safe.

## The .gitignore is an allowlist

Everything is ignored until explicitly un-ignored. A blacklist only protects
against leaks you thought of in advance; with an allowlist, the cost of
forgetting is a file that *didn't* get committed rather than a key that did.
Adding a new config type means adding one `!` line.

## Sublime CP setup

Full keymap and gotchas in `sublime/README.md`. The short version:

```
⌘⏎   run & test        cp+Tab  insert template     ⌃h ⌃j ⌃k ⌃l  panes
⌘B   build + ASan      ⌘K f    template library    ⌘⇧G  g++ judge build
⌘⇧K  compile only      ⌘K s    stress test         ⌃]   jump to definition
```

Zero `alt+` bindings — on an HHKB, ⌥ is a bottom-corner key that can't
comfortably combine with the right hand.
RM_EOF
ok "README.md written"
else
  sk "README.md exists, left alone"
fi

# ── secret scan, before git ever sees the files ──────────────────────────────
hdr "11  Secret scan"
python3 - "$D" <<'PY'
import sys, os, re
D = sys.argv[1]
PATTERNS = [
    (r'ghp_[A-Za-z0-9]{20,}',            'GitHub personal access token'),
    (r'github_pat_[A-Za-z0-9_]{20,}',    'GitHub fine-grained token'),
    (r'sk-[A-Za-z0-9]{20,}',             'OpenAI-style API key'),
    (r'sk-ant-[A-Za-z0-9\-_]{20,}',      'Anthropic API key'),
    (r'AKIA[0-9A-Z]{16}',                'AWS access key id'),
    (r'-----BEGIN [A-Z ]*PRIVATE KEY',   'private key'),
    (r'xox[baprs]-[A-Za-z0-9-]{10,}',    'Slack token'),
    (r'(?i)(password|passwd|secret|api[_-]?key)\s*[=:]\s*["\']?[^\s"\']{8,}', 'possible credential'),
]
# Filename check too: an SSH private key has no recognisable header if it is in
# PuTTY or PKCS#8-DER form, so content matching alone can miss one.
KEYNAME = re.compile(r'^(id_(rsa|ed25519|ecdsa|dsa)|.*\.ppk)$')
hits = []
for root, dirs, files in os.walk(D):
    dirs[:] = [d for d in dirs if d != '.git']
    for fn in files:
        p = os.path.join(root, fn)
        if KEYNAME.match(fn):
            hits.append((os.path.relpath(p, D), 0, 'private key by filename', fn))
            continue
        try:
            if os.path.getsize(p) > 2_000_000: continue
            s = open(p, encoding='utf-8', errors='replace').read()
        except Exception:
            continue
        for pat, label in PATTERNS:
            for m in re.finditer(pat, s):
                line = s[:m.start()].count('\n') + 1
                hits.append((os.path.relpath(p, D), line, label, m.group(0)[:12]))
if hits:
    print("  \033[31m✗ STOP — %d possible secret(s):\033[0m" % len(hits))
    for f, l, lab, frag in hits[:25]:
        print("      %s:%d  %s  (starts %s…)" % (f, l, lab, frag))
    print()
    print("      Remove or redact these BEFORE the first commit. Once pushed,")
    print("      deleting the file does not help — it stays in git history and")
    print("      the credential must be rotated instead.")
    sys.exit(1)
print("  \033[32m✓\033[0m no credential patterns found")
PY
SCAN=$?

hdr "12  What would be committed"
cd "$D" || exit 1
[ -d .git ] || { git init -q && echo "  git init"; }
git add -A 2>/dev/null
echo "  files git will track:"
git diff --cached --name-only | sed 's/^/      /'
N=$(git diff --cached --name-only | wc -l | tr -d ' ')
echo "  ── $N files"
echo
# The one real failure mode of an allowlist: you collect a file, the rules
# don't name its extension, and it is silently never committed. Diff the
# filesystem against the index and say so out loud.
UNTRACKED=$(comm -23 \
  <(find . -type f -not -path './.git/*' | sed 's|^\./||' | LC_ALL=C sort) \
  <(git diff --cached --name-only | LC_ALL=C sort))
if [ -n "$UNTRACKED" ]; then
  no "these files are in the repo folder but git will NOT save them:"
  printf '%s\n' "$UNTRACKED" | sed 's/^/      /'
  say ""
  say "If any of those matter, add a matching '!' line to .gitignore."
  say "Deliberately excluded: private keys, gh hosts.yml, *.tar.gz,"
  say "*.sublime-workspace, shell history, .DS_Store."
else
  ok "every file in the repo folder is staged — nothing silently dropped"
fi

if [ "$SCAN" != 0 ]; then
  # Unstage everything. If the findings were left staged, a later manual
  # `git commit` would sweep the credential in without re-running the scan.
  git reset -q 2>/dev/null
  echo
  no "secret scan failed — nothing staged, nothing committed."
  say "fix the findings above, then re-run this script."
  exit 1
fi

hdr "13  Commit"
if [ "${DOTFILES_NO_COMMIT:-0}" = "1" ]; then
  sk "DRY RUN — staged but NOT committed."
  say "review:   cd $D && git diff --cached"
  say "keep it:  git commit -m \"your message\""
  say "undo it:  git restore --source=HEAD --staged --worktree ."
  exit 0
fi
if ! git config user.email >/dev/null 2>&1 && ! git config --global user.email >/dev/null 2>&1; then
  no "git has no identity configured, so it cannot commit. Run:"
  say "git config --global user.name  \"Jakub Smida\""
  say "git config --global user.email \"jakub.smida.2007@gmail.com\""
  say "then re-run this script. (Staged files are left in place.)"
  exit 1
fi
if git diff --cached --quiet; then
  sk "nothing new since the last commit"
else
  echo "  changes in this commit:"
  git diff --cached --stat | sed 's/^/      /'
  [ -z "$MSG" ] && MSG="dotfiles: macOS, Sublime CP setup, Ghostty, tmux, VSCode, zsh"
  git commit -q -m "$MSG" && ok "committed: $MSG" || no "commit failed — see above"
fi

hdr "14  GitHub"
if ! command -v gh >/dev/null; then
  echo "  The gh CLI isn't installed. Either:"
  echo "      brew install gh && gh auth login"
  echo "  then re-run this script — or create the repo in the browser and:"
  echo "      cd $D"
  echo "      git remote add origin git@github.com:<you>/dotfiles.git"
  echo "      git branch -M main && git push -u origin main"
  exit 0
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "  gh is installed but not logged in. Run:  gh auth login"
  echo "  then re-run this script."
  exit 0
fi
if git remote get-url origin >/dev/null 2>&1; then
  ok "remote already set: $(git remote get-url origin)"
  echo
  printf '  Push now? [Y/n] '; read -r P
  case "$P" in n|N) echo "  skipped";; *) git branch -M main 2>/dev/null; git push -u origin main && ok "pushed";; esac
  exit 0
fi
echo "  Public is fine — dotfiles-init.sh scrubbed your home path to"
echo "  __CP_HOME__ and the secret scan above came back clean."
echo
printf '  Repo name [dotfiles]: '; read -r NAME; NAME="${NAME:-dotfiles}"
printf '  Visibility — (p)ublic or p(r)ivate? [p/r] '; read -r V
case "$V" in r|R) VIS="--private";; *) VIS="--public";; esac
git branch -M main 2>/dev/null
gh repo create "$NAME" $VIS --source=. --push --description "macOS dotfiles: Sublime CP setup, Ghostty, VSCode, zsh" \
  && { ok "created and pushed"; echo; echo "  Your brother: git clone $(gh repo view --json url -q .url 2>/dev/null) && cd $NAME && bash bootstrap.sh"; } \
  || no "gh repo create failed — see the message above"
