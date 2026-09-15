#!/usr/bin/env bash
# ~/.cp/stress.sh — stress test a solution against a brute force.
#
# Called by the "Stress test vs brute.cpp" build variant. Lives in a real
# script rather than inline in the .sublime-build because Sublime expands
# $-variables in build strings before the shell ever sees them — an inline
# `$i` silently becomes an empty string.
#
# usage: stress.sh /path/to/sol.cpp [num_tests]
# expects brute.cpp and gen.cpp in the same folder as sol.cpp
#   gen.cpp   — prints one random test case; takes a seed as argv[1]
#   brute.cpp — obviously-correct slow solution

set -u

SOL="${1:?usage: stress.sh <solution.cpp> [num_tests]}"
N="${2:-1000}"
DIR="$(cd "$(dirname "$SOL")" && pwd)"
INC="$HOME/.cp/include"

cd "$DIR" || exit 1

for f in brute.cpp gen.cpp; do
    if [ ! -f "$f" ]; then
        echo "missing $f in $DIR"
        echo "you need gen.cpp (random case from seed argv[1]) and brute.cpp (slow but correct)"
        exit 1
    fi
done

echo "compiling..."
clang++ -std=c++20 -I"$INC" -O2 -o .stress_sol   "$SOL"    || exit 1
clang++ -std=c++20 -I"$INC" -O2 -o .stress_brute brute.cpp || exit 1
clang++ -std=c++20 -I"$INC" -O2 -o .stress_gen   gen.cpp   || exit 1

echo "running $N tests..."
for i in $(seq 1 "$N"); do
    ./.stress_gen "$i" > .stress_in.txt
    ./.stress_sol   < .stress_in.txt > .stress_out1.txt
    ./.stress_brute < .stress_in.txt > .stress_out2.txt
    if ! diff -q .stress_out1.txt .stress_out2.txt > /dev/null; then
        echo
        echo "MISMATCH on seed $i"
        echo "--- input ---";    cat .stress_in.txt
        echo "--- got ---";      cat .stress_out1.txt
        echo "--- expected ---"; cat .stress_out2.txt
        echo
        echo "(input left in $DIR/.stress_in.txt)"
        exit 1
    fi
done

echo "all $N tests passed"
rm -f .stress_sol .stress_brute .stress_gen .stress_out1.txt .stress_out2.txt
