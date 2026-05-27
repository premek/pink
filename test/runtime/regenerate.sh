#!/bin/env bash
INKLECATE="$HOME/app/inklecate/inklecate"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ $# -eq 0 ]; then
    set -- 'W*' 'I*' 'P*'
fi

for PATTERN in "$@"; do
    for F in "$SCRIPT_DIR"/$PATTERN; do
        [ -d "$F" ] || continue
        echo "$F"
        STORY="$F/story.ink"
        [ -f "$F/setup.ink" ] && STORY="$F/setup.ink"
        $INKLECATE -p "$STORY" < "$F/input.txt" > "$F/transcript.txt"
    done
done
