# Unpacking this

Unzip at the repo root. It adds `linux/`, `docs/`, `shared/bin/`,
`shared/git/`, `bootstrap.sh` and `gitignore-additions.txt`.

`shared/git/.gitconfig` **replaces** the one you moved from `git/` — it
drops the hardcoded `[user]` block so the repo works for both of you.

Then:

    cat gitignore-additions.txt >> .gitignore
    rm gitignore-additions.txt
    chmod +x bootstrap.sh linux/setup.sh linux/gnome/setup.sh \
             linux/packages/manual.sh shared/bin/org-sync
    git add -A && git status        # confirm nothing was silently ignored

## What's in here

| File | |
|---|---|
| `bootstrap.sh` | root dispatcher; `uname` → `linux/setup.sh` |
| `linux/setup.sh` | the installer. `ROLE` auto-detects from `/sys/class/power_supply/BAT0` |
| `linux/packages/apt.txt` | apt list; lines tagged `# thinkpad` are role-gated |
| `linux/packages/flatpak.txt` | Flathub IDs |
| `linux/packages/manual.sh` | third-party apt repos, mise/uv/starship, npm globals, Nerd Font |
| `linux/zsh/.zshrc` | ported; every change from the macOS one is marked `LINUX` |
| `linux/ghostty/config` | ported |
| `linux/ssh/config` | ported; `UseKeychain` removed (hard parse error on Linux). Host renamed `tower`, `homelab` kept as an alias |
| `linux/ssh/install.sh` | **opt-in.** setup.sh skips SSH unless `WITH_SSH=1` |
| `linux/gnome/setup.sh` | Rectangle/AltTab/key-repeat replacement, Super+1–4 workspaces |
| `linux/keyd/thinkpad.conf` | ThinkPads only; ISO→ANSI and HHKB modifiers |
| `linux/systemd/org-sync.*` | the notes sync timer |
| `shared/bin/org-sync` | commit/rebase/push `~/Documents/notes` |
| `shared/git/.gitconfig` | identity-free; includes `~/.gitconfig.local` |
| `docs/RESTRUCTURE.md` | the `git mv` plan and what changed in each ported file |
| `docs/notes-sync.md` | org ↔ iPad, GoodNotes → org-noter, Claude on Linux |

## Fixed since the first zip

- `put()` nested directories on a second run (`~/.config/doom/doom`).
- Added the `~/.gitconfig.local` prompt, so one repo serves two people.
- Added org-sync deployment + timer enable.
- SSH is now opt-in and has its own installer, with a parse check.
- `eh()` points at `tower` and opens terminal Emacs in a persistent tmux.
