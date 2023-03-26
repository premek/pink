#!/usr/bin/env sh

TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT

DIR="$(dirname "$0")"

DIFF="delta --light --line-numbers --side-by-side"

RET=0

for D in $DIR/runtime/I*; do
    TEST=$(basename "$D")
    "./$DIR/pink-runner.lua" "$D/story.ink" < "$D/input.txt" > "$TMP/$TEST-output" &&
       $DIFF "$D/transcript.txt" "$TMP/$TEST-output" &&
       echo "$TEST OK"
    if test $? -gt 0; then RET=1; fi
done

exit $RET
