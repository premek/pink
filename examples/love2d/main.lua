local pink = require('pink.pink')

local story = pink.getStory('game.ink')

-- you can also jump to a story knot based on some event in your game
story.choosePathString('back_in_london');

local currentText = nil
local a=10

function love.update()
  if not currentText then
    if story.canContinue then
      currentText = story.continue() .. '\n\n(press space to continue)'
    elseif #story.currentChoices > 0 then
      for i = 1, #story.currentChoices do
        currentText = (currentText or '') .. i .. "] " .. story.currentChoices[i].text .. '\n'
      end
      currentText = currentText .. '\n\n(press a number to select the option)'
    end
  end
end

function love.keypressed(key)
  if key=='space' then currentText=nil end
  if tonumber(key) then
    story.chooseChoiceIndex(tonumber(key))
  end
end


function love.draw()

  if currentText then
    love.graphics.setColor(255,255,255)
    love.graphics.print(currentText, math.floor(a), math.floor(a))
  end
end
