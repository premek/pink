# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Code Style

Minimalistic, minimal abstractions and layers of indirection. Prefer direct, obvious code over clever patterns. Short functions with meaningful names are encouraged — the problem is redundant wrappers that add no meaning (a function that just delegates to another with the same name and no added semantics).

## Project Overview

**Pink** is a Lua implementation of the [Ink scripting language](https://github.com/inkle/ink) — a language for writing interactive branching narratives. It can be used standalone or with the LÖVE 2D game framework.

See [`docs/ink-language.md`](docs/ink-language.md) for a condensed Ink syntax reference.
See [`docs/ink-api.md`](docs/ink-api.md) for the story API and what is/isn't implemented.

## Workflow

### Formatting, Linting

After each change run:
```bash
stylua pink-cli pink/*.lua test/*.lua
luacheck --codes -q .
```

### Review
Before commit, look at the uncommitted changes and check if anything was missed elsewhere in the project.

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

## Architecture

Pipeline:
```
.ink file → Parser → AST → Compiler → Runtime → Story API
```

### Core Modules (`pink/`)

- **parser.lua** — Lexical and syntactic analysis; converts Ink text to AST (1606 lines)
- **compiler.lua** — Static phase; builds knot map, registers vars/consts/lists/functions, resolves initial values; called once before runtime starts
- **runtime.lua** — Execution engine; interprets AST nodes, manages story state and control flow
- **builtins.lua** — Built-in Ink functions (`FLOOR`, `RANDOM`, `CHOICE_COUNT`, `READ_COUNT`, etc.); wrapped in a factory that receives `getEnv`/`getChoices` deps
- **list.lua** — List type and all list operations; `list.defs` holds the global list schema
- **out.lua** — Output buffering; handles glue/trim/newline logic before returning lines
- **story.lua** — Minimal story state constructor (`globalTags`, `state`, `variablesState`, `canContinue`)
- **formatter.lua** — Reverse compilation: AST → formatted Ink text
- **logging.lua** — Debug logging and error utilities
- **node.lua** — Value and AST node constructors + type helpers (`node.int`, `node.is`, `node.output`, etc.)

### Entry Points

- **`pink/pink.lua`** — Main module: resolves INCLUDEs, calls parser, calls runtime; returns story
- **`pink-cli`** — CLI: `pink-cli [-v] [format] game.ink`

### Key Data Structures

**env** — nested hash tables; `_parent` chain for scope, `_children` subtables for knot.stitch paths. Root env holds builtins + all globals.

**knots** — `{[name]={tree,params}, [name][stitch]={tree,pointer}}` — jump table built by compiler. `noKnot` (a module-level empty table) is the sentinel key for top-level content.

**callstack** — `[{tree, pointer, fn}]` frames. `fn='fn'` marks function calls (vs tunnel calls) so `stepOut` knows where to stop.

**out.buffer** — mixed array of strings and instruction tables (`{glue=true}`, `{trim=true}`, `{outBlockStart=true}`, `{trimEnd=true}`). `out:collect()` processes these into clean lines.

**AST nodes** — all carry `.type` and `.location = {source, line, col}`. Named fields only. Key node types: `ink`, `knot`, `stitch`, `fndef`, `option`, `gather`, `choice`, `seq`, `if`, `out`, `divert`, `call`, `ref`, `var`, `const`, `tempvar`, `assign`, `return`, `tag`, `listdef`, `listlit`, `el`.

**Runtime value types**: `int`, `float`, `bool`, `str`, `list`, `el`, `fn`, `native`, `external`, `divert`.

### Test Structure

Each test case in `test/runtime/{Name}/` contains:
- `story.ink` — Input story
- `input.txt` — Choice sequence (one per line)
- `transcript.txt` — Expected output

API tests in `test/api.lua`. To add a test, create a directory and run `./test/test.sh {Name}`. See [`docs/testing.md`](docs/testing.md) for full detail on test structure, categories, and improvement plan.
