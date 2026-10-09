<p align="center">
  <img src="assets/GNU.jpg" width="420" alt="GNU meditating over a toppled CRT">
</p>

<h1 align="center">dotfiles</h1>

<p align="center">
  One command turns a fresh Ubuntu install into the machine I work on:<br>
  Sublime Text, Ghostty + tmux, Neovim, VS Code, Sioyek, and the keys that tie them together.
</p>

---

**Ubuntu 26.04 + GNOME (Wayland)**, on a desktop tower and a ThinkPad X13, for
maths at MFF, competitive programming, C++/ML projects, and agency web work.

- **Sublime Text** — competitive programming, C++, scripts, LaTeX. Vim keys
  through NeoVintageous. [`sublime/README.md`](sublime/README.md) has its keys.
- **VS Code** — frontend and AI-agent work, with real Neovim inside it.
- **Ghostty + tmux** — the terminal; Neovim lives in there.
- **Sioyek** — the skripta: highlights by kind, exported for the iPad.
- One muscle memory everywhere: **leader is `SPC`** with the same map in
  Sublime, Neovim and VS Code, `C-h/j/k/l` moves between splits, and nothing
  is bound to Alt, F-keys or arrows (HHKB rules).

**Contents:** [Quick start](#quick-start) · [Everyday](#everyday) ·
[Keys](#keys) · [Dock and shortcuts](#dock-and-shortcuts) · [Skripta → iPad](#skripta--ipad) ·
[What gets installed](#what-gets-installed) ·
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
`sudo tailscale up`, `rclone config` + `./install.sh drive`, open Sublime Text
and give Package Control two minutes, sign in to Brave Sync / Spotify /
Telegram, and point Timeshift at the big partition.

**On a machine that already runs an older version of this setup:**

```bash
cd ~/dotfiles && git pull
./install.sh            # links the new configs, installs Sublime Text
./install.sh prune      # removes Emacs and the Doom install; asks first
```

> The repo lives in `~/Documents/dotfiles`, and `~/dotfiles` points at it.
> Configs are symlinks into it, so **don't move or rename that folder**. If you
> do, run `./install.sh links` from the new location straight after.

## Everyday

| Command | Does |
|---|---|
| `dotsync "msg"` | commit + push this repo (configs are symlinks, so editing `~/.zshrc` edits the repo) |
| `git -C ~/dotfiles pull` | take the other machine's changes; follow with `./install.sh links`, `sublime` and `gnome` if configs or keys changed |
| `notes-push` | commit, rebase and push `~/Documents/notes` |
| `e file` | open a file or folder in Sublime Text |
| `v file` | Neovim in the terminal |
| `cprun a.cpp` / `cpjudge a.cpp` | C++ with sanitizers / with the judge's flags |
| `ta` | attach to tmux (Ghostty does it for you) |
| `update` | apt + snap upgrade |

**Installer modes**

| Mode | Does |
|---|---|
| `./install.sh` | everything, idempotent |
| `links` | re-link configs only |
| `sublime` | Sublime Text, Package Control and its settings |
| `gnome` | re-apply keys, dock and desktop settings |
| `drive` | mount Google Drive, create `Skripta` |
| `notes` | put `~/Documents/notes` in git + a private GitHub repo |
| `check` | full health report, changes nothing |
| `audit` | find leftovers from an older setup, changes nothing |
| `prune` | remove software this setup replaces — shows it, asks first |

## Keys

App keys are **run-or-raise**: jump to the app if it's open, start it if not.

| Key | App | Key | Window |
|---|---|---|---|
| `Super+E` | Sublime Text | `Super+1..4` | switch workspace |
| `Super+T` / `Super+Enter` | Ghostty (tmux) | `Super+Shift+1..4` | move window there |
| `Super+B` / `Super+Shift+B` | Brave / Firefox | `Super+Q` | close window |
| `Super+V` | Neovim (own window) | `Super+Tab` / `Alt+Tab` | apps / windows |
| `Super+C` | VS Code | `Super+←/→/↑` | tile / maximise |
| `Super+M` | Spotify | `Super+N` | notifications |
| `Super+F` | Files | `Super` | search, launch anything |

Inside the editors: [`sublime/README.md`](sublime/README.md) lists the leader
map and the Ctrl keys. Neovim and VS Code use the same leader map, from
`nvim/init.lua`.

## Dock and shortcuts

One file decides both the dock order and the app keys:
[`gnome/shortcuts.conf`](gnome/shortcuts.conf). One line per app:

```
<Super>e                   sublime_text.desktop
<Super>t <Super>Return     com.mitchellh.ghostty.desktop
-                          telegram-desktop_telegram-desktop.desktop
```

- **Left:** the key or keys. `<Super>x`, `<Super><Shift>x`; `-` means "in the
  dock, no key".
- **Right:** the app, by its `.desktop` file name. To find one:
  `ls /usr/share/applications ~/.local/share/applications /var/lib/snapd/desktop/applications | grep -i name`
- **Line order is dock order**, top line = first icon.

| To | Do |
|---|---|
| change an app's key | edit the left side of its line |
| move an app in the dock | move its line up or down |
| add an app | add a line |
| take an app out | delete its line, then unpin it in the dock by hand |

Then apply and save it:

```bash
e ~/dotfiles/gnome/shortcuts.conf     # edit
~/dotfiles/install.sh gnome           # apply
dotsync "dock: …"                     # commit + push, so the other machine gets it
```

On the other machine: `git -C ~/dotfiles pull && ~/dotfiles/install.sh gnome`.

Don't drag the listed icons around in the dock itself: GNOME ties each key to
a dock *position*, so dragging shifts every key after it. If that happens, run
`./install.sh gnome` again. Pinning extra apps by hand is fine; they go at the
end. At most nine apps can have a key.

Workspace and window keys (`Super+1..4`, `Super+Q`, …), key repeat and the
rest of the desktop settings live in [`gnome/settings.sh`](gnome/settings.sh).
Edit that file and run `./install.sh gnome` the same way.

## Skripta → iPad

```
Sioyek on the computer:  hd hv hp hk hz   highlight by kind
                         b                short note
                         g e              export → ~/GoogleDrive/Skripta
iPad:                    Files → Google Drive → Skripta   (read only)
```

- **Colours** are in [`sioyek/prefs_user.config`](sioyek/prefs_user.config):
  `d` blue definice, `v` red věta, `p` green příklad, `k` yellow key step,
  `z` purple zkouška.
- **See one kind only:** `gh` opens the list; type `[v]` for věty, `[d]` for
  definice. `gnv` / `gNv` jump to the next / previous věta (same for d, p, k, z).
- **Export:** `g e` writes a copy of the PDF with highlights and notes baked
  in. Save it over the previous export in `~/GoogleDrive/Skripta`.
- **Highlights live on the machine that made them** (`~/.local/share/sioyek`).
  They are not synced: a Sioyek database on the on-demand Drive mount is a
  good way to lose it. Annotate on one machine, export for the others.
- **Config files must be plain ASCII.** Sioyek stops reading at the first
  accented character, silently. `./install.sh check` tests for it.

## What gets installed

| | |
|---|---|
| **apt** (`packages/apt.txt`) | zsh, tmux, git, gh, gcc/gdb/clangd/cmake, ripgrep, fd, fzf, direnv, pandoc, **full TeX Live**, rclone, KeePassXC, Sioyek, Timeshift, Solaar, bat/eza/delta/zoxide |
| **vendor repos, snaps** | **Sublime Text**, VS Code, Brave, Ghostty, Spotify, Telegram, Tailscale, Docker (+ NVIDIA container toolkit where there's a GPU) |
| **user-level** | Neovim release build (with its app icon), starship, JetBrainsMono Nerd Font, npm globals, pipx tools, VS Code extensions |
| **editors** | Sublime Text with Package Control and its settings; restores Neovim plugins from `lazy-lock.json` |
| **system** | zsh as login shell, per-machine SSH key, Google Drive mount, GNOME keys and settings, clutter launchers hidden |

## Layout

| Path | Lands at / what it is |
|---|---|
| `install.sh` | the whole setup |
| `packages/` | apt, npm, pipx, VS Code extensions, launchers to hide, packages to remove |
| `gnome/shortcuts.conf` | app keys and dock order |
| `gnome/settings.sh` | workspaces, window keys, key repeat, dock, dark mode |
| `sublime/` | Sublime Text: `install.sh` copies `payload/` into place — see its README |
| `sioyek/` | `~/.config/sioyek` — highlight colours, keys, export |
| `nvim/` | `~/.config/nvim` (also drives the vim layer in VS Code) |
| `vscode/` | `~/.config/Code/User/` |
| `zsh/`, `tmux/`, `ghostty/`, `starship/`, `git/`, `gh/`, `clang-format/` | the shell and terminal side |
| `bin/notes-sync` | what `notes-push` runs |
| `env/10-path.conf` | `~/.config/environment.d/` — PATH for GNOME-launched apps |
| `systemd/` | `~/.config/systemd/user/` — the Drive mount |
| `ssh/config` | `~/.ssh/config` (copied, not linked) |
| `people/` | per-person identity, hosts, aliases |
| `hhkb/` | keyboard layout and how to flash it |
| `emacs/` | **parked**: the old Doom Emacs setup. `install.sh` never touches it |

## Two people

The setup is shared; identity isn't. Everything personal lives in `people/<name>/`:

| File | Used for |
|---|---|
| `gitconfig` | git name and email |
| `zshrc` | your own aliases and functions |
| `ssh_config` | your SSH hosts |

The first run asks who uses the machine and links `~/.config/dotfiles/person`
to that folder. A new name gets its folder created from two questions —
commit it with `dotsync "add <name>"`. Machine-only extras go in
`~/.zshrc.local` or `~/.ssh/config.d/`, neither of which is synced.

## When something breaks

Start with `./install.sh check`. It reports every program, every config link,
Ghostty's config, Sublime's settings and build, the GNOME keys against
`shortcuts.conf`, services and accounts.

| Symptom | Fix |
|---|---|
| Shortcuts open the wrong app | `./install.sh gnome` (the dock order moved) |
| A Sublime key or setting is off | `./install.sh sublime` (resets its settings to the repo's) |
| Sioyek colours or keys do nothing | a non-ASCII character in `sioyek/*.config`; `./install.sh check` names the line |
| Plain shell prompt, missing commands | the repo folder moved — `./install.sh links` from its new place |
| Neovim app has no icon or won't start | `./install.sh` |
| Ghostty ignoring its config | `ghostty +validate-config`; a legacy `~/.config/ghostty/config` overrides ours |
| `~/GoogleDrive` empty or stuck | `systemctl --user restart rclone-gdrive`, then `journalctl --user -u rclone-gdrive -e` |
| The machine had another setup before | `./install.sh audit`, then `prune` |

Replaced files are never deleted: they land in `~/dotfiles-backup-<date>/`.

## Why it's built this way

- **Symlinks, not copies.** Editing `~/.zshrc` edits the repo, so there's
  nothing to remember to copy back. Sublime Text is the exception: it and
  Package Control rewrite their own settings files, so those are copied from
  `sublime/payload`.
- **The `.gitignore` is an allowlist.** Everything is ignored until explicitly
  allowed, so forgetting a file means it isn't committed — instead of a secret
  being pushed.
- **SSH keys are per machine** and never committed. A private repo is one
  mis-click from public, and a key in git history stays there forever.
- **Run-or-raise, not launch.** GNOME's own `switch-to-application` mechanism:
  one editor, one terminal, no duplicate windows, and no extension to break at
  the next GNOME release.
- **One leader map.** Sublime, Neovim and VS Code share the same `SPC` groups
  (`f` file, `b` buffer, `s` search, `w` window, `c` code), so switching
  editor never means relearning keys.
- **Emacs is parked, not deleted.** `emacs/` keeps the Doom config; nothing
  installs it.
