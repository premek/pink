-- FIXME clean up

if not arg[1] and not (...) then error("Usage: `require` this file from a script or call `lua pink/pink.lua parse game.ink`") end
local folderOfThisFile = arg[1] and string.sub(..., 1, string.len(arg[1]))==arg[1] and arg[0]:match("(.-)[^/\\]+$") or (...):match("(.-)[^%.]+$")
local getParser = function () return require(folderOfThisFile .. 'parser') end
local runtime = require(folderOfThisFile .. 'runtime')

local newParser = require(folderOfThisFile .. 'newparser')


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
parse = function(f)
  local parsed = {}
  local reader = getFileReader()
  for _,t in ipairs(getParser():match(reader(f))) do
    if t[2] and t[1]=='include' then
      for _,included in ipairs(parse(basedir(f)..'/'..t[2])) do
        table.insert(parsed, included)
      end
    else
      table.insert(parsed, t)
    end
  end
  return parsed
end

local newParse = function(file)
    local read = getFileReader()
    return newParser(read(file))
end


local api = {
  getStory = function (filename)
    local parsed
    if not pcall(function ()
      parsed = require (string.sub(filename, 1, -5))
      --print('loaded precompiled story')
    end) then
      parsed = newParse(filename)
      --print('story compiled')
    end
    return runtime(parsed)
  end
}



local function dump ( t ) -- tables only
    local function sub_print_r(t)
            if (type(t)=="table") then
                local b = ""
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        b = b .. "{"..sub_print_r(val).."},"
                    elseif (type(val)=="string") then
                        b = b .. '"'..string.gsub(val,'"', '\\"')..'",'
                    else
                        b = b .. tostring(val) .. ','
                    end
                end
                return b
            else
                return tostring(t)
            end
    end
    return "-- This file was generated from an .ink file using the pink library - do not edit\nreturn {" .. sub_print_r(t) .. "}"
end




if arg[1] == 'parse' and arg[2] then
  print(dump(parse(arg[2])))
end


return api
