-- usage:
-- local logging = require('logging')
-- logging.debugEnabled = true
-- logging.debug(foo, bar, {foo=bar})
-- note: every time it's required the same instance is used, so the 'enabled' flag is shared

local function dump(v, indent)
    indent = indent or 0
    local t = type(v)
    if t == 'table' then
        local s = '{\n'
        for k, val in pairs(v) do
            s = s .. string.rep('  ', indent + 1) .. tostring(k) .. ' = ' .. dump(val, indent + 1) .. ',\n'
        end
        return s .. string.rep('  ', indent) .. '}'
    end
    return tostring(v)
end

local logging = {
    debugEnabled = false,
    lastLocation = nil,
}

local getLocation = function(location)
    return location[1] .. ', line ' .. location[2] .. ', column ' .. location[3]
end

local getLogMessage = function(message, token)
    local location = ''
    if token and token.location then
        location = '\n\tsomewhere around ' .. getLocation(token.location)
    elseif logging.lastLocation then
        location = '\n\tsomewhere after ' .. getLocation(logging.lastLocation)
    end
    if token and type(token) == 'table' and token.type then
        location = location .. ', node type: ' .. token.type
    end
    return message .. location
end

logging.debug = function(...)
    if not logging.debugEnabled then
        return
    end
    local args = { ... }
    if #args == 0 then
        print('(nil)')
    end
    for _, x in ipairs(args) do
        print(dump(x))
    end
end

logging.error = function(message, token)
    error(getLogMessage(message, token))
end

logging.info = function()
    -- TODO
end
logging.warn = function(message, token)
    io.stderr:write('WARNING: ' .. getLogMessage(message, token) .. '\n')
end

return logging
