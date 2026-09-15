#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  bootstrap.sh — repo root
#
#      bash bootstrap.sh                  # auto-detect role
#      ROLE=thinkpad bash bootstrap.sh    # force
#
#  Dispatches on OS. The macOS tree is a frozen archive; nothing here
#  runs it.
# ═══════════════════════════════════════════════════════════════════
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

case "$(uname -s)" in
  Linux)
    exec bash "$HERE/linux/setup.sh" "$@"
    ;;
  Darwin)
    echo "The macOS tree is archived — see macos/bootstrap.sh."
    echo "It is not maintained and is kept only as a reference."
    exit 1
    ;;
  *)
    echo "unsupported: $(uname -s)"
    exit 1
    ;;
esac
