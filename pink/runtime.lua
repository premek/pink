local base_path = (...):match("(.-)[^%.]+$")
local out = require(base_path .. 'out')
local list = require(base_path .. 'list')
local types = require(base_path .. 'types')
local builtins = require(base_path .. 'builtins')
local logging = require(base_path .. 'logging')
local err = logging.error
local _debug = logging.debug
local requireType = types.requireType
local is = types.is

math.randomseed(os.time())
local unpack = table.unpack or unpack




return function (globalTree)
    local rootEnv = builtins
    local env = rootEnv -- TODO should env be part of the callstack?

    -- set when interpreting a 'return' statement, read after stepping 'Out'
    -- TODO does it have to be a stack?
    local returnValue = {present = false, value = nil}

    -- story - this table will be passed to client code
    local s = {
        globalTags = {},
        state = {
            visitCount = {},
        },
        variablesState = env,
        canContinue = false
    }

    local tree = globalTree
    local pointer = 1
    local callstack = {}
    local knots = {}
    local tags = {}
    local tagsForContentAtPath = {}
    local externalDefs = {}
    local storyStarted = false

    local next = function()
        pointer = pointer + 1
    end

    -- TODO state should contain tree/pointer to be able to save / load


    local isEnd = function()
        return tree[pointer] == nil
    end
    local isNext = function (what)
        return is(what, tree[pointer])
    end


    local splitName = function(name)
        local first
        local rest = {}
        for token in name:gmatch("[^.]+") do
            if first == nil then
                first = token
            else
                table.insert(rest, token)
            end
        end
        return first, rest
    end

    local getChildren = function(parentName, path, tbl, token)
        for _, part in ipairs(path) do
            if not tbl._children or not tbl._children[part] then
                _debug(parentName, path, env)
                err('error accessing "' .. part .. '" in "' .. parentName .. '"', token)
            end
            tbl = tbl._children[part]
            parentName = parentName .. '.' .. part
        end
        return tbl
    end

    local getEnvOptional = function(name, startingEnv)
        local e = startingEnv or env
        while e ~= nil do
            local val = e[name]
            if val ~= nil then
                return val, e
            end
            e=e._parent
        end
    end

    local getEnv = function(name, token, startingEnv)
        local first, rest = splitName(name)
        local val, e = getEnvOptional(first, startingEnv)
        if val == nil then
            -- FIXME detect on compile time
            _debug(name, env)
            err('unresolved variable: ' .. name, token)
        end
        val = getChildren(first, rest, val, token)
        return val, e
    end
    builtins.getEnv = getEnv -- FIXME!!!

    local stepInto = function(block, newEnv, fn)
        _debug("step into")
        -- TODO everything on the stack, current pointer, tree, env; not 'out'
        table.insert(callstack, {tree=tree, pointer=pointer, fn=fn})
        newEnv = newEnv or {}
        newEnv._parent = env -- TODO make parent unaccessible from the script
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

    local stepOut
    stepOut = function(fn)
        local frame = table.remove(callstack)
        if not frame then
            return err('failed to step out')
        end
        _debug("stepOut")

        -- Step out of one (inner most) function
        -- keep stepping out until we get the frame marked as fn.
        if fn ~= nil and frame.fn ~= fn then
            stepOut(fn)
            return
        end

        pointer = frame.pointer
        tree = frame.tree
        env = env._parent -- TODO encapsulate somehow / add to the frame?
    end

    local incrementSeenCounter = function(path)
        _debug('increment seen counter: '..path)
        local var = getEnv(path, nil, rootEnv)
        requireType(var, 'int')
        var[2] = var[2] + 1
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
            goTo(val[2], args)
            return
        end

        if path:find('%.') ~= nil then
            -- TODO proper path resolve - could be stitch.gather or knot.stitch.gather or something else?
            local _, _, p1, p2 = path:find("(.+)%.(.+)")

            pointer = knots[p1][p2].pointer
            tree = knots[p1][p2].tree

            -- enter inside the knot
            if isNext('knot') then
                next()
            end

            incrementSeenCounter(path)

            -- FIXME duplicates
            currentKnot = p1
            -- automatically go to the first stitch (only) if there is no other content in the knot
            if isNext('stitch') then
                next()
            end

        elseif knots[currentKnot] and knots[currentKnot][path] then
            tree=globalTree --TODO store with knots?
            pointer = knots[currentKnot][path].pointer
            next()

            -- FIXME hack
        elseif knots["//no-knot"] and knots["//no-knot"][path] then
            tree=knots["//no-knot"][path].tree -- TODO this is not stepInto, we dont want to step back, right?
            pointer = knots["//no-knot"][path].pointer
            -- TODO messy
            if isNext('option') then
                local option = tree[pointer]
                option.used = true --FIXME different mechanism used for labelled and anon options
                -- TODO duplicated logic in chooseChoice
                returnTo(option[9])
                returnTo(option[5])
                stepInto(option[3])
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
            stepInto(body, newEnv)

            incrementSeenCounter(path) -- TODO not just knots

            currentKnot = path
            -- automatically go to the first stitch (only) if there is no other content in the knot
            if isNext('stitch') then
                incrementSeenCounter(path .. '.' .. tree[pointer][2])
                next()
            end

        else
            error("unknown path: " .. path) -- TODO check at compile time?
        end

        -- TODO s.state.visitCount[path] = s.state.visitCountAtPathString(path) + 1 -- TODO stitch
    end

    local lastKnot = "//no-knot" -- FIXME
    local lastStitch = nil
    knots[lastKnot]={} -- TODO use proper paths instead

    local preProcess
    preProcess = function (t)

        while isNext('tag') do
            table.insert(s.globalTags, t[pointer][2])
            next()
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
                list.listDef(n[2], n[3], env)
            end
        end

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
                knots[lastKnot][n[2]] = {pointer=p, tree=t}

                if lastKnot ~= '//no-knot' then -- FIXME
                    env[lastKnot]._children = env[lastKnot]._children or {}
                    env[lastKnot]._children[n[2]] = {'int', 0} -- seen counter TODO proper paths
                else
                    env[n[2]] = {'int', 0} -- seen counter TODO proper paths
                end
                lastStitch = n[2]
            end
            if is('gather', n) and n[4] then
                -- gather with a label
                if lastStitch then
                    knots[lastKnot][lastStitch][n[4]] = {pointer=p, tree=t}
                    if lastKnot ~= '//no-knot' then -- FIXME
                        env[lastKnot]._children = env[lastKnot]._children or {}
                        env[lastKnot]._children._children = env[lastKnot]._children._children or {}
                        env[lastKnot]._children[lastStitch]._children[n[4]] = {'int', 0} -- seen counter
                    else
                        env[n[4]] = {'int', 0} -- seen counter
                    end
                else
                    knots[lastKnot][n[4]] = {pointer=p, tree=t}
                    if lastKnot ~= '//no-knot' then -- FIXME
                        env[lastKnot]._children = env[lastKnot]._children or {}
                        env[lastKnot]._children[n[4]] = {'int', 0} -- seen counter
                    else
                        env[n[4]] = {'int', 0} -- seen counter
                    end
                end

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
                table.insert(n[4], {'return'}) -- make sure every function has a return at the end
                env[n[2]] = {'fn', n[3], n[4]}
            end

            if is('external', n) then
                -- store the definition. All external functions must be
                -- defined after the story is constructed but before it is played
                externalDefs[n[2]] = n[3]
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

            --if is('para', n) then
            --    tags[p] = aboveTags
            --    aboveTags = {}
            --    -- lastPara = p
            --end

        end



        -- 2nd pass for const/var - resolve values
        for _, n in ipairs(t) do
            if is('var', n) then
                local val = getValue(n[3])

                if is('el', val) then
                    -- TODO in getValue??? list.lua??
                    env[n[2]] = list.fromLit({'listlit', {val[3]}}, getEnv)
                elseif is('listlit', val) then
                    env[n[2]] = list.fromLit(val, getEnv)
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
            return getValue(list.fromLit(val, getEnv))

        elseif is('call', val) then
            local name = val[2]
            local args = val[3]

            local target = getEnv(name, val)
            _debug("CALL target", target)
            -- FIXME detect unresolved function on compile time

            -- call divert as fn -- FIXME
            if target[1] == 'divert' then
                local path = target[2]
                local divertTarget = getEnv(path)
                if divertTarget[1] == 'fn' then
                    target = divertTarget
                end
            end



            if target[1] == 'native' or target[1] == 'external' then
                local argumentValues = {}
                for _, arg in ipairs(args) do
                    table.insert(argumentValues, getValue(arg))
                end
                -- TODO convert arguments, return values for external
                return target[2](unpack(argumentValues))
            elseif target[1] == 'fn' then
                local params = target[2]
                local body = target[3]
                local newEnv = getArgumentsEnv(params, args)
                stepInto(body, newEnv, 'fn')
                out:instr('trim')
                update()
                local ret = returnValue.value
                out:instr('trimEnd')
                _debug('RET', ret)
                returnValue = {present = false, value = nil}
                return ret
            elseif target[1] == 'list' then
                if #args == 0 then
                    return list.empty()
                elseif #args > 1 then
                    err('too many arguments')
                end
                local index = getValue(args[1])
                requireType(index, 'int')
                return list.elByValue(name, index[2])
            else
                error('invalid call target: ' .. target[1])
            end

        elseif is('ink', val) then
            -- FIXME
            local result = ""
            for i=1, #val[2] do
                local value = getValue(val[2][i])
                if value ~= nil then
                    result = result .. types.output(value)
                end
            end
            return {'str', result}

        else
            _debug(val)
            error('getValue: unsupported type: ' .. (type(val[1])=='string' and val[1] or type(val[1])))
        end
    end

    local getNotBindExternalFunctionNames = function()
        for name in pairs(externalDefs) do
            local var = getEnvOptional(name)
            if is('fn', var) then
                -- fallback ink function used instead of the external one
                externalDefs[name] = nil
            end
        end

        local names = {}
        for name in pairs(externalDefs) do
            table.insert(names, name)
        end
        return names
    end

    local canContinue = function()
        if #s.currentChoices > 0 then
            return false
        end
        return not out:isEmpty()
    end

    local nodeUpdateAssign = function(n)
        local name = n[2]
        local oldValue, e = getEnv(name)
        _debug("ASSIGN", oldValue, name, n[3])

        if is('ref', oldValue) then
            local referenced = getEnv(oldValue[2])

            if is('list', referenced) then
                oldValue = referenced
            end
        end

        local newValue = getValue(n[3])
        if is('list', oldValue) and (is('el', newValue) or is('list', newValue)) then
            list.set(oldValue, newValue)
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
    end

    local nodeUpdateOutValue = function(n)
        local val = getValue(n)
        if val ~= nil then
            out:add(types.output(val))
        end
    end
    local nodeUpdateOut = function(n)
        out:instr('outBlockStart')
        nodeUpdateOutValue(n)
    end

    local seqShuffle = function(elements, len)
        local unshuffled = {}
        for i = 1, #elements do
            table.insert(unshuffled, elements[i])
        end

        local shuffled = {}
        -- shuffle the elements that needs to be shuffled, remove them from unshuffled, go from the end
        for i = len, 1, -1 do
            table.insert(shuffled, table.remove(unshuffled, math.random(i)))
        end
        -- insert the remaining unshuffled elements to the end
        for i=1, #unshuffled do
            table.insert(shuffled, unshuffled[i])
        end
        return shuffled
    end

    local nodeUpdateSeq = function(n)

        if n[2].shuffle and not n.shuffled then
            if n[2].stopping then
                n[3] = seqShuffle(n[3], #n[3]-1) -- shuffle all except the last one
            else
                n[3] = seqShuffle(n[3], #n[3])
            end
            n.shuffled = true
        end

        -- TODO not needed when continue stops on each end of line???
        out:instr('outBlockStart')

        -- FIXME store somewhere else, support save/load, could be a "seen counter" too
        n.current = n.current or 1

        local ret = nil
        if n.current <= #n[3] then
            ret = n[3][n.current]
        end

        if n[2].stopping then
            n.current = math.min(#n[3], n.current + 1) -- stay at the last one
        elseif n[2].once then
            n.current = math.min(#n[3] + 1, n.current + 1) -- stay *after* the last one
        elseif n[2].cycle then
            n.current = math.fmod(n.current, #n[3]) + 1
        end

        return ret
    end

    local nodeSkip = function() end

    local nodeUpdate = {
        var = nodeSkip,
        const = nodeSkip,
        comment = nodeSkip,
        knot = nodeSkip,
        fn = nodeSkip,
        external = nodeSkip,
        listdef = nodeSkip,
        -- skip following options after returning from an option where we jumped in by a name -- FIXME
        option = nodeSkip,

        tag = function(n)
            table.insert(tags, n[2])
        end,
        tempvar = function(n)
            -- FIXME what's the right env to write to?
            rootEnv[n[2]] = getValue(n[3])
        end,
        assign = nodeUpdateAssign,
        ['return'] = function(n)
            returnValue = {present=true, value=getValue(n[2])}
            stepOut('fn') -- step out of the function, not just the last block we stepped into
        end,
        tunnelreturn = function() stepOut(); end,

        str = nodeUpdateOutValue,
        bool = nodeUpdateOutValue,
        int = nodeUpdateOutValue,
        float = nodeUpdateOutValue,
        ref = nodeUpdateOutValue,

        out = nodeUpdateOut,

        seq = nodeUpdateSeq,

        call = function(n) getValue(n); end, -- ~ fn() -- call but ignore the result
        todo = function(n) logging.warn(n[2], n); end,
        glue = function() out:instr('glue'); end,
        nl = function() out:add('\n'); end, -- separates "a -> b" from "a\n -> b"
        stitch = function(n) incrementSeenCounter(n[2]); end,
        ink = function(n) return n[2]; end,
        gather = function(n)
            if n[4] then
                if currentKnot then
                    incrementSeenCounter(currentKnot .. '.' .. n[4]) -- TODO
                else
                    incrementSeenCounter(n[4])
                end
            end
            return n[3]
        end,


        ['if'] = function(n)
            for _, branch in ipairs(n[2]) do
                if types.isTruthy(getValue(branch[1])) then
                    out:instr('outBlockStart') -- TODO before or after the getValue call above?
                    return branch[2]
                end
            end
            -- no condition evaluated to true (and the else branch not present): do nothing
        end,
    }
    -- TODO move everything to getValue, call getValut from top and dont use the return value,
    -- but inside it can be used e.g. for recursive function call/return values
    update = function ()

        _debug('upd: ' .. pointer .. (tree[pointer] and tree[pointer][1] or 'END'))

        if returnValue.present then
            -- do not proceed when returning from a (nested?) function call
            pointer = pointer-1 -- FIXME what's going on here
            return
        end

        -- TODO return when we can output a line? so we dont progress unnecesarilly far ahead?

        if tree[pointer] and tree[pointer].location then
            logging.lastLocation = tree[pointer].location
        end

        --local lastpointer=pointer
        --local lasttree=tree -- TODO is this needed?


        if not storyStarted and #getNotBindExternalFunctionNames() > 0 then
            -- first update call before the first continue is called
            -- the external functions are not bound yet
            return
        end

        if isNext('divert') then
            goTo(tree[pointer][2], tree[pointer][3])
            update()
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
            builtins.currentChoices = s.currentChoices --FIXME how to pass the value

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
                        if not types.isTruthy(getValue(condition)) then
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
                    local text = out:popLine()
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
                    if gather then
                        returnTo(gather[3])
                    end
                    stepInto(fallbackOption[9])
                end
                if fallbackOption or gather then
                    update()
                    return
                end
            end

            next()
            return
        end



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



        if isEnd() then
            --FIXME refactor so we don't need this if
            if #s.currentChoices == 0 then
                if #callstack > 0 then
                    stepOut()
                    _debug("step out at end")
                    next()
                    update()
                    return
                end
            end
            next()
            s.canContinue = canContinue()
            return
        end

        local updateFn = nodeUpdate[tree[pointer][1]]
        if not updateFn then
            err('unexpected node', tree[pointer])
        end
        local nextStep = updateFn(tree[pointer])
        if nextStep then
            stepInto(nextStep)
        else
            next()
        end
        update()
        return



        --[[if lastpointer == pointer and lasttree == tree then
        _debug(tree, pointer)
        err('nothing consumed in continue at pointer '..pointer)
        end
        ]]


    end


    s.continue = function()
        -- first run
        if not storyStarted then
            local notBindExternalFunctionNames = getNotBindExternalFunctionNames()
            if #notBindExternalFunctionNames > 0 then
                error('Missing function(s) binding for external '
                    .. table.concat(notBindExternalFunctionNames, ', ')
                    .. ' and no fallback ink function found')
            end
            storyStarted = true
        end

        _debug("out", out.buffer)
        local res = ""
        if not out:isEmpty() then
            res = out:popLine()
        end
        _debug("OUT:", res)
        s.currentTags = tags
        tags = {}
        update()
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

        returnTo(choice.option[9])
        returnTo(choice.option[5])
        stepInto(choice.option[3])

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

    -- TODO document
    s.bindExternalFunction = function(name, fn)
        local externalFunctionParams = externalDefs[name]
        if externalFunctionParams == nil then
            error('cannot bind ' .. name .. ', external function not defined')
        end
        -- TODO check params
        externalDefs[name] = nil
        env[name] = {'external', fn}
        update()
    end

    s.currentTags = {}

    -- s.state.ToJson();s.state.LoadJson(savedJson);

    tree = preProcess(tree)
    _debug(tree)
    _debug("lists:", list.defs)
    _debug("external:", externalDefs)
    _debug("state:", s.variablesState)

    update()

    return s
end
