#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════════
#  sublime/install.sh — Sublime Text + the competitive-programming setup.
#
#  The main installer runs this for you:   ~/dotfiles/install.sh sublime
#  It also works on its own:
#
#      bash install.sh          install Sublime Text and put the settings in place
#      bash install.sh check    change nothing; report what is in place
#
#  Safe to re-run. Settings are COPIED, not symlinked (Sublime and Package
#  Control rewrite their own files, and two files need your home folder
#  written into them). So: edit the files in payload/, then re-run this.
#  Every file it replaces is copied to ~/Documents/cp-backups/ first, with a
#  restore.sh that puts it back.
# ═════════════════════════════════════════════════════════════════════════════
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PL="$HERE/payload"
ST="$HOME/.config/sublime-text"
U="$ST/Packages/User"
IP="$ST/Installed Packages"

# Where your competitive-programming repo lives. First match wins:
#   1. CP_ROOT=/some/path bash install.sh      (say so yourself)
#   2. a folder called competitive-programming in ~/Documents or ~
#   3. one anywhere up to three levels below your home folder
#   4. ~/Documents/cp                          (created if nothing else exists)
find_cp_root() {
  local d
  if [ -n "${CP_ROOT:-}" ]; then printf '%s' "${CP_ROOT%/}"; return; fi
  for d in "$HOME/Documents/competitive-programming" "$HOME/competitive-programming"; do
    [ -d "$d" ] && { printf '%s' "$d"; return; }
  done
  d="$(find "$HOME" -maxdepth 3 -type d -name competitive-programming -not -path '*/.*' 2>/dev/null | sort | head -1)"
  [ -n "$d" ] && { printf '%s' "$d"; return; }
  printf '%s' "$HOME/Documents/cp"
}
DEST="$(find_cp_root)"
CLANGD="$HOME/.config/clangd/config.yaml"
STAMP=$(date +%Y%m%d-%H%M%S)
VAULT="$HOME/Documents/cp-backups/pre-install-$STAMP"
PC_URL="https://github.com/wbond/package_control/releases/latest/download/Package.Control.sublime-package"
MODE="${1:-install}"

ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
no()  { printf '  \033[31m✗\033[0m %s\n' "$1"; }
wa()  { printf '  \033[33m!\033[0m %s\n' "$1"; }
hdr() { printf '\n\033[1m── %s\033[0m\n' "$1"; }

fetch() { # url outfile
  if command -v curl >/dev/null 2>&1; then curl -fsSL --retry 2 -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then wget -q -O "$2" "$1"
  else return 127; fi
}

# ─────────────────────────────────────────────────────────────────────────────
#  Checks shared by `install` and `check`
# ─────────────────────────────────────────────────────────────────────────────

