<p align="center">
  <img src="assets/GNU.jpg" width="420" alt="GNU meditating over a toppled CRT">
</p>

<h1 align="center">dotfiles</h1>

<p align="center">
  One command turns a fresh Ubuntu install into the machine I work on:<br>
  Doom Emacs, Ghostty + tmux, Neovim, VS Code, and the keys that tie them together.
</p>

---

**Ubuntu 26.04 + GNOME (Wayland)**, on a desktop tower and a ThinkPad X13, for
maths at MFF, competitive programming, C++/ML projects, and agency web work.

- **Doom Emacs** — notes, maths, CP, C++/ML projects, PDFs.
- **VS Code** — frontend and AI-agent work, with real Neovim inside it.
- **Ghostty + tmux** — the terminal; Neovim lives in there.
- One muscle memory everywhere: **leader is `SPC`**, `C-h/j/k/l` moves between
  splits, and nothing is bound to Alt, F-keys or arrows (HHKB rules).

**Contents:** [Quick start](#quick-start) · [Everyday](#everyday) ·
[Keys](#keys) · [iPad → notes](#ipad--notes) · [What gets installed](#what-gets-installed) ·
[Layout](#layout) · [Two people](#two-people) · [When something breaks](#when-something-breaks) ·
[Why it's built this way](#why-its-built-this-way)

## Quick start

```bash
sudo apt install -y git gh
gh auth login                                 # SSH; the repo is private
gh repo clone Kahndlivec/dotfiles ~/Documents/dotfiles
ln -s ~/Documents/dotfiles ~/dotfiles         # everything refers to ~/dotfiles
~/dotfiles/install.sh audit                   # only if the machine was used before
~/dotfiles/install.sh
```

Run it from a terminal inside GNOME, as yourself. It asks for sudo once, asks
who uses the machine, and is safe to re-run any time. Budget 45–60 minutes,
most of it TeX Live.

**Then, once:** log out and back in, `gh ssh-key add ~/.ssh/id_ed25519.pub`,
`sudo tailscale up`, `rclone config` + `./install.sh drive`, `./install.sh notes`,
`M-x pdf-tools-install` in Emacs, sign in to Brave Sync / Spotify / Telegram,
and point Timeshift at the big partition.

> The repo lives in `~/Documents/dotfiles`, and `~/dotfiles` points at it.
> Configs are symlinks into it, so **don't move or rename that folder**. If you
> do, run `./install.sh links` from the new location straight after.

## Everyday

| Command | Does |
|---|---|
| `dotsync "msg"` | commit + push this repo (configs are symlinks, so editing `~/.zshrc` edits the repo) |
| `git -C ~/dotfiles pull` | take the other machine's changes; follow with `./install.sh links` and `gnome` if configs or keys changed |
| `notes-push` / `SPC n p` | commit, rebase and push the org notes |
| `e file` / `et` | open a file in the running Emacs / a terminal frame |
| `v file` | Neovim in the terminal |
| `cprun a.cpp` / `cpjudge a.cpp` | C++ with sanitizers / with the judge's flags |
| `ta` | attach to tmux (Ghostty does it for you) |
| `update` | apt + snap upgrade |
| `doomsync` | `doom sync && doom doctor` after changing Doom config |

**Installer modes**

| Mode | Does |
|---|---|
| `./install.sh` | everything, idempotent |
| `links` | re-link configs only |
| `gnome` | re-apply keys, dock and desktop settings |
| `drive` | mount Google Drive, create `Org-inbox` |
| `notes` | put `~/Documents/notes` in git + a private GitHub repo |
| `check` | full health report, changes nothing |
| `audit` | find leftovers from an older setup, changes nothing |
| `prune` | remove software this setup replaces — shows it, asks first |

## Keys

App keys are **run-or-raise**: jump to the app if it's open, start it if not.

| Key | App | Key | Window |
|---|---|---|---|
| `Super+E` | Emacs | `Super+1..4` | switch workspace |
| `Super+T` / `Super+Enter` | Ghostty (tmux) | `Super+Shift+1..4` | move window there |
| `Super+B` | Brave | `Super+Q` | close window |
| `Super+V` | Neovim (own window) | `Super+Tab` / `Alt+Tab` | apps / windows |
| `Super+C` | VS Code | `Super+←/→/↑` | tile / maximise |
| `Super+M` | Spotify | `Super+N` | notifications |
| `Super+F` | Files | `Super` | search, launch anything |

**Changing them:** edit [`gnome/shortcuts.conf`](gnome/shortcuts.conf) — one line
per app, key on the left — then `./install.sh gnome`. GNOME ties these keys to
dock positions, so that file is also the dock order: pinning extra apps is fine
(they go at the end), but dragging or unpinning the listed ones shifts the keys.
Re-running `./install.sh gnome` puts it back. Workspace and window keys live in
[`gnome/settings.sh`](gnome/settings.sh).

## iPad → notes

```
GoodNotes page or lasso  →  Drive/Org-inbox  →  SPC n i  →  note + assets/
                                                               ↓ SPC n p
                              iPad: Working Copy → Orgro  ←  GitHub
```

- **Drive carries exports in; git carries notes out.** `Org-inbox/` is where the
  iPad sends a page or a lasso selection. GoodNotes' own `notes/` backup of whole
  notebooks is never touched. The notes sync through git only — one source of
  truth, with history.
- **Import:** `SPC n i` drops the newest export into the note at the cursor,
  copied into `assets/`. `SPC n I` picks an older one, `SPC n v` pastes from the
  clipboard. A PDF becomes one image per page. Imported files move to
  `Org-inbox/imported/`.
- **Save:** `SPC n p` commits, pulls with rebase, pushes. Nothing runs on a
  schedule — that key is the checkpoint.
- **Read on the iPad:** Working Copy clones the notes repo, Orgro opens the
  `.org` files from it through Files, so `assets/` images render inline.
- **Tweak:** `doom/+scans.el`, or per machine in `~/.config/doom/+local.el`.

## What gets installed

| | |
|---|---|
| **apt** (`packages/apt.txt`) | zsh, tmux, git, gh, gcc/gdb/clangd/cmake, ripgrep, fd, fzf, direnv, pandoc, **emacs-pgtk**, **full TeX Live**, rclone, KeePassXC, Sioyek, Timeshift, Solaar, bat/eza/delta/zoxide, build deps for pdf-tools and vterm |
| **vendor repos, snaps** | VS Code, Brave, Ghostty, Spotify, Telegram, Tailscale, Docker (+ NVIDIA container toolkit where there's a GPU) |
| **user-level** | Neovim release build (with its app icon), starship, JetBrainsMono Nerd Font, npm globals, pipx tools, VS Code extensions |
| **editors** | clones Doom and runs `doom install`; restores Neovim plugins from `lazy-lock.json` |
| **system** | zsh as login shell, per-machine SSH key, Google Drive mount, GNOME keys and settings, clutter launchers hidden |

## Layout

| Path | Lands at / what it is |
|---|---|
| `install.sh` | the whole setup |
| `packages/` | apt, npm, pipx, VS Code extensions, launchers to hide, packages to remove |
| `gnome/shortcuts.conf` | app keys and dock order |
| `gnome/settings.sh` | workspaces, window keys, key repeat, dock, dark mode |
| `doom/` | `~/.config/doom` — `SETUP.md` explains the choices |
| `nvim/` | `~/.config/nvim` (also drives the vim layer in VS Code) |
| `vscode/` | `~/.config/Code/User/` |
| `zsh/`, `tmux/`, `ghostty/`, `starship/`, `git/`, `gh/`, `clang-format/` | the shell and terminal side |
| `bin/notes-sync` | what `notes-push` and `SPC n p` run |
| `env/10-path.conf` | `~/.config/environment.d/` — PATH for GNOME-launched apps |
| `systemd/` | `~/.config/systemd/user/` — the Drive mount |
| `ssh/config` | `~/.ssh/config` (copied, not linked) |
| `people/` | per-person identity, hosts, aliases |
| `hhkb/` | keyboard layout and how to flash it |

## Two people

The setup is shared; identity isn't. Everything personal lives in `people/<name>/`:

| File | Used for |
|---|---|
| `gitconfig` | git name and email |
| `doom.el` | name and mail in Emacs (org export) |
| `zshrc` | your own aliases and functions |
| `ssh_config` | your SSH hosts |

The first run asks who uses the machine and links `~/.config/dotfiles/person`
to that folder. A new name gets its folder created from three questions —
commit it with `dotsync "add <name>"`. Machine-only extras go in
`~/.zshrc.local` or `~/.ssh/config.d/`, neither of which is synced.

## When something breaks

Start with `./install.sh check`. It reports every program, every config link,
Ghostty's config, the GNOME keys against `shortcuts.conf`, services and
accounts.

| Symptom | Fix |
|---|---|
| Shortcuts open the wrong app | `./install.sh gnome` (the dock order moved) |
| Plain shell prompt, missing commands | the repo folder moved — `./install.sh links` from its new place |
| Neovim app has no icon or won't start | `./install.sh` |
| Ghostty ignoring its config | `ghostty +validate-config`; a legacy `~/.config/ghostty/config` overrides ours |
| `~/GoogleDrive` empty or stuck | `systemctl --user restart rclone-gdrive`, then `journalctl --user -u rclone-gdrive -e` |
| The machine had another setup before | `./install.sh audit`, then `prune` |

Replaced files are never deleted: they land in `~/dotfiles-backup-<date>/`.

## Why it's built this way

- **Symlinks, not copies.** Editing `~/.zshrc` edits the repo, so there's
  nothing to remember to copy back.
- **The `.gitignore` is an allowlist.** Everything is ignored until explicitly
  allowed, so forgetting a file means it isn't committed — instead of a secret
  being pushed.
- **SSH keys are per machine** and never committed. A private repo is one
  mis-click from public, and a key in git history stays there forever.
- **Run-or-raise, not launch.** GNOME's own `switch-to-application` mechanism:
  one Emacs, one terminal, no duplicate windows, and no extension to break at
  the next GNOME release.
- **Notes sync through git only.** A second copy on Drive would be a second
  source of truth; Drive only carries iPad exports inwards.
- **No daemon for Emacs.** The server runs inside the GUI Emacs that `Super+E`
  raises, so `e file.cpp` in a terminal opens in the window you're looking at.
