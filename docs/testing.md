# Testing

## How tests are run

```bash
./test/test.sh              # all tests
./test/test.sh I129         # single test by name
./test/test.sh "W1.1.*"     # pattern match
./test/test.sh -v I129      # verbose (shows pink-cli debug output)
./test/test.sh -f I129      # show full diff on failure
```

`test.sh` runs five categories in sequence, tallies pass/fail, and appends a timestamped summary to `test/results/`. On each run it also diffs against the previous run to show newly passing (green) and newly failing (red) tests.

## Test categories

| Pattern | Count | What it covers |
|---------|-------|----------------|
| `I*` | 135 | From the [ink-proof](https://github.com/inkle/ink-proof) test suite — numbered sequentially |
| `W*` | 140 | From the official WritingWithInk spec — numbered `W<chapter>.<section>.<seq>` to track origin |
| `P*` | 39 | Pink/Premek — tests added specifically for this implementation (edge cases, regressions) |
| `L*` | 1 | Long tests (stories that take a while to run) |
| `api` | — | Lua API tests (`test/api.lua`) via luaunit |
| `lua` | — | Linting: luacheck, selene (Lua 5.2 + LÖVE configs), stylua |
| `sh` | — | shellcheck on shell scripts |

## Runtime transcript tests (I, W, P, L)

Each test lives in `test/runtime/{Name}/` with three files:

```
story.ink       ink source
input.txt       newline-separated choice indices (empty = no choices)
transcript.txt  expected stdout output
```

The runner does:
```sh
pink-cli story.ink < input.txt | cmp transcript.txt -
```

A test passes if stdout matches `transcript.txt` exactly (byte-for-byte, via `cmp -s`).

### Creating a new transcript test

`mktest.sh` automates it using the reference `inklecate` binary to generate the expected output:

```sh
# Creates test/runtime/P042/
test/runtime/mktest.sh 42
# Creates test/runtime/W2.3.007/
test/runtime/mktest.sh 2 3 7
# Then type the story.ink content, press Ctrl-D, type choices, press Ctrl-D
```

`regenerate.sh` reruns inklecate on all W* tests to refresh transcripts after upstream spec changes.

### Manually

```sh
mkdir test/runtime/I136
# write story.ink and input.txt
pink-cli test/runtime/I136/story.ink < test/runtime/I136/input.txt > test/runtime/I136/transcript.txt
# verify the output is correct, then run:
./test/test.sh I136
```

## API tests (`test/api.lua`)

Lua unit tests using luaunit. Cover the story API directly (not just transcript output):
- `story.continue()` return value
- `story.canContinue`
- `story.choosePathString`
- `story.state.visitCountAtPathString`
- `story.bindExternalFunction` + error on missing binding

Several tests are **commented out** — they cover features that aren't working yet (tags, visit counts, includes).

`test/external.lua` is required by `api.lua` and contains the `testExternal` function.

---

## What is not tested

- **Tags** — `currentTags`, `globalTags`, `tagsForContentAtPath` (api.lua tests commented out)
- **Visit counts** — `visitCountAtPathString` always returns 0 (bug #6); test commented out
- **Includes** — `INCLUDE` happy path commented out
- **Error messages** — no tests for parse errors or runtime errors from bad ink
- **`variablesState`** — reading/writing ink variables from host code
- **Save/load** — not implemented
- **Formatter** — `formatter.lua` (AST → ink text) has no tests at all
- **`EvaluateFunction`** — not implemented
- **LÖVE integration** — `pink.lua` LÖVE path not tested

---

## Plan: what to add and improve

### Add more P* transcript tests

P* is the right place for implementation-specific coverage. Priority areas with sparse or no coverage:
- `variablesState` read/write from host code
- Edge cases in list operations
- Glue and whitespace edge cases
- Error paths (unknown knot, unbound external, type errors)

Use `mktest.sh` when inklecate output is the expected behaviour; write manually when testing pink-specific behaviour.

### Add API tests for variablesState

`api.lua` has no tests for reading or writing ink variables from Lua. Add tests that set `story.variablesState['name']` and assert the story output changes accordingly.

### Add error/negative API tests

Currently only `testInvalidKnot` and `testExternal` cover error paths. Add cases for: binding an already-bound external, calling `chooseChoiceIndex` out of range, and type errors surfaced to the host.

### Multi-instance test

Create two stories simultaneously and run them interleaved. This will expose the `out` singleton bug (issue #11) and `list.defs` global bug (issue #12) — useful to have a failing test before fixing those.

### Consider an inline-ink test helper for api.lua

`api.lua` tests require a file on disk. A small helper that writes ink to a temp file and returns a story would allow compact inline tests:

```lua
local function story(ink)
    -- write to temp file, return pink(tempfile)
end
```

Useful for API edge cases that don't need to match inklecate output and don't warrant a full `test/runtime/` directory.
