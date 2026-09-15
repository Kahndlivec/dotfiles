#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════════
#  install.sh — restores this CP setup onto any Mac, under any username.
#
#      bash install.sh
#
#  Safe to re-run. Everything it replaces is backed up first, and it writes a
#  restore script so you can put the machine back exactly as it was.
# ═════════════════════════════════════════════════════════════════════════════
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PL="$HERE/payload"
ST="$HOME/Library/Application Support/Sublime Text"
U="$ST/Packages/User"
DEST="$HOME/Documents/cp"
STAMP=$(date +%Y%m%d-%H%M%S)
VAULT="$HOME/Documents/cp-backups/pre-install-$STAMP"

ok(){ printf '  \033[32m✓\033[0m %s\n' "$1"; }
no(){ printf '  \033[31m✗\033[0m %s\n' "$1"; }
wa(){ printf '  \033[33m!\033[0m %s\n' "$1"; }
hdr(){ printf '\n\033[1;44m %s \033[0m\n' "$1"; }

[ -d "$PL" ] || { no "no payload/ next to this script — unpack the whole bundle"; exit 1; }

hdr "0  Prerequisites"
MISSING=0
[ -d "/Applications/Sublime Text.app" ] && ok "Sublime Text installed" || { no "Sublime Text not in /Applications — install it first: https://www.sublimetext.com/download"; MISSING=1; }
command -v python3 >/dev/null && ok "python3" || { no "python3 — run: xcode-select --install"; MISSING=1; }
command -v clang++ >/dev/null && ok "clang++" || { no "clang++ — run: xcode-select --install"; MISSING=1; }
command -v brew >/dev/null && ok "homebrew" || wa "no homebrew — optional, but g++ and Ghostty come from it"
[ "$MISSING" = 1 ] && { echo; echo "Install the ✗ items, then re-run."; exit 1; }

# Sublime has to have run once to create Packages/User.
if [ ! -d "$U" ]; then
  wa "$U does not exist — Sublime has never been launched."
  echo "      Open Sublime Text once, quit it, then re-run this script."
  exit 1
fi
ok "Packages/User exists"

hdr "1  Backing up what is there now"
mkdir -p "$VAULT"
{ echo '#!/bin/bash'; echo 'set -e'
  echo 'V="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"'; } > "$VAULT/restore.sh"
n=0
while IFS= read -r -d '' src; do
  rel="${src#$PL/sublime-user/}"
  if [ -f "$U/$rel" ]; then
    cp "$U/$rel" "$VAULT/"
    printf 'cp "$V/%s" "%s"\n' "$rel" "$U/$rel" >> "$VAULT/restore.sh"
    n=$((n+1))
  fi
done < <(find "$PL/sublime-user" -type f -print0 2>/dev/null)
chmod +x "$VAULT/restore.sh"
ok "$n existing files archived → $VAULT"
[ "$n" = 0 ] && ok "(clean machine, nothing to overwrite)"

hdr "2  Installing"
mkdir -p "$U" "$DEST/algo" "$HOME/.cp" "$HOME/Library/Preferences/clangd"

copyin(){ # src dst
  cp "$1" "$2" && ok "$(basename "$1")"
}
while IFS= read -r -d '' f; do copyin "$f" "$U/$(basename "$f")"; done \
  < <(find "$PL/sublime-user" -type f -print0 2>/dev/null)

[ -f "$PL/clangd/config.yaml" ] && copyin "$PL/clangd/config.yaml" "$HOME/Library/Preferences/clangd/config.yaml"

