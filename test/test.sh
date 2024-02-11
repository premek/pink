#!/usr/bin/env sh

DIFF="colordiff  --side-by-side --suppress-common-lines"

while getopts vf flag
do
    case "${flag}" in
        v) VERBOSE="-v";;
        f) DIFF="colordiff -U999";;
        *) echo invalid flag; exit 1;;
    esac
done
shift $((OPTIND-1))

PATTERNS="$*"
test -z "$PATTERNS" && PATTERNS="I* W* P* api luaformat lua sh"

TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
DIR="$(dirname "$(dirname "$0")")"


RET=0
TESTS=0
PASSES=0

for P in $PATTERNS; do
  if [ "$P" = "lua" ]; then
    printf 'luacheck: '
    TESTS=$((TESTS+1)); luacheck --codes -q . && PASSES=$((PASSES+1)) || RET=1

  elif [ "$P" = "luaformat" ]; then
    echo 'luaformat...'
    for F in pink/*.lua test/api.lua; do
      TESTS=$((TESTS+1))
      if luaformatter -s4 "$F" | diff - "$F" > /dev/null 2>&1 ; then 
          PASSES=$((PASSES+1))
      else
          echo "$F not formatted"
          RET=1
      fi
    done

  elif [ "$P" = "sh" ]; then
    for F in test/*.sh; do
      TESTS=$((TESTS+1))
      shellcheck "$F" && PASSES=$((PASSES+1)) || RET=1
    done

  elif [ "$P" = "api" ]; then
    TESTS=$((TESTS+1))
    ./test/api.lua && PASSES=$((PASSES+1)) || RET=1

  else
    for D in "./$DIR/test/runtime/"$P; do
      TESTCASE=$(basename "$D")
      TESTS=$((TESTS+1))
      printf '%s ' "$TESTCASE" &&
         "./$DIR/pink/pink.lua" ${VERBOSE:+"$VERBOSE"} "$D/story.ink" < "$D/input.txt" 2>&1 | $DIFF "$D/transcript.txt" - &&
         echo "OK" && PASSES=$((PASSES+1)) || RET=1
    done
  fi
done

mkdir -p "test/results"
echo "$(date --iso-8601=seconds) - $PASSES/$TESTS passed" >> "test/results/$PATTERNS.txt" # watch out * in filenames?

tail "test/results/$PATTERNS.txt"

exit $RET
