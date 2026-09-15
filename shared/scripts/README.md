# Which file does what

Your repo: `~/Documents/dotfiles`  ·  Sublime bundle: `~/Documents/cp-portable`

Keep all of these in `~/Downloads` (or anywhere, as long as they're together —
several call each other).

## Updating the backup — the only one you normally run

```bash
cd ~/Downloads
bash dotfiles-update.sh "what I changed"
bash dotfiles-update.sh --dry-run        # look first, change nothing
```

Re-collects every config, re-exports the Sublime bundle if it's stale, runs the
secret scan, commits, pushes. Needs `dotfiles-init.sh` beside it.

## The rest

| File | What it does | When |
|---|---|---|
| `dotfiles-init.sh` | the collector — copies configs into the repo, writes `.gitignore` / `bootstrap.sh` / `README.md`, scans for secrets | called by update; run directly only to change the repo path |
| `cp-export.sh` | rebuilds `~/Documents/cp-portable` from your live Sublime setup | called by update; run directly after big Sublime changes |
| `cp-verify.sh` | read-only health check of the whole CP setup | when something breaks |
| `macos-prefs.sh` | Rectangle / AltTab / LinearMouse / Raycast settings | after changing app settings |
| `.clang-format` | C++ formatting — copy to `~/.clang-format` | once |
| `cp-install.sh` | installs the Sublime keymap, FOC settings, snippet, macro, project | only on a fresh machine |
| `cp-patch-judge.sh` + `judge.sh` | version-agnostic g++ for ⌘⇧G | already done |

## Doing it by hand instead

Nothing above is required. This works:

```bash
cd ~/Documents/dotfiles
git add -A
git commit -m "message"
git push
```

Use `git add -f <file>` for anything with no extension or a `.png` — the
`.gitignore` is an allowlist and skips those silently.

## The one rule

Edit configs **where the app reads them** (`~/.zshrc`, `~/.config/nvim/`,
`~/.clang-format`), never inside the repo. The repo is a mirror; a collection
run overwrites mirrored files from their sources.

Safe to hand-edit in the repo, because nothing overwrites them:
`hhkb/`, `macos/defaults.sh`, `README.md`.

## Undo anything

```bash
cd ~/Documents/dotfiles
git restore --source=HEAD --staged --worktree .   # discard uncommitted changes
git reset --hard <commit>                          # go back to a commit
```

Everything committed and pushed is recoverable. You cannot lose it.
