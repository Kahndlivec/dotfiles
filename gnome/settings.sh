#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  gnome/settings.sh — GNOME keybindings and desktop settings. Re-runnable.
#
#  Run from a terminal INSIDE your GNOME session (it needs the session bus).
#  install.sh calls it; you can also run it on its own after editing.
#
#  App shortcuts live in gnome/shortcuts.conf — edit that file, not this one.
#  This file sets workspaces, window keys, key repeat, dock look, dark mode.
#
#      ./settings.sh            apply everything
#      ./settings.sh verify     compare GNOME's live keys with shortcuts.conf
#
#  Window keys set here:
#    Super+1..4  go to workspace         Super+Q    close window
#    Super+Shift+1..4  move window there  Alt+Tab    switch windows
#    Super+N     notifications            Super+Tab  switch apps
#
#  Undo every key change and get GNOME's defaults back:
#      gsettings reset-recursively org.gnome.shell.keybindings
#      gsettings reset-recursively org.gnome.desktop.wm.keybindings
#      gsettings reset-recursively org.gnome.shell.extensions.dash-to-dock
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

CONF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/shortcuts.conf"
MODE="${1:-apply}"

APP_DIRS=(
  "$HOME/.local/share/applications"
  /usr/share/applications
  /usr/local/share/applications
  /var/lib/snapd/desktop/applications
  /var/lib/flatpak/exports/share/applications
  "$HOME/.local/share/flatpak/exports/share/applications"
)

# find_desktop "a.desktop|b.desktop" → first one that exists
find_desktop() {
  local id dir
  IFS='|' read -ra ids <<<"$1"
  for id in "${ids[@]}"; do
    for dir in "${APP_DIRS[@]}"; do
      [[ -f "$dir/$id" ]] && { printf '%s' "$id"; return 0; }
    done
  done
  return 1
}

# Parse shortcuts.conf into two parallel arrays: SLOT_IDS (desktop files, in
# dock order) and SLOT_KEYS (GVariant key lists, "[]" for dock-only).
SLOT_IDS=() SLOT_KEYS=() MISSING=()
parse_conf() {
  local line parts app keys id k
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    read -ra parts <<<"$line"
    ((${#parts[@]} >= 2)) || continue
    app="${parts[-1]}"
    keys=""
    for k in "${parts[@]:0:${#parts[@]}-1}"; do
      [[ "$k" == "-" ]] && continue
      keys+="${keys:+, }'$k'"
    done
    if id="$(find_desktop "$app")"; then
      SLOT_IDS+=("$id"); SLOT_KEYS+=("[$keys]")
    else
      MISSING+=("$app")
    fi
  done <"$CONF"
}

# ── verify: does GNOME match shortcuts.conf right now? ──────────────────────
if [[ "$MODE" == verify ]]; then
  parse_conf
  bad=0
  mapfile -t live_favs < <(gsettings get org.gnome.shell favorite-apps | tr -d "[]'" | tr ',' '\n' | sed 's/^ *//')
  for i in "${!SLOT_IDS[@]}"; do
    n=$((i + 1))
    want_keys="${SLOT_KEYS[$i]}"; want_app="${SLOT_IDS[$i]}"
    [[ "$want_keys" == "[]" ]] && continue
    live_keys="$(gsettings get org.gnome.shell.keybindings "switch-to-application-$n")"
    live_app="${live_favs[$i]:-<none>}"
    if [[ "$live_app" == "$want_app" && "$live_keys" == "$want_keys" ]]; then
      ok "$want_keys → $want_app"
    else
      printf '  \033[31m✗\033[0m %s should open %s, but opens %s\n' "$want_keys" "$want_app" "$live_app"
      bad=1
    fi
  done
  for a in "${MISSING[@]}"; do warn "not installed: $a"; done
  [[ "$(gsettings get org.gnome.shell.extensions.dash-to-dock hot-keys 2>/dev/null)" == false ]] \
    || { printf '  \033[31m✗\033[0m Ubuntu Dock still grabs Super+1..9\n'; bad=1; }
  exit "$bad"
fi

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

# 2. App keys from shortcuts.conf. Dock order = key slot, so the dock is set
#    to exactly this order, followed by anything else you'd pinned yourself.
parse_conf
if ((${#SLOT_IDS[@]} > 9)); then
  warn "GNOME supports 9 app slots; entries after the 9th get no key"
fi
mapfile -t old_favs < <(gsettings get org.gnome.shell favorite-apps | tr -d "[]'" | tr ',' '\n' | sed 's/^ *//' | sed '/^$/d')
favs=("${SLOT_IDS[@]}")
for f in "${old_favs[@]}"; do
  printf '%s\n' "${favs[@]}" | grep -qxF "$f" || favs+=("$f")
done
fav_value="[$(printf "'%s'," "${favs[@]}" | sed 's/,$//')]"
gset org.gnome.shell favorite-apps "$fav_value"

for i in "${!SLOT_IDS[@]}"; do
  n=$((i + 1)); ((n <= 9)) || break
  gset $SHELL_KB "switch-to-application-$n" "${SLOT_KEYS[$i]}"
  [[ "${SLOT_KEYS[$i]}" != "[]" ]] && ok "${SLOT_KEYS[$i]} → ${SLOT_IDS[$i]}"
done
for a in "${MISSING[@]}"; do warn "not installed, skipped: $a"; done

# Read the dock back: if GNOME didn't take the order, every key is wrong.
sleep 1
live="$(gsettings get org.gnome.shell favorite-apps | tr -d " ")"
want="$(tr -d " " <<<"$fav_value")"
if [[ "$live" == "$want" ]]; then
  ok "dock order matches shortcuts.conf"
else
  warn "GNOME changed the dock order after it was set — keys may be off. Run: ~/dotfiles/install.sh check"
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
