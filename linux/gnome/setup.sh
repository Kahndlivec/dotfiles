#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  linux/gnome/setup.sh
#
#  The Rectangle replacement, plus the keyboard and workspace settings
#  that macos/defaults.sh used to set with `defaults write`.
#
#  Everything here is gsettings, so it's reversible:
#    gsettings reset-recursively org.gnome.desktop.wm.keybindings
#
#  Idempotent. Run as your user, NOT with sudo.
# ═══════════════════════════════════════════════════════════════════
set -euo pipefail

ok(){ printf '  \033[32m✓\033[0m %s\n' "$1"; }
hdr(){ printf '\n\033[1;44m %s \033[0m\n' "$1"; }

g(){ gsettings set "$@"; }

# ═══════════════════════════════════════════════════════════════════
#  Workspaces — super+1..4
# ═══════════════════════════════════════════════════════════════════
hdr "workspaces"

# GNOME defaults to dynamic workspaces, which means the count changes
# under you and super+3 sometimes points at nothing. Fixed at 4.
g org.gnome.mutter dynamic-workspaces false
g org.gnome.desktop.wm.preferences num-workspaces 4

# Switching moves every monitor together. Set this true instead if you
# want the vertical iiyama to stay put while the main screen switches.
g org.gnome.mutter workspaces-only-on-primary false

# ─── THE GOTCHA ────────────────────────────────────────────────────
# Ubuntu binds super+1..9 to "launch the Nth app in the dock". That
# silently eats every binding below. Clear them first.
for i in 1 2 3 4 5 6 7 8 9; do
  g org.gnome.shell.keybindings "switch-to-application-$i" "[]"
done
ok "freed super+1..9 from the dock"

for i in 1 2 3 4; do
  g org.gnome.desktop.wm.keybindings "switch-to-workspace-$i" "['<Super>$i']"
  g org.gnome.desktop.wm.keybindings "move-to-workspace-$i"   "['<Super><Shift>$i']"
done
ok "super+1..4 switch, super+shift+1..4 move window"

# ═══════════════════════════════════════════════════════════════════
#  Tiling — the half of Rectangle that GNOME already does
# ═══════════════════════════════════════════════════════════════════
hdr "tiling"

# Halves are native. These are the defaults, set explicitly so the file
# documents the full keymap in one place.
g org.gnome.desktop.wm.keybindings toggle-tiled-left  "['<Super>Left']"
g org.gnome.desktop.wm.keybindings toggle-tiled-right "['<Super>Right']"
g org.gnome.desktop.wm.keybindings maximize           "['<Super>Up']"
g org.gnome.desktop.wm.keybindings unmaximize         "['<Super>Down']"
g org.gnome.desktop.wm.keybindings close              "['<Super>q']"
ok "halves, maximise, close"

# Quarters and custom layouts need an extension — see EXTENSIONS below.

# Alt-tab: GNOME groups by application by default, macOS-style. AltTab
# on the Mac was you undoing exactly that. Switch to window-level.
g org.gnome.desktop.wm.keybindings switch-windows      "['<Alt>Tab']"
g org.gnome.desktop.wm.keybindings switch-windows-backward "['<Alt><Shift>Tab']"
g org.gnome.desktop.wm.keybindings switch-applications "[]"
g org.gnome.desktop.wm.keybindings switch-applications-backward "[]"
ok "alt-tab cycles windows, not apps (replaces AltTab)"

# ═══════════════════════════════════════════════════════════════════
#  Keyboard
# ═══════════════════════════════════════════════════════════════════
hdr "keyboard"

# macos/defaults.sh: KeyRepeat 1 (15ms), InitialKeyRepeat 15 (225ms).
g org.gnome.desktop.peripherals.keyboard repeat-interval 15
g org.gnome.desktop.peripherals.keyboard delay 225
ok "key repeat 225ms / 15ms"

# US layout on the Italian ThinkPad: you touch-type ANSI, and this puts
# [ ] { } \ | @ # back on single keys instead of AltGr chords.
# Slovak second, toggled with super+space. Compose on Menu for the odd
# diacritic without switching layout.
g org.gnome.desktop.input-sources sources \
  "[('xkb', 'us'), ('xkb', 'sk(qwerty)')]"
g org.gnome.desktop.wm.keybindings switch-input-source \
  "['<Super>space']"
g org.gnome.desktop.wm.keybindings switch-input-source-backward \
  "['<Super><Shift>space']"

# caps -> control, in xkb. On the desktops this is all you need and you
# can skip keyd entirely. The ThinkPads still want keyd for the ISO
# keys — see linux/keyd/.
g org.gnome.desktop.input-sources xkb-options \
  "['ctrl:nocaps', 'compose:menu']"
ok "us + sk(qwerty), caps->ctrl, compose on Menu"

# ═══════════════════════════════════════════════════════════════════
#  Misc — the rest of macos/defaults.sh that has an equivalent
# ═══════════════════════════════════════════════════════════════════
hdr "misc"

g org.gnome.desktop.interface color-scheme 'prefer-dark'
g org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font Mono 11'
g org.gnome.desktop.interface clock-show-weekday true
g org.gnome.desktop.peripherals.touchpad tap-to-click true
g org.gnome.desktop.peripherals.touchpad natural-scroll true
g org.gnome.mutter center-new-windows true

# Screenshots to ~/Screenshots rather than ~/Pictures/Screenshots.
mkdir -p "$HOME/Screenshots"
ok "interface, touchpad, screenshots dir"

# ═══════════════════════════════════════════════════════════════════
cat <<'EXTENSIONS'

┌─ Install by hand, once, via Extension Manager ────────────────────┐
│                                                                   │
│  Tiling Shell   quarters + custom layouts. The other half of      │
│                 Rectangle. Set its shortcuts to super+ctrl+arrows │
│                 so they don't collide with the halves above.      │
│                                                                   │
│  Vitals         CPU/RAM/temp/net in the top bar. Replaces Stats.  │
│                 btop covers the deep dive from the terminal.      │
│                                                                   │
│  (Search is native — press Super and type. That was the only      │
│   thing you used Raycast for, so nothing to install.)             │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘

EXTENSIONS

printf '\033[1;42m gnome done — log out and back in \033[0m\n'
