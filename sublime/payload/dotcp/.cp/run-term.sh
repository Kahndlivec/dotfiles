#!/usr/bin/env bash
# ~/.cp/run-term.sh — run a command in a terminal window (Ghostty first).
#
# usage: run-term.sh <workdir> <command...>
#   run-term.sh /path/to/dir ./a_dbg
#   run-term.sh /path/to/dir './a_dbg < in.txt'
#
# Falls back to whatever terminal Ubuntu has if Ghostty is not installed.
# Force one with:  CP_TERMINAL=ghostty | ptyxis | gnome-terminal | xterm

set -u

DIR="${1:?usage: run-term.sh <workdir> <command...>}"
shift
CMD="$*"

# The trailing read holds the window open so you can read the output and the
# exit code instead of it vanishing the instant the program returns.
INNER="cd '$DIR' && $CMD; printf '\n[exit %s] press enter to close' \$?; read -r _"

launch() {
    case "$1" in
        ghostty)        setsid -f ghostty -e bash -c "$INNER" ;;
        ptyxis)         setsid -f ptyxis -- bash -c "$INNER" ;;
        gnome-terminal) setsid -f gnome-terminal -- bash -c "$INNER" ;;
        xterm)          setsid -f xterm -e bash -c "$INNER" ;;
        *)              return 1 ;;
    esac >/dev/null 2>&1
}

if [ -n "${CP_TERMINAL:-}" ]; then
    launch "$CP_TERMINAL" || { echo "run-term.sh: could not start $CP_TERMINAL"; exit 1; }
    exit 0
fi

for t in ghostty ptyxis gnome-terminal xterm; do
    if command -v "$t" >/dev/null 2>&1; then
        launch "$t" && exit 0
    fi
done

echo "run-term.sh: no terminal found (looked for ghostty, ptyxis, gnome-terminal, xterm)"
exit 1
