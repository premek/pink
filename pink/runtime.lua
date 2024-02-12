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
            local formatted, _ = string.format("%.7f", a[2]):gsub("%.?0+$", "")
            return formatted
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

local seedRandom = function(a)
    requireType(a, 'float', 'int')
    math.randomseed(a[2])
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

local gt = function(a,b)
    requireType(a, 'bool', 'int', 'float')
    requireType(b, 'bool', 'int', 'float')
    return {'bool', toFloat(a)[2] > toFloat(b)[2]}
end
local gte = function(a,b)
    requireType(a, 'bool', 'int', 'float')
    requireType(b, 'bool', 'int', 'float')
    return {'bool', toFloat(a)[2] >= toFloat(b)[2]}
end
local lt = function(a,b)
    requireType(a, 'bool', 'int', 'float')
    requireType(b, 'bool', 'int', 'float')
    return {'bool', toFloat(a)[2] < toFloat(b)[2]}
end
local lte = function(a,b)
    requireType(a, 'bool', 'int', 'float')
    requireType(b, 'bool', 'int', 'float')
    return {'bool', toFloat(a)[2] <= toFloat(b)[2]}
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

    local env = {
        FLOOR={'native', floor},
        CEILING={'native', ceil},
        INT={'native', int},
        SEED_RANDOM={'native', seedRandom},
        ['+']={'native', add},
        ['-']={'native', sub},
        ['*']={'native', mul},
        ['/']={'native', div},
        ['%']={'native', mod},
        ['mod']={'native', mod},
        ['==']={'native', eq},
        ['!=']={'native', notEq},
        ['?']={'native', contains},
        ['not']={'native', notFn},
        ['||']={'native', orFn},
        ['&&']={'native', andFn},
        ['or']={'native', orFn},
        ['and']={'native', andFn},
        ['<']={'native', lt},
        ['<=']={'native', lte},
        ['>']={'native', gt},
        ['>=']={'native', gte},
    }

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
    local currentDepth = 0 -- root level is 0, first option will nest to level 1 etc
    -- TODO reset currentDepth on gathers, when jumping to knots
    -- TODO what is it used for?

    -- TODO state should contain tree/pointer to be able to save / load


    local isEnd = function()
        return tree[pointer] == nil
    end
    local isNext = function (what)
        return is(what, tree[pointer])
    end

    local getEnv = function(name, token)
        local e = env
        local val = nil
        while val == nil and e ~= nil do
            val = e[name]
            e=e._parent
        end

        if val == nil then
            -- FIXME detect on compile time
            _debug(env)
            err('unresolved variable: ' .. name, token)
        end
        return val
    end

    local stepInto = function(block)
        table.insert(callstack, {tree=tree, pointer=pointer})
        local newEnv = {_parent=env} -- TODO make parent unaccessible from the script
        env = newEnv
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
            return false
        end
        pointer = frame.pointer
        tree = frame.tree
        env = env._parent -- TODO encapsulate somehow / add to the frame?
        pointer = pointer + 1 -- step after the function call where we stepped inside the function
        return true
    end

    -- var = var + a
    local addVariable = function(ref, a)
        local name = ref[2]
        local var = getEnv(name)
        requireType(var, 'float', 'int')
        var[2] = var[2] + a
    end

    local incrementSeenCounter = function(path)
        addVariable({'ref', path}, 1) --FIXME
    end

    local currentKnot = nil
    local goTo = function(path)
        _debug('go to', path, knots)
        if type(path) == 'number' then
            error('unused?')
            pointer = path -- TODO function call, add parameters

        elseif path == 'END' or path == 'DONE' then
            pointer = #tree+1

        elseif path:find('%.') ~= nil then
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
            tree=globalTree --TODO store with knots?
            pointer = knots["//no-knot"][path].pointer + 1

        elseif knots[path] then
            tree = knots[path]
            pointer = 1

            incrementSeenCounter(path) -- TODO not just knots

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

    local lastKnot = "//no-knot"
    local lastStitch = nil
    knots[lastKnot]={} -- TODO use proper paths instead

    local preProcess
    preProcess = function (t)

        while isNext('tag') do
            table.insert(s.globalTags, t[pointer][2])
            pointer = pointer + 1
        end

        local aboveTags = {}
        --local lastPara = {}

        local result = {}
        local addTo = {result} -- stack, number of items represents current depth
        local addThisTo


        for p, n in ipairs(t) do

            if is('ink', n) then
                n[2] = preProcess(n[2])
            end


            addThisTo = addTo[#addTo]

            if is('fn', n) or is('knot', n) then
                addTo = {result} -- start adding tokens incl. this one to the top level
                addThisTo = result
            end


            if is('fn', n) then
                local fnBody = {}
                n[4] = fnBody
                table.insert(addTo, fnBody) -- start adding following tokens to the body
            end

            --[[ if is('option', n) then
            local optionBody = {}
            n[9] = optionBody -- TODO call it body? call other numbered item by names?
            local optionDepth = n[2]

            while optionDepth < #addTo do
            table.remove(addTo)
            addThisTo = addTo[#addTo]
            end

            table.insert(addTo, optionBody) -- start adding following tokens to the body

            table.insert(optionBody, {'str', n[3]})
            table.insert(optionBody, {'str', n[5]})
            if #trim(n[3]) ~= 0 or #trim(n[5]) ~= 0 then
            table.insert(optionBody, {'nl'}) -- FIXME the whole trimming everywhere
            end

            end]]

            table.insert(addThisTo, n)


            if is('knot', n) then
                knots[n[2]] = n[3]
                env[n[2]] = {'int', 0} -- seen counter
                lastKnot = n[2]
                lastStitch = nil
                n[3] = preProcess(n[3]) --FIXME - mess in knots[]


                tagsForContentAtPath[lastKnot] = {}
            end
            if is('stitch', n) then
                -- TODO make stitches nested same as knots
                knots[lastKnot][n[2]] = {pointer=p, tree=t}
                -- TODO env[n[2]] = {'int', 0} -- seen counter
                lastStitch = n[2]
            end
            if is('gather', n) and n[4] then -- gather with a label
                if lastStitch then
                    knots[lastKnot][lastStitch][n[4]] = {pointer=p, tree=t}
            else
                knots[lastKnot][n[4]] = {pointer=p, tree=t}
            end
            env[n[4]] = {'int', 0} -- seen counter / FIXME
            end
            if is('option', n) and n[6] then -- option with a label
                if lastStitch then
                    knots[lastKnot][lastStitch][n[6]] = {pointer=p, tree=t}
            else
                knots[lastKnot][n[6]] = {pointer=p, tree=t}
            end
            env[n[6]] = {'int', 0} -- seen counter / FIXME
            end


            -- function declarations could be after function calls in source code
            if is('fn', n) then
                env[n[2]] = {'fn', n[3], n[4]}
            end



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

        return result
    end

    local update

    -- "run" the node and return the return value
    -- may return "nothing" (nil)
    local getValue
    getValue=function(val)

        if val == nil then
            err('nil value')
            --print('get nil')
            --val = tree[pointer] --FIXME 111
            --_debug(val)
            --update()
        end


        if is('str', val) or is('int', val) or is('float', val) or is('bool', val) then
            return val


        elseif is('ref', val) then
            local name = val[2]
            local var = getEnv(name, val)
            return getValue(var)

        elseif is('if', val) then
            if isTruthy(getValue(val[2])) then
                return getValue(val[3])
            elseif val[4] ~= nil then
                return getValue(val[4])
            else
                return
            end

        elseif is('seq', val) then
            return getValue(val[2]) -- TODO track visits, return next value each time

        elseif is('shuf', val) then
            return getValue(val[2][math.random(#val[2])])

        elseif is('call', val) then
            local name = val[2]
            local argumentExpressions = val[3]

            -- TODO use 'ref' attributes to call this the same as other functions
            -- TODO check var type
            if name == '++' then
                addVariable(argumentExpressions[1], 1)
                return
            end
            if name == '--' then
                addVariable(argumentExpressions[1], -1)
                return
            end

            local target = getEnv(name, val)
            -- FIXME detect unresolved function on compile time

            if target[1] == 'native' then
                local argumentValues = {}
                for _, argumentExpression in ipairs(argumentExpressions) do
                    _debug('AA', argumentExpression)
                    table.insert(argumentValues, getValue(argumentExpression))
                end

                return target[2](table.unpack(argumentValues))

            elseif target[1] == 'fn' then
                local argumentDefinitions = target[2]
                local body = target[3]

                stepInto(body)
                for i = 1, #argumentDefinitions do
                    local argumentName = argumentDefinitions[i][1]
                    local argumentExpression = argumentExpressions[i]

                    local ref = argumentDefinitions[i][2] == 'ref' -- TODO
                    if ref then
                        requireType(argumentExpression, 'ref')
                        env[argumentName] = argumentExpression
                    else
                        env[argumentName] = getValue(argumentExpression)
                    end
                end

                -----goTo(target[2]+1) -- jump after fn declaration
                -- TODO trim fn output?
                -- TODO arguments
                -- TODO return value - print after what the function prints
                return {"str", ''}
            else
                error('invalid call target: ' .. target[1])
            end

            --[[   elseif #val == 0 or type(val[1]) == 'table' then
            err('invalid') --TODO remove


            -- {} or {{'xxx', ...}, {'xxx', ...}}
            -- FIXME I006 - consolidate continue(), update() and getValue() and call recursively here
            local result = ""
            for i=1, #val do
            local value = getValue(val[i])
            if value ~= nil then
            result = result .. output(value)
            end
            end
            return {'str', result}


            ]]
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
            error('unsupported value type: ' .. (type(val[1])=='string' and val[1] or type(val[1])))
        end
    end




    local out = {}
    local lastOut = ''

    -- TODO move everything to getValue, call getValut from top and dont use the return value,
    -- but inside it can be used e.g. for recursive function call/return values
    update = function ()

        _debug('upd', pointer, tree[pointer] and tree[pointer][1] or 'END')

        if tree[pointer] and tree[pointer].location then
            lastLocation = tree[pointer].location
        end

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
            env[tree[pointer][2]] = tree[pointer][3]
            pointer = pointer + 1
            update()
            return
        end

        if isNext('assign') then
            -- TODO scope
            -- TODO env[tree[pointer][2]] = tree[pointer][3]
            pointer = pointer + 1
            update()
            return
        end


        if isNext('list') then
            env[tree[pointer][2]] = { table.unpack(tree[pointer], 3) }
            pointer = pointer + 1
            update()
            return
        end

        if isNext('return') then
            _debug(getValue(tree[pointer][2]))
            local steppedOut = stepOut()
            if not steppedOut then
                err('failed to return')
            end
            update()
            -- no return
        end

        if isNext('choice') then
            local options = tree[pointer][2]
            local gather = tree[pointer][3]

            s.currentChoices = {}

            for _, option in ipairs(options) do
                local _ = option[7] == "sticky" -- TODO
                local displayOption = true

                for _, condition in ipairs(option[8]) do
                    if not isTruthy(getValue(condition)) then
                        displayOption = false
                        break
                    end
                end

                if displayOption then
                    -- all possible choices printed like this before selecting
                    local text = trim((option[3] or '') .. (option[4] or '')) -- TODO trim
                    table.insert(s.currentChoices, {text = text, option=option, gather=gather})
                end
            end

            if #s.currentChoices > 0 then
                -- player will need to nest one level deeper
                currentDepth = currentDepth + 1
                s.canContinue = false
            end

            if #s.currentChoices == 0 and gather then
                stepInto(gather[2])
                update()
                return
            end

            pointer = pointer + 1
            return
        end



        local lastpointer=pointer
        local lasttree=tree -- TODO is this needed?

        if isNext('str')
            or isNext('bool')
            or isNext('int')
            or isNext('float')
            or isNext('ref')
            or isNext('seq')
            or isNext('shuf')
            or isNext('call')
            or isNext('if')
        --or tree[pointer] and type(tree[pointer][1]) == 'table' -- FIXME what for?
        then

            local val = getValue(tree[pointer])
            if val ~= nil then
                table.insert(out, output(val))
            end
            pointer = pointer + 1
            update()
            --table.insert(out, s.continue())

        elseif isNext('todo') then
            log(tree[pointer][2], tree[pointer]) -- TODO
            pointer = pointer + 1
            update()

        elseif isNext('glue') then
            out.sticky = true -- TODO or separate variable?
            pointer = pointer + 1
            update()

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

        elseif isNext('gather') then
            stepInto(tree[pointer][3])
            update()
        end

        -- separates "a -> b" from "a\n -> b"
        if isNext('nl') then
            while isNext('nl') do
                pointer = pointer + 1
            end

            if out.sticky or isNext('glue') then
                update()
            else
                table.insert(out, '\n')
            end
            --update()
            --return
        end

        if isNext('ink') then
            stepInto(tree[pointer][2])
            update()
        end


        if isEnd() or isNext('knot') or isNext('fn') then
            -- TODO change the parser so knots, fns etc are in separate table?
            local steppedOut = stepOut()
            if steppedOut then
                update()
            end
            pointer = pointer + 1
        end


        s.currentTags = tags[pointer] or {}

        if lastpointer == pointer and lasttree == tree then
            err('nothing consumed in continue at pointer '..pointer)
        end


        s.canContinue = #out > 0
        if not s.canContinue then
            _debug('--can-not-continue--')
        end

    end


    s.continue = function()
        _debug(out)
        local res = rtrim(table.concat(out))
        -- if last output ended with a space and this one starts with one, we want just one space
        if res:sub(1,1) == ' ' and lastOut:sub(-1) == ' ' then
            res = res:sub(1)
        end
        -- TODO whitespace when printing, not just here
        -- https://github.com/inkle/ink/blob/
        -- 6a512190365002f54bd501b0863ded40123cb8e5/ink-engine-runtime/StoryState.cs#L894

        lastOut = res;

        out={}
        update()

        -- TODO in update???
        if out.sticky then
            table.insert(out, 1, res)
            return s.continue()
        end

        _debug("OUT:"..res)
        return res;
    end

    s.currentChoices = {}

    s.chooseChoiceIndex = function(index)
        if type(index) ~= 'number' then
            error('number expected')
        end
        if s.currentChoices[index].gather then
            returnTo(s.currentChoices[index].gather[3])
        end
        stepInto(s.currentChoices[index].option[9])

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
    --_debug(s.variablesState)
    --_debug(tags)
    --_debug(knots)

    -- debug
    --s._tree = tree

    update()
    --getValue()

    return s
end