# Every settings file parses, every key that names a build variant names one
# that exists, and the three files that hold compiler flags agree on -std.
validate() {
  python3 - "$U" "$DEST" "$CLANGD" <<'PY'
import glob, json, os, re, sys
U, DEST, CLANGD = sys.argv[1:4]
G, R, Y, Z = '\033[32m', '\033[31m', '\033[33m', '\033[0m'
bad = 0

def load(path):
    s = open(path, encoding='utf-8').read()
    s = re.sub(r'(?m)^\s*//.*$', '', s)          # whole-line comments
    s = re.sub(r',(\s*[\]}])', r'\1', s)         # trailing commas
    return json.loads(s)

files = []
for pat in ('*.sublime-keymap', '*.sublime-settings', '*.sublime-build', '*.sublime-macro', '*.sublime-commands'):
    files += glob.glob(os.path.join(U, pat))
files += glob.glob(os.path.join(DEST, '*.sublime-project'))
data = {}
for p in sorted(files):
    name = os.path.basename(p)
    try:
        data[name] = load(p)
        print('  %s✓%s %s' % (G, Z, name))
    except Exception as e:
        print('  %s✗%s %s: %s' % (R, Z, name, e)); bad += 1

build = data.get('C++ CP.sublime-build')
keymap = data.get('Default (Linux).sublime-keymap')
if build and keymap:
    names = {v['name'] for v in build.get('variants', [])}
    wanted = {e['args']['variant'] for e in keymap
              if e.get('command') == 'build' and 'variant' in e.get('args', {})}
    rc = os.path.join(U, '.neovintageousrc')
    if os.path.isfile(rc):
        wanted |= set(re.findall(r':Build variant=(\S+?)<CR>', open(rc, encoding='utf-8').read()))
    missing = wanted - names
    if missing:
        print('  %s✗%s keys point at build variants that do not exist: %s' % (R, Z, sorted(missing))); bad += 1
    else:
        print('  %s✓%s every build key (Ctrl and leader) names a variant in C++ CP.sublime-build' % (G, Z))

stds = {}
if build:
    stds['C++ CP.sublime-build'] = set(re.findall(r'-std=[\w+]+', json.dumps(build)))
foc = data.get('FastOlympicCoding.sublime-settings')
if foc:
    cpp = [r for r in foc.get('run_settings', []) if r.get('name') == 'C++']
    stds['FastOlympicCoding.sublime-settings'] = set(re.findall(r'-std=[\w+]+', json.dumps(cpp)))
if os.path.isfile(CLANGD):
    stds['clangd/config.yaml'] = set(re.findall(r'-std=[\w+]+', open(CLANGD, encoding='utf-8').read()))
flat = set().union(*stds.values()) if stds else set()
if len(stds) == 3 and len(flat) == 1:
    print('  %s✓%s build file, FOC and clangd all use %s' % (G, Z, flat.pop()))
elif stds:
    print('  %s✗%s the C++ standard differs between files: %s' % (R, Z, {k: sorted(v) for k, v in stds.items()})); bad += 1

plugin = os.path.join(U, 'cp_companion.py')
if os.path.isfile(plugin):
    try:
        compile(open(plugin, encoding='utf-8').read(), plugin, 'exec')
        print('  %s✓%s cp_companion.py' % (G, Z))
    except SyntaxError as e:
        print('  %s✗%s cp_companion.py: %s' % (R, Z, e)); bad += 1

left = []
for root in (U, os.path.expanduser('~/.cp')):
    for p in glob.glob(os.path.join(root, '*')):
        if os.path.isfile(p):
            try:
                text = open(p, encoding='utf-8', errors='replace').read()
                if '__CP_HOME__' in text or '__CP_ROOT__' in text:
                    left.append(p)
            except OSError:
                pass
if left:
    print('  %s✗%s placeholder paths left in: %s' % (R, Z, left)); bad += 1
sys.exit(1 if bad else 0)
PY
}

# Compile the template with the real Ctrl+B command and run it once.
smoke_test() {
  local tmp cmd
  tmp="$(mktemp -d)" || return 1
  cp "$PL/cpdir/algo/cp.cpp" "$tmp/smoke.cpp"
  cmd="$(python3 - "$U/C++ CP.sublime-build" "$tmp" <<'PY'
import json, re, sys
s = open(sys.argv[1], encoding='utf-8').read()
s = re.sub(r'(?m)^\s*//.*$', '', s); s = re.sub(r',(\s*[\]}])', r'\1', s)
c = json.loads(s)['shell_cmd']
d = sys.argv[2]
print(c.replace('${file_path}', d).replace('${file_base_name}', 'smoke').replace('${file}', d + '/smoke.cpp'))
PY
)" || { rm -rf "$tmp"; return 1; }
  if ( cd "$tmp" && bash -c "$cmd" </dev/null >"$tmp/out.txt" 2>&1 ); then
    ok "Ctrl+B build works: g++ $(g++ -dumpversion), sanitizers on, template compiles and runs"
    rm -rf "$tmp"; return 0
  fi
  no "the Ctrl+B build command failed:"
  sed 's/^/      /' "$tmp/out.txt" | head -15
  rm -rf "$tmp"; return 1
}

# ─────────────────────────────────────────────────────────────────────────────
#  bash install.sh check
# ─────────────────────────────────────────────────────────────────────────────
if [ "$MODE" = check ]; then
  BAD=0
  hdr "Programs"
  if command -v subl >/dev/null 2>&1; then ok "Sublime Text — $(subl --version 2>/dev/null)"; else no "Sublime Text is not installed"; BAD=1; fi
  for c in g++ clangd python3; do
    if command -v "$c" >/dev/null 2>&1; then ok "$c"; else no "$c is missing"; BAD=1; fi
  done
  if [ -f "$IP/Package Control.sublime-package" ] || [ -d "$ST/Packages/Package Control" ]; then ok "Package Control"; else no "Package Control is missing"; BAD=1; fi
  hdr "Settings"
  if [ -d "$U" ] && [ -f "$U/Default (Linux).sublime-keymap" ]; then
    validate || BAD=1
    # Installed copies that differ from the repo: either you edited them in
    # Sublime, or the repo moved on and this machine has not re-run install.
    HOME_ESC="$(printf '%s' "$HOME" | sed 's/[&|\\]/\\&/g')"
    ROOT_ESC="$(printf '%s' "$DEST" | sed 's/[&|\\]/\\&/g')"
    DRIFT=""
    while IFS= read -r -d '' f; do
      n="$(basename "$f")"
      [ "$n" = "Package Control.sublime-settings" ] && continue   # Package Control rewrites it
      sed -e "s|__CP_ROOT__|$ROOT_ESC|g" -e "s|__CP_HOME__|$HOME_ESC|g" "$f" | cmp -s - "$U/$n" || DRIFT="$DRIFT $n"
    done < <(find "$PL/sublime-user" -maxdepth 1 -type f -print0)
    if [ -n "$DRIFT" ]; then wa "differ from the repo:$DRIFT  (re-run install to reset them)"; else ok "installed settings match the repo"; fi
  else
    no "settings are not installed yet — run: bash install.sh"; BAD=1
  fi
  hdr "Build"
  if [ -f "$U/C++ CP.sublime-build" ] && command -v g++ >/dev/null 2>&1; then smoke_test || BAD=1; else no "nothing to test yet"; BAD=1; fi
  exit "$BAD"
