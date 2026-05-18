local base_path = (...):match('(.-)[^%.]+$')
local Story = require(base_path .. 'story')
local newOutputBuffer = require(base_path .. 'output_buffer')
local newListDefinitions = require(base_path .. 'list_definitions')
local node = require(base_path .. 'node')
local createBuiltins = require(base_path .. 'builtins')
local compile = require(base_path .. 'compiler')
local logging = require(base_path .. 'logging')
local newStack = require(base_path .. 'stack')
local err = logging.error
local warn = logging.warn
local _debug = logging.debug
local requireType = node.requireType
local is = node.is

math.randomseed(os.time())
local unpack = table.unpack or unpack

local noKnot = {} -- sentinel key for top-level content not inside any knot

return function(globalTree)
    local outputBuffer = newOutputBuffer()
    local listDefinitions = newListDefinitions()
    local nodeOutput = node.makeOutput(listDefinitions)
    local getEnv, s, nodeById -- forward declarations needed by createBuiltins closures
    local currentKnot, currentStitch -- forward declarations needed by getEnv for label lookup
    local turns = 0
    local turnAtVisit = {}
    local turnHadOutput = false -- true when at least one line of text was output this turn
    local threadChoicesAdded = false -- true when runThread added choices to s.currentChoices this turn

    local rootEnv = createBuiltins({
        getEnv = function(...)
            return getEnv(...)
        end,
        getChoices = function()
            return s.currentChoices
        end,
        getTurns = function()
            return turns
        end,
        getTurnsSince = function(path)
            return turnAtVisit[path]
        end,
        listDefinitions = listDefinitions,
    })
    local env = rootEnv -- TODO should env be part of the callstack?

    -- set when interpreting a 'return' statement, read after stepping 'Out'
    -- TODO does it have to be a stack?
    local returnValue = { present = false, value = nil }

    -- story - this table will be passed to client code
    s = Story.new(rootEnv)

    local tree = globalTree
    local pointer = 1
    local callstack = newStack()
    -- Describes which block 'tree' refers to; nil = globalTree or unknown (direct goTo navigation).
    -- Updated by stepInto/stepOut. Enables callstack frame serialization for save/load.
    local currentAddr = nil
    local knots
    local tags = {}
    local externalDefs
    local storyStarted = false

    local markOptionUsed = function(option)
        s.state.usedOptions[option.nodeId] = true
    end
    local isOptionUsed = function(option)
        return s.state.usedOptions[option.nodeId] == true
    end
    -- Constructs an address: a serializable pointer to a block (array of nodes) inside a node.
    local addr = function(n, field, index, subfield)
        local a = { nodeId = n.nodeId, field = field }
        if index then
            a.index = index
        end
        if subfield then
            a.subfield = subfield
        end
        return a
    end
    local bodyAddr = function(n)
        return addr(n, 'body')
    end
    local nodesAddr = function(n)
        return addr(n, 'nodes')
    end
    local t1Addr = function(n)
        return addr(n, 't1')
    end
    local t2Addr = function(n)
        return addr(n, 't2')
    end
    local t3Addr = function(n)
        return addr(n, 't3')
    end
    local seqBranchAddr = function(n, i)
        return addr(n, 'branches', i)
    end
    local ifBranchAddr = function(n, i)
        return addr(n, 'branches', i, 'body')
    end
    -- Reconstructs a block from a saved address. Used by future save/load.
    local _blockFromAddr = function(a)
        if not a then
            return nil
        end
        local n = nodeById[a.nodeId]
        if not n then
            return nil
        end
        local field = n[a.field]
        if a.index then
            field = field[a.index]
            if a.subfield then
                return field[a.subfield]
            end
        end
        return field
    end
    local next = function()
        pointer = pointer + 1
    end

    -- TODO(save/load): serialize tree+pointer+callstack+env+storyStarted

    local isEnd = function()
        return tree[pointer] == nil
    end
    local isNext = function(what)
        return is(what, tree[pointer])
    end

    local splitName = function(name)
        local first
        local rest = {}
        for token in name:gmatch('[^.]+') do
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
            e = e._parent
        end
    end

    getEnv = function(name, token, startingEnv)
        local first, rest = splitName(name)
        local val, e = getEnvOptional(first, startingEnv)
        if val == nil then
            if currentKnot then
                local knotEntry = getEnvOptional(currentKnot, rootEnv)
                if knotEntry and knotEntry._children then
                    if #rest == 0 and knotEntry._children[name] then
                        -- bare label directly under current knot (e.g. 'done' inside 'review_case_notes')
                        return knotEntry._children[name], rootEnv
                    elseif #rest > 0 and knotEntry._children[first] then
                        -- stitch.label path relative to current knot (e.g. 'stitch_one.gatherpoint')
                        val = knotEntry._children[first]
                        e = rootEnv
                    end
                end
            end
            if val == nil then
                warn('variable not found: ' .. name .. ', using default value of 0', token)
                return node.int(0), env
            end
        end
        val = getChildren(first, rest, val, token)
        return val, e
    end

    local stepInto = function(block, newEnv, fn, blockAddr)
        _debug('step into')
        callstack.push({ tree = tree, pointer = pointer, fn = fn, env = env, addr = currentAddr })
        currentAddr = blockAddr
        if newEnv then
            newEnv._parent = env -- TODO make parent unaccessible from the script
            env = newEnv
        end
        tree = block
        pointer = 1
    end

    -- like stepInto but one step before, so when we step out, we do not skip the first instruction
    -- FIXME stepInto must be called after calling this
    local returnTo = function(block, blockAddr)
        stepInto(block, nil, nil, blockAddr)
        pointer = 0
    end

    -- like returnTo but marks the frame with gatherBody so discardGatherContinuations can find it
    local returnToGather = function(block, blockAddr)
        callstack.push({ tree = tree, pointer = pointer, fn = nil, env = env, addr = currentAddr, gatherBody = block })
        currentAddr = blockAddr
        tree = block
        pointer = 0
    end

    local stepOut
    stepOut = function(fn)
        local frame = callstack.pop()
        if not frame then
            return err('failed to step out')
        end
        _debug('stepOut')

        -- Step out of one (inner most) function
        -- keep stepping out until we get the frame marked as fn.
        if fn ~= nil and frame.fn ~= fn then
            stepOut(fn)
            return
        end

        pointer = frame.pointer
        tree = frame.tree
        env = frame.env
        currentAddr = frame.addr
    end

    local incrementSeenCounter = function(path)
        _debug('increment seen counter: ' .. path)
        local var = getEnv(path, nil, rootEnv)
        requireType(var, 'int')
        var.value = var.value + 1
        turnAtVisit[path] = turns
    end

    local update, getValue, seqPickBranch, runThread

    local getOptionConditionsResult = function(option)
        for _, condition in ipairs(option.conditions) do
            if not node.isTruthy(getValue(condition)) then
                return false
            end
        end
        return true
    end

    -- params: placeholders defined in the function/knot definition.
    -- args: the actual values or expressions passed to the function/knot when calling it
    -- returns a new env with names of params set to argument values
    local getArgumentsEnv = function(params, args)
        _debug('getArguments', 'params', params, 'args', args)
        args = args or {}
        local newEnv = {}
        for i = 1, #params do
            local paramName = params[i].name
            local paramType = params[i].ref
            local arg = args[i]
            if paramType == 'ref' then -- TODO supported for knots?
                requireType(arg, 'ref')
                local refName = arg.name
                if paramName ~= refName then
                    -- the referenced variable has different name inside the function
                    -- (the parameter has a different name than what's used when calling the fn)
                    -- we will point to the same value
                    -- but when assigning to it we cannot just replace it in the local env
                    newEnv[paramName] = node.ref(refName)
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

    currentKnot = nil
    currentStitch = nil
    local discardGatherContinuations = function(gatherBody)
        local popCount = 0
        for i = callstack.size(), 1, -1 do
            if callstack.get(i).gatherBody == gatherBody then
                break
            end
            popCount = popCount + 1
        end
        for _ = 1, popCount do
            callstack.pop()
        end
    end
    local goTo
    goTo = function(path, args, tunnel)
        _debug('go to', path, args)

        if path == 'END' or path == 'DONE' then
            -- ->END with buffered content: the nl that would follow was never reached,
            -- so suppress the trailing '\n' that continue() would otherwise append.
            -- ->DONE is a natural path end; keep the trailing '\n'.
            if path == 'END' and #outputBuffer.buffer > 0 then
                outputBuffer.midExpressionEnd = true
            end
            pointer = #tree + 1
            -- DONE with pending thread choices: leave callstack intact so thread
            -- continuations (e.g. ->-> tunnel returns) still work when a choice is made.
            if path == 'END' or #s.currentChoices == 0 then
                callstack.clear()
            end
            return
        end

        local val = getEnvOptional(path)
        if is('divert', val) then
            goTo(val.target, args, tunnel)
            return
        end

        if path:find('%.') ~= nil then
            local parts = {}
            for part in path:gmatch('[^%.]+') do
                table.insert(parts, part)
            end
            local entry
            if #parts == 2 then
                entry = knots[parts[1]] and knots[parts[1]][parts[2]]
                if entry then
                    currentKnot = parts[1]
                    currentStitch = nil
                end
            elseif #parts == 3 then
                entry = knots[parts[1]] and knots[parts[1]][parts[2]] and knots[parts[1]][parts[2]][parts[3]]
                if entry then
                    currentKnot = parts[1]
                    currentStitch = parts[2]
                end
            end
            if not entry then
                err('unknown path: ' .. path)
                return
            end
            pointer = entry.pointer
            tree = entry.tree

            if isNext('knot') then
                next()
            end

            if #parts == 2 then
                -- count the stitch visit; stitch node is skipped below so update() won't count it
                incrementSeenCounter(path)
            end
            -- for 3-part (knot.stitch.gather), let the gather node update count the visit

            -- automatically go to the first stitch (only) if there is no other content in the knot
            if isNext('stitch') then
                next()
            end
            if isNext('option') then
                local option = tree[pointer]
                markOptionUsed(option)
                returnTo(option.body, bodyAddr(option))
                returnTo(option.t3, t3Addr(option))
                stepInto(option.t1, nil, nil, t1Addr(option))
            end
        elseif knots[currentKnot] and knots[currentKnot][path] then
            local stitchEntry = knots[currentKnot][path]
            currentStitch = path
            pointer = stitchEntry.pointer
            tree = stitchEntry.tree
            if isNext('gather') then
                -- navigate into the gather body (not skip past it)
                tree = tree[pointer].body
                pointer = 1
                discardGatherContinuations(tree)
            else
                next() -- skip the stitch declaration node
                if isNext('nl') then
                    next() -- skip the newline that follows the stitch declaration in the source
                end
            end
            -- bind stitch parameters (divert args) into the env
            -- TODO: for non-thread callers this leaks env; currently only used via threads (runThread restores env)
            if stitchEntry.params and #stitchEntry.params > 0 then
                local newEnv = getArgumentsEnv(stitchEntry.params, args)
                newEnv._parent = env
                env = newEnv
            end
            incrementSeenCounter(currentKnot .. '.' .. path)
        elseif knots[noKnot] and knots[noKnot][currentStitch] and knots[noKnot][currentStitch][path] then
            tree = knots[noKnot][currentStitch][path].tree
            pointer = knots[noKnot][currentStitch][path].pointer
            if isNext('gather') then
                tree = tree[pointer].body
                pointer = 1
                discardGatherContinuations(tree)
            end
            incrementSeenCounter(path) -- TODO full paths
        elseif knots[noKnot] and knots[noKnot][path] then
            tree = knots[noKnot][path].tree -- TODO this is not stepInto, we dont want to step back, right?
            pointer = knots[noKnot][path].pointer
            if is('stitch', tree[pointer]) then
                currentStitch = path
            end
            -- TODO messy
            if isNext('option') then
                local option = tree[pointer]
                -- TODO different mechanism for labelled and anon options; duplicated in chooseChoice
                markOptionUsed(option)
                returnTo(option.body, bodyAddr(option))
                returnTo(option.t3, t3Addr(option))
                stepInto(option.t1, nil, nil, t1Addr(option))
            end
            if isNext('gather') then
                tree = tree[pointer].body
                pointer = 1
                -- discard orphaned returnTo frames for this gather body left by fallback setup
                discardGatherContinuations(tree)
            end
            incrementSeenCounter(path) -- TODO full paths
            if isNext('stitch') then
                next()
            end
        elseif knots[path] then
            local params = knots[path].params
            local body = knots[path].tree
            local newEnv = getArgumentsEnv(params, args)
            stepInto(body, newEnv, tunnel, bodyAddr(knots[path]))

            incrementSeenCounter(path) -- TODO not just knots

            currentKnot = path
            currentStitch = nil
            -- automatically go to the first stitch (only) if there is no other content in the knot
            if isNext('stitch') then
                currentStitch = tree[pointer].name
                incrementSeenCounter(path .. '.' .. tree[pointer].name)
                next()
            end
        else
            error('unknown path: ' .. path) -- TODO check at compile time?
        end

        -- TODO s.state.visitCount[path] = s.state.visitCountAtPathString(path) + 1 -- TODO stitch
    end

    -- "run" the node and return the return value
    -- may return "nothing" (nil)
    getValue = function(val)
        _debug('getValue', val)

        if val == nil then
            return nil --FIXME ???
            --err('nil value')
            --print('get nil')
            --val = tree[pointer] --FIXME 111
            --_debug(val)
            --update()
        end

        if
            is('str', val)
            or is('int', val)
            or is('float', val)
            or is('bool', val)
            or is('divert', val)
            or is('list', val)
            or is('el', val)
        then
            return val
        elseif is('out', val) then
            return getValue(val.content)
        elseif is('ref', val) then
            local name = val.name
            local var = getEnv(name, val)
            return getValue(var)
        elseif is('listlit', val) then
            return getValue(node.listFromLit(val, getEnv))
        elseif is('call', val) then
            local name = val.name
            local args = val.args

            local target = getEnv(name, val)
            _debug('CALL target', target)
            -- FIXME detect unresolved function on compile time

            -- call divert as fn -- FIXME
            if is('divert', target) then
                local path = target.target
                local divertTarget = getEnv(path)
                if is('fn', divertTarget) then
                    target = divertTarget
                end
            end

            if is('native', target) or is('external', target) then
                local argumentValues = {}
                for _, arg in ipairs(args) do
                    table.insert(argumentValues, getValue(arg))
                end
                -- TODO convert arguments, return values for external
                return target.fn(unpack(argumentValues))
            elseif is('fn', target) then
                local params = target.params
                local body = target.body
                local newEnv = getArgumentsEnv(params, args)
                stepInto(body, newEnv, 'fn', bodyAddr(target))
                outputBuffer:instr('trim')
                update()
                local ret = returnValue.value
                outputBuffer:instr('trimEnd')
                _debug('RET', ret)
                returnValue = { present = false, value = nil }
                return ret
            elseif is('list', target) then
                if #args == 0 then
                    return node.listEmpty()
                elseif #args > 1 then
                    err('too many arguments')
                end
                local index = getValue(args[1])
                requireType(index, 'int')
                return node.listElByValue(name, index.value, listDefinitions)
            else
                error('invalid call target: ' .. target.type)
            end
        elseif is('ink', val) then
            -- FIXME
            local result = ''
            for i = 1, #val.nodes do
                local value = getValue(val.nodes[i])
                if value ~= nil then
                    result = result .. nodeOutput(value)
                end
            end
            return node.str(result)
        elseif is('seq', val) then
            local branch = seqPickBranch(val)
            if branch == nil then
                return node.str('')
            end
            local result = ''
            for i = 1, #branch do
                local value = getValue(branch[i])
                if value ~= nil then
                    result = result .. nodeOutput(value)
                end
            end
            return node.str(result)
        else
            _debug(val)
            error('getValue: unsupported type: ' .. tostring(val.type))
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
        return not outputBuffer:isEmpty()
    end

    local nodeUpdateAssign = function(n)
        local name = n.name
        local oldValue, e = getEnv(name)
        _debug('ASSIGN', oldValue, name, n.expr)

        if is('ref', oldValue) then
            local referenced = getEnv(oldValue.name)

            if is('list', referenced) then
                oldValue = referenced
            end
        end

        local newValue = getValue(n.expr)
        if is('list', oldValue) and (is('el', newValue) or is('list', newValue)) then
            node.listSet(oldValue, newValue)
        else
            if newValue == nil then
                err('cannot assign nil')
            end
            if is('ref', oldValue) then
                local refName = oldValue.name
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
            outputBuffer:add(nodeOutput(val))
        end
    end
    local nodeUpdateOut = function(n)
        outputBuffer:instr('outBlockStart')
        nodeUpdateOutValue(n)
    end

    -- Returns a permutation (array of branch indices) with the first `shuffleLen` indices
    -- randomly ordered and the rest in their original order. Uses the same RNG call sequence
    -- as the previous element-based shuffle to preserve SEED_RANDOM test compatibility.
    local seqShuffle = function(total, shuffleLen)
        local indices = {}
        for i = 1, total do
            indices[i] = i
        end
        local perm = {}
        for i = shuffleLen, 1, -1 do
            local j = math.random(i)
            table.insert(perm, table.remove(indices, j))
        end
        for _, idx in ipairs(indices) do
            table.insert(perm, idx)
        end
        return perm
    end

    seqPickBranch = function(n)
        local st = s.state.seqState[n.nodeId]
        if not st then
            st = { current = 1 }
            s.state.seqState[n.nodeId] = st
        end

        if n.opts.shuffle and not st.shuffleOrder then
            local shuffleLen = n.opts.stopping and #n.branches - 1 or #n.branches
            st.shuffleOrder = seqShuffle(#n.branches, shuffleLen)
        end

        local branchIdx = st.shuffleOrder and st.shuffleOrder[st.current] or st.current
        local ret = n.branches[branchIdx]

        if n.opts.stopping then
            st.current = math.min(#n.branches, st.current + 1)
        elseif n.opts.once then
            st.current = math.min(#n.branches + 1, st.current + 1)
        elseif n.opts.cycle then
            st.current = math.fmod(st.current, #n.branches) + 1
        end

        return ret, branchIdx
    end

    local nodeSkip = function() end

    local nodeUpdate = {
        var = nodeSkip,
        const = nodeSkip,
        comment = nodeSkip,
        knot = nodeSkip,
        fndef = nodeSkip,
        external = nodeSkip,
        listdef = nodeSkip,
        -- skip following options after returning from an option where we jumped in by a name -- FIXME
        option = nodeSkip,

        tag = function(n)
            table.insert(tags, n.text)
        end,
        tempvar = function(n)
            env[n.name] = getValue(n.value)
        end,
        assign = nodeUpdateAssign,
        ['return'] = function(n)
            returnValue = { present = true, value = getValue(n.value) }
            stepOut('fn') -- step out of the function, not just the last block we stepped into
        end,
        tunnelreturn = function()
            stepOut('tunnel')
        end,

        str = nodeUpdateOutValue,
        bool = nodeUpdateOutValue,
        int = nodeUpdateOutValue,
        float = nodeUpdateOutValue,
        ref = nodeUpdateOutValue,

        out = nodeUpdateOut,

        seq = function(n)
            -- TODO not needed when continue stops on each end of line???
            outputBuffer:instr('outBlockStart')
            local branch, branchIdx = seqPickBranch(n)
            return branch, branch and seqBranchAddr(n, branchIdx)
        end,

        call = function(n)
            getValue(n)
        end, -- ~ fn() -- call but ignore the result
        todo = function(n)
            logging.warn(n.text, n)
        end,
        glue = function()
            outputBuffer:instr('glue')
        end,
        nl = function()
            outputBuffer:nl()
        end, -- separates "a -> b" from "a\n -> b"
        stitch = function(n)
            currentStitch = n.name
            incrementSeenCounter(n.name)
        end,
        ink = function(n)
            return n.nodes, nodesAddr(n)
        end,
        gather = function(n)
            if n.label then
                if currentKnot and currentStitch then
                    incrementSeenCounter(currentKnot .. '.' .. currentStitch .. '.' .. n.label)
                elseif currentKnot then
                    incrementSeenCounter(currentKnot .. '.' .. n.label)
                else
                    incrementSeenCounter(n.label)
                end
            end
            return n.body, bodyAddr(n)
        end,

        ['if'] = function(n)
            for i, branch in ipairs(n.branches) do
                if node.isTruthy(getValue(branch.cond)) then
                    outputBuffer:instr('outBlockStart') -- TODO before or after the getValue call above?
                    return branch.body, ifBranchAddr(n, i)
                end
            end
            -- no condition evaluated to true (and the else branch not present): do nothing
        end,

        fork = function(n)
            runThread(n)
        end,
    }
    -- TODO move everything to getValue, call getValut from top and dont use the return value,
    -- but inside it can be used e.g. for recursive function call/return values
    local clear = function()
        return { outSnapshot = outputBuffer:clear(), frames = callstack.clear(), currentAddr = currentAddr }
    end

    local reset = function(snapshot)
        outputBuffer:reset(snapshot.outSnapshot)
        callstack = newStack(snapshot.frames)
        currentAddr = snapshot.currentAddr
    end

    local evaluateOptionText = function(option)
        local snapshot = clear()
        local savedTree, savedPointer, savedAddr = tree, pointer, currentAddr
        -- Evaluate t1 and t2 directly without a boundary frame so the callstack
        -- is empty when each block ends, preventing update() from escaping into
        -- the parent story context via the stepOut path.
        tree = option.t1
        pointer = 1
        currentAddr = t1Addr(option)
        update()
        tree = option.t2
        pointer = 1
        currentAddr = t2Addr(option)
        update()
        local text = outputBuffer:popLine()
        tree, pointer, currentAddr = savedTree, savedPointer, savedAddr
        reset(snapshot)
        return text
    end

    runThread = function(n)
        local savedTree, savedPointer, savedEnv, savedAddr = tree, pointer, env, currentAddr
        local savedKnot, savedStitch = currentKnot, currentStitch
        local mainCallstack = callstack
        callstack = newStack()

        goTo(n.target, n.args)

        local threadChoices = {}

        while true do
            if tree[pointer] and tree[pointer].location then
                logging.lastLocation = tree[pointer].location
            end

            if isEnd() then
                if not callstack.isEmpty() then
                    stepOut()
                    next()
                    if callstack.isEmpty() then
                        break
                    end
                else
                    break
                end
            elseif isNext('divert') and (tree[pointer].target == 'DONE' or tree[pointer].target == 'END') then
                break
            elseif isNext('divert') then
                goTo(tree[pointer].target, tree[pointer].args, tree[pointer].tunnel)
            elseif isNext('choice') then
                local choiceNode = tree[pointer]
                local gather = choiceNode.gather
                local fallbacks = {}
                local visible = {}

                for _, option in ipairs(choiceNode.options) do
                    local sticky = option.sticky == 'sticky'
                    local fallback = option.fallback == 'fallback'
                    local show = sticky or not isOptionUsed(option)
                    if fallback then
                        table.insert(fallbacks, option)
                        show = false
                    end
                    if show and not getOptionConditionsResult(option) then
                        show = false
                    end
                    if show then
                        local text = evaluateOptionText(option)
                        -- save thread env so divert parameters (e.g. -> go_back_to) remain
                        -- accessible when the choice body and gather execute after selection;
                        -- save threadKnot so we can increment labeled gather counters correctly
                        table.insert(
                            visible,
                            { text = text, option = option, gather = gather, threadEnv = env, threadKnot = currentKnot }
                        )
                    end
                end

                if #visible > 0 then
                    threadChoices = visible
                    break
                else
                    local executed = false
                    for _, fallback in ipairs(fallbacks) do
                        local sticky = fallback.sticky == 'sticky'
                        if (sticky or not isOptionUsed(fallback)) and getOptionConditionsResult(fallback) then
                            markOptionUsed(fallback)
                            if gather then
                                returnToGather(gather.body, bodyAddr(gather))
                            end
                            stepInto(fallback.body, nil, nil, bodyAddr(fallback))
                            executed = true
                            break
                        end
                    end
                    if not executed then
                        -- No visible choices and no fallback: thread has nothing to contribute.
                        -- Do NOT follow the gather — it belongs to post-selection flow and can
                        -- cause infinite recursion if it diverts back into the story.
                        break
                    end
                end
            else
                local nodeType = tree[pointer].type
                local updateFn = nodeUpdate[nodeType]
                if not updateFn then
                    err('unexpected node in thread', tree[pointer])
                end
                local nextStep, nextAddr = updateFn(tree[pointer])
                if nextStep then
                    local inlineFn = (nodeType == 'if' or nodeType == 'seq') and 'inline' or nil
                    stepInto(nextStep, nil, inlineFn, nextAddr)
                else
                    next()
                end
            end
        end

        local threadFrames = callstack.clear()
        callstack = mainCallstack

        for _, c in ipairs(threadChoices) do
            if #threadFrames > 0 then
                c.threadFrames = threadFrames
            end
            table.insert(s.currentChoices, c)
            threadChoicesAdded = true
        end

        tree, pointer, env, currentAddr = savedTree, savedPointer, savedEnv, savedAddr
        currentKnot, currentStitch = savedKnot, savedStitch
    end

    update = function()
        _debug('upd: ' .. pointer .. (tree[pointer] and tree[pointer].type or 'END'))

        if returnValue.present then
            -- do not proceed when returning from a (nested?) function call
            pointer = pointer - 1 -- FIXME what's going on here
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
            goTo(tree[pointer].target, tree[pointer].args, tree[pointer].tunnel)
            update()
            return
        end

        if isNext('choice') then
            s.canContinue = canContinue()
            if s.canContinue then
                -- output buffer first
                return
            end

            local options = tree[pointer].options
            local gather = tree[pointer].gather
            local fallbacks = {}

            -- preserve any thread choices already added by fork nodes earlier this turn
            for _, option in ipairs(options) do
                local sticky = option.sticky == 'sticky' -- TODO
                local fallback = option.fallback == 'fallback'
                local displayOption = sticky or not isOptionUsed(option) -- TODO seen counter

                if fallback then
                    table.insert(fallbacks, option)
                    displayOption = false
                end

                if displayOption and not getOptionConditionsResult(option) then
                    displayOption = false
                end

                if displayOption then
                    local text = evaluateOptionText(option)
                    table.insert(s.currentChoices, { text = text, option = option, gather = gather })
                end
            end

            s.canContinue = canContinue()

            if #s.currentChoices == 0 then
                local doUpdate = false
                if gather then
                    stepInto(gather.body, nil, nil, bodyAddr(gather))
                    doUpdate = true
                end
                for _, fallback in ipairs(fallbacks) do
                    local sticky = fallback.sticky == 'sticky'
                    if (sticky or not isOptionUsed(fallback)) and getOptionConditionsResult(fallback) then
                        markOptionUsed(fallback)
                        if gather then
                            returnToGather(gather.body, bodyAddr(gather))
                        end
                        stepInto(fallback.body, nil, nil, bodyAddr(fallback))
                        doUpdate = true
                        break
                    end
                end
                if doUpdate then
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
                if not callstack.isEmpty() then
                    stepOut()
                    _debug('step out at end')
                    next()
                    update()
                    return
                end
            end
            next()
            s.canContinue = canContinue()
            return
        end

        local nodeType = tree[pointer].type
        local updateFn = nodeUpdate[nodeType]
        if not updateFn then
            err('unexpected node', tree[pointer])
        end
        local nextStep, nextAddr = updateFn(tree[pointer])
        if nextStep then
            -- 'if' and 'seq' are the only nodeUpdate handlers that emit {outBlockStart} before stepping in
            local inlineFn = (nodeType == 'if' or nodeType == 'seq') and 'inline' or nil
            stepInto(nextStep, nil, inlineFn, nextAddr)
        else
            next()
        end
        update()
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
                error(
                    'Missing function(s) binding for external '
                        .. table.concat(notBindExternalFunctionNames, ', ')
                        .. ' and no fallback ink function found'
                )
            end
            storyStarted = true
            update() -- first call: process story before popping
        end

        _debug('out', outputBuffer.buffer)
        local res = ''
        local trailingGlue = false
        local hadNl = true
        -- rawHadContent: was there anything to potentially collect (before processing)?
        -- bufferWasEmpty: did anything survive after collect() reduced the buffer?
        -- A buffer with only {nl=true} has rawHadContent=true but bufferWasEmpty=true.
        local rawHadContent = #outputBuffer.buffer > 0
        local bufferWasEmpty = outputBuffer:isEmpty()
        if not bufferWasEmpty then
            res, trailingGlue, hadNl = outputBuffer:popLine()
        end
        _debug('OUT:', res)
        s.currentTags = tags
        tags = {}
        if #s.currentChoices == 0 then
            update() -- advance to next output; skip if choices already populated
        end
        -- if update() added content to a truly empty buffer (no prior content this call),
        -- pop it now so it's returned as text rather than as a blank separator
        if res == '' and not rawHadContent and not outputBuffer:isEmpty() then
            res, trailingGlue, hadNl = outputBuffer:popLine()
            bufferWasEmpty = false
        end
        -- drain thread output before showing choices:
        -- if buffer still has content, keep going; once empty with choices ready, stop
        if not outputBuffer:isEmpty() then
            s.canContinue = true
        elseif #s.currentChoices > 0 then
            s.canContinue = false
        end
        if res == '' then
            if not bufferWasEmpty then
                return '\n' -- whitespace-only line → blank line
            elseif #s.currentChoices > 0 then
                -- when thread choices are present and a turn has been taken with no text output,
                -- emit an extra blank line (the thread transition creates a paragraph break)
                local hasThreadChoices = turns > 0 and not turnHadOutput and threadChoicesAdded
                return hasThreadChoices and '\n\n' or '\n'
            elseif rawHadContent then
                return '\n' -- buffer had nl-only content (e.g. loop ended at gather)
            else
                return '' -- story ended with no output
            end
        elseif trailingGlue or s.canContinue then
            turnHadOutput = true
            return res .. '\n'
        elseif #s.currentChoices == 0 then
            -- story ended; omit \n if the line was cut short (e.g. ->END mid-text)
            return res .. (hadNl and '\n' or '')
        else
            turnHadOutput = true
            return res .. '\n\n'
        end
    end

    s.chooseChoiceIndex = function(index)
        if type(index) ~= 'number' then
            error('number expected')
        end

        local choice = s.currentChoices[index]

        if choice.threadFrames then
            -- only re-push tunnel frames; entry frames (fn=nil) would re-execute the fork node
            for _, frame in ipairs(choice.threadFrames) do
                if frame.fn == 'tunnel' then
                    callstack.push(frame)
                end
            end
        end

        if choice.threadEnv then
            -- restore the env scope active when the thread collected this choice, so that
            -- divert parameters (e.g. -> go_back_to) remain accessible in the choice body
            env = choice.threadEnv
        end

        if choice.option.label then -- the option has a label
            incrementSeenCounter(choice.option.label) -- TODO full path??
        end
        markOptionUsed(choice.option)

        if choice.gather then
            -- thread choices bypass the gather node dispatch, so increment its label counter here
            if choice.gather.label and choice.threadKnot then
                incrementSeenCounter(choice.threadKnot .. '.' .. choice.gather.label)
            end
            returnToGather(choice.gather.body, bodyAddr(choice.gather))
        end

        returnTo(choice.option.body, bodyAddr(choice.option))
        returnTo(choice.option.t3, t3Addr(choice.option))
        stepInto(choice.option.t1, nil, nil, t1Addr(choice.option))

        s.currentChoices = {}
        turns = turns + 1
        turnHadOutput = false
        threadChoicesAdded = false
        update()
        -- canContinue() returns false when choices are present, even if the buffer has text
        -- to output. Force s.canContinue so continue() is called to drain pending output.
        if not outputBuffer:isEmpty() then
            s.canContinue = true
        elseif not s.canContinue and threadChoicesAdded then
            -- buffer empty: still need continue() so the thread-choice paragraph separator is emitted
            s.canContinue = true
        end
    end

    s.choosePathString = function(knotName)
        goTo(knotName)
        update()
    end

    s.state.visitCountAtPathString = function(knotName)
        return s.state.visitCount[knotName] or 0
    end

    -- TODO document
    s.bindExternalFunction = function(name, fn)
        local externalFunctionParams = externalDefs[name]
        if externalFunctionParams == nil then
            error('cannot bind ' .. name .. ', external function not defined')
        end
        -- TODO check params
        externalDefs[name] = nil
        env[name] = node.externalFn(fn)
        update()
    end

    -- s.state.ToJson();s.state.LoadJson(savedJson);

    local compiled = compile(tree, env, noKnot, listDefinitions)
    knots = compiled.knots
    nodeById = compiled.nodeById
    externalDefs = compiled.externalDefs
    s.globalTags = compiled.globalTags
    -- skip leading tags already collected into globalTags by compiler
    while is('tag', tree[pointer]) do
        pointer = pointer + 1
    end
    _debug(tree)
    _debug('lists:', listDefinitions)
    _debug('external:', externalDefs)
    _debug('state:', s.variablesState)

    return s
end
