# Notes: Linux ↔ iPad

Two separate problems that want two separate answers. Trying to solve
both with Google Drive is what makes this hard.

| | What moves | How |
|---|---|---|
| **Org text** | `.org` files you edit on both sides | git + Working Copy + beorg |
| **Handwriting** | GoodNotes PDFs, iPad → Linux, one way | Google Drive + rclone |

---

## 1. Org text — drop Google Drive entirely

There is no Google Drive client for Linux. GNOME Online Accounts gives
you a gvfs *mount*, not a sync — it stalls offline and it will lose an
org file eventually. Don't build on it.

You already own the pieces for a better version: Working Copy on the
iPads, and a shared private repo with Jakub.

```
~/org  ──git──►  GitHub  ──git──►  Working Copy (iPad)
                                        │ Files provider
                                        ▼
                                      beorg
```

**Setup, once:**

1. `~/org` is its own private repo. Not the dotfiles repo — notes churn
   constantly and you don't want that history mixed in.
2. iPad: clone it in Working Copy. In the Files app → Browse → Edit,
   make sure Working Copy is toggled on as a location.
3. iPad: install **beorg**. Settings → Sync method → **Choose Folder** →
   Link Folder → Working Copy → your repo. Sync Now.

beorg's "Choose Folder" mode reads and writes straight into the Working
Copy checkout. You commit and push from Working Copy when you're done.
(beorg also has a WebDAV mode aimed at Working Copy's built-in server,
but it needs both apps open in Split View to work — Choose Folder is
the one you want.)

**Alternatives if beorg doesn't suit:** *Plain Org* (paid, same Files-
provider approach, simpler), *Orgro* (read-only viewer, free — fine if
the iPad is just for reading).

**The conflict rule.** Give each side a job: iPad is **capture**,
desktop is **edit**. beorg captures to one `inbox.org`; you refile from
it in Emacs. Two devices editing the same heading is where git org sync
goes wrong, and a rule avoids it better than any tool does.

**Auto-commit on the Linux side** so you're never the one who forgot to
push:

```elisp
;; ~/.config/doom/config.el
(use-package! git-auto-commit-mode
  :hook (org-mode . (lambda ()
                      (when (string-prefix-p (expand-file-name "~/org/")
                                             (or buffer-file-name ""))
                        (git-auto-commit-mode 1))))
  :init (setq gac-automatically-push-p t
              gac-debounce-interval 300))
```

---

## 2. GoodNotes → org-noter

GoodNotes stays on the iPad. What crosses to Linux is a PDF, and your
Doom config is already set up to consume exactly that — you have
`(org +noter)` and `:tools pdf` enabled.

**iPad side:** GoodNotes → Settings → Auto-Backup → Google Drive, format
**PDF**, pick a folder. GoodNotes runs handwriting recognition, so the
exported PDF carries a text layer and stays searchable.

**Linux side:** one-way pull with rclone. This is the *only* thing
Google Drive is still doing, and it's read-only, so the sync problems
above don't apply.

```bash
rclone config            # new remote, type: drive, name: gdrive
mkdir -p ~/org/goodnotes
rclone sync gdrive:GoodNotes ~/org/goodnotes --progress
```

Put it on a systemd user timer so it runs every 15 minutes:

```ini
# ~/.config/systemd/user/goodnotes.service
[Unit]
Description=Pull GoodNotes PDFs from Drive

[Service]
Type=oneshot
ExecStart=/usr/bin/rclone sync gdrive:GoodNotes %h/org/goodnotes
```

```ini
# ~/.config/systemd/user/goodnotes.timer
[Unit]
Description=Pull GoodNotes PDFs every 15 min

[Timer]
OnBootSec=2min
OnUnitActiveSec=15min

[Install]
WantedBy=timers.target
```

```bash
systemctl --user enable --now goodnotes.timer
```

Add `goodnotes/` to `~/org/.gitignore` — those PDFs are large, they're
already backed up in Drive, and they'd bloat the repo the iPad clones.

**Then, in Emacs:** open the PDF, `M-x org-noter`. Notes land in an org
file beside it; `SPC n n` from your existing bindings still applies. The
lecture you wrote by hand on the iPad and the typed notes end up in the
same org tree, which is the point.

---

## 3. Reading PDFs on the vertical iiyama

Two tools, two jobs:

- **pdf-tools** inside Emacs — anything you're annotating, because
  org-noter depends on it. Evil gives you vim keys already.
- **sioyek** — standalone reading of long textbooks and papers. Vim
  keys, remembers position per document, and its smart-jump handles
  references and the table of contents better than zathura. Flatpak:
  `com.github.ahrm.sioyek`.

zathura is in the apt list as a lightweight fallback. Drop it if sioyek
sticks.

---

## Claude on Linux

You don't need a workaround — there's an official desktop app now.
Linux support for the Claude desktop app is in beta, and gives you the same Chat, Cowork, and Claude Code experience as on macOS and Windows: parallel sessions, visual diff review, an integrated terminal and editor, and live app preview. It's officially supported on Ubuntu 22.04+ and Debian 12+, x86_64 or arm64, installed through Anthropic's apt repository — so updates ride your normal apt upgrade rather than a separate in-app updater.

Install instructions: https://code.claude.com/docs/en/desktop-linux

Two gaps to know about: Computer Use is disabled entirely, voice dictation isn't included, and the Quick Entry global hotkey works on X11 but depends on the desktop environment's portal under Wayland.

You already have three other routes and they all still work: the
`claude` CLI (`@anthropic-ai/claude-code`, already in your npm globals),
`SPC l l` inside Doom, and claude.ai as a PWA in Brave.
