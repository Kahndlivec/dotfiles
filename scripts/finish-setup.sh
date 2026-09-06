#!/usr/bin/env bash
# Everything still outstanding, in one pass.
#   bash finish-setup.sh
set -uo pipefail

say() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

say "1/5  macOS key repeat"
# KeyRepeat is a delay in 15ms ticks, so LOWER = FASTER.
#   1 = 15ms = ~66 keys/sec  <- what you had. Faster than Emacs can redisplay.
#   2 = 30ms = ~33 keys/sec  <- still very fast, and Emacs keeps up.
# InitialKeyRepeat is the pause before repeating starts (15 = 225ms).
defaults write -g KeyRepeat -int 2
defaults write -g InitialKeyRepeat -int 15
echo "Set. Takes effect after you log out and back in (or restart Emacs + Ghostty)."

say "2/5  C/C++ toolchain"
brew install llvm
echo "clangd + lldb-dap are at /opt/homebrew/opt/llvm/bin (already on your PATH,"
echo "placed last so brew's clang doesn't shadow Xcode's)."

say "3/5  Language servers and Claude"
npm i -g pyright bash-language-server @anthropic-ai/claude-code

say "4/5  Fonts for prose in org"
brew install --cask font-inter || true

say "5/5  Notes directory"
if [[ -d "$HOME/Documents/notes" ]]; then
  echo "Already exists, skipping."
else
  mkdir -p "$HOME/Documents/notes"/{assets,denote}
  cd "$HOME/Documents/notes"
  printf '#+TITLE: Inbox\n\n'              > inbox.org
  printf '#+TITLE: Todo\n\n* Tasks\n'      > todo.org
  printf '#+TITLE: School\n\n* Tasks\n'    > school.org
  printf '#+TITLE: CP log\n\n'             > cp-log.org
  printf '#+TITLE: Math log\n\n'           > math-log.org
  cat > .gitignore <<'EOF'
.DS_Store
*~
\#*\#
.\#*
ltximg/
auto/
.org-id-locations
EOF
  git init -q && git add -A && git commit -qm "notes: initial structure"
  echo "Created ~/Documents/notes with a local git repo."
fi

say "Done"
cat <<'EOF'
Remaining, inside Emacs:

  SPC h p     perf report — tells you if native compilation is still running,
              which is the most likely cause of early sluggishness
  SPC h P     profile 5 seconds of typing, if it's still slow

  SPC l l     Claude in Emacs (first run will ask you to log in)
  SPC m c     start the Competitive Companion listener, then point the
              browser extension at http://localhost:10043

Not done, deliberately:
  LaTeX        — revisit in a few weeks
  org-noter    — once you have MFF skripta to annotate
  TRAMP        — see ssh_config.sample when you next work remotely
EOF
