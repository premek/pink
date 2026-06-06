# Whitespace and Glue Output Handling

Pink uses `output_buffer.lua` — a buffer of raw strings mixed with instruction tables. The runtime pushes content into the buffer as it executes; `collect()` processes it into clean output lines before they are returned to the caller.

## Buffer contents

The buffer is a flat array where each element is either a plain string or one of these instruction tables:

| Instruction | Meaning |
|-------------|---------|
| `{glue=true}` | suppress the newline before this point and after it |
| `{nl=true}` | soft newline — emitted only if the line had real content |
| `{trim=true}` | marks entry into a function scope boundary |
| `{trimEnd=true}` | marks exit from a function scope; right-trims preceding content |
| `{outBlockStart=true}` | entry into a conditional or sequence output block |
| `{outBlockEnd=true}` | exit from that block |
| `{terminalDivert=true}` | story ended via `->END` or `->DONE` |
| `{threadChoice=true}` | a thread contributed a choice this turn |

## The collect() pipeline

`collect()` runs only when `needsCollect` is set (i.e. something was pushed since the last call). It transforms the raw buffer into a `[string, '\n', string, '\n', ...]` sequence that `popLine()` consumes one entry at a time.

Passes in order:

1. **Meta-extraction** — pulls `{terminalDivert}` and `{threadChoice}` out into flags; they affect turn logic but not text layout.

2. **resolveNlInstructions** — converts `{nl=true}` to a real `'\n'` only when the current line already has content; otherwise drops it. Also tracks the `{trim}`/`{trimEnd}` stack (function scope) and whether each `outBlock` produced any output.

3. **insertOutBlockGlue** — when an `outBlockStart/End` pair (conditional or sequence branch) appears mid-line with content, inserts an implicit `{glue}` before it so the output joins without a line break.

4. **applyGlue** — on each `{glue}`: walks backward removing trailing `'\n'`s, then drops any subsequent `'\n'`s until real content resumes.

5. **applyTrimEnd** — right-trims the last non-empty string before each `{trimEnd}` marker.

6. **removeEmptyTrim** — drops leftover `{trim}` markers and empty strings.

7. **collapseDoubleNewlines** — removes consecutive `'\n\n'`.

8. **joinToLines** — concatenates strings with `'\n'` separators into the final sequence. Records whether the buffer ended with a trailing `'\n'` in `hadTrailingNl`.

## continue() and the two-phase pop

`continue()` uses a two-phase approach to handle the case where text and choices arrive in the same turn:

1. **prePop()** — called before `update()` runs; captures whatever is already in the buffer and pops it if non-empty.
2. **update()** — advances the story, pushing new content.
3. **popTurnLine()** — combines the pre-popped result with anything update() added, and decides what to return.

When text precedes choices, `popTurnLine()` returns `res .. '\n'` with `canContinue = true`, causing the caller to loop. The next `continue()` emits the blank `'\n'` separator before the choices are presented. No external flag is needed — the blank line is a normal `continue()` return value.

## Notable subtleties

**`hadTrailingGlue`** is detected on the raw buffer *before* `collect()` runs, because `applyGlue` consumes the `{glue}` instruction. This detection must happen first or the information is lost.

**`needsCollect` guard** makes `collect()` idempotent — both `isEmpty()` and `popLine()` call it, but the pipeline only runs once per push cycle.

**`outBlockDepth` tracking** in `collect()` detects whether an if-conditional entry is still open at end-of-turn (`hadOutBlockThisTurn`), which affects whether a blank separator is emitted before choices.
