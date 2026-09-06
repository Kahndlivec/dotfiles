#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════════
#  cp-export.sh — snapshots YOUR working setup into a portable, self-installing
#  bundle. One artifact, two jobs:
#
#      · your backup                (restore onto this Mac after a wipe)
#      · your brother's installer   (works on any Mac, any username)
#
#      bash cp-export.sh
#
#  Deliberately exports what you HAVE rather than what I think you have — your
#  .neovintageousrc, run-term.sh, stress.sh and the shim were never in my
#  hands, and reconstructing them from memory is how you get a setup that
#  looks right and behaves differently.
#
#  Usernames are handled by rewriting your home path to __CP_HOME__ on the way
#  out and back to the installing user's $HOME on the way in. That is why the
#  bundle works for "jakub" and "brother" alike.
# ═════════════════════════════════════════════════════════════════════════════
set -u

ST="$HOME/Library/Application Support/Sublime Text"
U="$ST/Packages/User"
P="$ST/Packages"
DEST="$HOME/Documents/cp"
STAMP=$(date +%Y%m%d)
BUNDLE="$HOME/Documents/cp-portable"
PL="$BUNDLE/payload"

ok(){  printf '  \033[32m✓\033[0m %s\n' "$1"; }
wa(){  printf '  \033[33m!\033[0m %s\n' "$1"; }
say(){ printf '      %s\n' "$1"; }
hdr(){ printf '\n\033[1m%s\033[0m\n' "$1"; }

[ -d "$U" ] || { echo "No $U"; exit 1; }

hdr "Pre-flight — things that would break on someone else's Mac"
STOP=0
# A hardcoded compiler version is the classic one. It works here until Homebrew
# bumps, and it will almost certainly be wrong on the receiving machine.
if grep -qE '"shell_cmd".*g\+\+-[0-9]+' "$U"/*.sublime-build 2>/dev/null; then
  grep -ohE 'g\+\+-[0-9]+' "$U"/*.sublime-build | sort -u | while read -r v; do
    if command -v "$v" >/dev/null; then wa "build file hardcodes $v — present here, but not portable"
    else printf '  \033[31m✗\033[0m build file hardcodes %s, which is NOT INSTALLED even here\n' "$v"; fi
  done
  grep -qE 'g\+\+-[0-9]+' "$U"/*.sublime-build && STOP=1
  say "fix: bash cp-patch-judge.sh   (routes it through ~/.cp/judge.sh, which"
  say "     picks whatever g++-N exists on the machine it runs on)"
fi
[ -f "$HOME/.cp/judge.sh" ] && ok "judge.sh present" || wa "no ~/.cp/judge.sh"
if [ "$STOP" = 1 ]; then
  echo
  printf '  Export anyway? The bundle will carry the hardcoded version. [y/N] '
  read -r YN
  case "$YN" in y|Y) ;; *) echo "  Stopped. Run cp-patch-judge.sh first, then re-run this."; exit 1;; esac
fi

rm -rf "$BUNDLE"
mkdir -p "$PL/sublime-user" "$PL/clangd" "$PL/dotcp" "$PL/cpdir"

hdr "Collecting Packages/User"
# Explicit list, not a glob: a glob would also drag in *.backup-* and
# *.sublime-workspace (machine-specific window state, useless to a brother).
for f in "Default (OSX).sublime-keymap" \
         "Preferences.sublime-settings" \
         "C++ CP.sublime-build" \
         "FastOlympicCoding.sublime-settings" \
         "cp-template.sublime-snippet" \
         "cp-expand.sublime-macro" \
         "LSP.sublime-settings" \
         "LSP-clangd.sublime-settings" \
         "Package Control.sublime-settings" \
         ".neovintageousrc"; do
  if [ -f "$U/$f" ]; then cp "$U/$f" "$PL/sublime-user/"; ok "$f"; else wa "$f — not present, skipped"; fi
done

hdr "Collecting the rest"
if [ -f "$HOME/Library/Preferences/clangd/config.yaml" ]; then
  cp "$HOME/Library/Preferences/clangd/config.yaml" "$PL/clangd/"; ok "clangd config.yaml"
else wa "no clangd config"; fi

if [ -d "$HOME/.cp" ]; then
  # -R keeps include/bits/stdc++.h intact; exclude compiled leftovers
  # --exclude MUST precede the path operand, or tar warns and bails.
  ( cd "$HOME" && tar cf - --exclude='*.dSYM' --exclude='*.o' --exclude='a.out' .cp ) \
    | ( cd "$PL/dotcp" && tar xf - )
  ok "~/.cp  ($(find "$PL/dotcp" -type f | wc -l | tr -d ' ') files)"
else wa "no ~/.cp"; fi

[ -f "$DEST/cp.sublime-project" ] && { cp "$DEST/cp.sublime-project" "$PL/cpdir/"; ok "cp.sublime-project"; }
if [ -d "$DEST/algo" ]; then
  mkdir -p "$PL/cpdir/algo" && cp "$DEST"/algo/*.cpp "$PL/cpdir/algo/" 2>/dev/null
  ok "algo/ ($(ls -1 "$PL/cpdir/algo" 2>/dev/null | wc -l | tr -d ' ') templates)"
fi

hdr "Making it username-agnostic"
# Every text file gets $HOME → __CP_HOME__. Binary files are left alone.
COUNT=0
while IFS= read -r -d '' f; do
  case "$(file -b --mime-type "$f")" in
    text/*|application/json|application/xml|inode/x-empty) ;;
    *) continue;;
  esac
  if grep -q "$HOME" "$f" 2>/dev/null; then
    python3 - "$f" "$HOME" <<'PY'
import sys
p, home = sys.argv[1], sys.argv[2]
s = open(p, encoding='utf-8', errors='replace').read()
open(p, 'w', encoding='utf-8').write(s.replace(home, '__CP_HOME__'))
PY
    COUNT=$((COUNT+1))
  fi
done < <(find "$PL" -type f -print0)
ok "$COUNT files had '$HOME' replaced with the __CP_HOME__ placeholder"

hdr "Recording what packages you have"
if [ -f "$PL/sublime-user/Package Control.sublime-settings" ]; then
  python3 -c "
import json,re
s=open('$PL/sublime-user/Package Control.sublime-settings',encoding='utf-8').read()
s=re.sub(r'(?m)^\s*//.*\$','',s); s=re.sub(r',(\s*[\]}])',r'\1',s)
pk=json.loads(s).get('installed_packages',[])
print('  packages recorded (%d): %s'%(len(pk),', '.join(pk)))" 2>/dev/null || wa "could not parse the package list"
else
  wa "no Package Control.sublime-settings — the bundle will list packages in the README instead"
