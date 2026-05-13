local base_path = (...):match('(.-)[^%.]+$')
local node = require(base_path .. 'node')
local logging = require(base_path .. 'logging')
local err = logging.error
local _debug = logging.debug
local requireType = node.requireType
local is = node.is

return function(deps)
    local listDefinitions = deps.listDefinitions
    local builtins = {}

    local floor = function(a)
        requireType(a, 'float', 'int')
        return node.int(math.floor(a.value))
    end

    local ceil = function(a)
        requireType(a, 'float', 'int')
        -- int -> int, float -> float
        return node[a.type](math.ceil(a.value))
    end

    local int = function(a)
        requireType(a, 'float', 'int')

        if a.value > 0 then
            return node.int(math.floor(a.value))
        else
            return node.int(math.ceil(a.value))
        end
    end

    local float = function(a)
        requireType(a, 'float', 'int')
        return node.float(a.value)
    end

    local seedRandom = function(a)
        requireType(a, 'float', 'int')
        math.randomseed(a.value)
    end
    local random = function(minInclusive, maxInclusive)
        requireType(minInclusive, 'int')
        requireType(maxInclusive, 'int')
        return node.int(math.random(minInclusive.value, maxInclusive.value))
    end

    local add = function(a, b)
        requireType(a, 'bool', 'str', 'float', 'int', 'list')
        requireType(b, 'bool', 'str', 'float', 'int', 'list', 'el')

        if a.type == 'str' or b.type == 'str' then
            return node.str(node.toStr(a).value .. node.toStr(b).value)
        end

        if a.type == 'list' and (b.type == 'list' or b.type == 'el') then -- FIXME
            return node.listPlus(a, b)
        end
        if a.type == 'list' and b.type == 'int' then
            return node.listInc(a, b.value, listDefinitions)
        end

        if a.type == 'bool' then
            a = node.toInt(a)
        end
        if b.type == 'bool' then
            b = node.toInt(b)
        end

        if a.type == 'float' or b.type == 'float' then
            return node.float(node.toFloat(a).value + node.toFloat(b).value)
        end

        local t = a.type == 'int' and b.type == 'int' and 'int' or 'float'
        return node[t](a.value + b.value)
    end

    local sub = function(a, b)
        requireType(a, 'float', 'int', 'bool', 'list')
        requireType(b, 'float', 'int', 'bool', 'list', 'el')

        if a.type == 'list' then
            return node.listMinus(a, b)
        end

        if b.type == 'bool' then
            b = node.toInt(b)
        end

        return add(a, node[b.type](-b.value))
    end

    local mul = function(a, b)
        requireType(a, 'float', 'int')
        requireType(b, 'float', 'int')

        local t = a.type == 'int' and b.type == 'int' and 'int' or 'float'

        return node[t](a.value * b.value)
    end

    local div = function(a, b)
        requireType(a, 'float', 'int')
        requireType(b, 'float', 'int')

        if a.type == 'float' or b.type == 'float' then
            return node.float(a.value / b.value)
        else
            return node.int(math.floor(a.value / b.value))
        end
    end

    local pow = function(a, b)
        requireType(a, 'float', 'int')
        requireType(b, 'float', 'int')

        if a.type == 'float' or b.type == 'float' then
            return node.float(a.value ^ b.value)
        else
            return node.int(math.floor(a.value ^ b.value))
        end
    end

    local mod = function(a, b)
        requireType(a, 'float', 'int')
        requireType(b, 'float', 'int')

        local t = a.type == 'int' and b.type == 'int' and 'int' or 'float'

        return node[t](math.fmod(a.value, b.value))
    end

    local notFn = function(a)
        requireType(a, 'bool', 'int', 'float') -- str not allowed

        return node.bool(not node.toBool(a).value)
    end

    local eq = function(a, b)
        _debug('EQ', a, b)
        requireType(a, 'bool', 'str', 'float', 'int', 'list', 'el', 'divert')
        requireType(b, 'bool', 'str', 'float', 'int', 'list', 'el', 'divert')

        -- str and bool/num
        if
            (a.type == 'str' and (b.type == 'bool' or b.type == 'float' or b.type == 'int'))
            or (b.type == 'str' and (a.type == 'bool' or a.type == 'float' or a.type == 'int'))
        then
            return node.bool(node.toStr(a).value == node.toStr(b).value)
        end

        -- bool and str/num
        if a.type == 'bool' or b.type == 'bool' then
            -- bool and number -> only '1' evaluates to true
            if node.isNum(a) then
                return node.bool((a.value == 1) == b.value)
            elseif node.isNum(b) then
                return node.bool((b.value == 1) == a.value)
            end
        end

        -- TODO all combinations
        if a.type == 'list' and b.type == 'el' then
            return node.bool(node.listContains(a, b))
        elseif a.type == 'el' and b.type == 'list' then
            return node.bool(node.listContains(b, a))
        elseif a.type == 'el' and b.type == 'el' then
            return node.bool(a.listName == b.listName and a.elName == b.elName)
        end

        if a.type == 'divert' and b.type == 'divert' then
            return node.bool(a.target == b.target) -- TODO resolve path when comparing diverts?
        end

        if
            (a.type == b.type) or ((a.type == 'int' or a.type == 'float') and (b.type == 'int' or b.type == 'float'))
        then
            return node.bool(a.value == b.value)
        end

        if (a.type == 'list' and b.type == 'str') or (b.type == 'list' and a.type == 'str') then
            err('eq not supported for list and str')
        end

        if (a.type == 'el' and b.type == 'str') or (b.type == 'el' and a.type == 'str') then
            -- TODO
            err('eq not yet implemented for el and str')
        end
        err('eq not yet implemented for: ' .. a.type .. ', ' .. b.type)
    end

    local notEq = function(a, b)
        return notFn(eq(a, b))
    end

    local gt
    gt = function(a, b)
        requireType(a, 'bool', 'int', 'float', 'el', 'list')
        requireType(b, 'bool', 'int', 'float', 'el', 'list')
        if (a.type == 'el' or a.type == 'list') and (b.type == 'el' or b.type == 'list') then
            return gt(node.listValue(a, listDefinitions), node.listValue(b, listDefinitions))
        end
        return node.bool(node.toFloat(a).value > node.toFloat(b).value)
    end
    local gte
    gte = function(a, b)
        requireType(a, 'bool', 'int', 'float', 'el', 'list')
        requireType(b, 'bool', 'int', 'float', 'el', 'list')
        if (a.type == 'el' or a.type == 'list') and (b.type == 'el' or b.type == 'list') then
            return gte(node.listValue(a, listDefinitions), node.listValue(b, listDefinitions))
        end
        return node.bool(node.toFloat(a).value >= node.toFloat(b).value)
    end
    local lt
    lt = function(a, b)
        requireType(a, 'bool', 'int', 'float', 'el', 'list')
        requireType(b, 'bool', 'int', 'float', 'el', 'list')
        if (a.type == 'el' or a.type == 'list') and (b.type == 'el' or b.type == 'list') then
            return lt(node.listValue(a, listDefinitions), node.listValue(b, listDefinitions))
        end
        return node.bool(node.toFloat(a).value < node.toFloat(b).value)
    end
    local lte
    lte = function(a, b)
        requireType(a, 'bool', 'int', 'float', 'el', 'list')
        requireType(b, 'bool', 'int', 'float', 'el', 'list')
        if (a.type == 'el' or a.type == 'list') and (b.type == 'el' or b.type == 'list') then
            return lte(node.listValue(a, listDefinitions), node.listValue(b, listDefinitions))
        end
        return node.bool(node.toFloat(a).value <= node.toFloat(b).value)
    end
    local min = function(a, b)
        requireType(a, 'bool', 'int', 'float')
        requireType(b, 'bool', 'int', 'float')
        return node.float(math.min(node.toFloat(a).value, node.toFloat(b).value))
    end
    local max = function(a, b)
        requireType(a, 'bool', 'int', 'float')
        requireType(b, 'bool', 'int', 'float')
        return node.float(math.max(node.toFloat(a).value, node.toFloat(b).value))
    end

    local contains = function(a, b)
        if is('str', a) and is('str', b) then
            local pos = string.find(a.value, b.value, 1, true)
            return node.bool(pos ~= nil)
        elseif is('el', a) and is('el', b) then
            return eq(a, b)
        elseif is('list', a) and is('el', b) then
            return node.bool(node.listContains(a, b))
        elseif is('list', a) and is('list', b) then
            return node.bool(node.listContainsAll(a, b))
        end
        _debug(a, b)
        err('unexpected type')
    end

    local notContains = function(a, b)
        return node.bool(not contains(a, b).value)
    end

    local orFn = function(a, b)
        requireType(a, 'bool', 'int', 'float') -- str not allowed
        requireType(b, 'bool', 'int', 'float') -- str not allowed
        return node.bool(node.toBool(a).value or node.toBool(b).value)
    end

    local andFn = function(a, b)
        requireType(a, 'bool', 'int', 'float') -- str not allowed
        requireType(b, 'bool', 'int', 'float') -- str not allowed
        return node.bool(node.toBool(a).value and node.toBool(b).value)
    end

    local readCount = function(a)
        requireType(a, 'divert')
        local var = deps.getEnv(a.target)
        requireType(var, 'int')
        return var
    end

    local choiceCount = function()
        return node.int(#deps.getChoices())
    end

    local turnsFn = function()
        return node.int(deps.getTurns())
    end

    local turnsSince = function(a)
        requireType(a, 'divert')
        local last = deps.getTurnsSince(a.target)
        if last == nil then
            return node.int(-1)
        end
        return node.int(deps.getTurns() - last)
    end

    builtins.FLOOR = node.native(floor)
    builtins.CEILING = node.native(ceil)
    builtins.INT = node.native(int)
    builtins.FLOAT = node.native(float)
    builtins.SEED_RANDOM = node.native(seedRandom)
    builtins.RANDOM = node.native(random)
    builtins.READ_COUNT = node.native(readCount)
    builtins.CHOICE_COUNT = node.native(choiceCount)
    builtins.TURNS = node.native(turnsFn)
    builtins.TURNS_SINCE = node.native(turnsSince)

    builtins['+'] = node.native(add)
    builtins['-'] = node.native(sub)
    builtins['*'] = node.native(mul)
    builtins['/'] = node.native(div)
    builtins.POW = node.native(pow)
    builtins['%'] = node.native(mod)
    builtins['mod'] = node.native(mod)
    builtins['=='] = node.native(eq)
    builtins['!='] = node.native(notEq)
    builtins['?'] = node.native(contains)
    builtins.has = node.native(contains)
    builtins['!?'] = node.native(notContains)
    builtins.hasnt = node.native(notContains)
    builtins['not'] = node.native(notFn)
    builtins['||'] = node.native(orFn)
    builtins['&&'] = node.native(andFn)
    builtins['or'] = node.native(orFn)
    builtins['and'] = node.native(andFn)
    builtins['<'] = node.native(lt)
    builtins['<='] = node.native(lte)
    builtins['>'] = node.native(gt)
    builtins['>='] = node.native(gte)
    builtins.MIN = node.native(min)
    builtins.MAX = node.native(max)
    local listValue = function(list)
        return node.listValue(list, listDefinitions)
    end
    local listAll = function(list)
        return node.listAll(list, listDefinitions)
    end
    local listMin = function(list)
        return node.listMin(list, listDefinitions)
    end
    local listMax = function(list)
        return node.listMax(list, listDefinitions)
    end
    local listInvert = function(list)
        return node.listInvert(list, listDefinitions)
    end
    local listRange = function(list, minIncl, maxIncl)
        return node.listRange(list, minIncl, maxIncl, listDefinitions)
    end

    builtins.LIST_VALUE = node.native(listValue)
    builtins.LIST_COUNT = node.native(node.listCount)
    builtins.LIST_RANDOM = node.native(node.listRandom)
    builtins.LIST_ALL = node.native(listAll)
    builtins.LIST_MIN = node.native(listMin)
    builtins.LIST_MAX = node.native(listMax)
    builtins.LIST_INVERT = node.native(listInvert)
    builtins.LIST_RANGE = node.native(listRange)
    builtins['^'] = node.native(node.listIntersection)

    return builtins
end
