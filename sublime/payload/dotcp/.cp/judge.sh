#!/bin/bash
# ~/.cp/judge.sh — "matches the judge" build.
#
# Why this exists as a script instead of inline in C++ CP.sublime-build:
#   1. Homebrew VERSIONS the binary (g++-14, g++-15, g++-16…) and bumps it on
#      every major release. Hardcoding "g++-15" breaks on the next upgrade,
#      silently, with exit 127. This picks the newest one present.
#   2. Finding it needs $(…) and $() — and Sublime eats $-variables in a
#      .sublime-build before the shell ever sees them (landmine #1). Shell
#      logic has to live in a file.
#   3. It can validate its input and say something useful, instead of
#      compiling '' into '/_g'.
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
    echo "  · the buffer has never been saved   → ⌘S first"
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
OUT="$DIR/${STEM}_g"

# ── Find the newest real GCC ─────────────────────────────────────────────────
# Apple's /usr/bin/g++ is a clang wrapper — useless here, the whole point is
# to compile with the same libstdc++ the judge uses. Look for a versioned
# Homebrew g++ and take the highest version.  sort -V is version-aware, so
# g++-9 sorts BEFORE g++-15 (plain sort would get that backwards).
GXX=""
for d in /opt/homebrew/bin /usr/local/bin; do
    [ -d "$d" ] || continue
    cand=$(ls "$d"/g++-[0-9]* 2>/dev/null | sort -V | tail -1)
    [ -n "$cand" ] && GXX="$cand"
done

if [ -z "$GXX" ]; then
    echo "judge.sh: no real GCC found."
    echo
    echo "Looked for g++-<N> in /opt/homebrew/bin and /usr/local/bin."
    echo "Apple's /usr/bin/g++ is a clang wrapper, so it cannot stand in —"
    echo "the point of this build is libstdc++ and -D_GLIBCXX_DEBUG, which"
    echo "clang's libc++ does not have."
    echo
    echo "  brew install gcc"
    echo
    echo "Everything else in your setup works without it. This build only"
    echo "exists to catch GCC-vs-clang differences before you submit."
    exit 3
fi

echo "[judge: $($GXX -dumpversion 2>/dev/null || echo '?') via $GXX]"

# ── Compile ──────────────────────────────────────────────────────────────────
# -D_GLIBCXX_DEBUG is the reason to run this at all: bounds-checked vectors,
# validated iterators. It is libstdc++-only, so it is unavailable in every
# other variant in the build file.
#
# No -I shim here, deliberately: real GCC ships a real bits/stdc++.h, and
# pointing it at the libc++ shim would be actively wrong.
"$GXX" -std=c++20 -O2 \
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
