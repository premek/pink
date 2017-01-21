local folderOfThisFile = (...):match("(.-)[^%.]+$")
local parser = require(folderOfThisFile .. 'parser')
local runtime = require(folderOfThisFile .. 'runtime')


local function read(file)
    local f = io.open(file, "rb")
    if not f then error('failed to open "'..file..'"') end
    local content = f:read("*all")
    f:close()
    return content
end

local function basename(str) return string.gsub(str, "(.*/)(.*)", "%2") end
local function basedir(str)  return string.gsub(str, "(.*)(/.*)", "%1") end

local api;


api = {
  getStory = function (filename)
    local parse;
    parse = function(f)
      local parsed = {}
      for _,t in ipairs(parser:match(read(f))) do
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

    return runtime(parse(filename))
  end
}

return api
