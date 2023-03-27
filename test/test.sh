#!/usr/bin/env sh

PATTERNS="$*"
test -z "$PATTERNS" && PATTERNS="I* lua sh"

TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
DIR="$(dirname "$0")"

DIFF="diff"
DIFF="colordiff"
DIFF="delta --light --line-numbers --side-by-side"

RET=0
TESTS=0
PASSES=0

for P in $PATTERNS; do
  if [ "$P" = "lua" ]; then
    TESTS=$((TESTS+1))      
    find . -iname '*.lua' -exec luacheck {} + && PASSES=$((PASSES+1)) || RET=1
    continue

  elif [ "$P" = "sh" ]; then
    TESTS=$((TESTS+1))      
    find . -iname '*.sh' -exec shellcheck {} + && PASSES=$((PASSES+1)) || RET=1
    continue

  else
    for D in "./$DIR/runtime/"$P; do
      TESTCASE=$(basename "$D")
      TESTS=$((TESTS+1))
      "./$DIR/pink-runner.lua" "$D/story.ink" < "$D/input.txt" > "$TMP/$TESTCASE-output" &&
         $DIFF "$D/transcript.txt" "$TMP/$TESTCASE-output" &&
         echo "$TESTCASE OK" && PASSES=$((PASSES+1)) || RET=1
    done
  fi
done

echo "$PASSES/$TESTS passed"

exit $RET
