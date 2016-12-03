local parser = require('pink.parser')
require('util') -- TODO file reading

-- 1) Load story
local story = require('pink.runtime')(parser:match(read('examples/game.ink')))
while true do
  -- 2) Game content, line by line
  while story.canContinue do
    print(story.continue())
  end
  -- 3) Display story.currentChoices list, allow player to choose one
  if #story.currentChoices == 0 then break end
  for i = 1, #story.currentChoices do
    print(i .. "> " .. story.currentChoices[i].text)
  end
  local answer=io.read()
  print (story.currentChoices[tonumber(answer)].choiceText)
  story.chooseChoiceIndex(answer)
end
