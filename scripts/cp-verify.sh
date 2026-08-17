#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════════
#  cp-verify.sh — READ-ONLY. Changes nothing. Replaces cp-doctor.sh,
#  cp-doctor2.sh and cp-go.sh's checking half.
#
#      bash cp-verify.sh
#
#  Everything it cannot test from a shell (keybindings, the Vim layer) is
#  listed at the end as a short manual pass.
# ═════════════════════════════════════════════════════════════════════════════
set -u

ST="$HOME/Library/Application Support/Sublime Text"
U="$ST/Packages/User"
P="$ST/Packages"
DEST="$HOME/Documents/cp"
SCRATCH="$(mktemp -d)"; trap 'rm -rf "$SCRATCH"' EXIT

PASS=0; FAIL=0; WARN=0
hdr(){ printf '\n\033[1;44m %s \033[0m\n' "$1"; }
ok(){  printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
no(){  printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
wa(){  printf '  \033[33m!\033[0m %s\n' "$1"; WARN=$((WARN+1)); }
say(){ printf '      %s\n' "$1"; }

hdr "1  Sublime data dir"
n=0
for d in "$ST" "$HOME/Library/Application Support/Sublime Text 3"; do
  [ -d "$d/Packages/User" ] && { n=$((n+1)); say "$d"; }
done
[ "$n" = 1 ] && ok "exactly one data dir" || { [ "$n" = 0 ] && { no "none found"; exit 1; } || wa "$n data dirs — ST4 uses the unnumbered one"; }

hdr "2  Packages/User contents"
python3 - "$U" "$DEST" <<'PY'
import sys, os, re, json, glob
U, DEST = sys.argv[1], sys.argv[2]
G='\033[32m✓\033[0m'; R='\033[31m✗\033[0m'; Y='\033[33m!\033[0m'
def jload(p):
    s=open(p,encoding='utf-8',errors='replace').read()
    s=re.sub(r'(?m)^\s*//.*$','',s); s=re.sub(r',(\s*[\]}])',r'\1',s)
    return json.loads(s)

# keymap
km=os.path.join(U,'Default (OSX).sublime-keymap')
kvariants=set()
if not os.path.isfile(km):
    print("  %s MISSING Default (OSX).sublime-keymap"%R)
else:
    try:
        d=jload(km)
        print("  %s keymap parses, %d bindings"%(G,len(d)))
        from collections import Counter
        for k,c in Counter(tuple(b['keys']) for b in d).items():
            if c>1 and k not in (('super+enter',),('escape',),('tab',)):
                print("  %s %s bound %d times"%(Y,'+'.join(k),c))
        kvariants={b['args']['variant'] for b in d if b.get('command')=='build' and 'variant' in b.get('args',{})}
        tabs=[b for b in d if b['keys']==['tab']]
        print("  %s %d tab binding(s) in User: %s"%(G if tabs else R,len(tabs),[b['command'] for b in tabs]))
        if any('alt+' in x for b in d for x in b['keys']):
            print("  %s an alt+ binding exists (rule 3 says none)"%Y)
    except Exception as e:
        print("  %s keymap INVALID JSON — Sublime drops the whole file: %s"%(R,e))

# build file
bfs=glob.glob(os.path.join(U,'*.sublime-build'))
if not bfs:
    print("  %s no .sublime-build"%R)
for bf in bfs:
    try:
        d=jload(bf)
        names={v.get('name') for v in d.get('variants',[])}
        print("  %s %s parses, %d variants"%(G,os.path.basename(bf),len(names)))
        missing=kvariants-names
        if missing:
            print("  %s keymap asks for variants that do not exist: %s"%(R,sorted(missing)))
        elif kvariants:
            print("  %s all %d keymap variants exist here"%(G,len(kvariants)))
        for v in d.get('variants',[]):
            if 'judge' in str(v.get('shell_cmd','')):
                print("      judge variant → %s"%v['shell_cmd'])
    except Exception as e:
        print("  %s %s INVALID: %s"%(R,os.path.basename(bf),e))

# FOC settings
fs=os.path.join(U,'FastOlympicCoding.sublime-settings')
if not os.path.isfile(fs):
    print("  %s MISSING FastOlympicCoding.sublime-settings (FOC on shipped defaults)"%R)
else:
    try:
        d=jload(fs)
        ab=d.get('algorithms_base')
        print("  %s FOC settings parse"%G)
        if not ab: print("  %s algorithms_base is null → cp+Tab via FOC cannot work"%R)
        elif not os.path.isdir(ab): print("  %s algorithms_base does not exist: %s"%(R,ab))
        else:
            n=len(glob.glob(os.path.join(ab,'*.cpp')))
            print("  %s algorithms_base %s (%d .cpp templates)"%(G,ab,n))
            print("      %s cp.cpp present"%(G if os.path.isfile(os.path.join(ab,'cp.cpp')) else R))
        cc=[r for r in d.get('run_settings',[]) if r.get('name')=='C++']
        if cc:
            cmd=cc[0].get('compile_cmd','')
            print("      %s -o present in compile_cmd"%(G if ' -o ' in cmd else R))
            print("      %s shim -I present"%(G if '.cp/include' in cmd else R))
    except Exception as e:
        print("  %s FOC settings INVALID: %s"%(R,e))

# snippet
sn=os.path.join(U,'cp-template.sublime-snippet')
if not os.path.isfile(sn):
    print("  %s MISSING cp-template.sublime-snippet → ⌘K t dead"%R)
else:
    s=open(sn,encoding='utf-8').read()
    import xml.etree.ElementTree as ET
    try:
        r=ET.fromstring(s); tags={c.tag for c in r}
        print("  %s snippet is well-formed XML"%G)
        print("      %s <tabTrigger> — without it, cp never shows in IntelliSense"%(G if 'tabTrigger' in tags else R))
        print("      %s <scope>"%(G if 'scope' in tags else R))
        print("      %s $0 caret placeholder"%(G if '$0' in s else Y))
    except Exception as e:
        print("  %s snippet malformed: %s"%(R,e))

# macro
mc=os.path.join(U,'cp-expand.sublime-macro')
if not os.path.isfile(mc):
    print("  %s MISSING cp-expand.sublime-macro → the plugin-free cp+Tab path"%R)
else:
    try:
        d=json.load(open(mc,encoding='utf-8'))
        cmds=[c['command'] for c in d]
        print("  %s macro parses: %s"%(G,' → '.join(cmds)))
        ref=[c for c in d if c['command']=='insert_snippet']
        if ref:
            nm=ref[0]['args']['name'].replace('Packages/User/','')
            print("      %s references %s"%(G if os.path.isfile(os.path.join(U,nm)) else R,nm))
    except Exception as e:
        print("  %s macro INVALID: %s"%(R,e))

# vimrc
rc=os.path.join(U,'.neovintageousrc')
if os.path.isfile(rc):
    body=[l for l in open(rc,encoding='utf-8',errors='replace') if l.strip()]
    lead=[l.strip() for l in body if 'mapleader' in l]
    print("  %s .neovintageousrc, %d non-blank lines%s"%(G,len(body),'  '+lead[0] if lead else ''))
else:
    print("  %s no .neovintageousrc (leading dot required)"%R)

# project
pj=os.path.join(DEST,'cp.sublime-project')
if os.path.isfile(pj):
    try:
        jload(pj); print("  %s cp.sublime-project parses"%G)
    except Exception as e:
        print("  %s cp.sublime-project INVALID: %s"%(R,e))
else:
    print("  %s no %s → 'No build system' will recur"%(R,pj))
PY

hdr "3  Who owns Tab in a .cpp"
python3 - "$P" <<'PY'
import sys, os, re, json, glob
pkgs=sys.argv[1]; rows=[]
for p in sorted(glob.glob(os.path.join(pkgs,'*','*.sublime-keymap'))):
    if os.path.basename(p) not in ('Default.sublime-keymap','Default (OSX).sublime-keymap'): continue
    s=open(p,encoding='utf-8',errors='replace').read()
    s=re.sub(r'(?m)^\s*//.*$','',s); s=re.sub(r',(\s*[\]}])',r'\1',s)
    try: d=json.loads(s)
    except Exception: continue
    for b in d:
        if 'tab' in [k.lower() for k in b.get('keys',[])]:
            rows.append((os.path.basename(os.path.dirname(p)),b.get('command')))
for pkg,cmd in rows: print("      %-26s %s"%(pkg,cmd))
print("      ── load order is Default → packages A-Z → User; LAST match wins.")
if rows and rows[-1][0]=='User': print("  \033[32m✓\033[0m User has the final say on Tab")
else: print("  \033[31m✗\033[0m User does not own Tab — cp+Tab is at the mercy of a package")
PY

hdr "4  ~/.cp helpers"
SH="$HOME/.cp/include/bits/stdc++.h"
if [ -f "$SH" ]; then
  L=$(grep -c '#include' "$SH" 2>/dev/null || echo 0)
  [ "$L" -ge 20 ] && ok "bits/stdc++.h shim, $L includes" || no "shim is a stub ($L includes) — compiles but declares nothing"
else no "no shim at $SH"; fi
for s in run-term.sh stress.sh judge.sh; do
  if [ -f "$HOME/.cp/$s" ]; then
    [ -x "$HOME/.cp/$s" ] && ok "$s (executable)" || wa "$s present but not executable — chmod +x"
  else no "$s missing"; fi
done

hdr "5  Compilers"
command -v clang++ >/dev/null && ok "clang++ $(clang++ --version | head -1 | sed 's/.*version //;s/ .*//')" || no "no clang++"
GXX=""
for d in /opt/homebrew/bin /usr/local/bin; do
  c=$(ls "$d"/g++-[0-9]* 2>/dev/null | sort -V | tail -1); [ -n "$c" ] && GXX="$c"
done
[ -n "$GXX" ] && ok "real GCC: $GXX ($("$GXX" -dumpversion 2>/dev/null))" || wa "no g++-N — ⌘⇧G unavailable until: brew install gcc"

hdr "6  Flags agree in all three places"
# Comment lines are stripped first — the FOC settings file mentions the OLD
# -std=gnu++11 in a comment explaining what changed, and a naive grep reads
# that as a live flag.
STDS=$(python3 - "$U" "$HOME/Library/Preferences/clangd/config.yaml" <<'PY'
import sys, os, re, json, glob
U, cc = sys.argv[1], sys.argv[2]
def strip(s):
    s = re.sub(r'(?m)^\s*//.*$', '', s)        # sublime-json comments
    s = re.sub(r'(?m)^\s*#.*$',  '', s)        # yaml comments
    return s
def stds(path):
    if not os.path.isfile(path): return set()
    return set(re.findall(r'-std=[a-z0-9+]+', strip(open(path,encoding='utf-8',errors='replace').read())))
c = stds(cc)
b = set().union(*[stds(p) for p in glob.glob(os.path.join(U,'*.sublime-build'))] or [set()])
f = stds(os.path.join(U,'FastOlympicCoding.sublime-settings'))
print('|'.join(','.join(sorted(x)) or 'none' for x in (c,b,f)))
PY
)
c=${STDS%%|*}; rest=${STDS#*|}; b=${rest%%|*}; f=${rest##*|}
say "clangd : $c"; say "build  : $b"; say "FOC    : $f"
if [ "$c" = "$b" ] && [ "$b" = "$f" ] && [ "$c" != "none" ]; then ok "all three on $c"
else wa "not a single value — reconcile before a contest"; fi

hdr "7  Every build variant, executed for real"
cat > "$SCRATCH/t.cpp" <<'CPP'
#include <bits/stdc++.h>
using namespace std;
int main(){ long long n=0; if(cin>>n) cout<<n*2<<'\n'; else cout<<"no input\n"; return 0; }
CPP
printf '21\n' > "$SCRATCH/in.txt"
python3 - "$U/C++ CP.sublime-build" "$SCRATCH" > "$SCRATCH/cmds" 2>/dev/null <<'PY'
import sys, os, re, json
s=open(sys.argv[1],encoding='utf-8').read(); sc=sys.argv[2]
s=re.sub(r'(?m)^\s*//.*$','',s); s=re.sub(r',(\s*[\]}])',r'\1',s)
d=json.loads(s)
def sub(c):
    for a,b in (('${file_path}',sc),('${file_base_name}','t'),('${file}',os.path.join(sc,'t.cpp')),
                ('$file_path',sc),('$file_base_name','t'),('$file',os.path.join(sc,'t.cpp'))):
        c=c.replace(a,b)
    return c
for v in d.get('variants',[]): print("%s\t%s"%(v['name'],sub(v['shell_cmd'])))
PY
while IFS=$'\t' read -r name cmd; do
  case "$cmd" in *run-term.sh*) wa "$name — opens a terminal, test with ⌘⇧T"; continue;; *stress.sh*) wa "$name — needs brute.cpp, test with ⌘⇧S"; continue;; esac
  out=$( cd "$SCRATCH" && eval "$cmd" 2>&1 ); rc=$?
  if [ $rc -eq 0 ]; then ok "$name"; say "→ $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-80)"
  else no "$name (exit $rc)"; printf '%s\n' "$out" | head -4 | sed 's/^/          /'; fi
done < "$SCRATCH/cmds"

hdr "8  FOC's own compile_cmd"
FC=$(python3 -c "
import re,json
s=open('$U/FastOlympicCoding.sublime-settings',encoding='utf-8').read()
s=re.sub(r'(?m)^\s*//.*\$','',s); s=re.sub(r',(\s*[\]}])',r'\1',s)
[print(r['compile_cmd']) for r in json.loads(s)['run_settings'] if r['name']=='C++']" 2>/dev/null)
if [ -n "$FC" ]; then
  FC=${FC//\{source_file\}/$SCRATCH/t.cpp}; FC=${FC//\{file_name\}/t_foc}; FC=${FC//\{source_file_dir\}/$SCRATCH}
  if ( cd "$SCRATCH" && eval "$FC" ) 2>"$SCRATCH/e"; then
    ok "compiles"; [ -x "$SCRATCH/t_foc" ] && ok "binary produced (-o correct)" || no "no binary — -o missing"
  else no "failed:"; head -4 "$SCRATCH/e" | sed 's/^/          /'
    grep -q "not declared in this scope" "$SCRATCH/e" && say "↑ that means the shim was found but is EMPTY"
  fi
else no "cannot read FOC compile_cmd"; fi

hdr "9  FOC package hygiene"
F="$P/CppFastOlympicCoding"
[ -d "$F" ] && ok "unpacked at CppFastOlympicCoding" || wa "not unpacked (packed .sublime-package is fine)"
ls "$F"/*.bak >/dev/null 2>&1 && wa "a .bak is still in the package folder — cp-cleanup.sh restores it" || ok "no stray .bak in the package"
ls "$U"/*.backup-* >/dev/null 2>&1 && wa "$(ls "$U"/*.backup-* | wc -l | tr -d ' ') backup-* files in Packages/User (harmless, delete when happy)" || ok "no leftover backups"

hdr "SUMMARY"
printf '  \033[32m%d pass\033[0m  \033[31m%d fail\033[0m  \033[33m%d warn\033[0m\n\n' "$PASS" "$FAIL" "$WARN"
cat <<'EOT'
  Manual pass — none of this is testable from a shell:

    Esc Space w        saves                      → Vim layer alive
    type cp, Tab       template expands           → macro path
    type cp, look      "cp" listed in the popup   → tabTrigger
    ⌘K t               template expands           → snippet path
    ⌘⏎                 FOC test panel opens
    ⌘K f               algorithm library panel
    ⌘K s               FOC stress (needs X__Good.cpp + X__Generator.cpp)
    ⌃h ⌃l              pane focus moves
    ⌘K j               new pane below AND focus follows
    ⌃]                 jump to definition
    ⌘⇧K ⌘⇧R ⌘⇧C        builds — from a SAVED .cpp, not a panel
    ⌘⇧G                judge build
    ⌘⇧T                Ghostty, accepts typed input
    ⌘⇧S                stress vs brute.cpp

  If a build key does nothing, check the [shell_cmd: …] line at the bottom
  of the panel. An empty '' where ${file} should be means the focused view
  was not a saved file — that is the commonest false alarm.
EOT