fi

if [ "$MODE" != install ]; then
  echo "usage: bash install.sh [check]"; exit 2
fi

# ─────────────────────────────────────────────────────────────────────────────
#  bash install.sh
# ─────────────────────────────────────────────────────────────────────────────
[ -d "$PL" ] || { no "no payload/ folder next to this script — unpack the whole bundle"; exit 1; }
[ "$(id -u)" != 0 ] || { no "run this as yourself, not with sudo — it asks for sudo when it needs it"; exit 1; }
if pgrep -x sublime_text >/dev/null 2>&1; then
  no "Sublime Text is open. Quit it (all windows), then run this again."; exit 1
fi

hdr "1  Sublime Text"
if command -v subl >/dev/null 2>&1; then
  ok "already installed — $(subl --version 2>/dev/null)"
else
  echo "  installing from Sublime's own apt repository (asks for your password)"
  KEY="$(mktemp)"
  if ! fetch https://download.sublimetext.com/sublimehq-pub.gpg "$KEY" || ! grep -q 'BEGIN PGP PUBLIC KEY BLOCK' "$KEY"; then
    rm -f "$KEY"; no "could not download Sublime's signing key — check the internet connection and re-run"; exit 1
  fi
  sudo install -d -m 0755 /etc/apt/keyrings \
    && sudo install -m 0644 "$KEY" /etc/apt/keyrings/sublimehq-pub.asc \
    && printf 'Types: deb\nURIs: https://download.sublimetext.com/\nSuites: apt/stable/\nSigned-By: /etc/apt/keyrings/sublimehq-pub.asc\n' \
         | sudo tee /etc/apt/sources.list.d/sublime-text.sources >/dev/null \
    && sudo apt-get update -qq \
    && sudo apt-get install -y sublime-text
  RC=$?; rm -f "$KEY"
  if [ "$RC" != 0 ] || ! command -v subl >/dev/null 2>&1; then
    no "Sublime Text did not install — the lines above say why"; exit 1
  fi
  ok "installed — $(subl --version 2>/dev/null)"
fi

hdr "2  Compiler and language server"
NEED=()
command -v g++     >/dev/null 2>&1 || NEED+=(build-essential)
command -v clangd  >/dev/null 2>&1 || NEED+=(clangd)
command -v python3 >/dev/null 2>&1 || NEED+=(python3)
if [ "${#NEED[@]}" -gt 0 ]; then
  echo "  installing: ${NEED[*]}"
  sudo apt-get install -y "${NEED[@]}" || { no "apt could not install ${NEED[*]}"; exit 1; }
fi
CLV="$(clangd --version 2>/dev/null | grep -o 'version [0-9.]*' | head -1 | cut -d' ' -f2)"
ok "g++ $(g++ -dumpversion), clangd ${CLV:-?}, python3"

hdr "3  Package Control"
mkdir -p "$U" "$IP"
if [ -f "$IP/Package Control.sublime-package" ] || [ -d "$ST/Packages/Package Control" ]; then
  ok "already there"
else
  TMP="$(mktemp)"
  if fetch "$PC_URL" "$TMP" && [ "$(head -c 2 "$TMP")" = "PK" ]; then
    mv "$TMP" "$IP/Package Control.sublime-package"
    ok "downloaded — it installs your packages the first time Sublime starts"
  else
    rm -f "$TMP"
    wa "could not download Package Control. After this script, in Sublime:"
    echo "      Tools → Install Package Control…, then restart Sublime."
  fi
