#!/usr/bin/env sh

DIFF="colordiff  --side-by-side --suppress-common-lines"
DIFF="cmp -s" #no diff output

# Override from env: LUAS="lua5.1 lua5.3 lua5.4 luajit" ./test/test.sh
LUAS="${LUAS:-lua}"

start=$(date +%s.%N)

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
test -z "$PATTERNS" && PATTERNS="I* W* P* X* api lua sh"

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
    find pink/ -mindepth 1 -name '*.lua' -not -name pink.lua -exec selene --config selene-lua52.toml '{}' \; && PASSED="$PASSED\n$P" && PASSES=$((PASSES+1)) || RET=1
    TESTS=$((TESTS+1))
    selene --config selene-lua52.toml pink-cli examples/game.lua && PASSED="$PASSED\n$P" && PASSES=$((PASSES+1)) || RET=1
    printf "\nselene-love: "
    TESTS=$((TESTS+1))
    selene --config selene-love.toml pink/pink.lua examples/love2d/ && PASSED="$PASSED\n$P" && PASSES=$((PASSES+1)) || RET=1

    echo 'stylua...'
    TESTS=$((TESTS+1))
    if stylua --check pink-cli pink/*.lua test/*.lua; then 
        PASSES=$((PASSES+1))
        PASSED="$PASSED\n$P:$F"
    else
        echo "run 'stylua pink-cli pink/*.lua test/*.lua'" 
        RET=1
    fi

  elif [ "$P" = "sh" ]; then
    for F in test/*.sh; do
      TESTS=$((TESTS+1))
      shellcheck "$F" && PASSED="$PASSED\n$P:$F" && PASSES=$((PASSES+1)) || RET=1
    done

  elif [ "$P" = "api" ]; then
    for SUITE in api.lua random.lua; do
      TESTS=$((TESTS+1))
      FAILED_VERS=""
      for LUA in $LUAS; do
        $LUA "./test/$SUITE" >/dev/null 2>&1 || FAILED_VERS="$FAILED_VERS $LUA"
      done
      if [ -z "$FAILED_VERS" ]; then
        PASSED="$PASSED\n$SUITE" && PASSES=$((PASSES+1))
      else
        printf "%s fail:%s\n" "$SUITE" "$FAILED_VERS"
        RET=1
      fi
    done

  else
    for D in "./$DIR/test/runtime/"$P; do
      TESTCASE=$(basename "$D")
      TESTS=$((TESTS+1))
      echo
      printf '%s ' "$TESTCASE"
      FAILED_VERS=""
      for LUA in $LUAS; do
        STORY="$D/story.ink"
        [ -f "$D/setup.ink" ] && STORY="$D/setup.ink"
        $LUA "./$DIR/pink-cli" ${VERBOSE:+"$VERBOSE"} "$STORY" < "$D/input.txt" 2>&1 \
          | $DIFF "$D/transcript.txt" - || FAILED_VERS="$FAILED_VERS $LUA"
      done
      if [ -z "$FAILED_VERS" ]; then
        printf "OK" && PASSED="$PASSED\n$TESTCASE" && PASSES=$((PASSES+1))
      else
        printf "fail:%s" "$FAILED_VERS"
        RET=1
      fi
    done
  fi
done

echo

mkdir -p "test/results"
D="$(date --iso-8601=seconds)"
end=$(date +%s.%N)

echo "$D - $PASSES/$TESTS passed in $( echo "$end - $start" | bc -l ) s" >> "test/results/$PATTERNS.txt" # watch out * in filenames?
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
