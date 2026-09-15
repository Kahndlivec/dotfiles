#!/usr/bin/env bash
# Clean up SSH state inherited from someone else's dotfiles: host blocks
# pointing at their tailnet, IdentityFile lines for private keys you don't
# have, their public keys, their known_hosts entries, and shell aliases
# referring to hosts that aren't yours.
#
# Reports first, changes nothing without asking.
#
#   bash fix-ssh-config.sh
set -euo pipefail

ask() {
  local __var=$1 __prompt=$2 __default=${3:-} __reply=""
  if [[ -n "$__default" ]]; then
    read -r -p "$__prompt [$__default]: " __reply </dev/tty || true
    __reply="${__reply:-$__default}"
  else
    while [[ -z "$__reply" ]]; do
      read -r -p "$__prompt: " __reply </dev/tty || true
    done
  fi
  printf -v "$__var" '%s' "$__reply"
}

confirm() {
  local __reply=""
  read -r -p "$1 [y/N]: " __reply </dev/tty || true
  [[ "$__reply" =~ ^[Yy] ]]
}

STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP=~/.ssh-cleanup-backup-$STAMP
mkdir -p "$BACKUP"

# ─── what is actually mine ───────────────────────────────────────────
tailscale_bin() {
  if command -v tailscale >/dev/null 2>&1; then command -v tailscale
  elif [[ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]]; then
    echo /Applications/Tailscale.app/Contents/MacOS/Tailscale
  else return 1; fi
}

