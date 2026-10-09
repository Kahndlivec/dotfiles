# emacs/ — parked

The Doom Emacs setup that was the main editor until October 2026. It was
dropped because Emacs kept crashing and was slow, and the org notes workflow
cost more time than it saved. **Sublime Text replaced it** (see `sublime/`).

Nothing here is installed, linked or read by `install.sh`. It is kept so the
work is not lost and can be looked at later.

| Path | Was |
|---|---|
| `doom/` | `~/.config/doom` — `init.el`, `config.el`, `packages.el`, `+cp.el` (competitive programming), `+scans.el` (iPad page import), snippets, templates. `SETUP.md` explains the choices. |
| `people/<name>.el` | per-person name and mail, loaded by `config.el` from `~/.config/dotfiles/person/doom.el` |
| `notes-README.md` | the README the org notes repo was created with |

## Removing Emacs from a machine

```bash
~/dotfiles/install.sh prune
```

It lists the Emacs packages and `~/.config/emacs` (the Doom install), and
removes them after you type `yes`.

## Bringing it back, by hand

```bash
sudo apt install emacs-pgtk libvterm-dev libpoppler-glib-dev libpoppler-private-dev
ln -s ~/dotfiles/emacs/doom ~/.config/doom
cp ~/dotfiles/emacs/people/<name>.el ~/.config/dotfiles/person/doom.el
git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs
~/.config/emacs/bin/doom install
```

`emacs-pgtk` is in `packages/remove-apt.txt`, so take it out of that file
first or the next `prune` will offer to remove it again.
