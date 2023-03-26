#!/bin/env lua

local parser = require('pink.parser')
local runtime = require('pink.runtime')

function dump(o, indent)
  indent = indent or 0;
  local sp = (" "):rep(indent*2)

  if type(o) == 'table' then
    local s = '{\n'
    for k,v in pairs(o) do
      if type(k) ~= 'number' then k = '"'..k..'"' end
      s = s .. sp..'['..k..'] = ' .. dump(v, indent+1) .. ',\n'
    end
    return s .. '}'
  elseif type(o) == 'string' then
    return "'"..(o:gsub("\\", "\\\\"):gsub("'", "\\'")).."'"
  else
    return tostring(o)
  end
end

function read(filename)
  local f = io.open(filename, "rb")
  if not f then error('failed to open "'..filename..'"') end
  local content = f:read("*all")
  f:close()
  return content
end

function write(filename, content)
  local f = io.open(filename, "wb")
  if not f then error('failed to open "'..filename..'"') end
  f:write(content)
  f:close()
end

function exists(filename)
  local f = io.open(filename, "r")
  return f ~= nil and io.close(f)
end



local inkFile = arg[1]
local parsed = parser(read(inkFile), inkFile)

if false then write(luaFile, "return "..dump(parsed)) end

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
  if not answer or answer > #story.currentChoices then
    error('invalid answer '..tostring(answer))
  end
  print ('?> '..story.currentChoices[answer].choiceText)
  story.chooseChoiceIndex(answer)
end


