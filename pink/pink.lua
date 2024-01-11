#!/bin/env lua

if not arg[1] and not (...) then
    error("Usage: `require` this file from a script or execute `lua pink/pink.lua game.ink`")
end

local folderOfThisFile = arg[1]
    and string.sub(..., 1, string.len(arg[1]))==arg[1]
    and arg[0]:match("(.-)[^/\\]+$")
    or (...):match("(.-)[^%.]+$")

local function requireLocal(f)
    return require(folderOfThisFile .. f)
end


local parser = requireLocal('parser')
local runtime = requireLocal('runtime')


local function loveFileReader(file)
    if not love.filesystem.getInfo(file, "file") then error('failed to open "'..file..'"') end
    return love.filesystem.read(file)
end

local function ioFileReader(file)
    local f = io.open(file, "rb")
    if not f then error('failed to open "'..file..'"') end
    local content = f:read("*all")
    f:close()
    return content
end


local function getFileReader() -- TODO allow provide implementation from client code or pass an ink content in a string
    if love and love.filesystem then
        return loveFileReader
else
    return ioFileReader
end
end

local function basedir(str)  return string.gsub(str, "(.*)(/.*)", "%1") end


local parse;
parse = function(file)
    local parsed = {}
    local reader = getFileReader()
    for _,t in ipairs(parser(reader(file), file)) do
        if t[2] and t[1]=='include' then
            for _,included in ipairs(parse(basedir(file)..'/'..t[2])) do
                table.insert(parsed, included)
            end
        else
            table.insert(parsed, t)
        end
    end
    return parsed
end

local function getStory(filename)
    return runtime(parse(filename))
end

if not arg[1] then
    return getStory
end

local story = getStory(arg[1])

while true do
    while story.canContinue do
        print(story.continue())
    end
    if #story.currentChoices == 0 then break end
    print()
    for i = 1, #story.currentChoices do
        print(i .. ": " .. story.currentChoices[i].text)
    end
    io.write('?> ')
    local answer = tonumber(io.read())
    if not answer then
        error('missing answer')
    end
    if not answer or answer > #story.currentChoices then
        error('invalid answer: '..tostring(answer))
    end
    story.chooseChoiceIndex(answer)
end


