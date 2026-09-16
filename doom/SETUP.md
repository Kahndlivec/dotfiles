# Doom Emacs — setup

Targets Ubuntu 26.04 + GNOME (Wayland) on the desktop and the ThinkPad X13.
`install.sh` at the repo root does sections 1–3 for you; this file explains why.

---

## 0. What I changed in the plan you had, and why

Your list was mostly right. Five things I'd change:

**`alias e='emacsclient -nw'` is wrong for you.** Terminal Emacs can't show images,
can't render PDFs, can't do inline LaTeX previews, and can't display your iPad
handwriting exports. That's four of your six use cases. GUI Emacs with a daemon
opens a frame in ~0.2s, so you lose nothing. Terminal client stays for SSH only.

**`lsp` → `lsp +eglot` — but this one is a genuine trade, not a free win.**
lsp-mode is heavier, and its UI extras (headerline breadcrumbs, lens overlays,
ui-doc childframes) are exactly what makes Emacs feel sluggish. Eglot is built
into Emacs, speaks the same protocol, and is what snappy looks like.

What you actually give up, now that real C++ and ML projects live here:

- **Semantic tokens.** clangd can say "this identifier is a type parameter, that
  one is a macro"; lsp-mode colours them, eglot ignores them. Tree-sitter
  recovers most of it.
- **Call hierarchy UI.** The real loss. Tracing who-calls-what through an
  unfamiliar 100k-line C++ codebase is materially worse with eglot.
- **Inline code lenses** (reference counts above functions). Gone.
- **Two servers on one buffer.** lsp-mode can run pyright *and* ruff together;
  eglot picks one. Handled here by running ruff as a formatter separately.

Start on eglot. The day you're deep in a large unfamiliar codebase and want
reference peeking or call hierarchy, delete `+eglot` from `init.el` and
`doom sync`. Both are first-class in Doom, so nothing else in this config
changes. It's a one-line reversible decision — don't agonise over it now.

**"Keep a tmux pane for compile-run rather than fighting Emacs about it" — no.**
For CP that's the wrong call. Half the value of a CP setup is that build → run →
diff-against-samples is one keystroke with no context switch. `+cp.el` does it
in-process: `SPC m t` builds and runs every sample. tmux stays for the homelab.

**TRAMP needs actual configuration or it will freeze Emacs.** ControlMaster in
`~/.ssh/config` is necessary but not sufficient — the freezes come from Emacs
re-probing the remote host for vc, projectile, and format-on-save. Section 7 of
`config.el` handles that.

