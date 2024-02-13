#!/bin/env bash
INKLECATE="$HOME/app/inklecate/inklecate"
for F in test/runtime/W*; do
    $INKLECATE -p $F/story.ink < $F/input.txt > $F/transcript.txt &
done
wait $(jobs -p)

