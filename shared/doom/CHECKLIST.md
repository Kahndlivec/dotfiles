# Where you are

Core setup is **done**. Emacs is installed, configured, and fast.

---

## ✅ Done

Emacs 31.1 · Doom 2.2.3 · 52 modules, 169 packages · config in place ·
nerd-icons · pdf-tools built · Dock icon · zshrc · key repeat · LLVM/clangd ·
pyright · bash-language-server · Claude Code CLI · notes directory ·
CP template + snippet · perf tuned (init 0.53s, no lag)

---

## Do next — 20 minutes, then stop configuring

### 1. Put your config in git

This is the one genuinely important thing left. Right now `~/.config/doom`
exists on one machine and nowhere else. All the work in this file is one disk
failure from gone, and the Panasonic can't get it.

```bash
cd ~/.config/doom
git init
cat > .gitignore <<'EOF'
*.elc
eln-cache/
.local/
EOF
git add -A && git commit -m "doom: initial config"
```

Then either push it somewhere, or move it into your existing dotfiles repo and
symlink it back.

### 2. Pick your theme

```
SPC h t
```

Scroll — each one previews live. `doom-monokai-ristretto` and `kanagawa-wave`
are the two I'd try first. Put the winner in `doom-theme` near the top of
config.el's section 2 so it survives a restart.

### 3. Check the font size

`:size 15` may be small on a 32" 4K. Edit `doom-font` in config.el, then
`SPC h r r`. Try 16, then 17.

### 4. Test the CP loop end to end

```bash
mkdir -p ~/Documents/cp
```

In Emacs: `SPC .` to `~/Documents/cp/`, then `SPC m n` for a new problem.
Write something trivial that echoes its input, put a sample in `tests/01.in`
and `tests/01.out`, then:

```
SPC m b     build
SPC m t     run samples, diff, verdicts
SPC m r     run interactively
```

If all three work, the CP setup is proven.

### 5. Claude

```
SPC l l
```

First run asks you to log in. `SPC l g` is gptel for plain questions.

### 6. Competitive Companion

Install the browser extension, point it at `http://localhost:10043`, then in
any C++ buffer:

```
SPC m c
```

Click the green plus on a Codeforces problem. It should create the directory,
write the samples, and open the file. Note: the listener is per-session —
`SPC m c` again after each Emacs restart.

---

## Then: stop, and use it

Two weeks of actually working in it will tell you more than any further
configuration. Things to come back to only when you hit them:

| when | what |
|---|---|
| you want rendered maths in notes | LaTeX — `brew install --cask mactex-no-gui` |
| you have MFF skripta to annotate | org-noter — `SPC r n` |
| you want prose to look like prose in org | mixed-pitch + Inter (Inter is installed) |
| you next work on the homelab | TRAMP — see `ssh_config.sample` |
| you open a real CMake project | `SPC c m` to generate compile_commands.json |
| you want the iPad to read notes | move notes into the Drive mirror, use Orgro |

---

## Keys you'll actually use

```
SPC .      open file            SPC ,      switch buffer
SPC p p    open project         SPC s p    search project
SPC g g    magit                SPC h r r  reload config
SPC :      M-x                  SPC h p    perf report
C-h/j/k/l  move between windows
SPC m ...  CP commands (in C++ buffers)
SPC n ...  notes and agenda
SPC l l    Claude
```
