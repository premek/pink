-- FIXME clean up

if not arg[1] and not (...) then error("Usage: `require` this file from a script or call `lua pink/pink.lua parse game.ink`") end
local folderOfThisFile = arg[1] and string.sub(..., 1, string.len(arg[1]))==arg[1] and arg[0]:match("(.-)[^/\\]+$") or (...):match("(.-)[^%.]+$")
local parser = require(folderOfThisFile .. 'parser')
local runtime = require(folderOfThisFile .. 'runtime')


local function loveFileReader(file)
    if not love.filesystem.getInfo(file, "file") then error('failed to open "'..file..'"') end
    local content, size = love.filesystem.read(file)
    return content
end

local function ioFileReader(file)
    local f = io.open(file, "rb")
    if not f then error('failed to open "'..file..'"') end
    local content = f:read("*all")
    f:close()
    return content
end


function getFileReader() -- TODO allow provide implementation from client code or pass an ink content in a string
  if love and love.filesystem then 
      return loveFileReader
  else
      return ioFileReader
  end
end

local function basename(str) return string.gsub(str, "(.*/)(.*)", "%2") end
local function basedir(str)  return string.gsub(str, "(.*)(/.*)", "%1") end


local parse;
parse = function(file)
  local parsed = {}
  local reader = getFileReader()
  for _,t in ipairs(parser(reader(file))) do
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

local api = {
  getStory = function (filename)
    return runtime(parse(filename))
  end
}




return api
