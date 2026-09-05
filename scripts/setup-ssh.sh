#!/usr/bin/env bash
# Set up ~/.ssh/config for the homelab, with the ControlMaster settings that
# make TRAMP usable rather than infuriating.
#
#   bash setup-ssh.sh <tailscale-hostname> <remote-user>
# e.g.
#   bash setup-ssh.sh homelab.tail1234.ts.net jakub
set -euo pipefail

HOST="${1:-}"; USER_="${2:-}"
if [[ -z "$HOST" || -z "$USER_" ]]; then
  echo "Usage: bash setup-ssh.sh <tailscale-hostname> <remote-user>"
  echo
  echo "Find the hostname with:  tailscale status"
  exit 1
fi

mkdir -p ~/.ssh && chmod 700 ~/.ssh

if grep -q "^Host homelab$" ~/.ssh/config 2>/dev/null; then
  echo "A 'homelab' entry already exists in ~/.ssh/config — not touching it."
  exit 0
fi

# ControlMaster needs somewhere to put its sockets.
mkdir -p ~/.ssh/cm && chmod 700 ~/.ssh/cm

cat >> ~/.ssh/config <<EOF

# ─── added for Doom Emacs / TRAMP ──────────────────────────────────
# ControlMaster keeps one authenticated connection open per host and
# reuses it. This is the single biggest factor in whether remote editing
# feels instant or takes two seconds per keystroke.
Host *
    ControlMaster auto
    ControlPath ~/.ssh/cm/%r@%h:%p
    ControlPersist 10m
    ServerAliveInterval 30
    ServerAliveCountMax 3
    AddKeysToAgent yes
    UseKeychain yes

Host homelab
    HostName $HOST
    User $USER_
    # TRAMP parses the remote shell prompt; a TTY confuses it.
    RequestTTY no
EOF

chmod 600 ~/.ssh/config
echo "Written. Testing..."
echo

if ssh -o ConnectTimeout=10 homelab 'echo "  connected as $(whoami) on $(hostname)"'; then
  echo
  echo "Working. In Emacs:"
  echo "  SPC o H            homelab in dired"
  echo "  SPC o S            shell on the homelab"
  echo "  SPC .  then  /ssh:homelab:~/   open any remote file"
  echo
  echo "If TRAMP ever hangs:  M-x tramp-cleanup-all-connections"
else
  echo
  echo "Couldn't connect. Check:"
  echo "  tailscale status          is the node up and are you on the tailnet?"
  echo "  ssh-add -l                is your key loaded?"
  echo "  ssh -v homelab            verbose output"
fi
