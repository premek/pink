local base_path = (...):match("(.-)[^%.]+$")
local out = require(base_path .. 'out')
local list = require(base_path .. 'list')
local types = require(base_path .. 'types')
local logging = require(base_path .. 'logging')
local err = logging.error
local _debug = logging.debug
local requireType = types.requireType
local is = types.is


local builtins = {
    }

local floor = function(a)
    requireType(a, 'float', 'int')
    return {'int', math.floor(a[2])}
end

local ceil = function(a)
    requireType(a, 'float', 'int')
    -- int -> int, float -> float
    return {a[1], math.ceil(a[2])}
end

local int = function(a)
    requireType(a, 'float', 'int')

    if a[2] > 0 then
        return {'int', math.floor(a[2])}
    else
        return {'int', math.ceil(a[2])}
    end
end

local float = function(a)
    requireType(a, 'float', 'int')
    return {'float', a[2]}
end

local seedRandom = function(a)
    requireType(a, 'float', 'int')
    math.randomseed(a[2])
end
local random = function(minInclusive, maxInclusive)
    requireType(minInclusive, 'int')
    requireType(maxInclusive, 'int')
    return {'int', math.random(minInclusive[2], maxInclusive[2])}
end

local readCount = function(a)
    requireType(a, 'divert')
    local var = builtins.getEnv(a[2]) -- FIXME
    requireType(var, 'int')
    return var
end

