<p align="center">
  <img src="assets/GNU.png" width="400" alt="GNU meditating over a toppled CRT">
</p>
# dotfiles

macOS setup for a maths student who does competitive programming, C++ and ML
projects, and keeps notes in org-mode.

**Doom Emacs** is the primary editor — CP, C++/ML projects, org notes, LaTeX,
PDF reading. **VS Code** keeps agency frontend work (TypeScript, JSX, HTML) and
heavy AI-agent work, because it handles those best. **Neovim** is the fallback
for remote boxes and quick edits. Ghostty and tmux own the terminal.

This repo is private. It contains a Tailscale hostname, a LAN IP and a MAC
address — none of them credentials, none of them worth publishing either.

## Fresh Mac

```bash
xcode-select --install
git clone <this repo> ~/dotfiles
cd ~/dotfiles && bash bootstrap.sh
```

Installs Homebrew, runs `brew bundle`, copies every config into place, installs
the VS Code extensions and npm globals, clones Doom and runs `doom install`,
applies the macOS defaults. Overwritten files go to `~/dotfiles-backup-*`.

Then, once, inside Emacs:

```
M-x nerd-icons-install-fonts
M-x pdf-tools-install
```

And symlink the app so it's launchable from the Dock:

```bash
ln -s /opt/homebrew/opt/emacs-plus@31/Emacs.app /Applications/Emacs.app
```

Sublime must have been launched once before bootstrap, so `Packages/User`
exists.

## Layout

| Path                                        | What                                                                                                                                   |
| ------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `Brewfile`                                  | every formula and cask — regenerated on each collection run                                                                            |
| `doom/`                                     | Doom Emacs: `init.el`, `config.el`, `packages.el`, `+cp.el`, the CP template and snippet, plus `CHECKLIST.md`, `SETUP.md`, `REMOTE.md` |
| `nvim/`                                     | Neovim `init.lua` and `lazy-lock.json`                                                                                                 |
| `vscode/`                                   | settings, keybindings, snippets, `extensions.txt`                                                                                      |
| `sublime/`                                  | self-installing CP setup, kept from before CP moved into Emacs                                                                         |
| `ghostty/config`                            | terminal                                                                                                                               |
| `tmux/`                                     | tmux config; TPM is re-cloned by bootstrap, `prefix + I` installs plugins                                                              |
| `zsh/.zshrc`                                | shell: PATH, `e`/`et`/`eh`, the CP shell fallbacks                                                                                     |
| `npm/global-packages.txt`                   | pyright, bash-language-server, Claude CLI — invisible to Homebrew                                                                      |
| `scripts/`                                  | the collector, plus the Emacs and homelab setup scripts                                                                                |
| `karabiner/`, `hhkb/`                       | keyboard remaps and layout notes                                                                                                       |
| `macos/defaults.sh`                         | key repeat, Dock, Finder, trackpad, hot corners, screenshots                                                                           |
| `macos/prefs/`                              | plists for apps with no config file (Rectangle, AltTab, LinearMouse)                                                                   |
| `git/`, `gh/`, `clang-format/`, `starship/` | the small ones                                                                                                                         |
| `ssh/`                                      | `config`, `known_hosts`, `*.pub` — **never private keys**                                                                              |
| `apps/apps.md`                              | generated: which apps Homebrew restores and which are manual                                                                           |

## Doom Emacs

Full documentation in `doom/`:

- **`CHECKLIST.md`** — where the setup stands and what's left
- **`SETUP.md`** — the reference manual: install order, why each decision was
  made, what actually costs performance
- **`REMOTE.md`** — running Emacs on the homelab over SSH and tmux

Keys worth knowing:

```
SPC k n/b/t/r    CP: new problem / build / run samples / run interactively
SPC k c          Competitive Companion listener (localhost:10043)
SPC n a/c/n      agenda / capture / new note
SPC c c/m        compile from project root / CMake configure
SPC l l          Claude in Emacs
C-h C-j C-k C-l  move between windows
SPC :            M-x
SPC h p          perf report
```

`+local.el` is a per-machine override and is deliberately **not** collected —
the homelab uses it to swap `g++-16` for `g++`. Build artefacts (`*.elc`,
`*.eln`, `eln-cache/`, `custom.el`) are excluded too: they're compiled for one
CPU and one Emacs build.

## Updating

```bash
cd ~/Documents/dotfiles/scripts
bash dotfiles-update.sh --dry-run       # look first, change nothing
bash dotfiles-update.sh "what changed"
```

Re-collects every config from this Mac, re-exports the Sublime bundle if it's
stale, exports the GUI app preferences, scans for secrets, commits, pushes.

Or by hand — nothing above is required:

```bash
cd ~/Documents/dotfiles && git add -A && git commit -m "..." && git push
```

**Edit configs where the app reads them** (`~/.zshrc`, `~/.config/doom/`,
`~/.clang-format`), never inside the repo. The repo is a mirror; a collection
run overwrites mirrored files from their sources. Safe to hand-edit here
because nothing overwrites them: `hhkb/`, `macos/defaults.sh`, `README.md`,
`scripts/`.

## What does not transfer

Dotfiles reproduce configuration, not a machine. These need doing by hand on a
new Mac, and no script can fix that:

- **Privacy & Security permissions.** Karabiner needs Input Monitoring;
  Rectangle and AltTab need Accessibility. They live in macOS's TCC database,
  tied to the machine and the app's code signature.
- Keychain, app licences, browser profiles
- Display arrangement, wallpaper, Dock contents, login items
- TeX package state — a fresh `mactex-no-gui` install is consistent anyway

## Why no SSH private keys

`~/.ssh/config` is host aliases, no secrets, and annoying to rebuild — so it
lives here. Public keys are public by definition. Private keys do not belong
here even in a private repo:

- they sit in plaintext in every clone and in history forever
- a private repo is one mis-click, or one compromised account, from public
- deleting one later doesn't help — it stays in history, and the only real fix
  is rotating the key

And it's unnecessary. `ssh-keygen -t ed25519` plus `gh ssh-key add` is thirty
seconds on a new machine. For genuine key portability, encrypt first (`age`,
`git-crypt`) or use a password manager.

## The .gitignore is an allowlist

Everything is ignored until explicitly un-ignored. A blacklist only protects
against leaks you thought of in advance; with an allowlist, the cost of
forgetting is a file that _didn't_ get committed rather than a key that did.
Adding a new config type means adding one `!` line.

This has bitten before: `*.el` wasn't on the list, so the entire Doom config
would have been skipped silently. Same for `doom/snippets/c++-mode/cp`, which
has no extension. If something you expect is missing after a collection run,
check the allowlist first.

## Sublime CP setup

Kept, though CP has moved into Emacs. Full keymap in `sublime/README.md`:

```
⌘⏎   run & test        cp+Tab  insert template     ⌃h ⌃j ⌃k ⌃l  panes
⌘B   build + ASan      ⌘K f    template library    ⌘⇧G  g++ judge build
⌘⇧K  compile only      ⌘K s    stress test         ⌃]   jump to definition
```

Zero `alt+` bindings anywhere in this repo — on an HHKB, ⌥ is a bottom-corner
key that can't comfortably combine with the right hand. Same rule in Doom and
Neovim: leader is `SPC`, and `SPC :` replaces `M-x`.
