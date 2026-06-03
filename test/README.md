# Test cases

## Running tests

```bash
./test/test.sh              # all tests
./test/test.sh "I*"         # one category
./test/test.sh I129         # single test
./test/test.sh -v I129      # verbose (pink-cli debug output)
./test/test.sh -f I129      # full diff on failure
```

## Test browser UI

```bash
./test/ui/ui.py
# → http://127.0.0.1:8765
```

## Scripts

| Script | Purpose |
|--------|---------|
| `test/test.sh` | Main test runner |
| `test/runtime/regenerate.sh [PATTERN]` | Regenerate transcripts for a category using inklecate (default: `W* I* P* G* H*`) |
| `test/runtime/mktest.sh N` | Create a new `P{N}` test interactively (reads story and input from stdin, runs inklecate) |
| `test/runtime/seed_search.sh TESTNAME` | Find a `SEED_RANDOM` value where Pink and inklecate agree — needed for RNG tests |

## Sources and licenses

| Category | Source | License |
|----------|--------|---------|
| `I*` | [ink-proof](https://github.com/chromy/ink-proof) by Hector Dearman | MIT |
| `W*` | [WritingWithInk](https://github.com/inkle/ink/blob/master/Documentation/WritingWithInk.md) by inkle Ltd. | MIT |
| `G*` | [gouache testdata](https://github.com/mgood/gouache/tree/main/testdata) by Matt Good | MIT |
| `H*` | [Inkpot TestInkSource](https://github.com/The-Chinese-Room/Inkpot/tree/release/TestInkSource) by The Chinese Room | MIT |
| `J*` | [blade-ink-rs conformance tests](https://github.com/bladecoder/blade-ink-rs/tree/main/conformance-tests/inkfiles) by Rafael Garcia Moreno | Apache 2.0 |
| `P*` | Pink — original tests for this implementation | |
| `X*` | Pink — original tests for Pink-specific extensions | |
