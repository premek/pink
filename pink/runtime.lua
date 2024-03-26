math.randomseed(os.time())

local debugOn = false
local _debug = function(...)
    if not debugOn then return end
    local args = {...}
    if #args == 0 then
        print(nil)
    end
    for _, x in ipairs(args) do
        print( require('test/luaunit').prettystr(x) )
    end
end

local lastLocation = nil
local getLocation = function(location)
    return location[1] .. ', line ' .. location[2] .. ', column ' .. location[3]
end

local getLogMessage = function (message, token)
    local location = ''
    if token and token.location then
        location = '\n\tsomewhere around ' .. getLocation(token.location)
    elseif lastLocation then
        location = '\n\tsomewhere after ' .. getLocation(lastLocation)
    end
    return message..location
end
local err = function(message, token)
    error(getLogMessage(message, token))
end
local log = function(_message, _token)
-- TODO print('WARN:\t' .. getLogMessage(message, token))
end


local is = function (what, node)
    return node ~= nil
        and (type(node) == "table" and node[1] == what)
end

-- requires a table where the first element is a string name of the type, e.g. {'int', 9}
local requirePinkType = function(a)
    if a == nil then
        err('null not allowed')
    end
    if type(a) ~= 'table' then
        err('table expected')
    end
    if #a < 1 or type(a[1]) ~= 'string' then
        error('pink type expected')
    end
end

local isNum = function(a)
    return a[1] == 'int' or a[1] == 'float'
end



local output




local rtrim = function(s)
    return s:match("(.-)%s*$")
end
--[[
local ltrim = function(s)
return s:match("^%s*(.-)")
end]]--
local trim = function(s)
    return s:match("^%s*(.-)%s*$")
end

