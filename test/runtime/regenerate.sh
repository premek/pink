#!/bin/env bash
INKLECATE="$HOME/app/inklecate/inklecate"
for F in test/runtime/W* test/runtime/I* test/runtime/P*; do
    echo "$F"
    STORY="$F/story.ink"
    [ -f "$F/setup.ink" ] && STORY="$F/setup.ink"
    $INKLECATE -p "$STORY" < "$F/input.txt" > "$F/transcript.txt"
done
#wait

