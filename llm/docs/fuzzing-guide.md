# Bug Hunting via Generated Ink Scripts

This guide explains how to find bugs in Pink by generating Ink stories, running them through both inklecate and Pink, spotting divergence, and turning it into a failing test.

## The Goal

Inklecate is the reference implementation. Any output difference between inklecate and Pink is either a bug in Pink or an intentional extension (which should already have an `X*` test). When you find one, it becomes a `P*` test.

**Only create a test if Pink fails it.** A passing test adds no value and clutters the suite.

---

## Step 1 — Write a Story

Write a short ink snippet targeting a specific feature or combination. There are no mandatory structural requirements — even a 3-line story can expose a bug. The only hard rule: **the story must terminate** (no infinite loops, choices must eventually run out) so inklecate doesn't hang.

Good candidate areas for bugs, roughly ordered by payoff:

- **Nesting of different structures** — choices inside conditionals inside sequences, etc.
- **Sequences** (`{a|b|c}`, `{&…}`, `{!…}`, `{~…}`) across multiple visits
- **Glue `<>`** — across knot boundaries, around choices, combined with conditionals
- **Diverts into the middle of a flow** then back out
- **Tunnels** (`-> knot ->`)
- **Conditional logic** with side-effecting expressions
- **Mixed gather/choice nesting** at depth 2+
- **Tags on choice text vs output text**
- **Sticky vs non-sticky choices** with repeat visits
- **Functions** with return values used inline
- **Variable modification across knots**
- **List operations** (`LIST_ALL`, `LIST_COUNT`, set membership)

Story size doesn't matter much. Short stories are easier to bisect; longer stories reach more interesting state. Generate many and discard the ones that produce no diff.

---

## Step 2 — Run Through Both Implementations

```bash
# Write your story to /tmp/test.ink
# Write your choice sequence to /tmp/input.txt (one index per line, empty if no choices)

# Run with Pink
./pink-cli --compat /tmp/test.ink < /tmp/input.txt > /tmp/pink.txt 2>&1

# Run with inklecate
~/app/inklecate/inklecate -p /tmp/test.ink < /tmp/input.txt > /tmp/inklecate.txt 2>&1

# Compare
diff /tmp/inklecate.txt /tmp/pink.txt
```

**No diff → stop here.** Discard the story and try a different one.

---

## Step 3 — Interpret the Diff

| Situation | Action |
|-----------|--------|
| Output is identical | Discard; try a different story or input |
| Pink is wrong (wrong text, wrong choices, wrong order) | Bug — continue to Step 4 |
| Pink is *better* (e.g., better error message) but different | May be intentional — check existing `X*` tests first |

Before declaring a bug, rule out user error:

- Did both get the same `input.txt`?
- Does the story compile without errors in inklecate (`inklecate` without `-p` prints compile errors)?
- Is the divergence reproducible (run both again)?

---

## Step 4 — Minimise the Story

Trim the story to the smallest version that still shows the diff. Smaller = easier to fix.

Bisect approach:

1. Remove a block of content.
2. Re-run both — does the diff persist?
3. If yes, keep the removal; if no, restore and try elsewhere.

Repeat until removing anything makes the divergence disappear.

---

## Step 5 — Create a Failing Test

```bash
# Find the next P number
ls test/runtime/P* | sort | tail -5

# Create the test directory
mkdir test/runtime/P042   # use the next available number

# Copy your minimised story and input
cp /tmp/test_minimised.ink test/runtime/P042/story.ink
cp /tmp/input.txt          test/runtime/P042/input.txt

# Generate transcript.txt from inklecate (this is the expected/correct output)
~/app/inklecate/inklecate -p test/runtime/P042/story.ink \
    < test/runtime/P042/input.txt \
    > test/runtime/P042/transcript.txt
```

Alternatively use the interactive helper:

```bash
test/runtime/mktest.sh 042
```

**Now confirm Pink actually fails the test:**

```bash
./test/test.sh P042
```

**If it passes — do not keep the test.** The bug is already fixed or the story doesn't reproduce it. Remove the directory and go back to Step 4 with a different variation.

---

## Step 6 — Document the Bug

Add a one-line comment at the top of `story.ink` describing what the test exercises:

```ink
// Test: sequence exhaustion across two visits with an interleaved choice
```

---

## Tips

**Volume helps:** generate many stories quickly; most will produce no diff and get discarded. The goal is throughput, not craftsmanship on any individual story.

**For random output:** any story using `RANDOM` must use `~SEED_RANDOM(n)`. Because Lua and C# use different RNGs, the same seed can produce different output — use `test/runtime/seed_search.sh TESTNAME` to find a seed where both agree.

**For multi-path stories:** create one `input.txt` per interesting path and one test per path. One path per test is easier to bisect.

**Where bugs live:** divergences usually come from `pink/runtime.lua` (execution) or `pink/output_buffer.lua` (text assembly). Use LSP `workspaceSymbol` to find the relevant function.

**Regression guard:** after fixing, run the full test suite and diff against baseline:

```bash
git stash
./test/test.sh 2>&1 > /tmp/baseline
git stash pop
./test/test.sh 2>&1 > /tmp/current
diff /tmp/baseline /tmp/current
```
