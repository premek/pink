local parser = require('pink.parser')
local runtime = require('pink.runtime')

local function read(file)
    local f = io.open(file, "rb")
    local content = f:read("*all")
    f:close()
    return content
end


return {
  getStory = function (filename)
    return runtime(parser:match(read(filename)))
  end


}
