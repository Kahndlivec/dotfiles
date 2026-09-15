#!/usr/bin/env bash
# ~/.cp/run-term.sh — run any command in a Ghostty window.
#
# usage: run-term.sh <workdir> <command...>
#   run-term.sh /path/to/dir ./a_dbg
#   run-term.sh /path/to/dir './a_dbg < in.txt'
#   run-term.sh /path/to/dir bash ~/.cp/stress.sh /path/a.cpp 1000
#
# Falls back to Terminal.app only if the Ghostty launch actually fails.
# Force one with:  CP_TERMINAL=ghostty   or   CP_TERMINAL=terminal
#
# Detection is "try it and see" rather than a path check, because Ghostty
# isn't always in /Applications and `open -na` resolves it through
# LaunchServices wherever it lives.

set -u

DIR="${1:?usage: run-term.sh <workdir> <command...>}"
shift
CMD="$*"

# The trailing read holds the window open so you can read the output and the
# exit code instead of it vanishing the instant the program returns.
INNER="cd '$DIR' && $CMD; printf '\n[exit %s] press enter to close' \$?; read"

open_ghostty() {
    open -na Ghostty --args -e /bin/bash -lc "$INNER" 2>/dev/null
}

open_terminal() {
    osascript \
        -e "tell application \"Terminal\" to do script \"$INNER\"" \
        -e 'tell application "Terminal" to activate' >/dev/null
}

case "${CP_TERMINAL:-auto}" in
    ghostty)  open_ghostty || { echo "run-term.sh: Ghostty launch failed"; exit 1; } ;;
    terminal) open_terminal ;;
    *)        open_ghostty || open_terminal ;;
esac
