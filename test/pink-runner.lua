#!/bin/env lua

local parser = require('pink.parser')
local runtime = require('pink.runtime')

local function read(filename)
  local f = io.open(filename, "rb")
  if not f then error('failed to open "'..filename..'"') end
  local content = f:read("*all")
  f:close()
  return content
end

local inkFile = arg[1]
local parsed = parser(read(inkFile), inkFile)

local story = runtime(parsed)

while true do
  while story.canContinue do
    print(story.continue())
  end
  if #story.currentChoices == 0 then break end
  print()
  for i = 1, #story.currentChoices do
    print(i .. ": " .. story.currentChoices[i].text)
  end
  local answer = tonumber(io.read())
  if not answer then
    error('missing answer')
  end
  if not answer or answer > #story.currentChoices then
    error('invalid answer: '..tostring(answer))
  end
  io.write('?> ')
  if story.currentChoices[answer].choiceText then
    print(story.currentChoices[answer].choiceText)
  end
  story.chooseChoiceIndex(answer)
end


