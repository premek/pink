local _debug = function(x) print( require('test/luaunit').prettystr(x) ) end

local is = function (what, node)
    return node ~= nil
        and (type(node) == "table" and node[1] == what)
end

-- requires a table where the first element is a string name of the type, e.g. {'int', 9}
local requirePinkType = function(a)
    if type(a) ~= 'table' then
        error('table expected')
    end
    if #a < 1 or type(a[1]) ~= 'string' then
        error('pink type expected')
    end
end

local isNum = function(a)
    return a[1] == 'int' or a[1] == 'float'
end

-- converts pink type to lua string type
-- TODO name?
local output = function(a)
    requirePinkType(a)

    if a[1] == 'str' then
        return a[2]

    elseif a[1] == 'int' then
        return tostring(math.floor(a[2]))

    elseif a[1] == 'float' then
        local int, frac = math.modf(a[2])
        if frac == 0 then
            return tostring(int)
        else
            return string.format("%.7f", a[2]):gsub("%.?0+$", "")
        end

    elseif a[1] == 'bool' then
        return tostring(a[2])

    else
        error('cannot output: '..a[1])
    end
end

-- casting (not conversion; int->float possible, float->int not possible)

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
    error("unexpected type")
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
    --_debug(a)

    if a[2] > 0 then
        return {'int', math.floor(a[2])}
    else
        return {'int', math.ceil(a[2])}
    end
end

local add = function(a,b)
    requireType(a, 'bool', 'str', 'float', 'int')
    requireType(b, 'bool', 'str', 'float', 'int')

    if a[1] == 'str' or b[1] == 'str' then
        return {"str", toStr(a)[2] .. toStr(b)[2]}
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
    requireType(a, 'float', 'int', 'bool')
    requireType(b, 'float', 'int', 'bool')

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

local mod = function(a,b)
    requireType(a, 'float', 'int')
    requireType(b, 'float', 'int')

    local t = a[1] == 'int' and b[1] == 'int' and 'int' or 'float'

    return {t, math.fmod(a[2],b[2])}
end


local eq = function(a,b)
    requireType(a, 'bool', 'str', 'float', 'int')
    requireType(b, 'bool', 'str', 'float', 'int')

    if a[1] == 'str' or b[1] == 'str' then
        return {"bool", toStr(a)[2] == toStr(b)[2]}
    end

    if a[1] == 'bool' or b[1] == 'bool' then
        -- bool and number -> only '1' evaluates to true
        if isNum(a) then
            return {"bool", (a[2] == 1) == b[2]}
        elseif isNum(b) then
            return {"bool", (b[2] == 1) == a[2]}
        end
    end
    return {"bool", a[1]==b[1] and a[2]==b[2]}
end

local notEq = function(a,b)
    return {"bool", not eq(a,b)[2]}
end

local contains = function(a,b)
    requireType(a, 'str')
    requireType(b, 'str')

    return {"bool", string.find(a[2], b[2])}
end

local notFn = function(a)
    requireType(a, 'bool', 'int', 'float') -- str not allowed

    return {"bool", not toBool(a)[2]}
end


