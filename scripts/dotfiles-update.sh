#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════════
#  dotfiles-update.sh — the one you run from now on. Re-collects every config
#  from this Mac, shows you exactly what changed, commits, pushes.
#
#      bash dotfiles-update.sh "bump tmux prefix to C-a"
#      bash dotfiles-update.sh                    # asks for the message
#
#  Set the repo path once at the top if yours isn't ~/dotfiles.
# ═════════════════════════════════════════════════════════════════════════════
set -u

# ── EDIT THIS if your repo lives somewhere else ──────────────────────────────
REPO="${DOTFILES_REPO:-$HOME/Documents/dotfiles}"
# ─────────────────────────────────────────────────────────────────────────────

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MSG="${1:-}"

# --dry-run / -n : collect and stage, but do not commit or push. Lets you see
# exactly what would change before anything is recorded.
DRY=0
case "$MSG" in --dry-run|-n) DRY=1; MSG="dry run";; esac

ok(){  printf '  \033[32m✓\033[0m %s\n' "$1"; }
no(){  printf '  \033[31m✗\033[0m %s\n' "$1"; }
sk(){  printf '  \033[33m–\033[0m %s\n' "$1"; }
say(){ printf '      %s\n' "$1"; }
hdr(){ printf '\n\033[1;44m %s \033[0m\n' "$1"; }

[ -d "$REPO/.git" ] || { no "no git repo at $REPO"; say "set it: DOTFILES_REPO=~/Documents/dotfiles bash dotfiles-update.sh"; exit 1; }
[ -f "$HERE/dotfiles-init.sh" ] || { no "dotfiles-init.sh must be beside this script"; exit 1; }

hdr "1  Is the Sublime setup stale?"
# cp-export.sh rebuilds the bundle that dotfiles-init.sh copies into sublime/.
# If a Sublime config is newer than the bundle, the bundle is out of date.
U="$HOME/Library/Application Support/Sublime Text/Packages/User"
BUNDLE="$HOME/Documents/cp-portable/payload"
NEEDS=0
if [ -d "$BUNDLE" ]; then
  while IFS= read -r -d '' f; do
    [ "$f" -nt "$BUNDLE" ] && { NEEDS=1; say "newer than the bundle: $(basename "$f")"; }
  done < <(find "$U" -maxdepth 1 -type f \( -name '*.sublime-*' -o -name '.neovintageousrc' \) -print0 2>/dev/null)
else
  NEEDS=1; say "no bundle at all yet"
fi
if [ "$NEEDS" = 1 ]; then
  if [ -f "$HERE/cp-export.sh" ]; then
    say "re-exporting…"
    bash "$HERE/cp-export.sh" >/dev/null 2>&1 && ok "Sublime bundle refreshed" || no "cp-export.sh failed — run it by hand to see why"
  else
    sk "cp-export.sh isn't here; sublime/ in the repo will stay as it was"
  fi
else
  ok "Sublime bundle is current"
fi

if [ -z "$MSG" ]; then
  echo
  printf '  Commit message (what did you change?): '
  read -r MSG
  [ -z "$MSG" ] && MSG="dotfiles: sync from $(hostname -s 2>/dev/null || echo mac)"
fi

# Record the exact commit we start from, so the undo advice at the end is
# specific rather than "figure it out".
BEFORE=$(cd "$REPO" && git rev-parse --short HEAD 2>/dev/null || echo none)

hdr "2  Re-collecting everything"
# dotfiles-init.sh is idempotent — it only copies, re-runs the secret scan, and
# regenerates bootstrap.sh and .gitignore so new config types get picked up.
DOTFILES_NO_COMMIT="$DRY" bash "$HERE/dotfiles-init.sh" "$REPO" "$MSG" 2>&1 | sed 's/^/  /'
RC=${PIPESTATUS[0]}
if [ "$RC" != 0 ]; then
  echo
  no "collection stopped (secret scan, or git identity). Nothing was committed."
  exit "$RC"
fi

cd "$REPO" || exit 1

if [ "$DRY" = 1 ]; then
  hdr "DRY RUN — nothing committed, nothing pushed"
  echo "  what would change:"
  git diff --cached --stat | sed 's/^/      /'
  echo
  say "see the actual lines:  cd $REPO && git diff --cached"
  say "go ahead and keep it:  git commit -m \"your message\" && git push"
  say "throw it all away:     git restore --source=HEAD --staged --worktree ."
  exit 0
fi

hdr "3  Push"
if ! git remote get-url origin >/dev/null 2>&1; then
  sk "no remote yet. Set one:"
  say "gh repo create dotfiles --public --source=. --push"
  exit 0
fi
AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "?")
if [ "$AHEAD" = "0" ]; then
  ok "already in sync with $(git remote get-url origin)"
else
  say "$AHEAD commit(s) to push"
  git push -q && ok "pushed to $(git remote get-url origin)" || no "push failed — see above"
fi

hdr "Where you stand"
git --no-pager log --oneline -5 | sed 's/^/      /'
echo
git status --short --branch | sed 's/^/      /'
echo
say "if this run did something you didn't want:"
say "    cd $REPO && git reset --hard $BEFORE     # back to where you started"
say "(only rewrites your local copy; if it was already pushed, add --force)"
