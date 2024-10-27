local base_path = (...):match('(.-)[^%.]+$')
local list = function()
    return require(base_path .. 'list')
end -- avoid cyclic dependency -- FIXME
local logging = require(base_path .. 'logging')
local err = logging.error
local _debug = logging.debug

local types = {}

types.is = function(what, node)
    return node ~= nil and (type(node) == 'table' and node[1] == what)
end

-- requires a table where the first element is a string name of the type, e.g. {'int', 9}
types.requirePinkType = function(a)
    if a == nil then
        err('null not allowed')
    end
    if type(a) ~= 'table' then
        _debug(a)
        err('table expected, got ' .. type(a))
    end
    if #a < 1 or type(a[1]) ~= 'string' then
        error('pink type expected')
    end
end

types.isNum = function(a)
    return a[1] == 'int' or a[1] == 'float'
end

-- casting (not conversion; int->float possible, float->int not possible)
types.toInt = function(a)
    types.requirePinkType(a)

    if a[1] == 'int' then
        return a
    elseif a[1] == 'bool' then
        return { 'int', a[2] and 1 or 0 }
    else
        err('cannot convert to int', a)
    end
end

types.toFloat = function(a)
    types.requirePinkType(a)

    if a[1] == 'float' then
        return a
    elseif a[1] == 'int' then
        return { 'float', a[2] }
    elseif a[1] == 'bool' then
        return { 'float', a[2] and 1 or 0 }
    else
        err('cannot convert to float', a)
    end
end

types.toStr = function(a)
    types.requirePinkType(a)

    if a[1] == 'str' then
        return a
    else
        return { 'str', types.output(a) }
    end
end

types.toBool = function(a)
    types.requirePinkType(a)

    if a[1] == 'bool' then
        return a
    elseif a[1] == 'int' or a[1] == 'float' then
        return { 'bool', a[2] ~= 0 }
    elseif a[1] == 'str' then
        return { 'bool', #a[2] ~= 0 }
    elseif a[1] == 'list' then
        return { 'bool', not list().isEmpty(a) }
    elseif a[1] == 'el' then
        return { 'bool', true }
    else
        err('cannot convert to bool', a)
    end
end

types.isTruthy = function(a)
    return types.toBool(a)[2]
end

types.requireType = function(a, ...)
    types.requirePinkType(a)
    for _, requiredType in ipairs({ ... }) do
        if a[1] == requiredType then
            return
        end
    end
    err('unexpected type: ' .. a[1] .. ', expected one of: ' .. table.concat({ ... }, ', '), a)
end

-- converts pink type to lua string type
-- TODO name?
types.output = function(a)
    types.requirePinkType(a)

    if a[1] == 'str' then
        return a[2]
    elseif a[1] == 'int' then
        return tostring(math.floor(a[2]))
    elseif a[1] == 'float' then
        local formatted, _ = string.format('%.7f', a[2]):gsub('%.?0+$', '')
        return formatted
    elseif a[1] == 'bool' then
        return tostring(a[2])
    elseif a[1] == 'el' then
        return a[3]
    elseif a[1] == 'list' then
        return list().output(a)
    else
        err('cannot output', a)
    end
end

return types
