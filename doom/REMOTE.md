# Remote Emacs on the homelab

## What this actually is

Emacs runs **on the homelab**, inside a tmux session that never closes. You SSH
in and attach to it. Your Mac is just a screen.

    Mac (Ghostty) ──ssh──> khandlab ──> tmux session "emacs" ──> emacs -nw

This is the same idea as VS Code Remote-SSH: the editor lives where the code
is, so clangd, git and ripgrep all run locally to the box. Nothing crosses the
network except your keystrokes and the screen.

It has one advantage over Remote-SSH: **the session persists**. Close your
laptop, come back tomorrow, and you're in the same buffers with the same window
layout. Nothing was reopened — it never stopped.

## Daily use

    eh                  connect (attaches, or creates if nothing's running)
    ⌃Space d            detach — leaves Emacs running on the box
    eh                  come back, exactly where you were

That's the whole workflow.

**Detaching is not quitting.** `⌃Space d` disconnects your terminal from the
session; Emacs keeps running. This is what you want almost always.

To actually quit Emacs on the homelab, `SPC q q` inside it. The tmux session
ends with it, and the next `eh` starts fresh.

If your connection drops — laptop asleep, wifi gone — nothing is lost. tmux
notices your terminal vanished and detaches automatically. `eh` reattaches.

## How tmux works

Four things, nested:

- **server** — one background process per machine, holds everything
- **session** — a workspace. Yours is called `emacs`
- **window** — like a tab, inside a session
- **pane** — a split, inside a window

The launcher runs `tmux new -A -s emacs emacs -nw`. `-A` means *attach if the
session exists, create it if it doesn't*, which is why one command does both
jobs.

Everything is driven by the **prefix**: press `⌃Space`, release, then a key.

    ⌃Space d        detach
    ⌃Space v        split vertically
    ⌃Space s        split horizontally
    ⌃Space z        zoom the current pane full-screen (toggle)
    ⌃Space c        new window
    ⌃Space n / p    next / previous window
    ⌃Space w        tree of all sessions and windows
    ⌃Space r        reload ~/.tmux.conf
    ⌃Space Enter    scrollback, with vim keys

You mostly won't need these — Emacs does its own splitting. tmux is here to
hold the session open, not to manage windows.

`C-h` `C-j` `C-k` `C-l` move between panes with no prefix, and tmux checks
whether the running program is Emacs first. If it is, the key is passed through
so Emacs moves its own windows. One set of keys, both programs.

## The one thing you lose

`⌃Space` is the tmux prefix, so Emacs never sees it — you lose `set-mark`.
In evil that barely matters: use visual mode instead. `⌃Space ⌃Space` sends a
real `⌃Space` through if you ever need it.

## Limits

**Terminal Emacs.** No images, no PDFs, no LaTeX previews, no inline org
images. Deliberate — that box is for code. Notes and maths stay on the Mac.

**Two configs.** Changes on the Mac don't propagate. Re-run
`setup-homelab-emacs.sh` to push them across; every step is idempotent.
`+local.el` on the homelab is excluded from the sync, so its `g++` override
survives.

**Reboot ends it.** tmux doesn't survive a restart of the machine. After a
homelab reboot, `eh` starts a fresh session.

## What went wrong getting here, and why

Worth keeping, because each of these will look familiar if it recurs.

**TRAMP froze Emacs.** TRAMP edits remote files by shelling out over SSH per
operation, and it parses the remote shell's output to work out what it's
talking to. Ubuntu's 20-line MOTD banner confused it. `touch ~/.hushlogin`
fixed the banner, but the architecture is still wrong for project work —
every LSP request and git call blocks the UI.

**`sudo: A terminal is required`.** `ssh host 'cmd'` gives no TTY, so sudo
can't prompt. `ssh -t` allocates one.

**`failed to look up local user "khandlab"`.** Passed the hostname where the
username goes. The machine is `khandlab`, the user is `khand`.

**`can't find socket`.** Non-login SSH shells don't get `XDG_RUNTIME_DIR`, so
emacsclient couldn't find the systemd daemon's socket.

**`Could not open file: /dev/pts/0`.** The daemon couldn't claim the terminal.
`loginctl enable-linger` runs the systemd user manager outside any login
session, and logind hands out device ACLs per session — so a session-less
daemon gets refused. This is why we abandoned the daemon for tmux.

**`missing or unsuitable terminal: xterm-ghostty`.** The real blocker.
Ghostty sets `TERM=xterm-ghostty` and Ubuntu's terminfo database has never
heard of it, so tmux refused to start. Fixed by shipping the entry over:
`infocmp -x xterm-ghostty | ssh homelab -- tic -x -`.

**`/Users/admin/.local/bin/e: No such file`.** zsh expanded `~` on the Mac
before sending the command. Single quotes and `$HOME` fix it.

## Quick reference

    eh                          connect
    ⌃Space d                    detach (Emacs keeps running)
    SPC q q                     quit Emacs on the homelab

    ssh homelab 'tmux ls'                   what's running
    ssh homelab 'tmux kill-server'          nuke everything, start clean
    ssh -t homelab                          plain shell on the box

    bash setup-homelab-emacs.sh homelab     push config changes across
