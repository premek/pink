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

| Pattern |  What it covers |
|---------|----------------|
| `I*` |  From the [ink-proof](https://github.com/inkle/ink-proof) test suite — numbered sequentially |
| `W*` |  From the official WritingWithInk spec — numbered `W<chapter>.<section>.<seq>` to track origin |
| `P*` |  Pink — tests added specifically for this implementation (edge cases, regressions) |
| `X*` |  Pink extensions and improvements incompatible with the original Ink/inklecate behaviour |
| `L*` |  Long tests (stories that take a while to run) |
| `api` |  Lua API tests (`test/api.lua`) via luaunit |
| `lua` |  Linting: luacheck, selene (Lua 5.2 + LÖVE configs), stylua |
| `sh` |  shellcheck on shell scripts |

All tests except `X*` run with `--compat` (inklecate-compatible output). `X*` tests run without `--compat`, enabling Pink's improvements and extensions that differ from the original Ink behaviour.

## Runtime transcript tests (I, W, P, L)

Each test lives in `test/runtime/{Name}/` with three files:

```
story.ink       ink source
input.txt       newline-separated choice indices (empty = no choices)
transcript.txt  expected stdout output
```

The runner does:
```sh
pink-cli --compat story.ink < input.txt | cmp transcript.txt -
```

A test passes if stdout matches `transcript.txt` exactly (byte-for-byte, via `cmp -s`).

## Extension/improvement tests (X*)

`X*` tests cover Pink behaviour that intentionally diverges from inklecate. They run without `--compat` and can check stdout, stderr, and their ordering independently. Files:

```
story.ink           ink source
input.txt           choice indices
transcript.txt      expected stdout (required)
stderr.txt          expected stderr, exact match (optional)
stderr_grep.txt     substring that must appear in stderr — use for fragile content like stack traces (optional)
stderr_stdout.txt   expected stdout+stderr merged — use to verify ordering (optional)
```

### Creating a new transcript test

```sh
mkdir test/runtime/Pxxx
# write story.ink and input.txt
# use inklecate to generate transacript.txt
# verify the output is correct, then run:
./test/test.sh I136
```
`mktest.sh` automates it using the reference `inklecate` binary to generate the expected output:
`regenerate.sh` reruns inklecate on all W* tests to refresh transcripts after upstream spec changes.


## API tests (`test/api.lua`)

Lua unit tests using luaunit. Cover the story API directly (not just transcript output):
- `story.continue()` return value
- `story.canContinue`
- `story.choosePathString`
- `story.state.visitCountAtPathString`
- `story.bindExternalFunction` + error on missing binding

Several tests are **commented out** — they cover features that aren't working yet.

`test/external.lua` is required by `api.lua` and contains the `testExternal` function.