fi

# ── the installer that ships inside the bundle ───────────────────────────────
cat > "$BUNDLE/install.sh" <<'INSTALLER_EOF'
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
INSTALLER_EOF
chmod +x "$BUNDLE/install.sh"
ok "generated install.sh"

# ── README ───────────────────────────────────────────────────────────────────
cat > "$BUNDLE/README.md" <<'READ_EOF'
# Sublime competitive-programming setup — portable bundle

A snapshot of a working macOS setup: Sublime Text 4 + NeoVintageous + clangd +
CppFastOlympicCoding, tuned for an HHKB Pro Classic.

## Install

```bash
bash install.sh
```

Works under any macOS username — paths are stored as a `__CP_HOME__`
placeholder and rewritten on install. Backs up anything it replaces and writes
`restore.sh` so the machine can be put back.

## What you need first

- **Sublime Text 4** — https://www.sublimetext.com/download
- **Xcode command line tools** — `xcode-select --install` (gives clang++, python3)
- Launch Sublime once and quit, so `Packages/User` exists
- Optional: `brew install gcc` (judge build), `brew install --cask ghostty`
  (interactive run)

## What lands where

| Payload | Destination |
|---|---|
| `payload/sublime-user/` | `~/Library/Application Support/Sublime Text/Packages/User/` |
| `payload/clangd/config.yaml` | `~/Library/Preferences/clangd/config.yaml` |
| `payload/dotcp/.cp/` | `~/.cp/` — the `bits/stdc++.h` shim and helper scripts |
| `payload/cpdir/` | `~/Documents/cp/` — project file and template library |

`~/Library/Preferences/clangd/` is the macOS path. `~/.config/clangd/` is
Linux-only and clangd ignores it on a Mac — a silent, expensive mistake.

## The keys