local choiceCount = function()
    return {'int', #builtins.currentChoices} -- FIXME get the value from runtime
end

local add = function(a,b)
    requireType(a, 'bool', 'str', 'float', 'int', 'list')
    requireType(b, 'bool', 'str', 'float', 'int', 'list', 'el')

    if a[1] == 'str' or b[1] == 'str' then
        return {"str", types.toStr(a)[2] .. types.toStr(b)[2]}
    end

    if a[1] == 'list' and (b[1] == 'list' or b[1] == 'el') then -- FIXME
        return list.plus(a, b)
    end
    if a[1] == 'list' and b[1] == 'int' then
        return list.inc(a, b[2])
    end

    if a[1] == 'bool' then
        a = types.toInt(a)
    end
    if b[1] == 'bool' then
        b = types.toInt(b)
    end

    if a[1] == 'float' or b[1] == 'float' then
        return {"float", types.toFloat(a)[2] + types.toFloat(b)[2]}
    end

    local t = a[1] == 'int' and b[1] == 'int' and 'int' or 'float'
    return {t, a[2] + b[2]}
end

local sub = function(a,b)
    requireType(a, 'float', 'int', 'bool', 'list')
    requireType(b, 'float', 'int', 'bool', 'list', 'el')

    if a[1] == 'list' then
        return list.minus(a, b)
    end

    if b[1] == 'bool' then
        b = types.toInt(b)
    end

    return add(a, {b[1], -b[2]})
end

local mul = function(a,b)
    requireType(a, 'float', 'int')
    requireType(b, 'float', 'int')

    local t = a[1] == 'int' and b[1] == 'int' and 'int' or 'float'

    return {t, a[2] * b[2]}
end

local div = function(a,b)
    requireType(a, 'float', 'int')
    requireType(b, 'float', 'int')

    if a[1] == 'float' or b[1] == 'float' then
        return {'float', a[2]/b[2]}
    else
        return {"int", math.floor(a[2]/b[2])}
    end
end

local pow = function(a, b)
    requireType(a, 'float', 'int')
    requireType(b, 'float', 'int')

    if a[1] == 'float' or b[1] == 'float' then
        return {'float', a[2] ^ b[2]}
    else
        return {"int", math.floor(a[2] ^ b[2])}
    end
end


local mod = function(a,b)
    requireType(a, 'float', 'int')
    requireType(b, 'float', 'int')

    local t = a[1] == 'int' and b[1] == 'int' and 'int' or 'float'

    return {t, math.fmod(a[2],b[2])}
end

local notFn = function(a)
    requireType(a, 'bool', 'int', 'float') -- str not allowed

    return {"bool", not types.toBool(a)[2]}
end

local eq = function(a,b)
    _debug("EQ", a, b)
    requireType(a, 'bool', 'str', 'float', 'int', 'list', 'el', 'divert')
    requireType(b, 'bool', 'str', 'float', 'int', 'list', 'el', 'divert')

    -- str and bool/num
    if a[1] == 'str' or b[1] == 'str' then
        return {"bool", types.toStr(a)[2] == types.toStr(b)[2]}
    end

    -- bool and str/num
    if a[1] == 'bool' or b[1] == 'bool' then
        -- bool and number -> only '1' evaluates to true
        if types.isNum(a) then
            return {"bool", (a[2] == 1) == b[2]}
        elseif types.isNum(b) then
            return {"bool", (b[2] == 1) == a[2]}
        end
    end

    -- TODO all combinations
    if a[1] == 'list' and b[1] == 'el' then
        return {'bool', list.contains(a, b)}
    elseif a[1] == 'el' and b[1] == 'list' then
        return {'bool', list.contains(b, a)}
    elseif a[1] == 'el' and b[1] == 'el' then
        return {'bool', a[2]==b[2] and a[3]==b[3]}
    end

    if (a[1]==b[1]) or
        ((a[1] == 'int' or a[1] == 'float') and (b[1] == 'int' or b[1] == 'float')) then
        return {"bool", a[2]==b[2]}
            -- TODO resolve path when comparing diverts?
    end

    err('eq not yet implemented for: '..a[1]..', '..b[1])
end

local notEq = function(a,b)
    return notFn(eq(a,b))
end

local gt
gt = function(a,b)
    requireType(a, 'bool', 'int', 'float', 'el', 'list')
    requireType(b, 'bool', 'int', 'float', 'el', 'list')
    if (a[1] == 'el' or a[1] == 'list') and (b[1] == 'el' or b[1] == 'list') then
        return gt(list.value(a), list.value(b))
    end
    return {'bool', types.toFloat(a)[2] > types.toFloat(b)[2]}
end
local gte
gte = function(a,b)
    requireType(a, 'bool', 'int', 'float', 'el', 'list')
    requireType(b, 'bool', 'int', 'float', 'el', 'list')
    if (a[1] == 'el' or a[1] == 'list') and (b[1] == 'el' or b[1] == 'list') then
        return gte(list.value(a), list.value(b))
    end
    return {'bool', types.toFloat(a)[2] >= types.toFloat(b)[2]}
end
local lt
lt = function(a,b)
    requireType(a, 'bool', 'int', 'float', 'el', 'list')
    requireType(b, 'bool', 'int', 'float', 'el', 'list')
    if (a[1] == 'el' or a[1] == 'list') and (b[1] == 'el' or b[1] == 'list') then
        return lt(list.value(a), list.value(b))
    end
    return {'bool', types.toFloat(a)[2] < types.toFloat(b)[2]}
end
local lte
lte = function(a,b)
    requireType(a, 'bool', 'int', 'float', 'el', 'list')
    requireType(b, 'bool', 'int', 'float', 'el', 'list')
    if (a[1] == 'el' or a[1] == 'list') and (b[1] == 'el' or b[1] == 'list') then
        return lte(list.value(a), list.value(b))
    end
    return {'bool', types.toFloat(a)[2] <= types.toFloat(b)[2]}
end
local min = function(a,b)
    requireType(a, 'bool', 'int', 'float')
    requireType(b, 'bool', 'int', 'float')
    return {'float', math.min(types.toFloat(a)[2], types.toFloat(b)[2])}
end
local max = function(a,b)
    requireType(a, 'bool', 'int', 'float')
    requireType(b, 'bool', 'int', 'float')
    return {'float', math.max(types.toFloat(a)[2], types.toFloat(b)[2])}
end

local contains = function(a,b)
    if is('str', a) and is('str', b) then
        return {"bool", string.find(a[2], b[2])}
    elseif is('el', a) and is('el', b) then
        return eq(a,b)
    elseif is('list', a) and is('el', b) then
        return {"bool", list.contains(a, b)}
    elseif is('list', a) and is('list', b) then
        return {"bool", list.containsAll(a, b)}
    end
    _debug(a, b)
    err('unexpected type')
end

local notContains = function(a,b)
    return {"bool", not contains(a,b)[2]}
end

local orFn = function(a,b)
    requireType(a, 'bool', 'int', 'float') -- str not allowed
    requireType(b, 'bool', 'int', 'float') -- str not allowed
    return {"bool", types.toBool(a)[2] or types.toBool(b)[2]}
end

local andFn = function(a,b)
    requireType(a, 'bool', 'int', 'float') -- str not allowed
    requireType(b, 'bool', 'int', 'float') -- str not allowed
    return {"bool", types.toBool(a)[2] and types.toBool(b)[2]}
end


builtins.FLOOR={'native', floor}
builtins.CEILING={'native', ceil}
builtins.INT={'native', int}
builtins.FLOAT={'native', float}
builtins.SEED_RANDOM={'native', seedRandom}
builtins.RANDOM={'native', random}
builtins.READ_COUNT={'native', readCount}
builtins.CHOICE_COUNT={'native', choiceCount}
builtins['+']={'native', add}
builtins['-']={'native', sub}
builtins['*']={'native', mul}
builtins['/']={'native', div}
builtins.POW={'native', pow}
builtins['%']={'native', mod}
builtins['mod']={'native', mod}
builtins['==']={'native', eq}
builtins['!=']={'native', notEq}
builtins['?']={'native', contains}
builtins.has={'native', contains}
builtins['!?']={'native', notContains}
builtins.hasnt={'native', notContains}
builtins['not']={'native', notFn}
builtins['||']={'native', orFn}
builtins['&&']={'native', andFn}
builtins['or']={'native', orFn}
builtins['and']={'native', andFn}
builtins['<']={'native', lt}
builtins['<=']={'native', lte}
builtins['>']={'native', gt}
builtins['>=']={'native', gte}
builtins.MIN={'native', min}
builtins.MAX={'native', max}
builtins.LIST_VALUE={'native', list.value}
builtins.LIST_COUNT={'native', list.count}
builtins.LIST_RANDOM={'native', list.random}
builtins.LIST_ALL={'native', list.all}
builtins.LIST_MIN={'native', list.min}
builtins.LIST_MAX={'native', list.max}
builtins.LIST_INVERT={'native', list.invert}
builtins.LIST_RANGE={'native', list.range}
builtins['^']={'native', list.intersection}

return builtins

