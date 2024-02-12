#!/bin/env sh
INKLECATE="$HOME/app/inklecate/inklecate"

[ -z "$1" ] && echo "missing argument" && exit 1

if [ -z "$2" ]; then
    D=$(printf '%s/P%03d' "$(dirname -- "$0")" "$1")
else
    D=$(printf '%s/W%d.%d.%03d' "$(dirname -- "$0")" "$1" "$2" "$3")
fi

[ -e "$D" ] && echo "$D already exists" && exit 1

mkdir "$D"
echo Story:
cat > "$D/story.ink"
echo Input:
cat > "$D/input.txt"
echo Output:
$INKLECATE -p "$D/story.ink" < "$D/input.txt" | tee "$D/transcript.txt"

echo
echo "$D created"
