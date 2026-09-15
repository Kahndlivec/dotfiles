#!/usr/bin/env bash
# Reports what is actually set up, rather than what we think is.
#   bash verify-setup.sh

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
no()   { printf '  \033[31m✗\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }
hdr()  { printf '\n\033[1m%s\033[0m\n' "$1"; }

D="$HOME/.config/doom"

hdr "Core"
command -v emacs >/dev/null && ok "emacs $(emacs --version | head -1 | awk '{print $3}')" || no "emacs missing"
command -v doom  >/dev/null && ok "doom CLI on PATH" || no "doom not on PATH"
[ -L /Applications/Emacs.app ] && ok "Emacs.app symlinked" || no "Emacs.app not symlinked"

hdr "Config files"
for f in init.el config.el packages.el +cp.el; do
  [ -f "$D/$f" ] && ok "$f" || no "$f MISSING"
done
[ -f "$D/templates/cp.cpp" ] && ok "CP template" || no "CP template missing"
[ -f "$D/snippets/c++-mode/cp" ] && ok "CP snippet" || no "CP snippet missing"

hdr "Is the LATEST config applied?"
grep -q "doom-monokai-pro"  "$D/config.el" 2>/dev/null && ok "theme = monokai-pro"        || no "old config: theme not set"
grep -q "mixed-pitch"       "$D/config.el" 2>/dev/null && ok "mixed-pitch block"          || no "old config: no mixed-pitch"
grep -q "center-frame"      "$D/config.el" 2>/dev/null && ok "centred 160x50 frame"       || no "old config: no frame sizing"
grep -q "projectile-project-search-path" "$D/config.el" 2>/dev/null && ok "project auto-discovery" || no "old config: no project search path"
grep -q "global-auto-revert-mode" "$D/config.el" 2>/dev/null && ok "auto-revert"          || no "old config: no auto-revert"
grep -q '"Inter"'           "$D/config.el" 2>/dev/null && ok "Inter as variable-pitch"    || no "old config: not using Inter"
grep -q "package! djvu"     "$D/packages.el" 2>/dev/null && ok "djvu (org-noter needs it)" || no "old packages.el: no djvu"
grep -q "^       dashboard" "$D/init.el" 2>/dev/null && ok "dashboard module renamed"     || warn "init.el still says doom-dashboard"

hdr "Binaries"
# gs, not ghostscript — the formula is called ghostscript, the binary is gs.
for b in rg fd clangd pyright direnv pngpaste gs black shfmt shellcheck claude; do
  command -v "$b" >/dev/null && ok "$b" || no "$b"
done
command -v latex >/dev/null && ok "latex ($(which latex))" || no "latex — is /Library/TeX/texbin on PATH?"
command -v dvisvgm >/dev/null && ok "dvisvgm" || no "dvisvgm"

hdr "Fonts"
brew list --cask 2>/dev/null | grep -q jetbrains && ok "JetBrainsMono Nerd Font" || no "JetBrainsMono Nerd Font"
brew list --cask 2>/dev/null | grep -q "font-inter" && ok "Inter" || no "Inter"
# nerd-icons installs as "Symbols Nerd Font Mono" or "SymbolsNerdFont*" —
# match loosely, and fall back to fc-list if it's installed system-wide.
if ls ~/Library/Fonts 2>/dev/null | grep -qiE "symbols.*nerd|nerdfont"; then
  ok "Symbols Nerd Font"
elif fc-list 2>/dev/null | grep -qi "symbols nerd"; then
  ok "Symbols Nerd Font (system)"
else
  warn "Symbols Nerd Font — M-x nerd-icons-install-fonts"
fi

hdr "Notes"
[ -d "$HOME/Documents/notes" ] && ok "~/Documents/notes" || no "notes directory missing"
for f in inbox.org todo.org school.org; do
  [ -f "$HOME/Documents/notes/$f" ] && ok "$f" || no "$f"
done
[ -d "$HOME/Documents/notes/.git" ] && ok "notes is a git repo" || warn "notes not under git"

hdr "Shell"
grep -q "direnv hook zsh" ~/.zshrc && ok "direnv hook" || no "direnv hook missing"
# What matters is whether latex resolves, not how it got onto PATH —
# /Library/TeX/texbin arrives via path_helper on macOS anyway.
command -v latex >/dev/null && ok "latex resolves in this shell" || warn "latex not on PATH"
grep -qE "^(eh\(\)|alias eh=)" ~/.zshrc && ok "eh (remote emacs)" || no "eh missing"
grep -qE "^e\(\)" ~/.zshrc && ok "e (open in running Emacs)" || warn "e missing"

hdr "Remote"
ssh -o ConnectTimeout=5 -o BatchMode=yes homelab 'true' 2>/dev/null \
  && ok "homelab reachable" || warn "homelab unreachable (probably powered off — fine)"

hdr "Dotfiles"
if [ -L "$D" ]; then ok "doom config symlinked into a repo: $(readlink "$D")"
else no "doom config NOT in git — this is the one that matters"; fi

hdr "Key repeat"
KR=$(defaults read -g KeyRepeat 2>/dev/null || echo "?")
case "$KR" in
  1|2) ok "KeyRepeat=$KR (1 and 2 both tested fine; 1 is faster everywhere else)" ;;
  *)   warn "KeyRepeat=$KR — 1 or 2 is what you want" ;;
esac
