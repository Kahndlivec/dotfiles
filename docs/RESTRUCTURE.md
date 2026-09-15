# Repo restructure

Your instinct was right, with one amendment.

```
dotfiles/
├── bootstrap.sh          # dispatches on uname
│
├── shared/               # ← identical on both. EDIT HERE.
│   ├── doom/             #   init.el config.el packages.el +cp.el
│   ├── nvim/             #   snippets/ templates/ *.md
│   ├── vscode/           #   settings keybindings extensions.txt
│   ├── tmux/  git/  gh/  clang-format/  starship/
│
├── linux/                # ← the living tree
│   ├── setup.sh
│   ├── packages/         #   apt.txt  flatpak.txt  manual.sh
│   ├── zsh/.zshrc
│   ├── ghostty/config
│   ├── ssh/config
│   ├── gnome/setup.sh
│   └── keyd/thinkpad.conf
│
├── macos/                # ← FROZEN. Archive. Don't edit.
│   ├── Brewfile
│   ├── defaults.sh  prefs/
│   ├── karabiner/  hhkb/  linearmouse/
│   ├── sublime/  apps/
│   └── scripts/          #   the old collector + homelab scripts
│
└── docs/
    ├── notes-sync.md
    └── RESTRUCTURE.md
```

## Why a full `linux/` tree and not templating

Duplicating a config across two OS trees is normally a mistake — the
copies drift and you fix every bug twice. It isn't a mistake here,
because **`macos/` is dead**. You're selling the MacBook. Nothing in
that tree will be edited again; it's a snapshot you keep in case you
buy a Mac in 2028. A frozen copy has no drift, so it has no cost.

That only holds for files that are genuinely OS-specific. `doom/`,
`nvim/`, `vscode/`, `tmux/`, `git/` are byte-identical on both and you
*will* keep editing them — those go in `shared/`, once. Duplicating
those would be the real mistake.

Three files moved from your macOS tree into `shared/` unchanged:

- `doom/init.el` already guards correctly:
  `(:if (featurep :system 'macos) macos)` — no edit needed.
- `tmux/.tmux.conf`, `git/.gitconfig`, `starship/starship.toml`,
  `gh/config.yml`, `clang-format/.clang-format` — no macOS references.

## What changed in the ported files

| File | Change |
|---|---|
| `linux/ssh/config` | **`UseKeychain yes` deleted.** macOS-only option; on Linux OpenSSH it's a parse error and every `ssh`/`git push` fails. It was in there twice |
| `linux/zsh/.zshrc` | `$(brew --prefix)/share/...` ×3 → `/usr/share/...` |
| | `open -a Emacs` → `setsid -f emacs` |
| | `g++-16` → `g++` in `cpjudge` |
| | `/opt/homebrew/opt/llvm/bin` dropped |
| | added: `fd`/`bat` aliases, `pbcopy`/`pbpaste` shims, `mise`, `zoxide`, `eza` |
| `linux/ghostty/config` | `macos-option-as-alt` block deleted — Alt is Meta natively |
| `linux/gnome/setup.sh` | replaces `macos/defaults.sh` key repeat, Rectangle, AltTab |
| `linux/keyd/thinkpad.conf` | replaces `macos/karabiner/` — ThinkPads only |

## Also update `.gitignore`

It's an allowlist, so new directories are silently skipped until you
un-ignore them. Add:

```gitignore
!linux/
!linux/**
!shared/
!shared/**
!macos/
!macos/**
!docs/
!docs/**
!*.conf
!*.txt
```

Your README already flags that this bit you once, when `*.el` wasn't on
the list.

## Two things to do before the Mac goes

1. **Re-flash the HHKB Fn layer.** `hhkb-fn-symbols.json` exists because
   your firmware Fn layer emits keypad codes (`keypad_slash` →`[`,
   `keypad_asterisk` → `]`, …) that Karabiner translates. On any other
   OS, Fn+E gives a numpad slash. Point the firmware at the real
   bracket keycodes with the Keymap Tool and the translation layer stops
   being needed anywhere, ever.

2. **Flip the DIP switches out of Macintosh mode.** Your `.hks` has
   `DipSwitch[1] = true`. On Linux that puts ⌘/⌥ in mac positions
   relative to Super/Alt.

## Repo visibility

`ssh/config`, `ssh/known_hosts` and the `wake-khandlab` alias carry
`khandlab.tailf80156.ts.net`, `192.168.99.250` and
`b4:2e:99:88:8e:d8`. Your README says the repo is private for exactly
that reason — it's public right now. Flip it back, or scrub those three
before you leave it open.
