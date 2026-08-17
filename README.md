# dotfiles

macOS setup: Sublime Text for competitive programming, Ghostty, VSCode, zsh,
and the `defaults write` tweaks that are otherwise redone from memory.

## Fresh Mac

```bash
xcode-select --install
git clone <this repo> ~/dotfiles
cd ~/dotfiles && bash bootstrap.sh
```

Installs Homebrew if missing, runs `brew bundle`, copies every config into
place, installs VSCode extensions, runs the Sublime installer, applies the
macOS defaults. Anything it overwrites is backed up to `~/dotfiles-backup-*`.

Sublime must have been launched once before bootstrap, so that `Packages/User`
exists.

## Layout

| Path | What |
|---|---|
| `Brewfile` | every formula and cask — `brew bundle install` |
| `sublime/` | self-installing CP setup: keymap, build system, clangd config, FOC settings, `bits/stdc++.h` shim. See `sublime/README.md` |
| `ghostty/config` | terminal |
| `tmux/` | tmux config; TPM is re-cloned by bootstrap, plugins install with `prefix + I` |
| `vscode/` | settings, keybindings, snippets, `extensions.txt` |
| `zsh/` | shell |
| `git/` | global gitconfig |
| `ssh/` | `config`, `known_hosts`, `allowed_signers`, `*.pub` — **no private keys** |
| `apps/apps_without_casks.md` | apps installed by hand that `brew bundle` won't restore |
| `macos/defaults.sh` | key repeat, Finder, no smart quotes |

## Why no SSH private keys

`~/.ssh/config` is just host aliases — no secrets, and genuinely annoying to
rebuild, so it lives here. Public keys are public by definition. Private keys
do not, even in a private repo:

- they sit in plaintext in every clone and in history forever
- a private repo is one mis-click, or one compromised account, from public
- deleting one later doesn't help — it stays in history, and the only real fix
  is rotating the key

And it's unnecessary. `ssh-keygen -t ed25519` plus `gh ssh-key add` is thirty
seconds on a new machine. If you specifically want key portability, encrypt
first (`age`, `git-crypt`) or use a password manager — don't hand it to git.

## Updating

```bash
bash cp-export.sh                    # if the Sublime setup changed
bash dotfiles-init.sh                # re-collects everything
cd ~/dotfiles && git add -A && git commit -m "..." && git push
```

`dotfiles-init.sh` only copies, so re-running it is safe.

## The .gitignore is an allowlist

Everything is ignored until explicitly un-ignored. A blacklist only protects
against leaks you thought of in advance; with an allowlist, the cost of
forgetting is a file that *didn't* get committed rather than a key that did.
Adding a new config type means adding one `!` line.

## Sublime CP setup

Full keymap and gotchas in `sublime/README.md`. The short version:

```
⌘⏎   run & test        cp+Tab  insert template     ⌃h ⌃j ⌃k ⌃l  panes
⌘B   build + ASan      ⌘K f    template library    ⌘⇧G  g++ judge build
⌘⇧K  compile only      ⌘K s    stress test         ⌃]   jump to definition
```

Zero `alt+` bindings — on an HHKB, ⌥ is a bottom-corner key that can't
comfortably combine with the right hand.
