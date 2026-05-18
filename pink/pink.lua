local base_path = (...):match('(.-)[^%.]+$')
local parser = require(base_path .. 'parser')
local runtime = require(base_path .. 'runtime')
local resolveIncludes = require(base_path .. 'includes')

local function loveFileReader(file)
    if not love.filesystem.getInfo(file, 'file') then
        error('failed to open "' .. file .. '"')
    end
    return love.filesystem.read(file)
end

local function ioFileReader(file)
    local f = io.open(file, 'rb')
    if not f then
        error('failed to open "' .. file .. '"')
    end
    local content = f:read('*all')
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

local function basedir(str)
    return string.gsub(str, '(.*)(/.*)', '%1')
end

return function(filename)
    local reader = getFileReader()
    local nodes = resolveIncludes(parser(reader(filename), filename), basedir(filename), reader)
    return runtime(nodes)
end