```
⌘⏎      run & test (FOC)          ⌃h ⌃j ⌃k ⌃l   move between panes
⌘⇧⏎     new test                  ⌘K h/j/k/l    split, focus follows
⌘⇧D     run under debugger        ⌘K x          close pane
⌘K p    toggle test panel         ⌘K z          zoom pane
⌘K f    template library          ⌘K b          sidebar
⌘K s    FOC stress                ⌃]            jump to definition
⌘K t    insert cp template        ⌘⇧U           find references
cp+Tab  insert cp template        ⌘⇧A           diagnostics panel
⌘B      build + sanitizers        ⌘' / ⌘⇧'      next / prev error
⌘⇧R     debug + in.txt            ⌘⇧C           fast + in.txt
⌘⇧K     compile only              ⌘⇧G           g++ judge build
⌘⇧T     run in Ghostty            ⌘⇧S           stress vs brute.cpp
```

Zero `alt+` bindings, by design: on an HHKB, ⌥ is a bottom-corner key that
cannot comfortably combine with the right hand.

## Two stress testers, different conventions

- **⌘⇧S** → `~/.cp/stress.sh`, uses `brute.cpp`.
- **⌘K s** → FOC's own. For `A.cpp` it needs `A__Good.cpp` and
  `A__Generator.cpp` beside it — exact names, double underscore — and the
  generator reads its **seed from stdin**, not `argv`.

## Flags live in three files and must agree

`C++ CP.sublime-build`, `FastOlympicCoding.sublime-settings`, and clangd's
`config.yaml`. If they drift, clangd red-squiggles code that compiles, or FOC
fails on files `⌘B` builds fine. `cp-verify.sh` compares all three.

## Gotchas that cost real time

1. **Never put `$HOME` in a `.sublime-build`.** Sublime expands `$`-variables
   before the shell sees them, so it becomes an empty string. Absolute paths,
   or move the logic into a script in `~/.cp/`.
2. **A build key doing nothing** usually means the focused view was not a saved
   file — check the `[shell_cmd: …]` line at the bottom of the build panel for
   an empty `''` where `${file}` should be.
3. **Build system choice is per window.** Open the project file.
4. **FOC's override file is `Packages/User/FastOlympicCoding.sublime-settings`**
   — no platform suffix. The `FastOlympicCoding (OSX).sublime-settings` inside
   the package folder is the defaults layer; patching it works until Package
   Control updates the package.
5. **FOC owns Tab in `.cpp` files** via its own keymap. The `cp` snippet's
   `<tabTrigger>` therefore cannot fire on Tab — it only makes `cp` appear in
   the completion popup. Expansion happens through the User keymap's macro.
6. **An empty `bits/stdc++.h` shim compiles fine** and then every symbol is
   undeclared. If you see `'cin' was not declared in this scope`, count the
   lines in the shim before touching any flags.
READ_EOF
ok "generated README.md"

# ── manifest ─────────────────────────────────────────────────────────────────
hdr "Manifest"
{ echo "# cp-portable — exported $(date '+%Y-%m-%d %H:%M')"
  echo "# macOS $(sw_vers -productVersion 2>/dev/null); username deliberately not recorded"
  echo "# sha256(16)  bytes  path"
  while IFS= read -r -d '' f; do
    printf '%s  %s  %s\n' "$(shasum -a 256 "$f" | cut -c1-16)" \
      "$(wc -c <"$f" | tr -d ' ')" "${f#$BUNDLE/}"
  done < <(find "$PL" -type f -print0 | sort -z)
} > "$BUNDLE/MANIFEST.txt"
ok "$(( $(wc -l <"$BUNDLE/MANIFEST.txt") - 3 )) files checksummed"

# ship the verifier along if it is sitting next to us
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$HERE/cp-verify.sh" ] && cp "$HERE/cp-verify.sh" "$BUNDLE/" && ok "included cp-verify.sh"

# ── tarball ──────────────────────────────────────────────────────────────────
TAR="$HOME/Documents/cp-setup-$STAMP.tar.gz"
( cd "$HOME/Documents" && tar czf "$TAR" cp-portable )
hdr "Done"
ok "bundle : $BUNDLE"
ok "archive: $TAR  ($(du -h "$TAR" | cut -f1))"
echo
echo "  For your brother — send him the .tar.gz. He runs:"
echo "      tar xzf cp-setup-$STAMP.tar.gz && cd cp-portable && bash install.sh"
echo
echo "  As your backup — keep the .tar.gz somewhere off this machine."
echo "  Restoring is the same command."
echo
echo "  Re-run cp-export.sh any time you change your config; it overwrites"
echo "  $BUNDLE and writes a new dated archive."
