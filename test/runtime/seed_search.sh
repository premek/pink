#!/usr/bin/env sh
# Find a seed where Pink and inklecate produce identical output for an RNG test.
# Usage: ./test/runtime/seed_search.sh TESTNAME
# Example: ./test/runtime/seed_search.sh I074
#
# Creates setup.ink and regenerates transcript.txt on success.
# Run from the project root directory.

set -e

TESTNAME="$1"
if [ -z "$TESTNAME" ]; then
    echo "Usage: $0 TESTNAME" >&2
    exit 1
fi

DIR="test/runtime/$TESTNAME"
INKLECATE="${INKLECATE:-$HOME/app/inklecate/inklecate}"

SEED_FILE="$DIR/_seed.ink"
FOUND=""

for seed in $(seq 1 200); do
    printf "~ SEED_RANDOM(%s)\nINCLUDE story.ink\n" "$seed" > "$SEED_FILE"
    ink=$("$INKLECATE" -p "$SEED_FILE" < "$DIR/input.txt" 2>/dev/null)
    pink=$(lua ./pink-cli "$SEED_FILE" < "$DIR/input.txt" 2>/dev/null)
    if [ "$ink" = "$pink" ]; then
        FOUND=$seed
        break
    fi
done


if [ -z "$FOUND" ]; then
    echo "No matching seed found in 1-200 for $TESTNAME" >&2
    rm -f "$SEED_FILE"
    exit 1
fi


mv "$SEED_FILE" "$DIR/setup.ink"
"$INKLECATE" -p "$DIR/setup.ink" < "$DIR/input.txt" > "$DIR/transcript.txt"

echo "Match: seed=$FOUND, written: $DIR/setup.ink, $DIR/transcript.txt"
