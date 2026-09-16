<p align="center">
  <img src="assets/GNU.jpg" width="400" alt="GNU meditating over a toppled CRT">
</p>

# dotfiles

Ubuntu 26.04 + GNOME setup for a maths student who does competitive
programming, C++ and ML projects, and keeps notes in org-mode. Same repo on
the desktop tower and the ThinkPad X13.

**Doom Emacs** is the primary editor — CP, C++/ML projects, org notes, PDFs.
**VS Code** keeps agency frontend (TypeScript, JSX, HTML) and heavy AI-agent
work. **Neovim** is the in-terminal editor. Ghostty and tmux own the terminal.

## Fresh machine

```bash
sudo apt install -y git gh
gh auth login                                  # pick SSH; works for a private repo
gh repo clone Kahndlivec/dotfiles ~/dotfiles
~/dotfiles/install.sh
```

Run it from a terminal inside GNOME, as yourself. It asks for sudo once, and
it's safe to re-run at any time. It installs:

| | |
|---|---|
| apt (`packages/apt.txt`) | zsh, tmux, git, gh, gcc/g++, gdb, clangd, cmake, ripgrep, fd, direnv, pandoc, emacs-pgtk, TeX Live (LuaLaTeX + org previews), rclone, KeePassXC, build deps for pdf-tools and vterm |
| vendor repos / snaps | VS Code, Brave, Ghostty, Spotify, Telegram, Tailscale |
| user-level | Neovim (release build), starship, JetBrainsMono Nerd Font, npm globals (`packages/npm.txt`), pipx tools (`packages/pipx.txt`), VS Code extensions |
| editors | clones Doom and runs `doom install`, restores Neovim plugins from `lazy-lock.json` |
| system | zsh as login shell, a fresh SSH key for this machine, Google Drive mount, GNOME keybindings and settings |

Then once, by hand: log out and back in, register the new SSH key with GitHub,
`sudo tailscale up`, set up Google Drive (below), `M-x pdf-tools-install` in
Emacs, and sign in to Brave Sync, Spotify and Telegram.

```bash
./install.sh links    # only re-link configs
./install.sh gnome    # only re-apply GNOME keybindings/settings
./install.sh drive    # only (re)enable the Google Drive mount
./install.sh check    # report what's installed, change nothing
```

## Keys (GNOME)

App keys are **run-or-raise**: jump to the app if it's open, start it if not.

| | | | |
|---|---|---|---|
| `Super+E` | Emacs | `Super+1..4` | workspace 1–4 |
| `Super+T` / `Super+Enter` | Ghostty (tmux) | `Super+Shift+1..4` | move window there |
| `Super+B` | Brave | `Super+Q` | close window |
| `Super+V` | VS Code | `Super+Tab` / `Alt+Tab` | apps / windows |
| `Super+M` | Spotify | `Super+N` | notifications |
| `Super+F` | Files | `Super` | search / launch anything |

`Super+←/→/↑` tile and maximise (GNOME defaults). Everything lives in
`gnome/settings.sh` — edit, then `./install.sh gnome`.

Inside the editors the rule is the same everywhere: **leader is `SPC`**,
`C-h/j/k/l` moves between splits (Emacs, Neovim, tmux panes, VS Code), no Alt
bindings, no F-keys. VS Code gets its SPC commands from the `vim.g.vscode`
branch of `nvim/init.lua`.

## Layout

| Path | Lands at |
|---|---|
| `install.sh` | — |
| `packages/` | apt, npm, pipx and VS Code extension lists |
| `gnome/settings.sh` | keybindings, workspaces, key repeat, dock, dark mode |
| `env/10-path.conf` | `~/.config/environment.d/` — PATH for GNOME-launched apps |
| `doom/` | `~/.config/doom` — see `doom/SETUP.md` for the why |
| `nvim/` | `~/.config/nvim` |
| `vscode/` | `~/.config/Code/User/` |
| `zsh/.zshrc` | `~/.zshrc` — PATH, `e`/`et`, `cprun`/`cpjudge`, `dotsync` |
| `ghostty/config` | `~/.config/ghostty/config` — opens straight into tmux session `main` |
| `tmux/.tmux.conf` | `~/.tmux.conf` |
| `git/`, `gh/`, `starship/`, `clang-format/` | the small ones |
| `ssh/` | `~/.ssh/config` and `known_hosts` (copied, not linked) |
| `hhkb/` | Linux layout, how to flash it, old layout backup |
| `systemd/` | `~/.config/systemd/user/` — the Google Drive mount |

## Google Drive

There's no Google Drive app for Linux, so rclone mounts it at `~/GoogleDrive`
(files download on demand, like the Mac app). One-time setup:

```bash
rclone config        # n → name: gdrive → storage: drive → Enter through the
                     # rest (defaults) → "auto config" y → sign in in the browser
./install.sh drive   # starts the mount now and at every login
```

GoodNotes exports land there; drag them into org buffers. Keep the org notes
themselves in `~/Documents/notes` on local disk — autosave onto a network
mount is slow and makes conflict copies.

## HHKB

The keyboard's layout lives in its firmware, so it follows the keyboard to any
machine. See `hhkb/README.md` for the Linux layout and how to flash it.

## Editing

Configs are **symlinks into this repo**, so `~/.zshrc`, `~/.config/doom/config.el`
and the rest *are* the repo. Edit them where they are, then:

```bash
dotsync "what changed"      # git add -A, commit, push
```

Per-machine Emacs tweaks (font size on the X13 vs the 4K desktop) go in
`~/.config/doom/+local.el`, which is git-ignored and loaded last.

## SSH keys are per machine

`install.sh` generates one on each machine and `gh auth login` registers it.
No key — private or public — is ever committed: a private repo is one
mis-click from public, and a key in git history stays there forever.

## The .gitignore is an allowlist

Everything is ignored until explicitly un-ignored. Forgetting to allow a file
means it doesn't get committed, rather than a secret getting pushed. Adding a
new config type means adding one `!` line. If a file you expect is missing
from a commit, check the allowlist first.
