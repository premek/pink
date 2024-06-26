#!/usr/bin/env lua

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

  local answer=io.read("*number")
  story.chooseChoiceIndex(tonumber(answer))
end
