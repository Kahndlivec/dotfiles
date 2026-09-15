#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  gnome/settings.sh — GNOME keybindings and desktop settings. Re-runnable.
#
#  Run from a terminal INSIDE your GNOME session (it needs the session bus).
#  install.sh calls it; you can also run it on its own after editing.
#
#  ── The layout ─────────────────────────────────────────────────────────────
#    Super+E        Emacs            Super+1..4        go to workspace
#    Super+T / ⏎    Ghostty (tmux)   Super+Shift+1..4  send window there
#    Super+B        Brave            Super+Q           close window
#    Super+V        VS Code          Super+Tab         switch apps
#    Super+M        Spotify          Alt+Tab           switch windows
#    Super+F        Files            Super+N           notifications
#    Super          overview / search / launch anything
#    Super+←/→/↑    tile left / right / maximise (GNOME default)
#
#  App keys are RUN-OR-RAISE, not "launch": if the app is open you jump to
#  its window (switching workspace if needed); if not, it starts. This uses
#  GNOME's own switch-to-application-N mechanism, re-pointed from Super+1..9
#  to letters — native on Wayland, no extension.
#
#  Why no Super+V for Neovim: nvim is the in-terminal editor (Super+T, then
#  `v file`). VS Code is the second GUI editor you actually switch to all
#  day, so it gets the key. Change APPS below if you disagree.
# ═══════════════════════════════════════════════════════════════════════════
set -uo pipefail

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }

if [[ "${XDG_CURRENT_DESKTOP:-}" != *GNOME* ]] || ! command -v gsettings >/dev/null; then
  warn "not in a GNOME session — skipping GNOME settings (re-run gnome/settings.sh from GNOME)"
  exit 0
fi

# gset <schema> <key> <value> — skips quietly-but-visibly if the key doesn't
# exist on this GNOME version, instead of aborting the whole script.
gset() {
  if gsettings list-keys "$1" 2>/dev/null | grep -x "$2" >/dev/null; then
    gsettings set "$1" "$2" "$3" || warn "failed: $1 $2"
  else
    warn "no such key on this GNOME: $1 $2"
  fi
}

WM=org.gnome.desktop.wm.keybindings
SHELL_KB=org.gnome.shell.keybindings
MEDIA=org.gnome.settings-daemon.plugins.media-keys
DOCK=org.gnome.shell.extensions.dash-to-dock

# ── Apps: "key(s)|desktop-id candidates" ────────────────────────────────────
# Candidates cover apt, snap and flatpak installs; the first one found wins.
APPS=(
  "['<Super>e']|emacs.desktop emacs_emacs.desktop org.gnu.emacs.desktop"
  "['<Super>t', '<Super>Return']|com.mitchellh.ghostty.desktop ghostty.desktop ghostty_ghostty.desktop"
  "['<Super>b']|brave-browser.desktop com.brave.Browser.desktop brave_brave.desktop"
  "['<Super>v']|code.desktop com.visualstudio.code.desktop code_code.desktop"
  "['<Super>m']|spotify_spotify.desktop spotify.desktop com.spotify.Client.desktop"
  "['<Super>f']|org.gnome.Nautilus.desktop"
)

APP_DIRS=(
  "$HOME/.local/share/applications"
  /usr/share/applications
  /usr/local/share/applications
  /var/lib/snapd/desktop/applications
  /var/lib/flatpak/exports/share/applications
  "$HOME/.local/share/flatpak/exports/share/applications"
)

find_desktop() {
  local id dir
  for id in "$@"; do
    for dir in "${APP_DIRS[@]}"; do
      [[ -f "$dir/$id" ]] && { printf '%s' "$id"; return 0; }
    done
  done
  return 1
}

echo "  keybindings"

# 1. Free the keys we're about to use from their stock owners.
gset $DOCK hot-keys false                        # Ubuntu Dock grabs Super+1..9
gset $DOCK shortcut "[]"                         # …and Super+Q
gset $MEDIA home "[]"                            # Super+E opened Files on Ubuntu
gset $SHELL_KB toggle-message-tray "['<Super>n']"  # was Super+V and Super+M
gset $SHELL_KB focus-active-notification "[]"      # was Super+N
for i in $(seq 1 9); do
  gset $SHELL_KB "switch-to-application-$i" "[]"
done

# 2. Run-or-raise app keys. Favourites order = dock order = key slot.
favs=() slot=0
for entry in "${APPS[@]}"; do
  keys="${entry%%|*}"
  # shellcheck disable=SC2086
  if id=$(find_desktop ${entry#*|}); then
    slot=$((slot + 1))
    favs+=("'$id'")
    gset $SHELL_KB "switch-to-application-$slot" "$keys"
    ok "$keys → $id"
  else
    warn "not installed, no key: ${entry#*|}"
  fi
done
if ((${#favs[@]})); then
  gset org.gnome.shell favorite-apps "[$(IFS=,; echo "${favs[*]}")]"
fi

# 3. Workspaces: a fixed four.
gset org.gnome.mutter dynamic-workspaces false
gset org.gnome.desktop.wm.preferences num-workspaces 4
for i in 1 2 3 4; do
  gset $WM "switch-to-workspace-$i" "['<Super>$i']"
  gset $WM "move-to-workspace-$i"   "['<Super><Shift>$i']"
done
ok "Super+1..4 workspaces, Super+Shift+1..4 move window"

# 4. Windows.
gset $WM close "['<Super>q', '<Alt>F4']"
gset $WM switch-windows "['<Alt>Tab']"
gset $WM switch-windows-backward "['<Shift><Alt>Tab']"
gset $WM switch-applications "['<Super>Tab']"
gset $WM switch-applications-backward "['<Shift><Super>Tab']"
ok "Super+Q close, Alt+Tab windows, Super+Tab apps"

echo "  desktop"

# Key repeat. Your Mac ended on KeyRepeat 2 / InitialKeyRepeat 15 because
# faster than 30 ms outran Emacs' redisplay — same values here, in ms.
gset org.gnome.desktop.peripherals.keyboard delay "uint32 225"
gset org.gnome.desktop.peripherals.keyboard repeat-interval "uint32 30"

# Laptop keyboard: Caps Lock becomes Control, where the HHKB has it.
gset org.gnome.desktop.input-sources xkb-options "['ctrl:nocaps']"

# Mouse: no acceleration curve (what LinearMouse was for).
gset org.gnome.desktop.peripherals.mouse accel-profile "'flat'"

# Look.
gset org.gnome.desktop.interface color-scheme "'prefer-dark'"
gset org.gnome.desktop.interface monospace-font-name "'JetBrainsMono Nerd Font Mono 11'"
gset org.gnome.desktop.interface show-battery-percentage true
gset org.gnome.desktop.interface clock-show-weekday true
gset org.gnome.desktop.interface enable-hot-corners false
gset org.gnome.mutter center-new-windows true

# Ubuntu Dock: bottom, hidden until you need it.
gset $DOCK dock-position "'BOTTOM'"
gset $DOCK dock-fixed false
gset $DOCK autohide true
gset $DOCK intellihide true
gset $DOCK extend-height false
gset $DOCK show-trash false
gset $DOCK show-mounts false
ok "key repeat 225/30 ms, ctrl:nocaps, flat mouse, dark, bottom autohide dock"
