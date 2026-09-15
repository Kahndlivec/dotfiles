#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════════
#  macos-prefs.sh — back up and restore GUI app settings (Rectangle, AltTab,
#  LinearMouse, Raycast, …) that have no config file you can edit.
#
#      bash macos-prefs.sh export    # dump them into the repo
#      bash macos-prefs.sh import    # restore them onto a new Mac
#      bash macos-prefs.sh list      # show every domain on this Mac, to find more
#
#  Set REPO if yours isn't ~/Documents/dotfiles.
# ═════════════════════════════════════════════════════════════════════════════
set -u

REPO="${DOTFILES_REPO:-$HOME/Documents/dotfiles}"
OUT="$REPO/macos/prefs"

ok(){  printf '  \033[32m✓\033[0m %s\n' "$1"; }
sk(){  printf '  \033[33m–\033[0m %s\n' "$1"; }
no(){  printf '  \033[31m✗\033[0m %s\n' "$1"; }
say(){ printf '      %s\n' "$1"; }

# Keywords, not bundle IDs. Bundle IDs are easy to get wrong from memory
# (com.knollsoft.Rectangle vs com.knollsoft.Hookshot for Pro), so instead we
# match these against the real domain list on this machine. Add your own.
# Domains that match a keyword but are not settings. Apple's telemetry
# matches "stats"; Raycast and the *.usage/*.license domains are runtime
# state that churns on every run and drowns real changes in the diff.
SKIP_RE="com\\.apple\\.|\\.usage$|\\.license$|raycast"

KEYWORDS="rectangle alt-tab alttab linearmouse raycast maccy karabiner hiddenbar
minimalbar shottr stats iina rcmd swish bettertouchtool aerospace amethyst
yabai skhd monitorcontrol appcleaner keka itsycal"

MODE="${1:-}"

case "$MODE" in
list)
  echo "Every preference domain on this Mac (grep this for your app):"
  defaults domains | tr ',' '\n' | sed 's/^ *//' | sort | sed 's/^/  /'
  echo
  say "then add a keyword to KEYWORDS at the top of this script,"
  say "or export one directly:  defaults export <domain> file.plist"
  ;;

export)
  mkdir -p "$OUT"
  ALL=$(defaults domains | tr ',' '\n' | sed 's/^ *//')
  FOUND=0
  for kw in $KEYWORDS; do
    while IFS= read -r dom; do
      [ -z "$dom" ] && continue
      printf %s "$dom" | grep -qE "$SKIP_RE" && continue
      # -; writes XML to stdout, so we control the filename and can diff it
      if defaults export "$dom" - > "$OUT/$dom.plist" 2>/dev/null && [ -s "$OUT/$dom.plist" ]; then
        ok "$dom  ($(wc -c <"$OUT/$dom.plist" | tr -d ' ') bytes)"
        FOUND=$((FOUND+1))
      else
        rm -f "$OUT/$dom.plist"
      fi
    done < <(printf '%s\n' "$ALL" | grep -i -- "$kw")
  done
  [ "$FOUND" = 0 ] && sk "no matching domains — run: bash macos-prefs.sh list"

  # LinearMouse is the exception worth knowing: it uses a real JSON config
  # under XDG, so it needs no plist dance at all.
  if [ -f "$HOME/.config/linearmouse/linearmouse.json" ]; then
    mkdir -p "$REPO/linearmouse"
    cp "$HOME/.config/linearmouse/linearmouse.json" "$REPO/linearmouse/linearmouse.json"
    ok "linearmouse/linearmouse.json (real config file, not a plist)"
  fi

  # Rectangle also has a proper Export in its own settings UI → JSON.
  # Worth doing once as a human-readable backup alongside the plist.
  say ""
  say "Rectangle also has Settings → Export in its own UI — that JSON is more"
  say "readable than the plist. Save it to $REPO/macos/rectangle-export.json"
  echo
  say "plists are XML, so git will diff them. Commit as usual:"
  say "    cd $REPO && git add -A && git commit -m 'app prefs' && git push"
  ;;

import)
  [ -d "$OUT" ] || { no "no $OUT — run export on the old Mac first"; exit 1; }
  echo "QUIT the apps you are about to restore first. A running app rewrites"
  echo "its own preferences from memory and will undo this within seconds."
  printf 'Ready? [y/N] '; read -r YN
  case "$YN" in y|Y) ;; *) echo "Stopped."; exit 0;; esac
  for f in "$OUT"/*.plist; do
    [ -f "$f" ] || continue
    dom=$(basename "$f" .plist)
    defaults import "$dom" "$f" && ok "$dom" || no "$dom failed"
  done
  if [ -f "$REPO/linearmouse/linearmouse.json" ]; then
    mkdir -p "$HOME/.config/linearmouse"
    cp "$REPO/linearmouse/linearmouse.json" "$HOME/.config/linearmouse/linearmouse.json"
    ok "linearmouse.json"
  fi
  # macOS caches preferences in cfprefsd; without this, imports appear to do
  # nothing until you log out.
  killall cfprefsd 2>/dev/null && ok "restarted cfprefsd (cache flushed)"
  echo
  say "now launch each app and confirm. Some need a login/logout to fully apply."
  ;;

*)
  echo "usage: bash macos-prefs.sh {export|import|list}"
  exit 1
  ;;
esac
