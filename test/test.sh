#!/usr/bin/env sh

PATTERNS="$*"
test -z "$PATTERNS" && PATTERNS="I* luaformat lua sh"

TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
DIR="$(dirname "$0")"

DIFF="colordiff"

RET=0
TESTS=0
PASSES=0

for P in $PATTERNS; do
  if [ "$P" = "lua" ]; then
    TESTS=$((TESTS+1)); luacheck --codes -q . && PASSES=$((PASSES+1)) || RET=1
    continue

  elif [ "$P" = "luaformat" ]; then
    for F in pink/*.lua ; do
      TESTS=$((TESTS+1))
      if luaformatter -s4 "$F" | diff - "$F" > /dev/null 2>&1 ; then 
          PASSES=$((PASSES+1))
      else
          echo "$F not formatted"
          RET=1
      fi
    done
    for F in test/pink*.lua test/test.lua test/*/*.lua; do
      TESTS=$((TESTS+1))
      if luaformatter -s2 "$F" | diff - "$F" > /dev/null 2>&1 ; then
          PASSES=$((PASSES+1))
      else
          echo "$F not formatted"
          RET=1
      fi

    done
    continue

  elif [ "$P" = "sh" ]; then
    for F in test/*.sh; do
      TESTS=$((TESTS+1))
      shellcheck "$F" && PASSES=$((PASSES+1)) || RET=1
    done
    continue

  else
    for D in "./$DIR/runtime/"$P; do
      TESTCASE=$(basename "$D")
      TESTS=$((TESTS+1))
      printf '%s ' "$TESTCASE" && "./$DIR/pink-runner.lua" "$D/story.ink" < "$D/input.txt" | $DIFF "$D/transcript.txt" - &&
         echo "OK" && PASSES=$((PASSES+1)) || RET=1
    done
  fi
done

echo "$PASSES/$TESTS passed"

exit $RET
