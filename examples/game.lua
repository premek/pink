#!/usr/bin/env lua

local pink = require('pink.pink')

-- 1) Load story
local story = pink.getStory('examples/game.ink')

story.choosePathString('back_in_london');

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
  story.chooseChoiceIndex(tonumber(answer))
end
