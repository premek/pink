local love = love
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

-- TODO allow provide implementation from client code or pass an ink content in a string
if love and love.filesystem then
    return loveFileReader
else
    return ioFileReader
end