fi

hdr "4  Settings"
ok "competitive-programming folder: $DEST"
# put <src> <dst>: write src to dst with __CP_HOME__ replaced by your home
# folder and __CP_ROOT__ by your competitive-programming folder.
# folder. If dst exists with different content, it is backed up first.
HOME_ESC="$(printf '%s' "$HOME" | sed 's/[&|\\]/\\&/g')"
ROOT_ESC="$(printf '%s' "$DEST" | sed 's/[&|\\]/\\&/g')"
BACKED=0; WROTE=0; SAME=0
put() {
  local src="$1" dst="$2" tmp
  tmp="$(mktemp)"
  sed -e "s|__CP_ROOT__|$ROOT_ESC|g" -e "s|__CP_HOME__|$HOME_ESC|g" "$src" > "$tmp"
  if [ -f "$dst" ] && cmp -s "$tmp" "$dst"; then
    rm -f "$tmp"; SAME=$((SAME + 1)); return 0
  fi
  if [ -f "$dst" ]; then
    local rel="${dst#"$HOME"/}"
    mkdir -p "$VAULT/$(dirname "$rel")"
    cp -p "$dst" "$VAULT/$rel"
    if [ ! -f "$VAULT/restore.sh" ]; then
      # shellcheck disable=SC2016
      printf '#!/usr/bin/env bash\n# Puts back the files install.sh replaced on %s.\nV="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n' "$STAMP" > "$VAULT/restore.sh"
      chmod +x "$VAULT/restore.sh"
    fi
    # shellcheck disable=SC2016  # $V and $HOME are for restore.sh to expand
    printf 'cp -p "$V/%s" "$HOME/%s"\n' "$rel" "$rel" >> "$VAULT/restore.sh"
    BACKED=$((BACKED + 1))
  fi
  mkdir -p "$(dirname "$dst")"
  chmod 644 "$tmp"
  mv "$tmp" "$dst"
  WROTE=$((WROTE + 1))
}

while IFS= read -r -d '' f; do
  put "$f" "$U/$(basename "$f")"
done < <(find "$PL/sublime-user" -maxdepth 1 -type f -print0)
ok "Sublime settings → $U"

put "$PL/clangd/config.yaml" "$CLANGD"
ok "clangd flags     → $CLANGD"

for f in "$PL"/dotcp/.cp/*.sh; do
  put "$f" "$HOME/.cp/$(basename "$f")"
  chmod +x "$HOME/.cp/$(basename "$f")"
done
ok "helper scripts   → ~/.cp"

put "$PL/cpdir/cp.sublime-project" "$DEST/cp.sublime-project"
mkdir -p "$DEST/algo"
if [ -f "$DEST/algo/cp.cpp" ]; then
  ok "project file     → $DEST   (your algo/cp.cpp was already there and is left alone)"
else
  cp "$PL/cpdir/algo/cp.cpp" "$DEST/algo/cp.cpp"
  ok "project + template → $DEST"
fi

if [ "$DEST" != "$HOME/Documents/cp" ] && [ -d "$HOME/Documents/cp" ]; then
  # shellcheck disable=SC2088  # display text
  wa "~/Documents/cp is no longer used. Move anything you want out of it, then delete it."
fi
echo "  $WROTE files written, $SAME already up to date"
if [ "$BACKED" -gt 0 ]; then
  wa "$BACKED files you already had were replaced. Originals: $VAULT"
  echo "      Undo: bash \"$VAULT/restore.sh\""
fi

hdr "5  Checking the result"
FAIL=0
validate || FAIL=1
smoke_test || FAIL=1

hdr "DONE"
if [ "$FAIL" = 1 ]; then
  wa "Installed, but something above is marked ✗. Send me that part."
fi
cat <<EOT
  Now, in this order:

    1. Open Sublime Text. It may complain once that the Monokai Pro theme is
       missing — that is expected. Package Control installs your 11 packages
       in the background; watch the status bar at the bottom. Give it two
       minutes, then quit Sublime and open it again.  (Super+E opens it.)
    2. Project → Open Project… → $DEST/cp.sublime-project
    3. Tools → Build System → C++ CP
    4. New file, save it as a.cpp, type  cp  then Tab — the template appears.
    5. Ctrl+Enter — it compiles and the test panel opens on the right.
    6. In the browser, add the Competitive Companion extension. Clicking its
       green plus on a problem creates the folder in $DEST
       and opens the file here.

  Check again any time: bash "$HERE/install.sh" check
EOT
