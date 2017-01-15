local folderOfThisFile = (...):match("(.-)[^%.]+$")
local parser = require(folderOfThisFile .. 'parser')
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


return {
  getStory = function (filename)
    return runtime(parser:match(read(filename)))
  end


}
