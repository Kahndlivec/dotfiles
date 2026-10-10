# Sublime Text

Sublime Text 4 + NeoVintageous + clangd + CppFastOlympicCoding. The editor for
competitive programming, C++, scripts and (later) LaTeX. Ubuntu, GNOME, HHKB.

## Install

```bash
~/dotfiles/install.sh sublime     # Sublime Text, Package Control, all settings
~/dotfiles/install.sh check       # includes a Sublime section
```

Safe to re-run. Anything it replaces is copied to `~/Documents/cp-backups/`
first, with a `restore.sh` beside it.

**Settings are copied, not symlinked.** Sublime and Package Control rewrite
their own files, and two files need your home folder written into them. To
change a setting for good: edit the file in `payload/`, run
`~/dotfiles/install.sh sublime`, then `dotsync "…"`.

## What lands where

| Payload | Destination |
|---|---|
| `payload/sublime-user/` | `~/.config/sublime-text/Packages/User/` |
| `payload/clangd/config.yaml` | `~/.config/clangd/config.yaml` |
| `payload/dotcp/.cp/` | `~/.cp/` (judge, stress and run-in-terminal scripts) |
| `payload/cpdir/` | your competitive-programming folder (project file, `algo/` template library) |

The competitive-programming folder is found by the installer: a folder called
`competitive-programming` in `~/Documents` or `~`, otherwise `~/Documents/cp`.
To name it yourself: `CP_ROOT=/path/to/repo ~/dotfiles/install.sh sublime`.

## New problem from the browser

Install the **Competitive Companion** browser extension. On a problem page,
click its green plus. Sublime then has the solution file open, cursor inside
`solve()`, and Ctrl+Enter already shows the samples.

```
<repo>/codeforces/2019/A/A.cpp          your template
<repo>/codeforces/2019/A/A.cpp:tests    the samples, as the test panel reads them
<repo>/codeforces/2019/A/tests/01.in    the same samples as plain files
<repo>/codeforces/2019/A/tests/01.out
<repo>/codeforces/2019/A/in.txt         sample 1, for Ctrl+Shift+R and cprun
```

- It listens whenever Sublime is open; the extension needs no setting.
  `SPC k c` switches it off and on. `curl localhost:10043` says whether it is up.
- Nothing that exists is overwritten. Clicking the plus again just reopens
  the file.
- "Parse contest" in the extension creates every problem and leaves you on
  the first.
- The layout is one line, `"path"`, in `CpCompanion.sublime-settings`
  (`{site}/{contest}/{problem}/{problem}.cpp`). The code is
  `payload/sublime-user/cp_companion.py`.

## Keys: two layers

**Space is the leader**, in normal mode. It is the same map as Neovim and
VS Code (`nvim/init.lua`), which is the Doom Emacs layout: one letter for the
group, one for the action. It lives in `payload/sublime-user/.neovintageousrc`.

```
SPC SPC  find file          SPC ,    switch buffer       SPC e    sidebar
SPC Enter  build and run (FOC test panel)

f  file      ff find    fs save    fS save all    fn new    fp open this config
b  buffer    bb switch  bd close   bo close others   bn / bp next / previous
s  search    sp project   ss symbol in file   sS symbol in project
             sb this buffer   sr replace in project   sd diagnostics
w  window    wv split right   ws split down   wd close pane   wm zoom
             wh wj wk wl move focus   wH wL move file to pane   w= equalise
c  code      cd definition   cR references   cr rename   ca action   cf format
             cc build and run   cC compile only   cs sanitizers   cj judge
             cn new solution (wipe buffer)
t  toggle    tn relative numbers   tw word wrap   ts spelling
q  quit      qq quit   qQ quit, discard
h  help      hr reload the config
k  competitive (Sublime only)
             kp test panel   ks / kS FOC stress start / stop   kf template library
             kc Competitive Companion listener on / off
```

Also on the leader: `SPC d{motion}` deletes without touching the clipboard,
`SPC a` selects the whole buffer, and in visual mode `SPC j` / `SPC k` move the
selected lines.

Not available here, unlike Neovim: `SPC g` (git), the debugger keys, `SPC m`
(harpoon), `SPC w o`. Sublime has no which-key popup, so this list is the
reference.

**Ctrl is for what must work in every mode.** It lives in
`payload/sublime-user/Default (Linux).sublime-keymap`.

```
Ctrl+h/j/k/l    move between panes        Ctrl+Enter      build and run (FOC)
Ctrl+B          build + sanitizers        Ctrl+Shift+R    sanitizers + in.txt
Ctrl+S          save                      Ctrl+Shift+C    -O2 + in.txt, timed
Ctrl+P          find file                 Ctrl+Shift+K    compile only
Ctrl+Shift+P    command palette           Ctrl+Shift+G    judge build
Ctrl+]          jump to definition        Ctrl+Shift+T    run in Ghostty (type input)
Ctrl+O          jump back                 Ctrl+Shift+S    stress vs brute.cpp
Ctrl+Shift+A    diagnostics panel         Ctrl+' / Ctrl+Shift+'   next / prev error
cp + Tab        insert the template
```

Inside the FOC test panel:

```
Ctrl+Enter         new test; again to finish typing it
Ctrl+V             paste the clipboard as test input
Ctrl+X             kill the running program
Ctrl+D             delete the selected test
Ctrl+Shift+Enter   run everything again
```

## Good to know

- **Copy and paste.** `y`, `d` and `p` use the system clipboard. Ctrl+V pastes
  in insert mode. In normal mode Ctrl+C and Ctrl+V are Vim's.
- **Ctrl+B builds**, so Vim's page-up is gone; use Ctrl+U.
- **Stock Sublime shortcuts that start with Ctrl+K are gone**, shadowed by
  "pane up". They are all in the palette.
- **Compiler.** `g++ -std=c++20` everywhere, the same standard as `cprun` /
  `cpjudge` in zsh and the build keys in Neovim.

## Two stress testers, different conventions

- **Ctrl+Shift+S** → `~/.cp/stress.sh`. Needs `brute.cpp` and `gen.cpp` beside
  the solution; the generator takes its seed as `argv[1]`.
- **SPC k s** → FOC's own. For `A.cpp` it needs `A__Good.cpp` and
  `A__Generator.cpp` beside it, and the generator reads its seed from stdin.

## Flags live in three files and must agree

`C++ CP.sublime-build`, `FastOlympicCoding.sublime-settings` and
`clangd/config.yaml`. If they drift, clangd red-squiggles code that compiles.
`~/dotfiles/install.sh check` compares them.

## Gotchas

1. **Never put `$HOME` in a `.sublime-build`.** Sublime expands `$`-variables
   before the shell sees them. Use absolute paths, or a script in `~/.cp/`.
2. **A build key doing nothing** usually means the focused view was not a
   saved file.
3. **Build system choice is per window.** Open the project file
   (`cp.sublime-project` in your competitive-programming folder), then pick
   Tools → Build System → C++ CP once.
4. **Build variant names are one word** (`judge`, `compile`, `debug-in`, …)
   because the leader map cannot pass a name with spaces.
