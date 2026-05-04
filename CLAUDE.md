# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.


## Code Style

The code should be a joy to read: minimalistic, with minimal abstractions and layers of indirection. Prefer direct, obvious code over clever patterns. Avoid unnecessary wrappers, helper functions, or intermediate layers unless they genuinely reduce complexity.

Short functions with meaningful names that call other functions with parameters are encouraged — this is not indirection, it's clarity. The issue is redundant wrappers that add no meaning (e.g. a function that just delegates to another with the same name and no added semantics).

## Project Overview

**Pink** is a Lua implementation of the [Ink scripting language](https://github.com/inkle/ink) — a language for writing interactive branching narratives. It can be used standalone or with the LÖVE 2D game framework.

## Workflow

### Formatting, Linting

After each change run
```bash
stylua pink-cli pink/*.lua test/*.lua
luacheck --codes -q . 
```
Fix the luacheck warnings.

### Review
Before commit, look at the uncommited changes, check in the rest of the project if you didnt forget anything.

### Running Tests

```bash
./test/test.sh              # Run all tests, including linting
./test/test.sh I129         # Run a single test by name
./test/test.sh "W1.3.*"     # Run tests matching a pattern
```

To check for regressions, always compare against the baseline before your change:
```bash
git stash && ./test/test.sh 2>&1 | tail -1
git stash pop && ./test/test.sh 2>&1 | tail -1
```

To find which tests newly regressed:
```bash
git stash && ./test/test.sh 2>&1 | grep -v "OK$" > /tmp/baseline_fails.txt && git stash pop
./test/test.sh 2>&1 | grep -v "OK$" > /tmp/current_fails.txt
diff /tmp/baseline_fails.txt /tmp/current_fails.txt
```
Lines added (`>`) are newly failing tests.



## Naming Conventions

- `camelCase` for all Lua variables, locals, and functions
- `UPPER_SNAKE_CASE` only for Ink built-in function names (`FLOOR`, `RANDOM`, `LIST_ALL`, etc.) — because they are uppercase in the Ink language spec
- `_prefix` for intentionally unused variables (`_debug`, `_ctx`, `_node`)
- Single-letter locals are fine for short-lived values (`n`, `s`, `e`, `p`)

## Ink Language Overview

Ink marks up plain text with flow directives to produce interactive branching narratives.
Full docs: 
[WritingWithInk](https://github.com/inkle/ink/blob/master/Documentation/WritingWithInk.md)
[RunningYourInk](https://github.com/inkle/ink/blob/master/Documentation/RunningYourInk.md)

### Story structure

- **Knot** `=== name(p1, p2) ===` — named story section; `name`: identifier, `params`: optional comma-separated parameter names
- **Stitch** `= name` — subdivision within a knot; `name`: identifier, no parameters
- **Choice** `* [onlyText]innerText` — once-only option (`*`) or sticky (`+`); text before `[` shown when choosing and after; text inside `[]` shown only when choosing; text after `]` shown only after chosen; nesting depth (`**`, `***`) sets weave level
- **Gather** `- (label)` — convergence point where branches rejoin; `label`: optional identifier for diverting to this point
- **Divert** `-> target(args)` — jump to knot/stitch/label; `target`: dot-separated path (`knot.stitch`), `args`: optional values matching target's params
- **Weave** — implicit structure formed by choices and gathers at multiple nesting levels; no syntax of its own

### State & logic

- **VAR** `VAR name = value` — global variable; `name`: identifier, `value`: initial value; persists for the whole story
- **CONST** `CONST name = value` — immutable global; same params as VAR
- **temp** `temp name = value` — local variable scoped to the current knot/function
- **Assign** `~ name = expr` — update a variable; `name`: existing variable, `expr`: new value expression
- **LIST** `LIST name = (el1, el2, ...)` — define an enum/flag set; elements in `()` are initially active
- **Sequence** `{opts: b1|b2|b3}` — alternatives; `opts`: `-` (sequence), `&` (cycle), `!` (once-only), `~` (shuffle); `branches`: `|`-separated content
- **Conditional** `{cond: text | else}` — inline branch; `cond`: boolean expression; else branch is optional; block form: `{- cond: body}`
- **Function** `=== function name(p1, p2) ===` — reusable block that can return a value; `params`: optional; no choices or diverts allowed inside
- **Return** `~ return expr` — exit function and return `expr`; bare `~ return` returns nothing
- **Tag** `# text` — metadata line attached to the preceding output; `text`: arbitrary string; not shown to player

### Advanced flow

- **Tunnel** `-> target(args) ->` — call a knot as a subroutine and return to caller; same params as divert; `->->` returns from inside the tunnel
- **Thread** `<- target(args)` — merge content from another knot into current flow in parallel
- **Glue** `<>` — suppress the line break between two adjacent lines
- **INCLUDE** `INCLUDE path` — inline another `.ink` file at parse time; `path`: relative file path
- **EXTERNAL** `EXTERNAL name(p1, p2)` — declare a function to be bound from host code before story starts

## Architecture

The system follows a compiler/interpreter pipeline:

```
.ink file → Parser → AST → Runtime → Story API
```

### Core Modules (`pink/`)

- **parser.lua** — Lexical and syntactic analysis; converts Ink text to AST
- **runtime.lua** — Execution engine; interprets AST, manages story state and control flow
- **builtins.lua** — Built-in functions (`floor`, `ceil`, `random`, `CHOICE_COUNT`, `READ_COUNT`, etc.)
- **list.lua** — List data type and operations
- **out.lua** — Output buffering with glue/trim logic
- **formatter.lua** — Reverse compilation: AST → formatted Ink text
- **logging.lua** — Debug logging and error utilities
- **story.lua** — Story state object definition

### Entry Points

- **`pink/pink.lua`** — Main module: `pink(filename)` returns a story object
- **`pink-cli`** — CLI: `pink-cli [-v] [format] game.ink`

### Story API

```lua
local pink = require("pink/pink")
local story = pink("game.ink")

while story.canContinue do
    print(story.continue())
end
for i, choice in ipairs(story.currentChoices) do
    print(i, choice.text)
end
story.chooseChoiceIndex(1)
```

### Runtime Values

All value nodes use named fields only (no positional indices).

| Value | Key fields | Notes |
|-------|-----------|-------|
| `int` | `.value` | |
| `float` | `.value` | |
| `bool` | `.value` | |
| `str` | `.value` | |
| `divert` | `.target`, `.args`, `.tunnel` | |
| `el` | `.listName`, `.elName` | |
| `list` | `.elements` | `{[listName]={[elName]=1, ...}, ...}` |
| `fn` | `.params`, `.body` | stored in env when a knot/function is registered |
| `native` | `.fn` | Lua function bound via `bindExternalFunction` |

### AST Nodes

All nodes are produced by `token(type, ...)` or `wrapToken(node.X(...))` in parser.lua and carry a `.location = {source, line, col}` and `.type` field. All nodes use named fields — no positional indices.

| Node | Named fields | Ink syntax |
|------|-------------|------------|
| `ink` | `.nodes` | top-level / included file |
| `knot` | `.name`, `.params`, `.body` | `=== name(params) ===` |
| `stitch` | `.name`, `.args` | `= name =` |
| `fn` | `.name`, `.params`, `.body` | `=== function name(params) ===` |
| `external` | `.name`, `.params` | `EXTERNAL name(params)` |
| `choice` | `.options`, `.gather` | choice block |
| `option` | `.nesting`, `.t1`, `.t2`, `.t3`, `.name`, `.sticky`, `.conditions`, `.body`, `.fallback` | `*`/`+`; t1=pre-`[`, t2=inside `[]`, t3=post-`]` |
| `gather` | `.nesting`, `.body`, `.label` | `-` |
| `divert` | `.target`, `.args`, `.tunnel` | `-> target` |
| `fork` | `.target`, `.args` | `<- target` |
| `tunnelreturn` | — | `->->` |
| `out` | `.content`, `.opts` | text output |
| `glue` | — | `<>` |
| `nl` | — | newline |
| `tag` | `.text` | `# text` |
| `seq` | `.opts`, `.branches` | `{\|once\|cycle\|shuffle: ...}` |
| `if` | `.branches` (each: `.cond`, `.body`), `.opts` | `{cond: ...}` |
| `var` | `.name`, `.value` | `VAR name = value` |
| `const` | `.name`, `.value` | `CONST name = value` |
| `tempvar` | `.name`, `.value` | `temp name = value` |
| `assign` | `.name`, `.expr` | `~ name = expr` |
| `return` | `.value` (nil for bare return) | `~ return` |
| `listdef` | `.name`, `.elements` (each: `.name`, `.set`, `.value`) | `LIST name = (...)` |
| `listlit` | `.elements` | `(el1, el2)` |
| `call` | `.name`, `.args` | function call or binary operator |
| `ref` | `.name` | variable reference |
| `comment` | `.text` | `// text` |
| `int` | `.value` | integer literal |
| `float` | `.value` | float literal |
| `bool` | `.value` | `true`/`false` |
| `str` | `.value` | string literal |
| `include` | `.filename` | `INCLUDE file` |
| `params` entries | `.name`, `.ref` | function parameter; `.ref` is `'ref'` for pass-by-ref |


### Test Structure

Each test case in `test/runtime/{Name}/` contains:
- `story.ink` — Input story
- `input.txt` — Choice sequence (one per line)
- `transcript.txt` — Expected output

To add a test, create a directory matching this pattern and run `./test/test.sh {Name}`.