if [ -d "$PL/dotcp/.cp" ]; then
  ( cd "$PL/dotcp" && tar cf - .cp ) | ( cd "$HOME" && tar xf - )
  chmod +x "$HOME"/.cp/*.sh 2>/dev/null || true
  ok "~/.cp restored ($(find "$HOME/.cp" -type f | wc -l | tr -d ' ') files, *.sh made executable)"
fi

[ -f "$PL/cpdir/cp.sublime-project" ] && copyin "$PL/cpdir/cp.sublime-project" "$DEST/cp.sublime-project"
if [ -d "$PL/cpdir/algo" ]; then
  cp "$PL/cpdir"/algo/*.cpp "$DEST/algo/" 2>/dev/null && ok "algo/ templates"
fi

hdr "3  Rewriting paths for THIS user"
# The bundle stores __CP_HOME__ wherever the exporting machine's home path was.
CH=0
while IFS= read -r -d '' f; do
  case "$(file -b --mime-type "$f")" in text/*|application/json|application/xml) ;; *) continue;; esac
  if grep -q '__CP_HOME__' "$f" 2>/dev/null; then
    python3 - "$f" "$HOME" <<'PY'
import sys
p, home = sys.argv[1], sys.argv[2]
s = open(p, encoding='utf-8', errors='replace').read()
open(p, 'w', encoding='utf-8').write(s.replace('__CP_HOME__', home))
PY
    CH=$((CH+1))
  fi
done < <( { find "$U" -maxdepth 1 -type f -print0; find "$HOME/.cp" -type f -print0; \
            find "$DEST" -maxdepth 2 -type f -print0; \
            printf '%s\0' "$HOME/Library/Preferences/clangd/config.yaml"; } 2>/dev/null )
ok "$CH files repointed at $HOME"
grep -rl '/Users/' "$U" 2>/dev/null | grep -v "$HOME" | head -3 | sed 's/^/      leftover absolute path in: /' || true

hdr "4  Validating every JSON file we just wrote"
python3 - "$U" "$DEST" <<'PY'
import sys, os, re, json, glob
U, DEST = sys.argv[1], sys.argv[2]
bad = 0
targets = (glob.glob(os.path.join(U,'*.sublime-keymap')) + glob.glob(os.path.join(U,'*.sublime-settings'))
           + glob.glob(os.path.join(U,'*.sublime-build')) + glob.glob(os.path.join(U,'*.sublime-macro'))
           + glob.glob(os.path.join(DEST,'*.sublime-project')))
for p in targets:
    s = open(p, encoding='utf-8', errors='replace').read()
    s = re.sub(r'(?m)^\s*//.*$','',s); s = re.sub(r',(\s*[\]}])',r'\1',s)
    try:
        d = json.loads(s)
        n = len(d) if isinstance(d,(list,dict)) else 0
        print("  \033[32m✓\033[0m %-42s %d entries" % (os.path.basename(p), n))
    except Exception as e:
        print("  \033[31m✗\033[0m %s: %s" % (os.path.basename(p), e)); bad += 1
sys.exit(1 if bad else 0)
PY

hdr "5  Sublime packages"
PC="$U/Package Control.sublime-settings"
if [ -f "$PC" ]; then
  python3 -c "
import json,re
s=open('$PC',encoding='utf-8').read()
s=re.sub(r'(?m)^\s*//.*\$','',s); s=re.sub(r',(\s*[\]}])',r'\1',s)
pk=json.loads(s).get('installed_packages',[])
print('  this bundle asks for %d packages:'%len(pk))
for p in pk: print('     ',p)
" 2>/dev/null
  echo
  echo "  Package Control installs these automatically ON NEXT LAUNCH — but only"
  echo "  if Package Control itself is present. If it is not:"
  echo "     Sublime → Tools → Install Package Control…, then restart."
  echo "  Give it a minute after restarting; watch the status bar."
else
  wa "no package list in the bundle — install these by hand via ⌘⇧P → Install Package:"
  echo "     NeoVintageous, LSP, LSP-clangd, CppFastOlympicCoding,"
  echo "     Origami, SideBarEnhancements, Terminus, Monokai Pro"
fi

hdr "6  Optional extras"
echo "  brew install gcc       real GCC for the judge build (⌘⇧G)"
echo "  brew install llvm      newer clangd than Xcode's, if LSP misbehaves"
echo "  brew install --cask ghostty    the interactive-run terminal (⌘⇧T)"
echo
echo "  Everything else works without these."

hdr "DONE"
cat <<'EOT'
  In Sublime, in this order:

    1. Quit and reopen Sublime (twice if Package Control is installing).
    2. Project → Open Project → ~/Documents/cp/cp.sublime-project
    3. Tools → Build System → C++ CP
    4. ⌘⇧P → NeoVintageous: Reload Config
    5. Open a .cpp, press Esc then Space then w — it should save.
    6. New .cpp, type  cp  then Tab — the template should expand.
    7. ⌘⏎ — FOC compiles and opens the test panel.

  Then run  bash cp-verify.sh  if it came with this bundle.

  Undo the whole install:  bash ~/Documents/cp-backups/pre-install-*/restore.sh
EOT
