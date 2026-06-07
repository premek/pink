-- usage:
-- local logging = require('logging')
-- logging.debugEnabled = true / logging.compat = true  (process-wide config)
-- local logger = logging.newLogger()   (one per story)
-- logger.debug(foo, bar, {foo=bar})

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
    compat = false,
}

local getLocation = function(location)
    return location[1] .. ', line ' .. location[2] .. ', column ' .. location[3]
end

local getLogMessage = function(message, token)
    local location = ''
    if token and token.location then
        location = '\n\tsomewhere around ' .. getLocation(token.location)
    end
    if token and type(token) == 'table' and token.type then
        location = location .. ', node type: ' .. token.type
    end
    return message .. location
end

local compatLocation = function(token)
    local loc = token and (token.location or (token[1] and token))
    if not loc then
        return ''
    end
    local filename = loc[1]:match('[^/]+$') or loc[1]
    return "'" .. filename .. "' line " .. loc[2] .. ': '
end

local function debug(...)
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

local function die(message, token)
    error(getLogMessage(message, token))
end
local function dieCompat(message, token)
    io.write('ERROR: ' .. compatLocation(token) .. message .. '\n')
    os.exit(1)
end

local function warn(message, token)
    io.stderr:write('WARNING: ' .. getLogMessage(message, token) .. '\n')
end
local function warnCompat(message, token)
    io.write('WARNING: ' .. compatLocation(token) .. message .. '\n')
end

logging.newLogger = function()
    local pendingCompatWarnings = {}

    local function ranOutOfContent(token)
        io.stderr:write('RUNTIME ERROR: ' .. getLogMessage('ran out of content', token) .. '\n')
    end
    local function ranOutOfContentCompat(token)
        io.write(
            'RUNTIME ERROR: ' .. compatLocation(token) .. "ran out of content. Do you need a '-> DONE' or '-> END'?\n"
        )
    end

    local function listStringEquality(token)
        io.stderr:write('RUNTIME ERROR: ' .. getLogMessage('eq not supported for list and string', token) .. '\n')
    end
    local function listStringEqualityCompat(token)
        io.write('RUNTIME ERROR: ' .. compatLocation(token) .. "Can not call use '==' operation on List and String\n")
    end

    local function variableNotFound(name, token)
        io.stderr:write(
            'RUNTIME WARNING: '
                .. getLogMessage('variable not found: ' .. name .. ', using default value of 0', token)
                .. '\n'
        )
    end
    local function variableNotFoundCompat(name, token)
        table.insert(
            pendingCompatWarnings,
            'RUNTIME WARNING: '
                .. compatLocation(token)
                .. "Variable not found: '"
                .. name
                .. "'. Using default value of 0 (false). This can happen with temporary variables if the"
                .. " declaration hasn't yet been hit. Globals are always given a default value on load if"
                .. " a value doesn't exist in the save state.\n"
        )
    end

    local function todo(message, token)
        io.stderr:write('TODO: ' .. getLogMessage(message, token) .. '\n')
    end
    local function todoCompat(message, token)
        io.stderr:write('TODO: ' .. compatLocation(token) .. message .. '\n')
    end
    local dieMissingExternalBinding = function(names)
        die(
            'Missing function binding for external(s): '
                .. table.concat(names, ', ')
                .. ' and no fallback ink function found'
        )
    end
    local dieMissingExternalBindingCompat = function(names)
        local quoted = {}
        for _, name in ipairs(names) do
            table.insert(quoted, "'" .. name .. "'")
        end
        local m = 'Missing function binding for external' .. (#names > 1 and 's' or '') .. ': '
        m = m .. table.concat(quoted, ', ')
        m = m .. ' , and no fallback ink function found.'
        dieCompat(m)
    end

    local log = function(pinkFn, compatFn, ...)
        if logging.compat then
            compatFn(...)
        else
            pinkFn(...)
        end
    end

    return {
        debug = debug,
        die = function(message, token)
            log(die, dieCompat, message, token)
        end,
        warn = function(message, token)
            if logging.compat then
                warnCompat(message, token)
            else
                warn(message, token)
            end
        end,
        dieRanOutOfContent = function(token)
            if logging.compat then
                ranOutOfContentCompat(token)
            else
                ranOutOfContent(token)
            end
            os.exit(1)
        end,
        dieListStringEquality = function(token)
            if logging.compat then
                listStringEqualityCompat(token)
            else
                listStringEquality(token)
            end
            os.exit(1)
        end,
        variableNotFound = function(name, token)
            if logging.compat then
                variableNotFoundCompat(name, token)
            else
                variableNotFound(name, token)
            end
        end,
        todo = function(message, token)
            if logging.compat then
                todoCompat(message, token)
            else
                todo(message, token)
            end
        end,
        drainCompatWarnings = function()
            if #pendingCompatWarnings == 0 then
                return ''
            end
            local result = table.concat(pendingCompatWarnings, '')
            pendingCompatWarnings = {}
            return result
        end,
        dieMissingExternalBindings = function(...)
            log(dieMissingExternalBinding, dieMissingExternalBindingCompat, ...)
        end,
    }
end

return logging
