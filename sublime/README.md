# Sublime competitive-programming setup — portable bundle

A snapshot of a working macOS setup: Sublime Text 4 + NeoVintageous + clangd +
CppFastOlympicCoding, tuned for an HHKB Pro Classic.

## Install

```bash
bash install.sh
```

Works under any macOS username — paths are stored as a `__CP_HOME__`
placeholder and rewritten on install. Backs up anything it replaces and writes
`restore.sh` so the machine can be put back.

## What you need first

- **Sublime Text 4** — https://www.sublimetext.com/download
- **Xcode command line tools** — `xcode-select --install` (gives clang++, python3)
- Launch Sublime once and quit, so `Packages/User` exists
- Optional: `brew install gcc` (judge build), `brew install --cask ghostty`
  (interactive run)

## What lands where

| Payload | Destination |
|---|---|
| `payload/sublime-user/` | `~/Library/Application Support/Sublime Text/Packages/User/` |
| `payload/clangd/config.yaml` | `~/Library/Preferences/clangd/config.yaml` |
| `payload/dotcp/.cp/` | `~/.cp/` — the `bits/stdc++.h` shim and helper scripts |
| `payload/cpdir/` | `~/Documents/cp/` — project file and template library |

`~/Library/Preferences/clangd/` is the macOS path. `~/.config/clangd/` is
Linux-only and clangd ignores it on a Mac — a silent, expensive mistake.

## The keys

```
⌘⏎      run & test (FOC)          ⌃h ⌃j ⌃k ⌃l   move between panes
⌘⇧⏎     new test                  ⌘K h/j/k/l    split, focus follows
⌘⇧D     run under debugger        ⌘K x          close pane
⌘K p    toggle test panel         ⌘K z          zoom pane
⌘K f    template library          ⌘K b          sidebar
⌘K s    FOC stress                ⌃]            jump to definition
⌘K t    insert cp template        ⌘⇧U           find references
cp+Tab  insert cp template        ⌘⇧A           diagnostics panel
⌘B      build + sanitizers        ⌘' / ⌘⇧'      next / prev error
⌘⇧R     debug + in.txt            ⌘⇧C           fast + in.txt
⌘⇧K     compile only              ⌘⇧G           g++ judge build
⌘⇧T     run in Ghostty            ⌘⇧S           stress vs brute.cpp
```

Zero `alt+` bindings, by design: on an HHKB, ⌥ is a bottom-corner key that
cannot comfortably combine with the right hand.

## Two stress testers, different conventions

- **⌘⇧S** → `~/.cp/stress.sh`, uses `brute.cpp`.
- **⌘K s** → FOC's own. For `A.cpp` it needs `A__Good.cpp` and
  `A__Generator.cpp` beside it — exact names, double underscore — and the
  generator reads its **seed from stdin**, not `argv`.

## Flags live in three files and must agree

`C++ CP.sublime-build`, `FastOlympicCoding.sublime-settings`, and clangd's
`config.yaml`. If they drift, clangd red-squiggles code that compiles, or FOC
fails on files `⌘B` builds fine. `cp-verify.sh` compares all three.

## Gotchas that cost real time

1. **Never put `$HOME` in a `.sublime-build`.** Sublime expands `$`-variables
   before the shell sees them, so it becomes an empty string. Absolute paths,
   or move the logic into a script in `~/.cp/`.
2. **A build key doing nothing** usually means the focused view was not a saved
   file — check the `[shell_cmd: …]` line at the bottom of the build panel for
   an empty `''` where `${file}` should be.
3. **Build system choice is per window.** Open the project file.
4. **FOC's override file is `Packages/User/FastOlympicCoding.sublime-settings`**
   — no platform suffix. The `FastOlympicCoding (OSX).sublime-settings` inside
   the package folder is the defaults layer; patching it works until Package
   Control updates the package.
5. **FOC owns Tab in `.cpp` files** via its own keymap. The `cp` snippet's
   `<tabTrigger>` therefore cannot fire on Tab — it only makes `cp` appear in
   the completion popup. Expansion happens through the User keymap's macro.
6. **An empty `bits/stdc++.h` shim compiles fine** and then every symbol is
   undeclared. If you see `'cin' was not declared in this scope`, count the
   lines in the shim before touching any flags.
