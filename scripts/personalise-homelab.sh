#!/usr/bin/env bash
# Replace inherited host values (MAC address, LAN IP, hostname) with the
# real ones read off your own box.
#
#   bash personalise-homelab.sh [ssh-alias]
set -euo pipefail

HOST="${1:-homelab}"

confirm() {
  local __reply=""
  read -r -p "$1 [y/N]: " __reply </dev/tty || true
  [[ "$__reply" =~ ^[Yy] ]]
}

echo "== Reading values from $HOST"

# The interface carrying the default route is the one that matters for both
# wake-on-LAN and the LAN address. Wi-Fi can't do WoL reliably; if this
# comes back as a wlan interface, the wake alias won't work.
read -r IFACE MAC LAN_IP REMOTE_HOST < <(ssh "$HOST" 'bash -s' <<'REMOTE'
iface=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
mac=$(cat "/sys/class/net/$iface/address" 2>/dev/null)
lan=$(ip -4 -o addr show dev "$iface" 2>/dev/null | awk '{split($4,a,"/"); print a[1]; exit}')
echo "${iface:-?} ${mac:-?} ${lan:-?} $(hostname)"
REMOTE
)

echo "  hostname:  $REMOTE_HOST"
echo "  interface: $IFACE"
echo "  MAC:       $MAC"
echo "  LAN IP:    $LAN_IP"

case "$IFACE" in
  wl*|wlan*) echo "  ! wireless — wake-on-LAN won't work over Wi-Fi" ;;
esac

STAMP=$(date +%Y%m%d-%H%M%S)

# ─── ~/.zshrc ────────────────────────────────────────────────────────
echo
echo "== ~/.zshrc"
if grep -qE "^alias wake-.*wakeonlan" ~/.zshrc 2>/dev/null; then
  OLD=$(grep -E "^alias wake-.*wakeonlan" ~/.zshrc)
  NEW="alias wake-$REMOTE_HOST='wakeonlan $MAC'"
  echo "  old:  $OLD"
  echo "  new:  $NEW"
  if confirm "  Replace?"; then
    cp ~/.zshrc ~/.zshrc.bak.$STAMP
    # ed-style: delete the old alias line, append the new one in its place
    awk -v new="$NEW" '/^alias wake-.*wakeonlan/ { print new; next } { print }' \
      ~/.zshrc > ~/.zshrc.new && mv ~/.zshrc.new ~/.zshrc
    echo "  done (backup: ~/.zshrc.bak.$STAMP)"
  fi
else
  echo "  no wakeonlan alias found — nothing to change"
fi

# ─── ~/.ssh/config ───────────────────────────────────────────────────
echo
echo "== ~/.ssh/config"
if grep -qE "^[[:space:]]*Host[[:space:]]+$HOST-lan([[:space:]]|\$)" ~/.ssh/config 2>/dev/null; then
  echo "  $HOST-lan already exists"
elif [[ "$LAN_IP" != "?" ]]; then
  USER_ON_BOX=$(ssh "$HOST" 'whoami')
  echo "  Add a LAN shortcut? Faster than Tailscale when you're on the same"
  echo "  network, and it still works when MagicDNS is being difficult."
  echo
  echo "    Host $HOST-lan"
  echo "        HostName $LAN_IP"
  echo "        User $USER_ON_BOX"
  echo "        RequestTTY no"
  if confirm "  Add it?"; then
    cp ~/.ssh/config ~/.ssh/config.bak.$STAMP
    cat >> ~/.ssh/config <<EOF

Host $HOST-lan
    HostName $LAN_IP
    User $USER_ON_BOX
    RequestTTY no
EOF
    chmod 600 ~/.ssh/config
    echo "  added (backup: ~/.ssh/config.bak.$STAMP)"
  fi
fi

# ─── anything still pointing at someone else ─────────────────────────
echo
echo "== Remaining foreign values"
FOUND=0
for f in ~/.zshrc ~/.ssh/config; do
  [[ -f "$f" ]] || continue
  HITS=$(grep -nE '([0-9a-f]{2}:){5}[0-9a-f]{2}|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|\.ts\.net' "$f" \
    | grep -vF "$MAC" | grep -vF "$LAN_IP" || true)
  if [[ -n "$HITS" ]]; then
    echo "  $f:"
    echo "$HITS" | sed 's/^/    /'
    FOUND=1
  fi
done

DOTS=~/Documents/dotfiles
if [[ -d "$DOTS" ]]; then
  HITS=$(grep -rInE '([0-9a-f]{2}:){5}[0-9a-f]{2}|\.ts\.net' "$DOTS" --exclude-dir=.git 2>/dev/null \
    | grep -vF "$MAC" || true)
  if [[ -n "$HITS" ]]; then
    echo "  $DOTS:"
    echo "$HITS" | sed 's/^/    /'
    FOUND=1
  fi
fi
(( FOUND )) || echo "  none"

cat <<EOF

== Done

  exec zsh
  wake-$REMOTE_HOST

For wake-on-LAN to actually work, $REMOTE_HOST needs it enabled in the NIC
and usually in the BIOS too:

  ssh $HOST "sudo ethtool $IFACE | grep Wake"
  ssh $HOST "sudo ethtool -s $IFACE wol g"     # 'g' = wake on magic packet

That ethtool setting resets on reboot on most distros — make it a systemd
unit or a NetworkManager dispatcher script if you want it to stick.
EOF
