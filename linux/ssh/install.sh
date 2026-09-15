#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  linux/ssh/install.sh
#
#  Opt-in. setup.sh skips this unless WITH_SSH=1.
#
#  SSH is network state, not dotfiles: it depends on hostnames and keys
#  that want settling separately from a machine build. It's also the one
#  file where a mistake blocks `git push` on every machine at once — a
#  bad option makes OpenSSH refuse the whole config, not just that line.
#
#      bash linux/ssh/install.sh
# ═══════════════════════════════════════════════════════════════════
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

mkdir -p ~/.ssh/cm
chmod 700 ~/.ssh ~/.ssh/cm

if [[ -f ~/.ssh/config ]] && ! diff -q "$HERE/config" ~/.ssh/config >/dev/null 2>&1; then
  BAK=~/.ssh/config.bak-$(date +%Y%m%d-%H%M%S)
  cp -a ~/.ssh/config "$BAK"
  printf '  \033[33m–\033[0m backed up existing config to %s\n' "$BAK"
fi

cp -a "$HERE/config" ~/.ssh/config
chmod 600 ~/.ssh/config

# Parse check. Catches UseKeychain-style mistakes now rather than on the
# next git push. Any bad option makes ssh -G fail.
if ssh -G tower >/dev/null 2>&1; then
  printf '  \033[32m✓\033[0m ~/.ssh/config parses\n'
else
  printf '  \033[31m✗\033[0m ~/.ssh/config has a bad option. Run: ssh -G tower\n'
  exit 1
fi

printf '  \033[32m✓\033[0m ~/.ssh/cm (ControlPath needs it to exist)\n'