return function (globalTree, debuggg)
    debugOn = debuggg
    -- casting (not conversion; int->float possible, float->int not possible)

    local listDefs = {}
    local env
    local getEnv

    local listPlus, listMinus

    local toInt = function(a)
        requirePinkType(a)

        if a[1] == 'int' then
            return a
        elseif a[1] == 'bool' then
            return {'int', a[2] and 1 or 0}
        else
            error('cannot convert: '..a[1])
        end
    end


    local toFloat = function(a)
        requirePinkType(a)

        if a[1] == 'float' then
            return a
        elseif a[1] == 'int' then
            return {'float', a[2]}
        elseif a[1] == 'bool' then
            return {'float', a[2] and 1 or 0}
        else
            error('cannot convert: '..a[1])
        end
    end


    local toStr = function(a)
        requirePinkType(a)

        if a[1] == 'str' then
            return a
        else
            return {'str', output(a)}
        end
    end

    local toBool = function(a)
        requirePinkType(a)

        if a[1] == 'bool' then
            return a
        elseif a[1] == 'int' or a[1] == 'float' then
            return {'bool', a[2] ~= 0}
        elseif a[1] == 'str' then
            return  {'bool', #a[2] ~= 0}
        else
            error('cannot convert: '..a[1])
        end
    end


    local requireType = function(a, ...)
        requirePinkType(a)
        for _, requiredType in ipairs{...} do
            if a[1] == requiredType then
                return
            end
        end
        err("unexpected type: " .. a[1] .. ", expected one of: " .. table.concat({...}, ', '), a)
    end


    -- builtin functions

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

    local add = function(a,b)
        requireType(a, 'bool', 'str', 'float', 'int', 'list')
        requireType(b, 'bool', 'str', 'float', 'int', 'list', 'el')

        if a[1] == 'str' or b[1] == 'str' then
            return {"str", toStr(a)[2] .. toStr(b)[2]}
        end

        if a[1] == 'list' and (b[1] == 'list' or b[1] == 'el') then -- FIXME
            return listPlus(a, b)
        end

        if a[1] == 'bool' then
            a = toInt(a)
        end
        if b[1] == 'bool' then
            b = toInt(b)
        end

        if a[1] == 'float' or b[1] == 'float' then
            return {"float", toFloat(a)[2] + toFloat(b)[2]}
        end

        local t = a[1] == 'int' and b[1] == 'int' and 'int' or 'float'
        return {t, a[2] + b[2]}
    end

    local sub = function(a,b)
        requireType(a, 'float', 'int', 'bool', 'list')
        requireType(b, 'float', 'int', 'bool', 'el')

        if a[1] == 'list' and b[1] == 'el' then
            return listMinus(a, b)
        end

        if a[1] == 'bool' then
            a = toInt(a)
        end
        if b[1] == 'bool' then
            b = toInt(b)
        end

        local t = a[1] == 'int' and b[1] == 'int' and 'int' or 'float'
        return {t, a[2] - b[2]}
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

    local listIterateElements = function(list, callback)
        for listName, els in pairs(list[2]) do
            for elName, _ in pairs(els) do
                callback({'el', listName, elName})
            end
        end
    end

    local listValueInt = function(a)
        requireType(a, 'el', 'list')

        if is('el', a) then
            local listName, elementName = a[2], a[3]
            if not listName then
                err('ambiguous list element: '..elementName)
            end
            return listDefs[listName].byName[elementName]

        elseif is('list', a) then
            local result = 0
            for listName, els in pairs(a[2]) do
                for elementName, _ in pairs(els) do
                    result = listDefs[listName].byName[elementName]
                    -- do not break, use the last one that is set to true
                end
            end
            return result
        end
    end

    local listValue = function(a)
        return {'int', listValueInt(a)}
    end

    local listContains = function(list, el)
        requireType(list, 'list')
        requireType(el, 'el')

        local listName, elName = el[2], el[3]
        return list[2][listName] ~= nil and list[2][listName][elName] ~= nil
    end
    local listContainsAll = function(hay, needles)
        requireType(hay, 'list')
        requireType(needles, 'list')

        local empty = true -- no lists contain the empty list
        local res = true
        listIterateElements(needles, function(needle)
            empty = false
            res = res and listContains(hay, needle)
        end)
        return empty or res
    end

    local listElByValue = function(listName, elementValue)
        return {'el', listName, listDefs[listName].byValue[elementValue]}
    end

    local listGetElements = function(list)
        local els = {}
        listIterateElements(list, function(el)
            table.insert(els, el)
        end)
        return els
    end

    local getListElements = function(els, knownListNames)
        local elements = {}
        for _, listName in ipairs(knownListNames) do
            elements[listName] = {}
        end
        for _, el in ipairs(els) do
            requireType(el, 'el')
            local listName, elName = el[2], el[3]
            if listName == nil then
                err('ambiguous list element: ' .. elName)
            end

            elements[listName] = elements[listName] or {}
            elements[listName][elName] = 1
        end
        -- elements: {[listName1] = {elName1=1, elName2=1}, [listName2] = {...}, ...}
        return elements
    end

    local listFromEls = function(els, knownListNames)
        return {'list', getListElements(els, knownListNames)}
    end

    local listFromLit = function(listLiteral)
        requireType(listLiteral, 'listlit')
        local els = {}
        for _, elName in ipairs(listLiteral[2]) do
            local el = getEnv(elName)
            table.insert(els, el)
        end
        return listFromEls(els, {})
    end

    local listCopy = function(list)
        local res = {}
        for listName, els in pairs(list[2]) do

            res[listName] = res[listName] or {}
            for elName, _ in pairs(els) do
                res[listName][elName] = 1
            end
        end
        return {'list', res}
    end

    local listSetInternal = function(list, el, internalValue)
        requireType(list, 'list')
        requireType(el, 'el')
        list[2][el[2]] = list[2][el[2]] or {}
        list[2][el[2]][el[3]] = internalValue -- just a placeholder value, we're using keys, nil to unset
    end
    local listAdd = function(list, el)
        listSetInternal(list, el, 1)
    end
    local listRemove = function(list, el)
        listSetInternal(list, el, nil)
    end

    listPlus = function(a, b)
        requireType(a, 'list')
        requireType(b, 'el', 'list')

        local new = listCopy(a)
        if is('el', b) then
            listAdd(new, b)
        else
            for listName, els in pairs(b[2]) do
                for elName, _ in pairs(els) do
                    listAdd(new, {'el', listName, elName}) -- FIXME not nice?
                end
            end
        end
        return new
    end
    listMinus = function(list, el)
        local new = listCopy(list)
        listRemove(new, el)
        return new
    end

    local listSet = function(list, new)
        requireType(list, 'list')
        requireType(new, 'list', 'el')

        local els
        if is('el', new) then
            els = {new}
        else
            -- TODO -- rename functions
            els = listGetElements(new)
        end
        if #els == 0 then
            -- keep the known lists
            listIterateElements(list, function(el) list[2][el[2]] = {} end)
        else
            list[2] = getListElements(els, {}) --FIXME known lists
        end
    end

    -- set all to false,except the element (element does not have to be from the same list)
    local listSetValue = function(list, value)
        for listName, _ in pairs(list[2]) do
            local elName = listDefs[listName].byValue[value]
            if elName then
                listSet(list, {'el', listName, elName}) --FIXME
            end
        end
    end

    local listOutput = function(list)
        local outEls = listGetElements(list)
        table.sort(outEls, function(a,b)
            local val = listValueInt(a) - listValueInt(b)
            return val == 0 and a[2]<b[2] or val<0
        end)

        local names = {}
        for _, el in ipairs(outEls) do
            table.insert(names, el[3])
        end
        return table.concat(names, ', ')
    end


    -- sets the present value of the list 'a' times to the next element
    -- empty list stays empty
    -- list with elements from different listDefs: undefined??? --TODO
    local listInc = function(list, a)
        local value=listValueInt(list) + a
        listSetValue(list, value)
    end

    local listAll = function(a)
        requireType(a, 'el', 'list') -- TODO is 'el' just a 'list' with one element?
        local listNames = {}
        if a[1] == 'el' then
            table.insert(listNames, a[2])
        else
            -- collect "known" lists
            for listName, _ in pairs(a[2]) do
                table.insert(listNames, listName)
            end
        end
        local els = {}

        for _, listName in ipairs(listNames) do
            for elName, _ in pairs(listDefs[listName].byName) do
                table.insert(els, {'el', listName, elName})
            end
        end

        return listFromEls(els, listNames)
    end

    local listInvert = function(list)
        -- TODO optimise
        local new = listAll(list)
        for listName, els in pairs(list[2]) do
            for elName, _ in pairs(els) do
                new = listMinus(new, {'el', listName, elName})
            end
        end
        return new
    end

    local listRange = function(list, minIncl, maxIncl)
        if is('el', minIncl) then
            minIncl = listValue(minIncl)
        end
        if is('el', maxIncl) then
            maxIncl = listValue(maxIncl)
        end
        requireType(minIncl, 'int')
        requireType(maxIncl, 'int')

        local els = {}
        local listNames = {}
        listIterateElements(list, function(el)
            table.insert(listNames, el[2])
            local val = listValueInt(el)
            if minIncl[2] <= val and val <= maxIncl[2] then
                table.insert(els, el)
            end
        end)
        return listFromEls(els, listNames)
    end

    local listIntersection = function(a, b)
        requireType(a, 'list')
        requireType(b, 'list')
        local els = {}
        listIterateElements(b, function(el)
            if listContains(a, el) then
                table.insert(els, el)
            end
        end)
        return listFromEls(els, {})
    end


    local eq = function(a,b)
        _debug("EQ", a, b)
        requireType(a, 'bool', 'str', 'float', 'int', 'list', 'el')
        requireType(b, 'bool', 'str', 'float', 'int', 'list', 'el')

        -- str and bool/num
        if a[1] == 'str' or b[1] == 'str' then
            return {"bool", toStr(a)[2] == toStr(b)[2]}
        end

        -- bool and str/num
        if a[1] == 'bool' or b[1] == 'bool' then
            -- bool and number -> only '1' evaluates to true
            if isNum(a) then
                return {"bool", (a[2] == 1) == b[2]}
            elseif isNum(b) then
                return {"bool", (b[2] == 1) == a[2]}
            end
        end

        -- TODO all combinations
        if a[1] == 'list' and b[1] == 'el' then
            return {'bool', listContains(a, b)}
        elseif a[1] == 'el' and b[1] == 'list' then
            return {'bool', listContains(b, a)}
        elseif a[1] == 'el' and b[1] == 'el' then
            return {'bool', a[2]==b[2] and a[3]==b[3]}
        end

        -- same type
        if a[1]==b[1] then
            return {"bool", a[2]==b[2]}
        end

        return {'bool', false}
    end

    local notEq = function(a,b)
        return {"bool", not eq(a,b)[2]}
    end

    local gt
    gt = function(a,b)
        requireType(a, 'bool', 'int', 'float', 'el', 'list')
        requireType(b, 'bool', 'int', 'float', 'el', 'list')
        if (a[1] == 'el' or a[1] == 'list') and (b[1] == 'el' or b[1] == 'list') then
            return gt(listValue(a), listValue(b))
        end
        return {'bool', toFloat(a)[2] > toFloat(b)[2]}
    end
    local gte
    gte = function(a,b)
        requireType(a, 'bool', 'int', 'float', 'el', 'list')
        requireType(b, 'bool', 'int', 'float', 'el', 'list')
        if (a[1] == 'el' or a[1] == 'list') and (b[1] == 'el' or b[1] == 'list') then
            return gte(listValue(a), listValue(b))
        end
        return {'bool', toFloat(a)[2] >= toFloat(b)[2]}
    end
    local lt
    lt = function(a,b)
        requireType(a, 'bool', 'int', 'float', 'el', 'list')
        requireType(b, 'bool', 'int', 'float', 'el', 'list')
        if (a[1] == 'el' or a[1] == 'list') and (b[1] == 'el' or b[1] == 'list') then
            return lt(listValue(a), listValue(b))
        end
        return {'bool', toFloat(a)[2] < toFloat(b)[2]}
    end
    local lte
    lte = function(a,b)
        requireType(a, 'bool', 'int', 'float', 'el', 'list')
        requireType(b, 'bool', 'int', 'float', 'el', 'list')
        if (a[1] == 'el' or a[1] == 'list') and (b[1] == 'el' or b[1] == 'list') then
            return lte(listValue(a), listValue(b))
        end
        return {'bool', toFloat(a)[2] <= toFloat(b)[2]}
    end

    local contains = function(a,b)
        if is('str', a) and is('str', b) then
            return {"bool", string.find(a[2], b[2])}
        elseif is('list', a) and is('el', b) then
            return {"bool", listContains(a, b)}
        elseif is('list', a) and is('list', b) then
            return {"bool", listContainsAll(a, b)}
        end
        err('unexpected type')
    end

    local notContains = function(a,b)
        return {"bool", not contains(a,b)[2]}
    end

    local notFn = function(a)
        requireType(a, 'bool', 'int', 'float') -- str not allowed

        return {"bool", not toBool(a)[2]}
    end


    local orFn = function(a,b)
        requireType(a, 'bool', 'int', 'float') -- str not allowed
        requireType(b, 'bool', 'int', 'float') -- str not allowed
        return {"bool", toBool(a)[2] or toBool(b)[2]}
    end

    local andFn = function(a,b)
        requireType(a, 'bool', 'int', 'float') -- str not allowed
        requireType(b, 'bool', 'int', 'float') -- str not allowed
        return {"bool", toBool(a)[2] and toBool(b)[2]}
    end


    local rootEnv = {
        FLOOR={'native', floor},
        CEILING={'native', ceil},
        INT={'native', int},
        FLOAT={'native', float},
        SEED_RANDOM={'native', seedRandom},
        RANDOM={'native', random},
        ['+']={'native', add},
        ['-']={'native', sub},
        ['*']={'native', mul},
        ['/']={'native', div},
        POW={'native', pow},
        ['%']={'native', mod},
        ['mod']={'native', mod},
        ['==']={'native', eq},
        ['!=']={'native', notEq},
        ['?']={'native', contains},
        ['!?']={'native', notContains},
        ['not']={'native', notFn},
        ['||']={'native', orFn},
        ['&&']={'native', andFn},
        ['or']={'native', orFn},
        ['and']={'native', andFn},
        ['<']={'native', lt},
        ['<=']={'native', lte},
        ['>']={'native', gt},
        ['>=']={'native', gte},
        LIST_VALUE={'native', listValue},
        LIST_ALL={'native', listAll},
        LIST_INVERT={'native', listInvert},
        LIST_RANGE={'native', listRange},
        ['^']={'native', listIntersection},
    }

    env = rootEnv -- TODO should env be part of the callstack?

    local returnValue -- set when interpreting a 'return' statement, read after stepping 'Out'
    -- does it have to be a stack?
    -- TODO add isReturning boolean flag  - allow returning nil

    -- story - this table will be passed to client code
    local s = {
        globalTags = {},
        state = {
            visitCount = {},
        },
        variablesState = env
    }

    local tree = globalTree
    local pointer = 1
    local callstack = {}
    local knots = {}
    local tags = {} -- maps (pointer to para) -> (list of tags)
    local tagsForContentAtPath = {}

    -- TODO rewrite
    local out = {
        buffer = {},
        instr = function(self, instr)
            table.insert(self.buffer, {[instr] = true})
        end,
        add = function(self, text)
            table.insert(self.buffer, text)
        end,
        collect = function(self)
            _debug(self.buffer)

            local t = {}
            local glue = false
            for _, e in ipairs(self.buffer) do
                if e['glue'] then
                    glue = true
                    for i=#t, 1, -1 do
                        if t[i] == '\n' then
                            table.remove(t, i)
                        elseif t[i] == ' ' then
                            local _ -- keep spaces, but keep glueing
                        elseif type(t[i])=='string' then -- don't stop glueing at instructions
                            break
                        end
                    end
                elseif glue and e=='\n' then
                    local _
                    -- ignore newlines after glue
                else
                    table.insert(t, e)
                    if type(e)=='string' then -- TODO
                        -- don't stop glueing at instructions
                        glue = false
                    end
                end
            end
            self.buffer = t


            t = {}
            for i, e in ipairs(self.buffer) do
                if e['trimEnd'] then
                    for j=i-1, 1, -1 do
                        if t[j] then
                            if t[j]['trim'] then
                                break
                            end
                            t[j] = rtrim(t[j])
                            if #(t[j]) > 0 then
                                break
                            end
                        end
                    end
                else
                    table.insert(t, e)
                end
            end
            self.buffer = t
            _debug(t)


            t = {}
            for _, e in ipairs(self.buffer) do
                if e['trim'] then
                    local _
                elseif e == '' then
                    local _
                else
                    table.insert(t, e)
                end
            end
            self.buffer = t

            t = {}
            for _, e in ipairs(self.buffer) do
                if e == '\n' and t[#t] == '\n' then
                    local _
                    -- remove double newlines
                else
                    table.insert(t, e)
                end
            end

            _debug(t)
            local str, _ = table.concat(t):gsub(" +", " "):gsub("\n +", "\n"):gsub(" \n", "\n") --FIXME
            self.buffer = {str}
        end,
        toString = function(self)
            self:collect()
            return rtrim(self.buffer[1])
        end,
        clear = function(self)
            self.buffer = {}
        end,
        isEmpty = function(self)
            return (#(self:toString()) == 0)
        end
    }

    -- TODO state should contain tree/pointer to be able to save / load


    local isEnd = function()
        return tree[pointer] == nil
    end
    local isNext = function (what)
        return is(what, tree[pointer])
    end

    local getEnvOptional = function(name)
        local e = env
        while e ~= nil do
            local val = e[name]
            if val ~= nil then
                return val, e
            end
            e=e._parent
        end
    end

    getEnv = function(name, token)
        local val, e = getEnvOptional(name)
        if val == nil then
            -- FIXME detect on compile time
            _debug(name, env)
            err('unresolved variable: ' .. name, token)
        end
        return val, e
    end

    local stepInto = function(block, opts)
        opts = opts or {}
        _debug("step into")
        if opts.lineStart ~= nil and not opts.lineStart then
            out:instr('glue')
        end
        -- TODO everything on the stack, current pointer, tree, env; not 'out'
        table.insert(callstack, {tree=tree, pointer=pointer})
        local newEnv = opts.env or {}
        newEnv._parent = env -- TODO make parent unaccessible from the script
        env = newEnv
        _debug(env)
        tree = block
        pointer = 1
    end

    -- like stepInto but one step before, so when we step out, we do not skip the first instruction
    -- FIXME stepInto must be called after calling this
    local returnTo = function(block)
        stepInto(block)
        pointer = 0
    end

    local stepOut = function()
        local frame = table.remove(callstack)
        if not frame then
            return err('failed to step out')
        end
        _debug("stepOut")

        pointer = frame.pointer
        tree = frame.tree
        env = env._parent -- TODO encapsulate somehow / add to the frame?
    end

    -- var = var + a
    local addVariable = function(ref, a)
        local name = ref[2]
        local var = getEnv(name)
        requireType(var, 'float', 'int', 'list')
        if is('list', var) then
            listInc(var, a)
        else
            var[2] = var[2] + a
        end
    end

    local incrementSeenCounter = function(path)
        _debug('increment seen counter: '..path)
        rootEnv[path][2] = rootEnv[path][2] + 1 --FIXME??
    end

    local update, getValue


    -- params: placeholders defined in the function/knot definition.
    -- args: the actual values or expressions passed to the function/knot when calling it
    -- returns a new env with names of params set to argument values
    local getArgumentsEnv = function(params, args)
        _debug("getArguments", "params", params, "args", args)
        args=args or {}
        local newEnv = {}
        for i = 1, #params do
            local paramName = params[i][1]
            local paramType = params[i][2]
            local arg = args[i]
            if paramType == 'ref' then -- TODO supported for knots?
                requireType(arg, 'ref')
                local refName = arg[2]
                if paramName ~= refName then
                    -- the referenced variable has different name inside the function
                    -- (the parameter has a different name than what's used when calling the fn)
                    -- we will point to the same value
                    -- but when assigning to it we cannot just replace it in the local env
                    newEnv[paramName] = {'ref', refName}
                end
                -- if the name is the same in and out-side the function:
                -- do not create a local variable that would reference to itself and create a loop
            elseif paramType == '->' then
                requireType(arg, 'divert')
                newEnv[paramName] = arg
            else
                -- get values from old env, set new env only after all vars are resolved from the old one
                newEnv[paramName] = getValue(arg)
            end
        end
        return newEnv

    end


    -- converts pink type to lua string type
    -- TODO name?
    output = function(a)
        requirePinkType(a)

        if a[1] == 'str' then
            return a[2]

        elseif a[1] == 'int' then
            return tostring(math.floor(a[2]))

        elseif a[1] == 'float' then
            local intPart, fracPart = math.modf(a[2])
            if fracPart == 0 then
                return tostring(intPart)
            else
                local formatted, _ = string.format("%.7f", a[2]):gsub("%.?0+$", "")
                return formatted
            end

        elseif a[1] == 'bool' then
            return tostring(a[2])

        elseif a[1] == 'el' then
            return a[3]
        elseif a[1] == 'list' then
            return listOutput(a)
        else
            error('cannot output: '..a[1])
        end
    end

    local currentKnot = nil
    local goTo
    goTo = function(path, args)
        _debug('go to', path, args)

        if path == 'END' or path == 'DONE' then
            pointer = #tree+1
            callstack={} -- ? do not step out anywhere
            return
        end

        local val = getEnvOptional(path)
        if is('divert', val) then
            goTo(val[2])
            return
        end

        if path:find('%.') ~= nil then
            -- TODO proper path resolve - could be stitch.gather or knot.stitch.gather or something else?
            local _, _, p1, p2 = path:find("(.+)%.(.+)")

            pointer = knots[p1][p2].pointer
            tree = knots[p1][p2].tree

            -- enter inside the knot
            if isNext('knot') then
                pointer = pointer + 1
            end

            incrementSeenCounter(p1) -- TODO not just knots

            -- FIXME duplicates
            currentKnot = p1
            -- automatically go to the first stitch (only) if there is no other content in the knot
            if isNext('stitch') then
                pointer = pointer + 1
            end

        elseif knots[currentKnot] and knots[currentKnot][path] then
            tree=globalTree --TODO store with knots?
            pointer = knots[currentKnot][path].pointer + 1

            -- FIXME hack
        elseif knots["//no-knot"] and knots["//no-knot"][path] then
            tree=knots["//no-knot"][path].tree -- TODO this is not stepInto, we dont want to step back, right?
            pointer = knots["//no-knot"][path].pointer
            -- TODO messy
            if isNext('option') then
                tree[pointer].used = true --FIXME different mechanism used for labelled and anon options
                tree=tree[pointer][9]
                pointer = 1
                _debug(tree)
            end
            if isNext('gather') then
                tree=tree[pointer][3]
                pointer = 1
            end
            incrementSeenCounter(path) -- TODO full paths

        elseif knots[path] then
            local params = knots[path].params
            local body = knots[path].tree
            local newEnv = getArgumentsEnv(params, args)
            stepInto(body, {env=newEnv})

            incrementSeenCounter(path) -- TODO not just knots

            currentKnot = path
            -- automatically go to the first stitch (only) if there is no other content in the knot
            if isNext('stitch') then
                pointer = pointer + 1
            end

        else
            error("unknown path: " .. path) -- TODO check at compile time?
        end

        -- TODO s.state.visitCount[path] = s.state.visitCountAtPathString(path) + 1 -- TODO stitch
    end

    local isTruthy = function(a)
        return toBool(a)[2]
    end

    local lastKnot = "//no-knot"
    local lastStitch = nil
    knots[lastKnot]={} -- TODO use proper paths instead

    local preProcess
    preProcess = function (t)

        while isNext('tag') do
            table.insert(s.globalTags, t[pointer][2])
            pointer = pointer + 1
        end


        -- 1st pass, top level const/var can reference each other in any order
        for _, n in ipairs(t) do

            -- TODO check if name already taken
            -- Errors:
            -- VAR/CONST already defined
            -- VAR/CONST name already used for a function
            if is('var', n) then
                env[n[2]] = n[3]
            end
            if is('const', n) then
                env[n[2]] = n[3] -- TODO make it constant
            end
            if is('listdef', n) then
                local listName = n[2]
                local elements = {}
                listDefs[listName] = {byName={}, byValue={}}
                for _, elDef in pairs(n[3]) do
                    local elName, elSet, elValue = elDef[1], elDef[2], elDef[3]
                    local el = {'el', listName, elName}
                    if env[elName] == nil then
                        env[elName] = el
                    else
                        -- multiple lists has an element with the same name
                        env[elName][2] = nil
                    end
                    -- TODO do we need both
                    listDefs[listName].byName[elName] = elValue
                    listDefs[listName].byValue[elValue] = elName

                    if elSet then
                        table.insert(elements, el)
                    end
                end
                env[listName] = listFromEls(elements, {listName})
            end
        end



        local aboveTags = {}
        --local lastPara = {}

        for p, n in ipairs(t) do

            if is('ink', n) then
                n[2] = preProcess(n[2])
            end
            if is('gather', n) then
                n[3] = preProcess(n[3])
            end
            if is('choice', n) then
                n[2] = preProcess(n[2]) --options
                if n[3] then
                    n[3] = preProcess({n[3]})[1] --gather -- FIXME hack
                end
            end




            if is('knot', n) then
                knots[n[2]] = {tree=n[4], params=n[3]}

                env[n[2]] = {'int', 0} -- seen counter
                lastKnot = n[2]
                lastStitch = nil
                n[4] = preProcess(n[4]) --FIXME - mess in knots[]


                tagsForContentAtPath[lastKnot] = {}
            end
            if is('stitch', n) then
                -- TODO make stitches nested same as knots
                knots[lastKnot][n[2]] = {pointer=p, tree=t}
                env[n[2]] = {'int', 0} -- seen counter TODO full paths
                lastStitch = n[2]
            end
            if is('gather', n) and n[4] then
                -- gather with a label
                if lastStitch then
                    knots[lastKnot][lastStitch][n[4]] = {pointer=p, tree=t}
                else
                    knots[lastKnot][n[4]] = {pointer=p, tree=t}
                end
                env[n[4]] = {'int', 0} -- seen counter / FIXME
            end
            if is('option', n) and n[6] then -- option with a label
                env[n[6]] = {'int', 0} -- seen counter

                if lastStitch then
                    knots[lastKnot][lastStitch][n[6]] = {pointer=p, tree=t}
                else
                    knots[lastKnot][n[6]] = {pointer=p, tree=t}
                end
            end


            -- function declarations could be after function calls in source code
            if is('fn', n) then
                env[n[2]] = {'fn', n[3], n[4]}
            end





            --  if is('tag', n) then
            --if n[2] == 'above' then
            --      if lastKnotName then table.insert(tagsForContentAtPath[lastKnotName], n[3]) end
            --      table.insert(aboveTags, n[3])
            --    end
            --if n[2] == 'end' then
            --    if tags[lastPara] then
            --         table.insert(tags[lastPara], n[2])
            --    end
            --    end
            --  end

            if is('para', n) then
                tags[p] = aboveTags
                aboveTags = {}
                -- lastPara = p
            end

        end



        -- 2nd pass for const/var - resolve values
        for _, n in ipairs(t) do
            if is('var', n) then
                local val = getValue(n[3])

                if is('el', val) then
                    -- TODO in getValue???
                    env[n[2]] = listFromLit({'listlit', {val[3]}})
                elseif is('listlit', val) then
                    env[n[2]] = listFromLit(val)
                else
                    env[n[2]] = val
                end
            end
            if is('const', n) then
                env[n[2]] = getValue(n[3]) -- TODO make it constant
            end
        end


        return t
    end


    -- "run" the node and return the return value
    -- may return "nothing" (nil)
    getValue = function(val)
        _debug("getValue", val)

        if val == nil then
            return nil --FIXME ???
                --err('nil value')
                --print('get nil')
                --val = tree[pointer] --FIXME 111
                --_debug(val)
                --update()
        end


        if is('str', val) or is('int', val) or is('float', val) or is('bool', val)
            or is('divert', val) or is('list', val) or is('el', val)
        then
            return val

        elseif is('out', val) then
            return getValue(val[2])

        elseif is('ref', val) then
            local name = val[2]
            local var = getEnv(name, val)
            return getValue(var)

        elseif is('listlit', val) then
            return getValue(listFromLit(val))

        elseif is('call', val) then
            local name = val[2]
            local args = val[3]

            -- TODO use 'ref' attributes to call this the same as other functions
            -- TODO check var type
            if name == '++' then
                addVariable(args[1], 1)
                return
            end
            if name == '--' then
                addVariable(args[1], -1)
                return
            end

            local target = getEnv(name, val)
            _debug("CALL target", target)
            -- FIXME detect unresolved function on compile time
            --

            -- call divert as fn -- FIXME
            if target[1] == 'divert' then
                local path = target[2]
                local divertTarget = getEnv(path)
                if divertTarget[1] == 'fn' then
                    target = divertTarget
                end
            end



            if target[1] == 'native' then
                local argumentValues = {}
                for _, arg in ipairs(args) do
                    table.insert(argumentValues, getValue(arg))
                end

                return target[2](table.unpack(argumentValues))

            elseif target[1] == 'fn' then
                local params = target[2]
                local body = target[3]
                local newEnv = getArgumentsEnv(params, args)
                stepInto(body, {env=newEnv})
                out:instr('trim')
                update()
                local ret = returnValue
                out:instr('trimEnd')
                _debug('RET', ret)
                returnValue = nil
                return ret
            elseif target[1] == 'list' then
                if #args == 0 then
                    return {'list', {}}
                elseif #args > 1 then
                    err('too many arguments')
                end
                requireType(args[1], 'int')
                return listElByValue(name, args[1][2])
            else
                error('invalid call target: ' .. target[1])
            end

        elseif is('ink', val) then
            -- FIXME
            local result = ""
            for i=1, #val[2] do
                local value = getValue(val[2][i])
                if value ~= nil then
                    result = result .. output(value)
                end
            end
            return {'str', result}

        else
            _debug(val)
            error('getValue: unsupported type: ' .. (type(val[1])=='string' and val[1] or type(val[1])))
        end
    end

    local canContinue = function()
        if #s.currentChoices > 0 then
            return false
        end
        return not out:isEmpty()
    end

    -- TODO move everything to getValue, call getValut from top and dont use the return value,
    -- but inside it can be used e.g. for recursive function call/return values
    update = function ()

        _debug('upd: ' .. pointer .. (tree[pointer] and tree[pointer][1] or 'END'))

        if returnValue ~= nil then
            -- do not proceed when returning from a (nested?) function call
            return
        end


        if tree[pointer] and tree[pointer].location then
            lastLocation = tree[pointer].location
        end

        local lastpointer=pointer
        local lasttree=tree -- TODO is this needed?

        if isNext('divert') then
            goTo(tree[pointer][2], tree[pointer][3])
            update()
            return
        end

        if isNext('tag') or isNext('var') or isNext('const') or isNext('nop') or
            isNext('knot') or isNext('fn') or isNext('listdef')
        then
            pointer = pointer + 1
            update()
            return
        end

        if isNext('tempvar') then
            -- TODO scope
            env[tree[pointer][2]] = getValue(tree[pointer][3])
            pointer = pointer + 1
            update()
            return
        end

        if isNext('assign') then
            local name = tree[pointer][2]
            local oldValue, e = getEnv(name)
            _debug("ASSIGN", oldValue, name, tree[pointer][3])

            if is('ref', oldValue) then
                local referenced = getEnv(oldValue[2])

                if is('list', referenced) then
                    oldValue = referenced
                end
            end

            local newValue = getValue(tree[pointer][3])
            if is('list', oldValue) and (is('el', newValue) or is('list', newValue)) then
                listSet(oldValue, newValue)
            else
                if newValue == nil then
                    err('cannot assign nil')
                end
                if is('ref', oldValue) then
                    local refName = oldValue[2]
                    local _, refEnv = getEnv(refName)
                    refEnv[refName] = newValue
                else
                    e[name] = newValue
                end
            end
            _debug(env)
            pointer = pointer + 1
            update()
            return
        end


        if isNext('return') then
            returnValue = getValue(tree[pointer][2])
            stepOut()
            --update()
            return
        end

        if isNext('choice') then
            s.canContinue = canContinue()
            if s.canContinue then
                -- output buffer first
                return
            end

            local options = tree[pointer][2]
            local gather = tree[pointer][3]
            local fallbackOption = nil

            s.currentChoices = {}

            for _, option in ipairs(options) do
                local sticky = option[7] == "sticky" -- TODO
                local fallback = option[10] == "fallback"
                local displayOption = sticky or not option.used -- TODO seen counter

                if fallback then
                    fallbackOption = option
                    displayOption = false
                end

                if displayOption then
                    for _, condition in ipairs(option[8]) do
                        if not isTruthy(getValue(condition)) then
                            displayOption = false
                            break
                        end
                    end
                end

                if displayOption then
                    -- all possible choices printed like this before selecting
                    -- FIXME
                    local oldBuf = out.buffer
                    local oldCS = callstack
                    callstack = {}
                    --TODO
                    out:clear()
                    stepInto(option[3])
                    update()
                    stepInto(option[4])
                    update()
                    local text = trim(out:toString())
                    out.buffer = oldBuf
                    callstack = oldCS
                    --local text = trim((option[3] or '') .. (option[4] or '')) -- TODO trim
                    table.insert(s.currentChoices, {text = text, option=option, gather=gather})
                end
            end

            s.canContinue = canContinue()

            if #s.currentChoices == 0 then
                if gather then
                    stepInto(gather[3])
                end
                if fallbackOption then
                    stepInto(fallbackOption[9])
                end
                if fallbackOption or gather then
                    update()
                    return
                end
            end

            pointer = pointer + 1
            return
        end




        if isNext('str')
            or isNext('bool')
            or isNext('int')
            or isNext('float')
            or isNext('ref') --?
        then

            local val = getValue(tree[pointer])
            if val ~= nil then
                out:add(output(val))
            end
            pointer = pointer + 1
            update()
            return
            --table.insert(out, s.continue())

        elseif isNext('out') then

            local lineStart = tree[pointer][3]
            if not lineStart then
                _debug("AAA")
                out:instr('glue')
            end
            local val = getValue(tree[pointer])
            if val ~= nil then
                out:add(output(val))
            end
            pointer = pointer + 1
            update()
            return

        elseif isNext('call') then
            -- ~ fn()
            -- call but ignore the result
            getValue(tree[pointer])
            pointer = pointer + 1
            update()
            return

        elseif isNext('todo') then
            log(tree[pointer][2], tree[pointer]) -- TODO
            pointer = pointer + 1
            update()
            return

        elseif isNext('glue') then
            out:instr('glue')
            pointer = pointer + 1
            update()
            return

            -- TODO tidy up
            --local last = #out > 0 and out[#out] or lastOut -- FIXME when the whole ink starts with glue
            --update()
            --            local rest = s.continue()

            --            _debug(rest)
            --            _debug(last)

            --[[ if last output ended with a space and this one starts with one, we want just one space
            if (rest:sub(1,1) == ' ' or rest:sub(1,1) == '\n')
            and last
            and (last:sub(-1) == ' ' or last:sub(-1) == '\n') then

            rest = ltrim(rest)
            end
            --]]
            -- TODO whitespace when printing, not just here
            -- https://github.com/inkle/ink/blob/
            -- 6a512190365002f54bd501b0863ded40123cb8e5/ink-engine-runtime/StoryState.cs#L894

            --table.insert(out, rest)
        elseif isNext('stitch') then
            incrementSeenCounter(tree[pointer][2])
            pointer = pointer + 1
            update()
            return

        elseif isNext('gather') then
            stepInto(tree[pointer][3])
            update()
            return

        elseif isNext('seq') then
            local seq = tree[pointer]
            -- FIXME store somewhere else, support save/load, could be a "seen counter" too
            local current = seq.current or 1
            -- TODO the lineStart parameter is on multiple places
            -- and a bit non systematic
            stepInto(seq[2][current], {lineStart=seq[3]})
            seq.current = math.min(#seq[2], current + 1)
            update()
            return

        elseif isNext('shuf') then
            local shuf = tree[pointer]
            local shuffleType = shuf[2]
            if not shuf.shuffled then
                local unshuffled = {}
                for i = 1, #shuf[3] do
                    table.insert(unshuffled, shuf[3][i])
                end

                shuf.shuffled = {}
                local shuffleUpTo = #unshuffled
                if shuffleType == 'stopping' then
                    -- shuffle all except the last one
                    shuffleUpTo = #unshuffled-1
                    shuf.shuffled[#unshuffled] = unshuffled[#unshuffled]
                end
                for i = shuffleUpTo, 1, -1 do
                    table.insert(shuf.shuffled, table.remove(unshuffled, math.random(i)))
                end
            end

            shuf.current = (shuf.current or 0) + 1 -- FIXME store somewhere else, support save/load

            if shuffleType ~= 'once' then
                shuf.current = math.min(#shuf.shuffled, shuf.current) -- TODO store for save/load
            end
            if shuf.shuffled[shuf.current] then
                stepInto(shuf.shuffled[shuf.current], {lineStart=shuf[4]})
            else
                pointer = pointer + 1
            end
            update()
            return

        elseif isNext('cycle') then
            local cycle = tree[pointer]
            -- FIXME store somewhere else, support save/load, could be a "seen counter" too
            cycle.current = cycle.current or 1
            stepInto(cycle[2][cycle.current], {lineStart=cycle[3]})
            cycle.current = cycle.current + 1
            if cycle.current > #cycle[2] then
                cycle.current = 1
            end
            update()
            return

        elseif isNext('once') then
            local once = tree[pointer]
            -- FIXME store somewhere else, support save/load, could be a "seen counter" too
            once.current = once.current or 1
            if once.current > #once[2] then
                pointer = pointer + 1
            else
                stepInto(once[2][once.current], {lineStart=once[3]})
                once.current = once.current + 1
            end
            update()
            return


            -- separates "a -> b" from "a\n -> b"
        elseif isNext('nl') then
            out:add('\n')
            pointer = pointer + 1
            update()
            return

        elseif isNext('if') then
            for _, branch in ipairs(tree[pointer][2]) do
                if isTruthy(getValue(branch[1])) then
                    stepInto(branch[2], {lineStart=tree[pointer][3]})
                    update()
                    return
                end
            end
            -- no condition evaluated to true (and the else branch not present): do nothing
            pointer = pointer + 1
            update()
            return

        elseif isNext('ink') then
            stepInto(tree[pointer][2])
            update()
            return
        end


        if isEnd() then
            --FIXME refactor so we don't need this if
            if #s.currentChoices == 0 then
                if #callstack > 0 then
                    stepOut()
                    _debug("step out at end")
                    -- FIXME
                    if isNext('call') or (isNext('out') and is('call', tree[pointer][2])) then
                        -- we just stepped out of a function without a return statement
                        out:instr('trimEnd')
                    end
                    pointer = pointer + 1 -- step after the call where we stepped in
                    update()
                    return
                end
            end
            pointer = pointer + 1
            s.canContinue = canContinue()
            return
        end


        s.currentTags = tags[pointer] or {}

        if lastpointer == pointer and lasttree == tree then
            _debug(tree, pointer)
            err('nothing consumed in continue at pointer '..pointer)
        end


    end


    s.continue = function()
        _debug("out", out.buffer)
        local res = trim(out:toString())
        out:clear()
        update()
        _debug("OUT:"..res)
        return res;
    end

    s.currentChoices = {}

    s.chooseChoiceIndex = function(index)
        if type(index) ~= 'number' then
            error('number expected')
        end

        local choice = s.currentChoices[index]

        if choice.option[6] then -- the option has a label
            incrementSeenCounter(choice.option[6]) -- TODO full path??
        end
        choice.option.used = true -- FIXME store somewhere else, support save/load


        if choice.gather then
            returnTo(choice.gather[3])
        end
        stepInto(choice.option[9])

        s.currentChoices = {}
        update()
    end

    s.choosePathString = function(knotName)
        goTo(knotName)
        update()
    end

    s.state.visitCountAtPathString = function(knotName)
        return s.state.visitCount[knotName] or 0
    end

    s.tagsForContentAtPath = function(knotName)
        return tagsForContentAtPath[knotName] or {}
    end

    s.currentTags = {}

    -- s.state.ToJson();s.state.LoadJson(savedJson);

    tree = preProcess(tree)
    _debug(tree)
    _debug(listDefs)
    _debug(s.variablesState)

    update()

    return s
end
