#!/usr/bin/env sh

DIFF="colordiff  --side-by-side --suppress-common-lines"
DIFF="cmp -s" #no diff output

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
PASSED=""

for P in $PATTERNS; do
  echo

  if [ "$P" = "lua" ]; then
    printf "\nluacheck: "
    TESTS=$((TESTS+1))
    luacheck --codes -q . && PASSED="$PASSED\n$P" && PASSES=$((PASSES+1)) || RET=1
    printf "\nselene: "
    TESTS=$((TESTS+1))
    selene --config selene-lua52.toml pink/runtime.lua pink/parser.lua examples/game.lua && PASSED="$PASSED\n$P" && PASSES=$((PASSES+1)) || RET=1
    printf "\nselene-love: "
    TESTS=$((TESTS+1))
    selene --config selene-love.toml pink/pink.lua examples/love2d/ && PASSED="$PASSED\n$P" && PASSES=$((PASSES+1)) || RET=1

  elif [ "$P" = "luaformat" ]; then
    echo 'luaformat...'
    for F in pink/*.lua test/api.lua; do
      TESTS=$((TESTS+1))
      if luaformatter -s4 "$F" | diff - "$F" > /dev/null 2>&1 ; then 
          PASSES=$((PASSES+1))
          PASSED="$PASSED\n$P:$F"
      else
          echo "$F not formatted"
          RET=1
      fi
    done

  elif [ "$P" = "sh" ]; then
    for F in test/*.sh; do
      TESTS=$((TESTS+1))
      shellcheck "$F" && PASSED="$PASSED\n$P:$F" && PASSES=$((PASSES+1)) || RET=1
    done

  elif [ "$P" = "api" ]; then
    TESTS=$((TESTS+1))
    ./test/api.lua && PASSED="$PASSED\n$P" && PASSES=$((PASSES+1)) || RET=1

  else
    for D in "./$DIR/test/runtime/"$P; do
      TESTCASE=$(basename "$D")
      TESTS=$((TESTS+1))
      echo
      printf '%s ' "$TESTCASE" &&
         "./$DIR/pink/pink.lua" ${VERBOSE:+"$VERBOSE"} "$D/story.ink" < "$D/input.txt" 2>&1 | $DIFF "$D/transcript.txt" - &&
         printf "OK" && PASSED="$PASSED\n$TESTCASE" && PASSES=$((PASSES+1)) || RET=1
    done
  fi
done

echo

mkdir -p "test/results"
D="$(date --iso-8601=seconds)"
echo "$D - $PASSES/$TESTS passed" >> "test/results/$PATTERNS.txt" # watch out * in filenames?
echo "$PASSED" >> "test/results/$PATTERNS-passed-$D.txt"

tail "test/results/$PATTERNS.txt"

LATEST="$(find "test/results/" -name "$PATTERNS-passed*" |sort|tail -1)"
PREV="$(find "test/results/" -name "$PATTERNS-passed*" |sort|tail -2|head -1)"
if [ -f "$LATEST" ] && [ -f "$PREV" ] ; then
  printf '\033[1;32m' #green
  grep -xvFf "$PREV" "$LATEST"
  printf '\033[1;31m' #red
  grep -xvFf "$LATEST" "$PREV" 
  printf '\033[0m' #reset
fi

exit $RET
