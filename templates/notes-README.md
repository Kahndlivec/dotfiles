# notes

Org notes: Matfyz lectures and problem sheets, competitive programming, ML and
agency work. Written in **Doom Emacs**, read on the **iPad** through Working
Copy + Orgro. This repo is the only source of truth — no Drive copy, no
schedule, no sync daemon.

## Structure

| Path | What goes in it |
|---|---|
| `inbox.org` | anything caught in a hurry, sorted later |
| `todo.org` | tasks |
| `school.org` | lectures, deadlines, exam dates (scheduled items) |
| `cp-log.org` | one entry per Codeforces problem: idea, and what I missed |
| `math-log.org` | scratch maths by date |
| `denote/` | permanent notes, one topic per file |
| `assets/` | handwriting from the iPad and pasted images |

The first three are the agenda files. `cp-log.org` and `math-log.org` are
date trees, so entries land under today automatically.

## Keys

All under `SPC n`, from any buffer:

| Key | Does |
|---|---|
| `SPC n c` | capture (inbox, todo, school, CP problem, maths scratch) |
| `SPC n a` | agenda |
| `SPC n n` | new permanent note (denote) |
| `SPC n f` / `SPC n s` | find a note / search inside all notes |
| `SPC n l` / `SPC n b` | insert a link / show backlinks |
| `SPC n i` | insert the newest iPad export at the cursor |
| `SPC n I` | pick an older export |
| `SPC n v` | paste an image from the clipboard |
| `SPC n p` | **save**: commit, rebase, push |

In a note: `C-c C-x C-l` renders the LaTeX fragment at point, `SPC m l p`
toggles previews. Maths is written as plain `$...$` and `\[...\]`.

## The iPad loop

```
GoodNotes page or lasso  →  Drive/Org-inbox  →  SPC n i  →  note + assets/
                                                               ↓ SPC n p
                              iPad: Working Copy → Orgro  ←  GitHub
```

1. **iPad:** lasso the derivation or export the page → Share → PNG → Files →
   Drive → `Org-inbox`.
2. **Emacs:** in the note you're writing, `SPC n i`. The image is copied into
   `assets/` and linked relative to the note, so it travels with the repo.
3. **Save:** `SPC n p`.
4. **Read anywhere:** pull in Working Copy on the iPad, open the file in Orgro.

Nothing is automatic. If it isn't pushed, it isn't on the other machine.

## Conventions

- **One idea per denote file**, tagged from: `math analysis algebra cp ml linux
  emacs mff agency ref`. Lecture-by-lecture material stays in `school.org`.
- **Images go in `assets/`**, never linked from `~/GoogleDrive` — a link into a
  network mount breaks when it isn't mounted and can't be followed on the iPad.
- **Don't rename note files by hand**; `SPC n R` keeps the links intact.
- **Work on one machine at a time**, or `SPC n p` before switching. The save
  rebases, so a forgotten push means a conflict to fix by hand.

## If something goes wrong

| Symptom | Fix |
|---|---|
| `SPC n i` says the inbox is empty | Drive hasn't synced yet, or the mount is down: `ls ~/GoogleDrive/Org-inbox`, then `systemctl --user restart rclone-gdrive` |
| Push fails | you're offline, or the other machine pushed first: `git pull --rebase` then `git push` |
| Images missing on the iPad | pull in Working Copy; Orgro reads `assets/` from the clone, not from Drive |
| A note is lost or wrecked | it's in git: `git log -p -- path/to/note.org` |

Setup for a new machine lives in the dotfiles repo: `./install.sh notes`.
