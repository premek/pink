# pink
An attempt to implement [ink](https://github.com/inkle/ink) in pure lua,
currently under development and probably not yet very useful (as of Jan 2024).

  <a href="https://premek.github.io/ink-proof/#!/tests?overview=ink" alt="pink test results">
    <img src="https://premek.github.io/ink-proof/pink_compiler.svg"/> 
  </a>

_Ink is [inkle](https://www.inklestudios.com/)'s scripting language for writing interactive narrative,
both for text-centric games as well as more graphical games that contain highly branching stories._

See [WritingWithInk](https://github.com/inkle/ink/blob/master/Documentation/WritingWithInk.md) 
and [RunningYourInk](https://github.com/inkle/ink/blob/master/Documentation/RunningYourInk.md) 
for the description of the reference ink implementation.

## Used by
pink was used by my small game https://github.com/premek/enjoy

## How to use this to run a game
To use it in your project download the latest source or the latest [release](../../releases). You need just the [pink](../../tree/master/pink) directory.

### Example
Given some .ink file like below, you can easily run it in your lua application using the pink library.

```ink
=== back_in_london ===
We arrived into London at 9.45pm exactly.
*   "There is not a moment to lose!"[] I declared. -> hurry_outside
*   "Monsieur, let us savour this moment!"[] I declared.
    My master clouted me firmly around the head and dragged me out of the door.
    -> dragged_outside

=== hurry_outside ===
We hurried home to Savile Row  -> as_fast_as_we_could

=== dragged_outside ===
He insisted that we hurried home to Savile Row
-> as_fast_as_we_could

=== as_fast_as_we_could ===
<> as fast as we could.
```


```lua
local pink = require('pink.pink')
-- 1) Load story
local story = pink('examples/game.ink')
while true do
  -- 2) Game content, line by line
  while story.canContinue do
    print(story.continue())
  end
  -- 3) Display story.currentChoices list, allow player to choose one
  if #story.currentChoices == 0 then break end -- cannot continue and there are no choices
  for i = 1, #story.currentChoices do
    print(i .. "> " .. story.currentChoices[i].text)
  end
  local answer=io.read()
  story.chooseChoiceIndex(answer)
end
```

See the examples directory for a simple text based example and a LÖVE integration.

This is how to run the text-based example:

    $ lua examples/game.lua

or just:

    $ examples/game.lua

And this example shows [LÖVE](https://love2d.org) integration:

    $ love examples/love2d

## How to run tests
    $ ./test/test.sh           # all tests
    $ ./test/test.sh I129      # run a single test case
    $ ./test/test.sh W1.3.*    # run test cases mathing a pattern

- [More tests](https://premek.github.io/ink-proof/#!/tests?overview=ink) - source: [premek/ink-proof](https://github.com/premek/ink-proof) 
    
