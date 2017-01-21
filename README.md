# pink
An attempt to implement a subset of [ink](https://github.com/inkle/ink) in lua using [lpeg](http://www.inf.puc-rio.br/~roberto/lpeg)

_Ink is inkle's scripting language for writing interactive narrative, both for text-centric games as well as more graphical games that contain highly branching stories._

## Currently supported

### Parser
- Paragraphs
- Comments
- Choices
    - choice and output text
    - nested choices
- Knots
- Diverts
- Glue
- Include

### Runtime
- state.visitCountAtPathString() - allows the runtime to check if the story went through a scpecific point

See [WritingWithInk](https://github.com/inkle/ink/blob/master/Documentation/WritingWithInk.md) and [RunningYourInk](https://github.com/inkle/ink/blob/master/Documentation/RunningYourInk.md) for the description of the reference ink implementation.

## Used by
pink is used by my small game https://github.com/premek/enjoy

Let me know if you want to use it too.

## Install dependencies

Install luarocks (Or see https://luarocks.org/#quick-start for instructions for other platforms):

    sudo aptitude install luarocks

Install lpeg:

    luarocks install --local lpeg

Get pink:

Clone this repo or download an archive from [releases](../../releases) page. You need just the `pink` subdirectory.

### Note on dependencies
The pink **parser** depends on lpeg which can easily be instaled by luarocks (see above) but it may be difficult to distribute it with your game for each platform (it is a C library). Please consider compiling the .ink file into lua table, save it into a file and distribute just the compiled file with a lua table instead of compiling at runtime. (See: [#3](/../../issues/3))

Pink **runtime** is just a pure lua.


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
local story = pink.getStory('examples/game.ink')
while true do
  -- 2) Game content, line by line
  while story.canContinue do
    print(story.continue())
  end
  -- 3) Display story.currentChoices list, allow player to choose one
  for i = 1, #story.currentChoices do
    print(i .. "> " .. story.currentChoices[i].text)
  end
  if #story.currentChoices == 0 then break end -- cannot continue and there are no choices
  local answer=io.read()
  print (story.currentChoices[tonumber(answer)].choiceText)
  story.chooseChoiceIndex(answer)
end
```

See the examples directory for a simple text based example and a LÖVE integration.

This is how to run the text-based example:

    $ lua examples/game.lua

And this example shows [LÖVE](https://love2d.org) integration:

    $ love examples/love2d

<!-- TODO: short example here -->

## How to run tests
    $ lua test.lua
