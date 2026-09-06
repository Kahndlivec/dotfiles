#!/usr/bin/env bash
# Set up ~/.ssh/config for a remote box, with the ControlMaster settings that
# make TRAMP usable rather than infuriating.
#
#   bash setup-ssh.sh                                   # asks for everything
#   bash setup-ssh.sh <hostname> <remote-user> [alias]  # or pass it in
#
# Detects Tailscale peers automatically when Tailscale is running. Nothing is
# hardcoded: run it once per machine you want to reach.
set -euo pipefail

# ─── helpers ─────────────────────────────────────────────────────────
# read from the terminal, not stdin: this script gets piped to sometimes.
ask() {  # ask <varname> <prompt> [default]
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

confirm() {  # confirm <prompt>  -> 0 if yes
  local __reply=""
  read -r -p "$1 [y/N]: " __reply </dev/tty || true
  [[ "$__reply" =~ ^[Yy] ]]
}

tailscale_bin() {
  if command -v tailscale >/dev/null 2>&1; then
    command -v tailscale
  elif [[ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]]; then
    echo /Applications/Tailscale.app/Contents/MacOS/Tailscale
  else
    return 1
  fi
}

# ─── work out the hostname ───────────────────────────────────────────
HOST="${1:-}"
REMOTE_USER="${2:-}"
ALIAS="${3:-}"

if [[ -z "$HOST" ]]; then
  TS=$(tailscale_bin 2>/dev/null || true)
  if [[ -n "$TS" ]]; then
    # MagicDNSSuffix turns a short peer name into a fully qualified one.
    # sed, not jq — jq isn't in the Brewfile and this is one JSON line.
    SUFFIX=$("$TS" status --json 2>/dev/null \
      | sed -n 's/.*"MagicDNSSuffix"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
      | head -1 || true)

    # Peer lines are: <ip> <shortname> <owner@> <os> <state>. Skip blanks
    # and the "# Health check" footer some versions print.
    mapfile -t PEERS < <("$TS" status 2>/dev/null \
      | awk 'NF >= 4 && $1 ~ /^100\./ {print $2}' || true)

    if (( ${#PEERS[@]} > 0 )); then
      echo "Tailscale peers on this tailnet:"
      for i in "${!PEERS[@]}"; do
        printf "  %2d) %s%s\n" "$((i+1))" "${PEERS[$i]}" \
          "${SUFFIX:+.$SUFFIX}"
      done
      echo "   0) enter a hostname by hand"
      echo
      ask PICK "Which one" "0"
      if [[ "$PICK" =~ ^[0-9]+$ ]] && (( PICK >= 1 && PICK <= ${#PEERS[@]} )); then
        HOST="${PEERS[$((PICK-1))]}${SUFFIX:+.$SUFFIX}"
        # a sensible default alias: the short name
        ALIAS="${ALIAS:-${PEERS[$((PICK-1))]}}"
      fi
    fi
  fi
fi

if [[ -z "$HOST" ]]; then
  echo
  echo "Enter the hostname or IP. For Tailscale this is the full name,"
  echo "e.g. homelab.tail1234.ts.net — find it with: tailscale status"
  ask HOST "Hostname or IP"
fi

[[ -n "$REMOTE_USER" ]] || ask REMOTE_USER "Username on that machine" "$(whoami)"
[[ -n "$ALIAS" ]] || ask ALIAS "Short alias to use locally" "homelab"

echo
echo "  ssh $ALIAS  →  $REMOTE_USER@$HOST"
confirm "Write this to ~/.ssh/config?" || { echo "Nothing written."; exit 0; }

# ─── write it ────────────────────────────────────────────────────────
mkdir -p ~/.ssh && chmod 700 ~/.ssh
touch ~/.ssh/config

if grep -qE "^[[:space:]]*Host[[:space:]]+$ALIAS([[:space:]]|\$)" ~/.ssh/config 2>/dev/null; then
  echo
  echo "A '$ALIAS' entry already exists in ~/.ssh/config."
  echo "Edit it by hand, or re-run with a different alias. Not touching it."
  exit 0
fi

# ControlMaster needs somewhere to put its sockets.
mkdir -p ~/.ssh/cm && chmod 700 ~/.ssh/cm

# The Host * block is global, so it goes in exactly once no matter how many
# machines you add. A marker comment is how we know it's already there.
MARKER="# ─── tramp-friendly defaults (setup-ssh.sh) ───"
if ! grep -qF "$MARKER" ~/.ssh/config 2>/dev/null; then
  cat >> ~/.ssh/config <<EOF

$MARKER
# ControlMaster keeps one authenticated connection open per host and reuses
# it. This is the single biggest factor in whether remote editing feels
# instant or takes two seconds per keystroke.
Host *
    ControlMaster auto
    ControlPath ~/.ssh/cm/%r@%h:%p
    ControlPersist 10m
    ServerAliveInterval 30
    ServerAliveCountMax 3
    AddKeysToAgent yes
    UseKeychain yes
EOF
  echo "Added the global ControlMaster block."
fi

cat >> ~/.ssh/config <<EOF

Host $ALIAS
    HostName $HOST
    User $REMOTE_USER
    # TRAMP parses the remote shell prompt; a TTY confuses it.
    RequestTTY no
EOF

chmod 600 ~/.ssh/config
echo "Written. Testing..."
echo

if ssh -o ConnectTimeout=10 "$ALIAS" 'echo "  connected as $(whoami) on $(hostname)"'; then
  echo
  echo "Working. In Emacs:"
  echo "  SPC o H            $ALIAS in dired"
  echo "  SPC o S            shell on $ALIAS"
  echo "  SPC .  then  /ssh:$ALIAS:~/   open any remote file"
  echo
  echo "Next:  bash setup-homelab-terminal.sh $ALIAS"
  echo "       bash setup-homelab-emacs.sh $ALIAS"
  echo
  echo "If TRAMP ever hangs:  M-x tramp-cleanup-all-connections"
else
  echo
  echo "Couldn't connect. The config is written — fix the connection, then:"
  echo "  tailscale status          is the node up and are you on the tailnet?"
  echo "  ssh-add -l                is your key loaded?"
  echo "  ssh-copy-id $ALIAS        is your key on the remote box at all?"
  echo "  ssh -v $ALIAS             verbose output"
fi
