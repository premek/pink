#!/bin/env sh

[ -z "$3" ] && echo "missing argument" && exit 1

D=$(printf '%s/W%d.%d.%03d' "$(dirname -- "$0")" "$1" "$2" "$3")

[ -e "$D" ] && echo "$D already exists" && exit 1

mkdir "$D"
echo Story:
cat > "$D/story.ink"
echo Input:
cat > "$D/input.txt"
echo Output:
cat > "$D/transcript.txt"

echo "$D created"
