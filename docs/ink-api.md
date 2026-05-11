# Pink Story API

Reference for the Lua API returned by `pink(filename)`. Modelled on the official C# API described in [RunningYourInk](https://github.com/inkle/ink/blob/master/Documentation/RunningYourInk.md).

## Basic loop

```lua
local pink = require('pink.pink')
local story = pink('game.ink')

-- drive the story
while story.canContinue do
    io.write(story.continue())  -- continue() returns text with trailing \n
    -- story.currentTags contains tags for this line
end

-- present choices
for i, choice in ipairs(story.currentChoices) do
    print(i, choice.text)
end

story.chooseChoiceIndex(1)  -- 1-based
-- then loop again
```

## API reference

### Driving

| Member | Type | Description |
|--------|------|-------------|
| `story.canContinue` | bool | true when there is more content to output |
| `story.continue()` | `→ string` | output next line; advances story; returned string includes trailing `\n` (use `io.write`, not `print`) |
| `story.currentChoices` | `[{text, option, gather}]` | choices waiting for input; non-empty when canContinue is false |
| `story.chooseChoiceIndex(n)` | | select choice by 1-based index |
| `story.choosePathString(knotName)` | | jump to a knot by name |

### Tags

| Member | Type | Description |
|--------|------|-------------|
| `story.currentTags` | `[string]` | tags attached to the last line returned by continue() |
| `story.globalTags` | `[string]` | tags at the top of the main ink file |

### State

| Member | Type | Description |
|--------|------|-------------|
| `story.variablesState` | env table | read/write ink variables: `story.variablesState['health']` |
| `story.state.visitCountAtPathString(path)` | `→ int` | how many times a knot/stitch has been visited |

### External functions

```lua
story.bindExternalFunction('soundName', function(name)
    -- called when ink executes ~ soundName("clip")
end)
```

Must be bound after `pink(filename)` and before the first `continue()`. If an ink fallback function with the same name exists it is used instead, and binding is not required.

### Save / load

```lua
-- NOT YET IMPLEMENTED
-- local saved = story.state.toJson()
-- story.state.loadJson(saved)
```

## What is not yet implemented

Compared to the official C# runtime:

- **Save / load** (`state.toJson` / `state.loadJson`) — planned; static/runtime boundary is already split for this purpose
- **`tagsForContentAtPath(knotName)`** — knot-level tag metadata; removed (was stub, never populated)
- **`EvaluateFunction(name, ...)`** — call an ink function directly from host code
- **Variable observers** — register a callback fired on variable change
- **Multiple flows** — parallel independent story flows
- **`continueMaximally()`** — run all lines until choices or end
- **Error handler callback** — `story.onError`
- **`TURNS()` / `TURNS_SINCE()`** builtins