return function (tree)
    local variables = {
        FLOOR={'native', floor},
        CEILING={'native', ceil},
        INT={'native', int},
        ['+']={'native', add},
        ['-']={'native', sub},
        ['*']={'native', mul},
        ['%']={'native', mod},
        ['/']={'native', div},
        ['mod']={'native', mod},
        ['==']={'native', eq},
        ['!=']={'native', notEq},
        ['?']={'native', contains},
        ['not']={'native', notFn},
    }

    local s = {
        globalTags = {},
        state = {
            visitCount = {},
        },
        variables = variables,
        callstack = {}
    }

    local pointer = 1
    local knots = {}
    local tags = {} -- maps (pointer to para) -> (list of tags)
    local tagsForContentAtPath = {}
    local currentChoicesPointers = {}

    -- TODO state should contain tree/pointer to be able to save / load


    local isEnd = function()
        return tree[pointer] == nil
    end
    local isNext = function (what)
        return is(what, tree[pointer])
    end


    local currentKnot = nil
    local goTo = function(path)
        --_debug(knots)
        --
        if type(path) == 'number' then
            pointer = path -- TODO function call, add parameters

        elseif path == 'END' or path == 'DONE' then
            pointer = #tree+1

        elseif path:find('%.') ~= nil then
            -- TODO proper path resolve - could be stitch.gather or knot.stitch.gather or something else?
            local _, _, p1, p2 = path:find("(.+)%.(.+)")

            pointer = knots[p1][p2].pointer

            -- enter inside the knot
            if isNext('knot') then
                pointer = pointer + 1
            end

            -- FIXME duplicates
            currentKnot = p1
            -- automatically go to the first stitch (only) if there is no other content in the knot
            if isNext('stitch') then
                pointer = pointer + 1
            end

        elseif knots[currentKnot] and knots[currentKnot][path] then
            pointer = knots[currentKnot][path].pointer + 1

        elseif knots[path] then
            pointer = knots[path].pointer + 1
            currentKnot = path
            -- automatically go to the first stitch (only) if there is no other content in the knot
            if isNext('stitch') then
                pointer = pointer + 1
            end

        else
            error("unknown path: " .. path) -- TODO check at compile time?
        end

        s.state.visitCount[path] = s.state.visitCountAtPathString(path) + 1 -- TODO stitch
    end

    local isTruthy = function(a)
        return toBool(a)[2]
    end

    local getValue
    getValue=function(val)
        --_debug(val)

        if val[1] == 'str' or val[1] == 'int' or val[1] == 'float' or val[1] == 'bool' then
            return val

        elseif val[1] == 'ref' then
            local name = val[2]
            local var = s.variables[name]
            if var == nil then
                -- TODO log code location, need info from parser
                -- FIXME detect on compile time
                error('unresolved variable: ' .. name)
            end
            return getValue(var)

        elseif val[1] == 'if' then
            if isTruthy(getValue(val[2])) then
                return val[3]
            elseif val[4] ~= nil then
                return val[4]
            else
                return ""
            end

        elseif val[1] == 'gather' then -- diverted into a labelled gather
            return val[3]

        elseif val[1] == 'call' then
            local name = val[2]
            -- TODO use 'ref' attributes to call this the same as other functions
            -- TODO check var type
            if name == '++' then
                s.variables[val[3]][2] = tostring(tonumber(s.variables[val[3]][2]) + 1)
                return
            end
            if name == '--' then
                s.variables[val[3]][2] = tostring(tonumber(s.variables[val[3]][2]) - 1) -- FIXME var types
                return
            end

            local target = s.variables[name]
            if target == nil then
                -- TODO log code location, need info from parser
                -- FIXME detect on compile time
                error('unresolved function: ' .. name)
            end

            if target[1] == 'native' then
                local arguments = {}
                for i=3, #val do
                    table.insert(arguments, getValue(val[i]))
                end

                return target[2](table.unpack(arguments))

            elseif target[1] == 'fn' then
                table.insert(s.callstack, pointer)
                goTo(target[2]+1) -- jump after fn declaration
                -- TODO arguments
                -- TODO return value
                return {"str", ''}
            else
                error('invalid call target: ' .. target[1])
            end

        else
            error('unsupported value type: '..val[1])
        end
    end



    local update
    update = function ()

        if isNext('divert') then
            goTo(tree[pointer][2])
            update()
            return
        end



        if isNext('tag') or isNext('var') or isNext('const') then
            pointer = pointer + 1
            update()
            return
        end

        if isNext('tempvar') then
            -- TODO scope
            s.variables[tree[pointer][2]] = tree[pointer][3]
            pointer = pointer + 1
            update()
            return
        end

        if isNext('assign') then
            -- TODO scope
            -- TODO s.variables[tree[pointer][2]] = tree[pointer][3]
            pointer = pointer + 1
            update()
            return
        end


        if isNext('list') then
            s.variables[tree[pointer][2]] = { table.unpack(tree[pointer], 3) }
            pointer = pointer + 1
            update()
            return
        end

        -- FIXME
        s.canContinue = isNext('nl')
            or isNext('str')
            or isNext('alt')
            or isNext('if')
            or isNext('gather')
            or isNext('call')

        s.currentChoices = {}
        currentChoicesPointers = {}

        if isNext('option') then
            local choiceDepth = tree[pointer][2]
            -- find all choices on the same level in the same knot and in the same super-choice
            for p=pointer, #tree do
                local n = tree[p]
                --print('looking for options', choiceDepth, n[1], n[2])
                if is('knot', n) or is('stitch', n) or (is('option', n) and n[2] < choiceDepth) then
                    --print('stop looking for options');
                    break
                end

                if is('option', n) and n[2] == choiceDepth then
                    -- print('adding', p, n[3])
                    table.insert(currentChoicesPointers, p)
                    table.insert(s.currentChoices, {
                        text = (n[3] or '') .. (n[4] or ''),
                        choiceText = n[3] .. (n[5] or ''),
                    })
                end
            end
        end
    end



    local preProcess = function ()

        while isNext('tag') do
            table.insert(s.globalTags, tree[pointer][2])
            pointer = pointer + 1
        end

        local aboveTags = {}
        --local lastPara = {}
        local lastKnot, lastStitch

        for p, n in ipairs(tree) do
            if is('knot', n) then
                knots[n[2]] = {pointer=p}
                lastKnot = n[2]
                lastStitch = nil

                tagsForContentAtPath[lastKnot] = {}
            end
            if is('stitch', n) then
                knots[lastKnot][n[2]] = {pointer=p}
                lastStitch = n[2]
            end
            if is('gather', n) and n[4] then -- gather with a label
                if lastStitch then
                    knots[lastKnot][lastStitch][n[4]] = {pointer=p}
            else
                knots[lastKnot][n[4]] = {pointer=p}
            end
            end

            -- function declarations could be after function calls in source code
            if is('fn', n) then
                s.variables[n[2]] = {'fn', p}
            end


            -- TODO check if var can be redefined, e.g. VAR cannot be set if it has the same name as a function
            if is('var', n) then
                s.variables[n[2]] = n[3]
            end
            if is('const', n) then
                s.variables[n[2]] = n[3] -- TODO const
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
    end

    s.canContinue = nil



    local lastOut = nil

    s.continue = function()
        local lastpointer=pointer

        local res = ''
        if isNext('str') or isNext('ref') then
            res = res..output(getValue(tree[pointer]))
            pointer = pointer + 1
            update()
            res = res .. s.continue()

        elseif isNext('alt') then
            res = output(getValue(tree[pointer][2]))
            pointer = pointer + 1
            update()
            res = res .. s.continue()

        elseif isNext('call') then
            getValue(tree[pointer])
            pointer = pointer + 1
            update()
            res = res .. s.continue()

        elseif isNext('if') then
            if isTruthy(getValue(tree[pointer][2])) then
                res=tree[pointer][3]
            elseif tree[pointer][4] ~= nil then
                res=tree[pointer][4]
            end
            pointer = pointer + 1
            update()
            res = res .. s.continue()
        end


        if isNext('glue') then
            pointer = pointer + 1
            update()
            res = res .. s.continue()

        elseif isNext('gather') then -- diverted into a labeled gather
            res = res..getValue(tree[pointer])
            pointer = pointer + 1
            update()
            res = res .. s.continue()

        elseif isNext('divert') then -- TODO duplicated code in update
            goTo(tree[pointer][2])
            update()
            res = res .. s.continue()
        end

        -- separates "a -> b" from "a\n -> b"
        while isNext('nl') do
            pointer = pointer + 1
            update()
        end

        if isNext('return') then
            -- TODO return value
            goTo(table.remove(s.callstack))
            pointer = pointer + 1
            update()

        end

        if isEnd() then
            local returnTo = table.remove(s.callstack)
            if returnTo ~= nil then
                goTo(returnTo)
            end
            pointer = pointer + 1
            update()
        end


        s.currentTags = tags[pointer] or {}

        if lastpointer == pointer then
            error('nothing consumed in continue at pointer '..pointer)
        end

        -- if last output ended with a space and this one starts with one, we want just one space
        if res:sub(1,1) == ' ' and lastOut:sub(-1) == ' ' then
            res = res:sub(1)
        end

        lastOut = res;
        return res;
    end

    s.currentChoices = {}

    s.chooseChoiceIndex = function(index)
        pointer = currentChoicesPointers[index]+1
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

    s.variablesState = {}
    -- s.state.ToJson();s.state.LoadJson(savedJson);

    preProcess()
    --_debug(tree)
    --_debug(tags)
    --_debug(knots)

    -- debug
    s._tree = tree

    update()

    --_debug(s)
    return s
end
