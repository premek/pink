# Bug Hunting Plan

Strategy: write small focused ink snippets, run through both inklecate and pink, diff output. When a mismatch is found, minimise to the smallest reproducer and add as a P* test.

```sh
# Quick compare helper
cmp_ink() {
    echo "=== inklecate ===" && echo "$INPUT" | ~/app/inklecate/inklecate -p story.ink
    echo "=== pink ===" && echo "$INPUT" | ./pink-cli story.ink 2>/dev/null
}
```

Scope: basic implemented features only

---

## 1. Text output (highest priority)

This is the most fundamental thing. Everything else is irrelevant if text doesn't come out right.

- **Plain text** — single line, multi-line, blank lines between paragraphs
- **Whitespace** — leading/trailing spaces on lines, spaces around inline expressions `{x}`
- **Newlines** — when does a new paragraph start vs continue?
- **Glue `<>`** — suppresses newline between two lines; across multiple lines; at start/end of knot
- **Choice text: pre-bracket** — `* word[rest]` — "word" appears in menu AND in output
- **Choice text: bracket-only** — `* [word]` — "word" appears only in menu, nothing in output
- **Choice text: post-bracket** — `* [choice] continuation` — "continuation" appears only in output
- **Choice text: combined** — `* pre[mid]post` — menu shows "premid", output shows "prepost"
- **Text in choice body** — paragraph after selecting a choice, before gather
- **Text at gather** — text on the gather line itself
- **Text in knot** — text before the first choice in a knot
- **Empty output** — choosing a `[silent]` option with no body produces no extra line
- **Inline expressions in text** — `The value is {x}.` — spacing around the braces
- **Multi-paragraph choice body** — multiple lines inside a chosen branch

## 2. Knot/stitch navigation

Before variables — navigation correctness determines whether the right text is even reached.

- **Divert to knot** — text before and after divert
- **Divert inside choice body**
- **Divert to stitch** — `-> knot.stitch`
- **Knot with parameters**
- **Divert to gather label**
- **END and DONE** — story terminates cleanly

## 3. Variables and arithmetic

Test areas in order of complexity:

- **VAR declaration and output** — `VAR x = 5`, then `{x}` in text
- **Assignment** — `~ x = x + 1`, various operators (`+`, `-`, `*`, `/`, `%`, `mod`)
- **Type coercion** — int+float, bool+int, string+int
- **CONST** — verify it cannot be reassigned (error expected)
- **temp** — scoped to knot, not visible outside
- **Cross-knot variable sharing** — VAR modified in one knot, read in another
- **Variable in choice condition** — `* {x > 0} [Option]`
- **Variable in choice text** — `* Pick {x} items`

## 4. Conditionals

- **Inline if** — `{cond: text}` and `{cond: true | false}`
- **Block if** — `{- cond: \n body \n}`
- **Multi-branch** — `{- cond1: body | - cond2: body | else}`
- **Nested conditionals**
- **Condition on variable comparison** — `==`, `!=`, `<`, `>`, `<=`, `>=`
- **Condition on list membership** — `{list ? el: ...}`
- **Bool truthiness** — 0 is false, non-zero is true; empty list is false

## 5. Sequences

- **Stopping** `{a|b|c}` — cycles through then stays on last
- **Cycle** `{&a|b|c}` — repeats
- **Once-only** `{!a|b|c}` — goes blank after exhausted
- **Shuffle** `{~a|b|c}` — random order (can only test that all values appear, not order)
- **Nested sequences**
- **Sequence in choice text**
- **Sequence across revisits** — knot visited multiple times, sequence advances

## 6. Functions

- **Basic return value** — `=== function double(x) === ~ return x * 2`
- **Call in expression** — `{double(3) + 1}`
- **Call in text** — `The result is {double(4)}.`
- **Recursive function** — factorial or countdown
- **Pass by reference** — `ref` parameter, modifying caller's variable
- **No return value** — function used for side effect only
- **Function with conditional return**

## 7. Lists

- **Basic membership test** — `list ? element`
- **Add/remove** — `~ l += el`, `~ l -= el`
- **Output** — list printed as element names
- **Comparison** — `l == (el1, el2)`
- **LIST_ALL**, **LIST_MIN**, **LIST_MAX**, **LIST_COUNT**, **LIST_INVERT**
- **LIST_RANGE**
- **List as bool** — empty list is false
- **Multi-list intersection** `^`
- **Element from multiple lists** (ambiguous element name)

## 8. Knots and stitches

- **Divert to knot** — basic `-> knot`
- **Divert to stitch** — `-> knot.stitch`
- **Knot with parameters** — `-> knot(arg)`, `=== knot(p) ===`
- **Stitch seen counter** — `READ_COUNT(knot.stitch)`
- **Divert inside choice body**
- **Divert to gather label** — `- (label)`, `-> label`

## 9. Tags

- **Line tag** — `This line. # tag`, check `currentTags`
- **Tag above line** — `# tag \n line`, check tag appears with that line
- **Global tags** — tags at top of file, check `globalTags`
- **Multiple tags** — `line # a # b`

## 10. Glue

- **Basic glue** — `line one <> \n line two` produces single line
- **Glue with choice** — glue before/after a choice
- **Glue across knot boundary** — last line of knot ends with `<>`, first line of next continues

## 11. Builtins

- **FLOOR, CEILING** — rounding
- **INT, FLOAT** — conversion
- **MIN, MAX** — two-argument
- **ABS** — negative numbers
- **POW** — exponentiation
- **RANDOM** — value in range (run multiple times, check bounds)
- **CHOICE_COUNT** — correct count of available choices
- **READ_COUNT** — knot visit counter (note: currently broken, issue #6)

---

## Methodology

1. Write the snippet in `/tmp/t.ink`
2. Run both: `diff <(~/app/inklecate/inklecate -p /tmp/t.ink < input) <(./pink-cli /tmp/t.ink < input 2>/dev/null)`
3. If diff is empty: move on
4. If diff is non-empty: minimise the ink, then save as `P0NN`

## Prioritisation

1. **Text output and glue** — the most fundamental; a bug here breaks everything
2. **Knot/stitch navigation** — determines whether the right text is even reached
3. **Choice text formatting** — pre/mid/post bracket rules are subtle
4. **Sequences** — high chance of subtle off-by-one bugs on revisit
5. **Conditionals** — gate text visibility
6. **Variables** — underpin conditionals and expressions
7. **Functions** — parameter passing, recursion
8. **Lists and tags** — more self-contained

Skip for now: `READ_COUNT` / `TURNS` (issue #6 visitCount broken), tunnels, threads.
