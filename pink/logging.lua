-- usage:
-- local logging = require('logging')
-- logging.debugEnabled = true
-- logging.debug(foo, bar, {foo=bar})
-- note: every time it's required the same instance is used, so the 'enabled' flag is shared

local dump = require('test/lib/luaunit').prettystr -- TODO optional dep

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
    if token and type(token) == 'table' and #token > 0 then
        location = location .. ', node type: ' .. token[1]
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
logging.warn = function()
    -- TODO
end

return logging
