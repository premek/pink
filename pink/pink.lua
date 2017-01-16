-- FIXME
if not arg[1] and not (...) then error("Usage: `require` this file from a script or call `lua pink/pink.lua parse game.ink`") end
local folderOfThisFile = arg[1] and string.sub(..., 1, string.len(arg[1]))==arg[1] and arg[0]:match("(.-)[^/\\]+$") or (...):match("(.-)[^%.]+$")
local getParser = function () return require(folderOfThisFile .. 'parser') end
local runtime = require(folderOfThisFile .. 'runtime')

local function read(file) -- TODO should this be here or in client code? At lease allow to pass an ink content in a string
  if love and love.filesystem and love.filesystem.read then
    local content, size = love.filesystem.read(file)
    return content
  else
    local f = io.open(file, "rb")
    if not f then error('failed to open "'..file..'"') end
    local content = f:read("*all")
    f:close()
    return content
  end
end


local api = {
  getStory = function (filename)
    local parsed
    if not pcall(function ()
      parsed = require (string.sub(filename, 1, -5))
      print('loaded precompiled story')
    end) then
      parsed = getParser():match(read(filename))
      print('story compiled')
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
                        b = b .. '"'..string.gsub(val,'"', '\\"')..'", '
                    else
                        b = b .. tostring(val) .. ', '
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
  print(dump(getParser():match(read(arg[2]))))
end


return api
