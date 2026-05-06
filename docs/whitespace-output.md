# Whitespace and Glue Output Handling

## How the C# ink runtime does it

### Output stream

All output is accumulated in `StoryState.outputStream` — a flat `List<Runtime.Object>` containing `StringValue`, `Glue`, `ControlCommand`, and `Tag` objects.

Each `StringValue` is pre-classified at construction time into one of three categories:
- `isNewline` — the string is exactly `"\n"`
- `isInlineWhitespace` — all spaces/tabs
- `isNonWhitespace` — real content

This makes whitespace decisions O(1) without any regex scanning at output time.

### Glue

When a `Glue` object is pushed to the stream, `TrimNewlinesFromOutputStream()` is called immediately — it walks backward through the stream removing `StringValue` objects from the last newline onward. So glue eagerly removes the newline that preceded it, right when it is processed.

Newlines that follow glue are skipped in `PushToOutputStreamIndividual()` via a `glue` active flag.

### Lookahead for newlines

`ContinueInternal()` stops when `outputStreamEndsInNewline` becomes true. At that point it saves a snapshot. It then continues one more step to detect whether a `Glue` follows immediately. `CalculateNewlineOutputStateChange()` returns one of:
- `NoChange` — still waiting
- `ExtendedBeyondNewline` — real content confirmed the newline, snapshot discarded
- `NewlineRemoved` — glue appeared, snapshot restored (newline retroactively removed)

This lookahead is what makes glue work across statement boundaries.

### Deduplication and leading-newline suppression

`PushToOutputStreamIndividual()` drops a newline if the stream already ends with one, or if no real content has been output yet. This prevents double-blank-lines and leading blank lines without any special pass.

### Text generation

`currentText` is lazily built from the stream. `CleanOutputWhitespace()` collapses consecutive inline whitespace to single spaces and trims line edges. The returned string ends with `\n` if the story ended on a natural paragraph break, or without `\n` when glue consumed it.

The CLI checks the trailing `\n` to decide whether to print a blank separator before choices.

---

## How pink does it

Pink uses `out.lua` — a buffer of raw strings and instruction tables: `{glue=true}`, `{trim=true}`, `{trimEnd=true}`, `{outBlockStart=true}`.

`collect()` processes the buffer in several sequential passes:

1. **outBlockStart pass** — inserts implicit glue when a sequence/if block is inline with preceding text (not at line start)
2. **Glue pass** — scans forward; on `{glue=true}`, removes trailing `\n`s from the result so far; drops subsequent `\n`s until real content resumes
3. **trimEnd pass** — right-trims content before a `{trimEnd}` marker
4. **trim pass** — removes `{trim}` markers (blank placeholder elements)
5. **Dedup pass** — drops consecutive `\n\n`
6. **Join pass** — concatenates into line strings separated by `\n`
7. **Split pass** — re-splits into `[line, '\n', line, '\n', ...]` for `popLine()` to consume one at a time

`canContinue()` calls `out:isEmpty()` which calls `collect()`. `popLine()` also calls `collect()` (idempotent on already-collected data).

---

## Key differences

| Concern | C# ink | Pink |
|---------|--------|------|
| Storage | typed object list, mixed in place | flat buffer of strings + instruction tables |
| Glue timing | **eager** — trims stream immediately when glue is pushed | **lazy** — resolved in `collect()` passes |
| Newline lookahead | snapshot + one-step lookahead | no lookahead; glue in same buffer is enough |
| Dedup/leading suppress | inline in `PushToOutputStreamIndividual()` | separate passes in `collect()` |
| Text generation | lazy property, `CleanOutputWhitespace()` | collect + join + split |
| Trailing-newline signal | trailing `\n` on returned string | `story.outputEndsWithGlue` flag (explicit) |

### Blank line before choices

C#: the CLI checks whether `Continue()` returned a string ending with `\n`. If so, a paragraph break is natural. If glue was active, no `\n` → no blank line. The runtime doesn't insert it; the CLI reads the signal from the string itself.

Pink: `pink-cli` always did `print()` (blank line) before choices, regardless of glue. The fix adds `story.outputEndsWithGlue` so the CLI can skip it.

### What pink does well

- The multi-pass approach is simple to read in isolation — each pass has a clear single job.
- No snapshot/lookahead complexity; glue and the content it joins are typically in the same `collect()` call.

### What could be improved

- `collect()` is called twice per line (once in `isEmpty()`, once in `popLine()`). It's idempotent but redundant.
- The `TODO refactor` comment at the top of `out.lua` acknowledges this.
- The `hadTrailingGlue` flag was added to `collect()`'s glue pass to survive the double-call — the "only update when glue was seen" logic is non-obvious. A simpler alternative is to scan the raw buffer in `isEmpty()` before `collect()` modifies it.
- Pink does not pre-classify strings; all whitespace decisions happen during `collect()` passes. Fine at this scale but less efficient than C#'s O(1) approach.