**Missing pieces you'll want:** `pdf-tools` + `org-noter` (PDF annotation anchored
to your notes — this is the real reason to use Emacs for MFF), `cdlatex` (fast math
typing), `org-download` (paste iPad images), `denote` (notes management without
org-roam's SQLite index), and `claude-code-ide`.

One thing to know up front: **`ligatures` and `indent-guides` are off on purpose.**
They're pure redisplay cost. If you miss them, add them to `init.el` and see how
it feels.

---

## 1. Install

`install.sh` does all of this. By hand, it's:

```bash
# Emacs itself. emacs-pgtk is the native Wayland build — the X11 one renders
# soft under GNOME's scaling on 4K screens.
sudo apt install emacs-pgtk

# Doom's own dependencies
sudo apt install ripgrep fd-find git && ln -sf "$(command -v fdfind)" ~/.local/bin/fd

# pdf-tools builds a C module; vterm builds one too
sudo apt install cmake automake autoconf libtool-bin pkgconf \
  libpoppler-glib-dev libpoppler-private-dev libpng-dev zlib1g-dev libvterm-dev

# Real project work: clangd for C++, gdb (speaks DAP natively) for dape
sudo apt install build-essential gdb clangd clang-format cmake

# Language servers, Claude, Python debugger
npm i -g pyright bash-language-server @anthropic-ai/claude-code
pipx install debugpy        # for dape on Python

# LaTeX: all of TeX Live (~6 GB), so no package is ever missing
sudo apt install texlive-full dvisvgm latexmk

sudo apt install pandoc

# Doom
git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs
~/.config/emacs/bin/doom install
```

`zsh/.zshrc` already has the PATH entry, `e`, `et` and `doomsync`.

## 2. Config files

`install.sh` symlinks `~/.config/doom` to `doom/` in the repo, so editing
`~/.config/doom/config.el` IS editing the repo. Then:

```bash
doom sync
doom doctor       # fix anything it flags before going further
```

Then once, inside Emacs: `M-x pdf-tools-install` and `M-x nerd-icons-install-fonts`.

If `doom sync` rejects a module flag, it names the module and the flag. Delete that
flag and re-run — nothing in `init.el` is load-bearing. The most likely candidate
is `:tools tree-sitter`.

Per-machine tweaks (a bigger font on the 4K desktop, say) go in
`~/.config/doom/+local.el`, which is git-ignored and loaded last.

## 2b. Keys

Two rules shaped these: nvim muscle memory transfers, and nothing binds Alt, an
F-key, or anything that stretches your right pinky to `0 - = \`.

| key | does | note |
|---|---|---|
| `C-h` `C-j` `C-k` `C-l` | move between windows | same as vim-tmux-navigator |
| `C-w s` / `C-w v` | split | unchanged from nvim |
| `C-w c` / `C-w o` | close / only | unchanged |
| `SPC w` | same window map, leader-led | pick whichever your hand reaches |
| `SPC w z` | maximise this window | added |
| `SPC w u` / `SPC w U` | undo / redo window layout | added |
| `SPC :` | `M-x` | **burn this in** |
| `SPC ;` | eval elisp expression | |
| `gc` | comment operator | replaces `M-;` |
| `SPC h` | all help | replaces the `C-h` prefix |
| `]e` / `[e` | next / previous error | matches `]b` `[b` `]d` `[d` |
| `SPC m` | localleader — CP commands live here | |

**The one real trade: `C-h` is no longer the help prefix.** Everything that
lived there is on `SPC h` — `SPC h k` describes a key, `SPC h v` a variable,
`SPC h f` a function. On a board with Ctrl at caps, `C-h` is too valuable to
spend on a menu you visit twice a week.

**`SPC :` matters more than it looks.** `M-x` is the most-pressed binding in all
of Emacs and you've ruled out Alt. Two comfortable keys instead of a stretch.

Deliberately *not* rebound: the whole `C-w` window map, `]b` `[b`, `gt` `gT`,
`gd`, `gr`, `SPC p` project commands. They already behave the way you expect.
Adding a second way to do them would be noise, and a config you can't remember
is worse than one that's slightly less clever.

## 3. Launching: Super+E, no daemon

`config.el` starts a server inside the GUI Emacs you open, instead of running a
separate systemd daemon. A daemon plus a launched Emacs gives you two independent
Emacsen with different buffers, which buys nothing.

**Super+E** is GNOME's native run-or-raise (see `gnome/settings.sh`): if Emacs
is running it's focused, if not it's launched. So there's one Emacs, one window
to find, and the shell side attaches to it:

```bash
e file.cpp     # open in the running GUI Emacs (launches it if needed)
et             # terminal frame, same session — SSH or inside tmux
```

Trade-off: `emacsclient` only works once Emacs is open, and there's a ~2 s cold
start after each login. If that starts to bother you, a systemd user service
(`systemctl --user enable --now emacs`) is the upgrade path; `config.el` guards
on `daemonp`, so nothing needs editing.

**Note on tmux:** your tmux prefix is `C-Space`, which is also `set-mark` in
Emacs. Inside `et` running in tmux, tmux wins. Evil's visual mode covers it in
practice, but the cleaner answer is not to run Emacs inside tmux locally — use the
GUI, and let Emacs' own vterm (`SPC o t`) handle terminals.

## 4. Notes

The config expects:

```
~/Documents/notes/
├── inbox.org        # capture target, SPC n c i
├── todo.org         # SPC n c t
├── school.org       # MFF, SPC n c s
├── cp-log.org       # per-problem log, SPC m p from a C++ buffer
├── math-log.org
├── assets/          # pasted images land here
└── denote/          # the actual notes, one file per note
```

Create it and `git init` it. Two useful keys: `SPC n a` (agenda), `SPC n n` (new note).

**iPad.** Put `~/Documents/notes` inside your Google Drive mirror (or symlink it
there), then use **Orgro** on the iPad. It renders LaTeX fragments, tables,
attached images and folding faithfully, and opens files from the Files app.
Seven-day trial, then a one-time unlock.

Correction to what I said earlier: Orgro isn't read-only any more. It edits, and
with the right file permissions it writes back to the original file. It also does
TODO and checkbox toggling, narrowing, search, and agenda notifications.

So read-only is your choice, not the tool's limit — and it's still the right
choice, for a reason that has nothing to do with Orgro. Two devices writing the
same file through Drive gives you conflict copies, and Emacs' autosave makes that
more likely, not less. Reading on one side and writing on the other removes the
whole class of problem.

If you ever do want to capture from the iPad, don't lift the rule — route around
it. Have the iPad write to one file nothing else touches:

```
~/Documents/notes/mobile-inbox.org    # iPad writes, Emacs only reads and refiles
```

Add it to `org-agenda-files`, refile out of it with `SPC m r` when you're back at
the desk, and no file ever has two writers. **Beorg** is the better app for that
job specifically — it's built around capture and agenda rather than reading — but
Orgro is the one that renders your math properly, so use Orgro for notes and only
add Beorg if capture-on-the-go turns out to be something you actually do.

For the handwriting loop: work the proof out in GoodNotes → export the region as PNG
→ it syncs to Drive → drag it into the org buffer, or copy it and `SPC n v` pastes
it (via `wl-paste`) as a linked image in `assets/`. For anything on screen: PrtSc,
select the area — GNOME puts it on the clipboard — then `SPC n v`.

## 5. Competitive programming

Drop your template at `~/.config/doom/templates/cp.cpp`. It gets copied verbatim
into every new problem file — no editing needed on my side.

Set up Competitive Companion in Chrome to POST to `http://localhost:10043`, then
`SPC m c` in any C++ buffer to start the listener. Clicking the green plus on a
Codeforces problem creates `~/Documents/cp/<contest>/<problem>/`, writes every
sample as `tests/01.in` + `tests/01.out`, seeds your template, and opens the file.

Then:

| key | what |
|---|---|
| `SPC m t` | build + run all samples, diff, verdicts in one buffer |
| `SPC m b` | build only (g++, -O2) |
| `SPC m B` | build with ASan + UBSan (g++) |
| `SPC m r` | build + run interactively, type your own input |
| `SPC m s` | stress test against `brute.cpp` using `gen.cpp` |
| `SPC m p` | log the problem into `cp-log.org` |

`SPC m s` expects `gen.cpp` to take a seed as `argv[1]`. On a mismatch it writes the
failing input to `tests/hack.in` and opens it.

The compiler settings are at the top of `+cp.el` — `+cp-compiler`, `+cp-standard`,
`+cp-fast-flags`. Keep them in sync with `cprun` / `cpjudge` in `.zshrc`.

## 5b. Real projects: build, debug, navigate

For a C++ project, the single most important thing is
`compile_commands.json` at the project root. Without it clangd sees one
translation unit and guesses; with it, it understands the whole project and
`gd` / `gr` / rename actually work.

`SPC c m` runs a CMake configure that emits it and symlinks it to the root.
`SPC c M` builds. `SPC c c` compiles from the project root (not the current
file's directory, which is the usual `M-x compile` annoyance). `SPC c o`
toggles header/source.

Debugging is `dape` — a DAP client built on Emacs 29's own machinery, about a
tenth the size of dap-mode and actually maintained. `SPC d d` prompts with the
available adapters. For C++ pick `gdb` (GDB 14+ speaks DAP itself); for Python,
`debugpy`. `SPC d b` toggles a breakpoint. Breakpoints survive restarts.

For ML/Python work, `direnv` is the piece that makes this pleasant: drop an
`.envrc` with `layout python` or `source .venv/bin/activate` in a project and
Emacs picks up the right interpreter, the right pyright, and the right packages
automatically when you open a file there. No manual `pyvenv-activate`.

## 5c. Claude, in the terminal or in Emacs

Both work, and they're for different things.

**Claude Code in Ghostty/tmux, beside Emacs.** Full TUI fidelity, best for long
conversations and multi-file agent runs. Nothing to configure.

**`claude-code-ide` inside Emacs — `SPC l l`.** Runs the same CLI in a vterm
buffer, but also bridges Emacs to Claude over MCP: it can use your xref, your
LSP diagnostics, your tree-sitter parse, and show diffs as Emacs buffers you
review before accepting. This is the better one when you want surgical changes
to code you're already reading.

**`gptel` — `SPC l g`.** Not agentic at all. A chat buffer in org-mode for
"explain this proof step", "what does this linker error mean", "is this
complexity analysis right". Send a region with `SPC l s`. Different tool from
the two above; don't use it to edit code.

Given you said the heavy generation stays in VS Code: `claude-code-ide` for
targeted work, `gptel` for thinking out loud, terminal Claude when you want a
full screen.

## 6. SSH

`ssh/config` has the ControlMaster setup TRAMP needs, and `install.sh` copies it.
`/ssh:homelab:~/` then works as a path anywhere Emacs takes a filename —
`SPC .`, `SPC f f`, dired — e.g. from the ThinkPad into the desktop.

**For heavy remote work, don't use TRAMP.** Run Emacs on the other machine and
`ssh -t khandlab "emacsclient -t -a ''"`. TRAMP is right for editing a config file
over there; it's wrong for a whole project, because every LSP request and git call
goes over the wire synchronously and blocks your UI.

## 7. Calendar

Org agenda (`SPC n a`) is the source of truth; `SPC n k` gives you a month view.
To get your org deadlines onto your phone/iPad calendar without any sync daemon,
export one-way to an `.ics` that Google Calendar subscribes to:

```elisp
;; add to config.el when you want it
(setq org-icalendar-combined-agenda-file "~/Documents/notes/agenda.ics"
      org-icalendar-include-todo t
      org-icalendar-use-deadline '(event-if-todo todo-due)
      org-icalendar-use-scheduled '(event-if-todo todo-start))
;; M-x org-icalendar-combine-agenda-files
```

Put `agenda.ics` somewhere with a public URL (a private gist, or the homelab behind
Tailscale) and subscribe from Google Calendar. Two-way sync exists but is genuinely
fiddly and you said you don't want to spend time on config.

---

## 8. Honest expectations on speed

**Where you'll get what you want.** With the daemon running, a frame opens in
roughly 0.2s. Typing latency in a normal source file, an org file, or a LaTeX
buffer is indistinguishable from nvim — native compilation plus the redisplay
settings in section 1 of `config.el` handle that. Scrolling a 5k-line file is fine.
Your CP loop will be faster than it was in Sublime because nothing switches windows.

**Where Emacs will still lose to nvim, permanently.** Emacs is single-threaded.
Anything that blocks, blocks the whole UI: the first `magit-status` in a large repo,
a TRAMP connection being established, generating LaTeX previews for a long document,
a slow clangd request on a big translation unit. nvim hides more of this behind its
event loop. For your workload these are all seconds-scale and occasional, not
keystroke-scale — but they're real, and no configuration removes them.

**The three things that will make it feel slow if you let them:** letting
`org-agenda-files` grow to a recursive directory scan, opening a file over TRAMP in
a project where LSP is active, and adding UI packages that hook into
post-command-hook. The config guards against the first two.

Check it yourself: `M-x emacs-init-time` for daemon boot, and `doom doctor`
whenever something feels wrong.
---

## 8b. What actually costs you performance

Worth internalising, because it will stop you from fiddling later.

**Almost everything in Doom is lazy-loaded.** Magit, pdf-tools, vterm, zen,
workspaces — none of them exist in memory until you invoke them. Cutting them
from `init.el` to make Emacs "faster" saves you nothing. Cut modules because
you won't use them, not for speed.

The things that genuinely cost you on every keystroke are a short list:

| Thing | Cost | Status here |
|---|---|---|
| lsp-mode instead of eglot | large | using eglot |
| `undo-tree` (the `+tree` flag) | real on big buffers | cut, using undo-fu |
| flycheck checking on every change | real | delayed to 1.5s idle |
| `+pretty` **and** org-modern **and** org-appear together | real, org only | `+pretty` cut |
| relative line numbers | ~5-10% of redisplay | kept, you're a vim user |
| doom-modeline segments | small | trimmed |
| ligatures | small on Emacs 30+ | ON — you're used to them |
| indent-bars | small | off; turn on if you write much Python |
| TRAMP re-probing the remote host | huge, situational | guarded in section 7 |

Two corrections to what I told you earlier: ligatures are cheaper than I made
out, and `:ui indent-guides` now uses `indent-bars`, which draws with stipples
and is fast. Neither is a performance argument. Ligatures are on because you
already read them all day in Sublime; indent guides are off because brace
languages don't need them.

One note on the ligatures module: no `+extra` flag. Plain `ligatures` gives you
font ligatures. `+extra` additionally substitutes symbols in text — `lambda`
rendered as λ — which looks impressive in screenshots and produces buffers
where what you see isn't what you can search for.

---

## 9. What we haven't decided yet

Left open on purpose, for when you've used this for a week:

- Whether `:tools tree-sitter` earns its place, or whether Emacs 31's built-in
  `treesit` via the lang modules is enough on its own.
- Whether you want `dape` (debugger) for CP, or whether sanitizers + prints are
  enough. For your rating range, sanitizers are almost certainly enough.
- Whether org files or denote notes are the right unit for lecture notes — you'll
  know after the first two weeks of MFF.
- Whether Claude lives in Emacs (`SPC l l`) or stays in Ghostty. Try both; the
  Emacs one is better when you want it to read your buffer, worse when you want a
  full-screen conversation.