SUFFIX=""
MY_PEERS=()
if TS=$(tailscale_bin 2>/dev/null); then
  SUFFIX=$("$TS" status --json 2>/dev/null \
    | sed -n 's/.*"MagicDNSSuffix"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1 || true)
  mapfile -t MY_PEERS < <("$TS" status 2>/dev/null \
    | awk 'NF >= 4 && $1 ~ /^100\./ {print $2}' || true)
fi

echo "═══ Your tailnet"
if [[ -n "$SUFFIX" ]]; then
  echo "  suffix: $SUFFIX"
  for p in "${MY_PEERS[@]}"; do echo "  peer:   $p.$SUFFIX"; done
else
  echo "  Tailscale not running or not found — can't tell yours from theirs"
  echo "  automatically. You'll be asked about each entry."
fi

# ─── ~/.ssh/config ───────────────────────────────────────────────────
echo
echo "═══ ~/.ssh/config"
if [[ ! -f ~/.ssh/config ]]; then
  echo "  (no file)"
else
  cp ~/.ssh/config "$BACKUP/config"
  echo "  backed up to $BACKUP/config"
  echo
  # One line per host block: alias -> hostname
  awk '
    /^[[:space:]]*Host[[:space:]]/ {
      if (alias != "") printf "  %-20s %s\n", alias, (hn == "" ? "(no HostName)" : hn)
      alias = $2; hn = ""; next
    }
    /^[[:space:]]*HostName[[:space:]]/ { hn = $2 }
    END { if (alias != "") printf "  %-20s %s\n", alias, (hn == "" ? "(no HostName)" : hn) }
  ' ~/.ssh/config

  # IdentityFile lines whose key is missing are a silent auth failure.
  echo
  MISSING=0
  while read -r keypath; do
    expanded="${keypath/#\~/$HOME}"
    if [[ -n "$expanded" && ! -f "$expanded" ]]; then
      echo "  ! IdentityFile points at a key you don't have: $keypath"
      MISSING=1
    fi
  done < <(awk '/^[[:space:]]*IdentityFile[[:space:]]/ {print $2}' ~/.ssh/config)
  (( MISSING )) || echo "  IdentityFile lines: all present (or none)"

  echo
  echo "  Options:"
  echo "    1) start fresh — archive this file, write a new one"
  echo "    2) leave it alone, I'll edit by hand"
  ask CHOICE "  Which" "2"

  if [[ "$CHOICE" == "1" ]]; then
    mv ~/.ssh/config "$BACKUP/config.removed"
    touch ~/.ssh/config && chmod 600 ~/.ssh/config
    echo "  Cleared. Old file: $BACKUP/config.removed"
    echo "  Now run:  bash setup-ssh.sh"
  fi
fi

# ─── inherited public keys ───────────────────────────────────────────
echo
echo "═══ Public keys in ~/.ssh"
FOREIGN=()
for pub in ~/.ssh/*.pub; do
  [[ -e "$pub" ]] || continue
  priv="${pub%.pub}"
  if [[ -f "$priv" ]]; then
    echo "  keep  $(basename "$pub")  (you have the private half)"
  else
    echo "  ?     $(basename "$pub")  — no matching private key, so it's not yours"
    FOREIGN+=("$pub")
  fi
done
[[ -e ~/.ssh/id_ed25519.pub || -e ~/.ssh/id_rsa.pub ]] || \
  echo "  ! you have no personal keypair — generate one: ssh-keygen -t ed25519"

if (( ${#FOREIGN[@]} > 0 )) && confirm "  Move the unmatched public keys to the backup?"; then
  for f in "${FOREIGN[@]}"; do mv "$f" "$BACKUP/"; echo "  moved $(basename "$f")"; done
fi

# ─── known_hosts ─────────────────────────────────────────────────────
echo
echo "═══ ~/.ssh/known_hosts"
if [[ -f ~/.ssh/known_hosts ]]; then
  cp ~/.ssh/known_hosts "$BACKUP/known_hosts"
  echo "  $(wc -l < ~/.ssh/known_hosts | tr -d ' ') entries, backed up"
  echo "  These are their machines' host keys. Stale ones cause"
  echo "  'REMOTE HOST IDENTIFICATION HAS CHANGED' later."
  if confirm "  Clear it? (you'll re-confirm fingerprints on first connect)"; then
    mv ~/.ssh/known_hosts "$BACKUP/known_hosts.removed"
    echo "  cleared"
  fi
else
  echo "  (no file)"
fi

# ─── shell config ────────────────────────────────────────────────────
echo
echo "═══ ~/.zshrc"
if [[ -f ~/.zshrc ]]; then
  cp ~/.zshrc "$BACKUP/zshrc"
  HITS=$(grep -nE 'ts\.net|tailscale|homelab|emacsclient|ssh -t|100\.[0-9]+\.[0-9]+\.[0-9]+' ~/.zshrc || true)
  if [[ -n "$HITS" ]]; then
    echo "  Lines mentioning remote hosts:"
    echo "$HITS" | sed 's/^/    /'
    echo
    echo "  Most of these use the SSH alias, not a hostname — those are fine"
    echo "  once ~/.ssh/config points the alias at your box. Only edit lines"
    echo "  with a literal hostname or 100.x IP in them."
  else
    echo "  nothing host-specific found"
  fi
else
  echo "  (no file)"
fi

# ─── the rest of the dotfiles ────────────────────────────────────────
echo
echo "═══ Literal host references elsewhere in the dotfiles"
DOTS=~/Documents/dotfiles
if [[ -d "$DOTS" ]]; then
  grep -rInE 'ts\.net|100\.[0-9]+\.[0-9]+\.[0-9]+|([0-9a-f]{2}:){5}[0-9a-f]{2}' \
    "$DOTS" --exclude-dir=.git 2>/dev/null | sed 's/^/  /' || echo "  none found"
  echo
  echo "  Anything above is their network. Scripts that take the host as an"
  echo "  argument are fine; hardcoded values in docs or configs are not."
else
  echo "  no ~/Documents/dotfiles"
fi

cat <<EOF

═══ Done

Backup of everything touched: $BACKUP

Next:

  bash setup-ssh.sh morskycertlab.taile9d697.ts.net <your-user-on-that-box> homelab

Keeping the alias as 'homelab' means verify-setup.sh, REMOTE.md and the
existing shell aliases all keep working — only the HostName changes.

Then:

  bash setup-homelab-terminal.sh homelab
  bash setup-homelab-emacs.sh homelab
EOF
