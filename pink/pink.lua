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


return {
  getStory = function (filename)
    return runtime(parser:match(read(filename)))
  end


}
