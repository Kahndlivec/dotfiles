#!/bin/bash
# ~/.cp/judge.sh — the "judge" build variant: g++ -O2 with checked containers.
#
# Lives in a script rather than inline in C++ CP.sublime-build because it
# validates its input and says something useful instead of compiling ''
# into '/_g'.
#
# Usage (from the build file):  bash ~/.cp/judge.sh '${file}'
set -u

SRC="${1:-}"

# ── Guard: Sublime passes an empty ${file} when no SAVED file is focused ─────
if [ -z "$SRC" ]; then
    echo "judge.sh: no source file."
    echo
    echo "Sublime expanded \${file} to nothing, which means the focused view is"
    echo "not a saved file on disk. Usual causes:"
    echo "  · the buffer has never been saved   → save it first"
    echo "  · focus was in the build output panel or the FOC test panel"
    echo "    when you pressed the key         → click into the .cpp, retry"
    exit 2
fi
if [ ! -f "$SRC" ]; then
    echo "judge.sh: '$SRC' does not exist."
    exit 2
fi

DIR=$(dirname "$SRC")
BASE=$(basename "$SRC")
STEM="${BASE%.*}"
OUT="$DIR/${STEM}_g.out"

if ! command -v g++ >/dev/null 2>&1; then
    echo "judge.sh: g++ not found.  sudo apt install build-essential"
    exit 3
fi

echo "[judge: g++ $(g++ -dumpversion 2>/dev/null || echo '?')]"

# ── Compile ──────────────────────────────────────────────────────────────────
# -D_GLIBCXX_DEBUG is the reason to run this at all: bounds-checked vectors,
# validated iterators. -Wconversion is on here and nowhere else, as a last
# look before you submit.
g++ -std=c++20 -O2 \
    -Wall -Wextra -Wshadow -Wconversion \
    -DLOCAL -D_GLIBCXX_DEBUG -D_GLIBCXX_DEBUG_PEDANTIC \
    "$SRC" -o "$OUT" || exit $?

# ── Run ──────────────────────────────────────────────────────────────────────
if [ -f "$DIR/in.txt" ]; then
    echo "[stdin: in.txt]"
    "$OUT" < "$DIR/in.txt"
else
    echo "[no in.txt beside the source — running with empty stdin]"
    "$OUT" < /dev/null
fi
