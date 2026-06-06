# TODO

## Missing API (vs C# Ink runtime)
- `state.toJson()` / `state.loadJson()` — save/load; compiler is already split from runtime for this purpose; needs callstack + env + output buffer + seen/turn counter serialization
- `EvaluateFunction(name, ...)` — call ink function from host code
- Variable observers — callback on variable change
- `continueMaximally()` — run all lines until choices or end
- `story.onError` — error handler callback
- Multiple flows

## Known incomplete
- `formatter.lua` — many node types are stubs; not usable for debugging
- `compiler.lua` — no compile-time detection of unresolved functions (runtime error only)
- `runtime.lua:805` — skip remaining options after named-label jump

## Where things break
- Output / blank lines / glue → `output_buffer.lua`, start at `collect()`
- Story flow / variable values → `runtime.lua`, start at `update()` and `goTo()`
- Parse errors / wrong AST → `parser.lua`
