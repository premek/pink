local base_path = (...):match('(.-)[^%.]+$')
local Story = require(base_path .. 'story')
local newOutputBuffer = require(base_path .. 'output_buffer')
local newListDefinitions = require(base_path .. 'list_definitions')
local node = require(base_path .. 'node')
local createBuiltins = require(base_path .. 'builtins')
local compile = require(base_path .. 'compiler')
local logging = require(base_path .. 'logging')
local newStack = require(base_path .. 'stack')
local random = require(base_path .. 'random')
local Path = require(base_path .. 'path')
local requireType = node.requireType
local is = node.is

random.seed(os.time())
local unpack = table.unpack or unpack

local noKnot = {} -- sentinel key for top-level content not inside any knot

return function(globalTree)
    local log = logging.newLogger()
    local outputBuffer = newOutputBuffer()
    local listDefinitions = newListDefinitions()
    local nodeOutput = node.makeOutput(listDefinitions)
    local getEnv, s, nodeById, turnAtVisitGet -- forward declarations needed by createBuiltins closures
    local lastTokenWithLocation = nil
    local currentKnot, currentStitch -- forward declarations needed by getEnv for label lookup
    local turns = 0
    -- Each node has `.turn` (recorded turn number) and `.children` (subtable keyed by path segment).
    local turnAtVisit = {}
    -- true when choices were collected inside an inline frame; must step out before presenting
    local choicesNeedDrain = false
    -- true during evaluateOptionText; allows handleEndOfTree to step out of seq-inline frames
    -- even when s.currentChoices is non-empty (choices from the outer evaluation)
    local evaluatingOptionText = false
    -- callstack depth after the most recent goTo; frames above this belong to the current knot context
    local lastDivertDepth = 0

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
            return turnAtVisitGet(path)
        end,
        listDefinitions = listDefinitions,
        getLocation = function()
            return lastTokenWithLocation
        end,
    })
    local env = rootEnv -- TODO should env be part of the callstack?

    -- set when interpreting a 'return' statement, read after stepping 'Out'
    -- TODO does it have to be a stack?
    local returnValue = { active = false, value = nil }
    -- set to a die function when an error is detected inside update(); s.continue() returns
    -- any buffered content (already popped into res) first, then calls this on the next turn
    local pendingDie = nil
    local hadCleanEnd = false
    local lastOutputTokenWithLocation = nil

    -- story - this table will be passed to client code
    s = Story.new(rootEnv)

    local tree = globalTree
    local pointer = 1
    local callstack = newStack()
    -- Describes which block 'tree' refers to; nil = globalTree or unknown (direct goTo navigation).
    -- Updated by stepInto/stepOut. Enables callstack frame serialization for save/load.
    local currentAddr = nil
    local knots
    local externalDefs
    local storyStarted = false
    -- Tags are collected in pendingTags as update() runs. When an nl node fires and
    -- the current line had output, the pending tags are committed to tagLines. continue()
    -- always pops one entry per call; entries are {} when a line carries no tags.
    local pendingTags = {}
    local lineHadContent = false
    local tagLines = {}
    -- set in chooseChoiceIndex; cleared by the first nl in the option body so that
    -- option tags (from bodyOnlyText) get their own dedicated continue() call
    local flushOptionTags = false

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
    local sharedStartTextAddr = function(n)
        return addr(n, 'sharedStartText')
    end
    local choiceOnlyTextAddr = function(n)
        return addr(n, 'choiceOnlyText')
    end
    local bodyOnlyTextAddr = function(n)
        return addr(n, 'bodyOnlyText')
    end
    local seqBranchAddr = function(n, i)
        return addr(n, 'branches', i)
    end
    local ifBranchAddr = function(n, i)
        return addr(n, 'branches', i, 'body')
    end
    -- Reconstructs a block from a saved address. Used by future save/load.
    ---@diagnostic disable-next-line: unused-local, unused-function
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

    local getChildren = function(parentName, segments, tbl, token)
        log.debug('DDD', parentName, segments, tbl, token)
        for _, part in ipairs(segments) do
            if not tbl._children or not tbl._children[part] then
                -- list type variable may have been reassigned to a non-list value, but
                -- listName.elementName always refers to the list definition, not the current value
                if listDefinitions[parentName] and listDefinitions[parentName].byName[part] then
                    tbl = node.el(parentName, part)
                else
                    log.debug(parentName, segments, env)
                    log.die('error accessing "' .. part .. '" in "' .. parentName .. '"', token)
                end
            else
                tbl = tbl._children[part]
            end
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

    getEnv = function(path, token, startingEnv)
        local first = path[1]
        local rest = { unpack(path, 2) }
        local val, e = getEnvOptional(first, startingEnv)
        if val == nil then
            if currentKnot then
                local knotEntry = getEnvOptional(currentKnot, rootEnv)
                if knotEntry and knotEntry._children then
                    if #rest == 0 and knotEntry._children[first] then
                        -- bare label directly under current knot (e.g. 'done' inside 'review_case_notes')
                        return knotEntry._children[first], rootEnv
                    elseif #rest > 0 and knotEntry._children[first] then
                        -- stitch.label path relative to current knot (e.g. 'stitch_one.gatherpoint')
                        val = knotEntry._children[first]
                        e = rootEnv
                    end
                end
            end
            if val == nil then
                log.variableNotFound(Path.toString(path), token)
                return node.int(0), env
            end
        end
        val = getChildren(first, rest, val, token)
        return val, e
    end

    -- All callstack frames share this schema. Fields: tree/pointer/env/addr = saved execution state;
    -- fn = frame type (nil=entry, 'fn'=function call, 'tunnel'=tunnel, 'inline'/'seq-inline'=inline block);
    -- savedKnot/savedStitch = restored on tunnel step-out; gatherEntry = body block for discardGatherContinuations.
    local newFrame = function(frameFn, frameGatherEntry)
        return {
            tree = tree,
            pointer = pointer,
            fn = frameFn,
            env = env,
            addr = currentAddr,
            savedKnot = currentKnot,
            savedStitch = currentStitch,
            gatherEntry = frameGatherEntry,
        }
    end

    local stepInto = function(block, newEnv, fn, blockAddr, gatherEntryBlock)
        log.debug('step into')
        callstack.push(newFrame(fn, gatherEntryBlock))
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

    -- like returnTo but marks the frame with gatherEntry so discardGatherContinuations can find it
    local returnToGather = function(block, blockAddr)
        stepInto(block, nil, nil, blockAddr, block)
        pointer = 0
    end

    local stepOut
    stepOut = function(fn)
        local frame = callstack.pop()
        if not frame then
            return log.die('failed to step out')
        end
        log.debug('stepOut')

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
        if frame.fn == 'tunnel' then
            currentKnot = frame.savedKnot
            currentStitch = frame.savedStitch
        end
    end

    local turnAtVisitSet = function(path, value)
        local t = turnAtVisit
        for _, segment in ipairs(path) do
            t.children = t.children or {}
            t.children[segment] = t.children[segment] or {}
            t = t.children[segment]
        end
        t.turn = value
    end

    turnAtVisitGet = function(path)
        local t = turnAtVisit
        for _, segment in ipairs(path) do
            if not t.children then
                return nil
            end
            t = t.children[segment]
            if not t then
                return nil
            end
        end
        return t.turn
    end

    local incrementSeenCounter = function(path)
        log.debug('increment seen counter: ' .. Path.toString(path))
        local var = getEnv(path, nil, rootEnv)
        requireType(var, 'int')
        var.value = var.value + 1
        s.state.visitCount[Path.toString(path)] = var.value
        turnAtVisitSet(path, turns)
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
        log.debug('getArguments', 'params', params, 'args', args)
        args = args or {}
        local newEnv = {}
        for i = 1, #params do
            local paramName = params[i].name
            local paramType = params[i].ref
            local arg = args[i]
            if paramType == 'ref' then -- TODO supported for knots?
                requireType(arg, 'ref')
                local refName = arg.path[1]
                if paramName ~= refName then
                    -- the referenced variable has different name inside the function
                    -- (the parameter has a different name than what's used when calling the fn)
                    -- we will point to the same value
                    -- but when assigning to it we cannot just replace it in the local env
                    newEnv[paramName] = node.ref(Path.of(refName))
                end
                -- if the name is the same in and out-side the function:
                -- do not create a local variable that would reference to itself and create a loop
            elseif paramType == '->' then
                local argValue = getValue(arg)
                requireType(argValue, 'divert')
                if argValue ~= nil then -- for lsp warning
                    local qualifiedPath =
                        Path.qualify(argValue.target, currentKnot, currentKnot and knots[currentKnot], currentStitch)
                    newEnv[paramName] = node.divert(qualifiedPath, argValue.args, argValue.tunnel)
                end
            else
                -- get values from old env, set new env only after all vars are resolved from the old one
                newEnv[paramName] = getValue(arg)
            end
        end
        return newEnv
    end

    currentKnot = nil
    currentStitch = nil
    local discardGatherContinuations = function(gatherEntry)
        local popCount = 0
        local found = false
        for i = callstack.size(), 1, -1 do
            local frame = callstack.get(i)
            if frame.gatherEntry == gatherEntry then
                found = true
                break
            end
            popCount = popCount + 1
        end
        if found then
            for _ = 1, popCount do
                callstack.pop()
            end
        end
    end
    local gotoTerminal = function(name)
        hadCleanEnd = true
        outputBuffer:instr('terminalDivert')
        pointer = #tree + 1
        -- DONE with pending thread choices: leave callstack intact so thread
        -- continuations (e.g. ->-> tunnel returns) still work when a choice is made.
        if name == 'END' or #s.currentChoices == 0 then
            callstack.clear()
        end
        choicesNeedDrain = false
    end

    local gotoAbsolutePath = function(path)
        local entry
        if #path == 2 then
            entry = knots[path[1]] and knots[path[1]][path[2]]
            if entry then
                currentKnot = path[1]
                currentStitch = nil
            end
        elseif #path == 3 then
            entry = knots[path[1]] and knots[path[1]][path[2]] and knots[path[1]][path[2]][path[3]]
            if entry then
                currentKnot = path[1]
                currentStitch = path[2]
            end
        end
        if not entry then
            log.die('unknown path: ' .. Path.toString(path))
            return
        end
        pointer = entry.pointer
        tree = entry.tree

        if isNext('knot') then
            next()
        end
        if #path == 2 then
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
            if entry.gather then
                returnToGather(entry.gather.body, bodyAddr(entry.gather))
            end
            returnTo(option.body, bodyAddr(option))
            returnTo(option.bodyOnlyText, bodyOnlyTextAddr(option))
            stepInto(option.sharedStartText, nil, nil, sharedStartTextAddr(option))
        end
    end

    local gotoRelativeStitch = function(name, args, tunnel)
        if tunnel then
            callstack.push(newFrame(tunnel))
        end
        local stitchEntry = knots[currentKnot][name]
        local incomingStitch = currentStitch
        currentStitch = name
        pointer = stitchEntry.pointer
        tree = stitchEntry.tree
        local isGatherEntry = isNext('gather')
        if isGatherEntry then
            -- navigate into the gather body (not skip past it)
            tree = tree[pointer].body
            pointer = 1
            discardGatherContinuations(tree)
        else
            next() -- skip the stitch declaration node
        end
        -- bind stitch parameters (divert args) into the env
        -- TODO: for non-thread callers this leaks env; currently only used via threads (runThread restores env)
        if stitchEntry.params and #stitchEntry.params > 0 then
            local newEnv = getArgumentsEnv(stitchEntry.params, args)
            newEnv._parent = env
            env = newEnv
        end
        -- gather labels always increment; skip only for self-recursive stitch diverts
        if isGatherEntry or incomingStitch ~= name then
            incrementSeenCounter(Path.of(currentKnot, name))
        end
    end

    local gotoRelativeStitchLabel = function(name, tunnel)
        if tunnel then
            local entryNode = knots[noKnot][currentStitch][name].tree[knots[noKnot][currentStitch][name].pointer]
            callstack.push(newFrame(tunnel, is('gather', entryNode) and entryNode.body or nil))
        end
        tree = knots[noKnot][currentStitch][name].tree
        pointer = knots[noKnot][currentStitch][name].pointer
        if isNext('gather') then
            tree = tree[pointer].body
            pointer = 1
            discardGatherContinuations(tree)
        end
        incrementSeenCounter(Path.of(name)) -- TODO full paths
    end

    local gotoTopLevelLabel = function(name, tunnel)
        local noKnotEntry = knots[noKnot][name]
        local entryNode = noKnotEntry.tree[noKnotEntry.pointer]
        if tunnel then
            callstack.push(newFrame(tunnel, is('gather', entryNode) and entryNode.body or nil))
        end
        tree = noKnotEntry.tree -- TODO this is not stepInto, we dont want to step back, right?
        pointer = noKnotEntry.pointer
        if is('gather', entryNode) then
            tree = entryNode.body
            pointer = 1
            -- discard orphaned returnTo frames for this gather body left by fallback setup
            discardGatherContinuations(tree)
        elseif is('stitch', entryNode) then
            currentStitch = name
            next() -- skip the stitch declaration node
        elseif is('option', entryNode) then
            -- TODO different mechanism for labelled and anon options; duplicated in chooseChoice
            markOptionUsed(entryNode)
            if noKnotEntry.gather then
                returnToGather(noKnotEntry.gather.body, bodyAddr(noKnotEntry.gather))
            end
            returnTo(entryNode.body, bodyAddr(entryNode))
            returnTo(entryNode.bodyOnlyText, bodyOnlyTextAddr(entryNode))
            stepInto(entryNode.sharedStartText, nil, nil, sharedStartTextAddr(entryNode))
        end
        incrementSeenCounter(Path.of(name)) -- TODO full paths
    end

    local gotoKnot = function(name, args, tunnel)
        local params = knots[name].params
        local body = knots[name].tree
        local newEnv = getArgumentsEnv(params, args)
        local incomingKnot = currentKnot
        stepInto(body, newEnv, tunnel, bodyAddr(knots[name]))

        currentKnot = name
        currentStitch = nil
        if incomingKnot ~= name then
            incrementSeenCounter(Path.of(name)) -- TODO not just knots
        end
        -- automatically go to the first stitch (only) if there is no other content in the knot
        if isNext('stitch') then
            currentStitch = tree[pointer].name
            incrementSeenCounter(Path.of(name, tree[pointer].name))
            next()
        end
    end

    local goTo
    goTo = function(path, args, tunnel)
        log.debug('go to', path, args)

        if path[1] == 'END' or path[1] == 'DONE' then
            gotoTerminal(path[1])
            return
        end

        local val = getEnvOptional(path[1])
        if is('divert', val) then
            goTo(val.target, args, tunnel)
            return
        end

        if #path > 1 then
            gotoAbsolutePath(path)
        elseif knots[currentKnot] and knots[currentKnot][path[1]] then
            gotoRelativeStitch(path[1], args, tunnel)
        elseif knots[noKnot] and knots[noKnot][currentStitch] and knots[noKnot][currentStitch][path[1]] then
            gotoRelativeStitchLabel(path[1], tunnel)
        elseif knots[noKnot] and knots[noKnot][path[1]] then
            gotoTopLevelLabel(path[1], tunnel)
        elseif knots[path[1]] then
            gotoKnot(path[1], args, tunnel)
        else
            error('unknown path: ' .. Path.toString(path)) -- TODO check at compile time?
        end

        -- frames above this depth belong to the current knot context (vs thread continuations)
        lastDivertDepth = callstack.size()
    end

    -- "run" the node and return the return value
    -- may return "nothing" (nil)
    getValue = function(val)
        log.debug('getValue', val)
        if
            is('str', val)
            or is('int', val)
            or is('float', val)
            or is('bool', val)
            or is('list', val)
            or is('el', val)
        then
            return val
        elseif is('out', val) then
            return getValue(val.content)
        elseif is('ref', val) then
            local var = getEnv(val.path, val)
            return getValue(var)
        elseif is('listlit', val) then
            return getValue(node.listFromLit(val, function(n)
                return getEnv(Path.of(n))
            end))
        elseif is('divert', val) then
            return node.divert(
                Path.qualify(val.target, currentKnot, currentKnot and knots[currentKnot], currentStitch),
                val.args,
                val.tunnel
            )
        elseif is('call', val) then
            local args = val.args

            local target = getEnv(Path.of(val.name), val)
            log.debug('CALL target', target)
            -- FIXME detect unresolved function on compile time

            -- call divert as fn -- FIXME
            if is('divert', target) then
                local divertPath = target.target
                local divertTarget = getEnv(divertPath)
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
                log.debug('RET', ret)
                returnValue = { active = false, value = nil }
                return ret
            elseif is('list', target) then
                if #args == 0 then
                    return node.listEmpty()
                elseif #args > 1 then
                    log.die('too many arguments')
                end
                local index = getValue(args[1])
                requireType(index, 'int')
                return node.listElByValue(val.name, assert(index).value, listDefinitions)
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
            log.debug(val)
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
        local oldValue, e = getEnv(Path.of(n.name))
        log.debug('ASSIGN', oldValue, n.name, n.expr)

        if is('ref', oldValue) then
            local referenced = getEnv(Path.of(oldValue.path[1]))

            if is('list', referenced) then
                oldValue = referenced
            end
        end

        local newValue = getValue(n.expr)
        if is('list', oldValue) and (is('el', newValue) or is('list', newValue)) then
            node.listSet(oldValue, newValue)
        else
            if newValue == nil then
                log.die('cannot assign nil')
            end
            if is('ref', oldValue) then
                local refName = oldValue.path[1]
                local _, refEnv = getEnv(Path.of(refName))
                refEnv[refName] = newValue
            else
                e[n.name] = newValue
            end
        end
        log.debug(env)
    end

    local nodeUpdateOutValue = function(n)
        local val = getValue(n)
        if val ~= nil then
            local text = nodeOutput(val)
            outputBuffer:add(text)
            if text:match('%S') then
                lineHadContent = true
            end
            if n.location then
                lastOutputTokenWithLocation = n
            end
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
            local j = random.int(1, i)
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
        todo = nodeSkip,
        knot = nodeSkip,
        fndef = nodeSkip,
        external = nodeSkip,
        listdef = nodeSkip,
        -- skip following options after returning from an option where we jumped in by a name -- FIXME
        option = nodeSkip,

        tag = function(n)
            table.insert(pendingTags, (n.text:gsub('%s+$', '')))
        end,
        tempvar = function(n)
            local val = getValue(n.value)
            env[n.name] = val
        end,
        assign = nodeUpdateAssign,
        ['return'] = function(n)
            local val = nil
            if n.value then
                val = getValue(n.value)
            end
            returnValue = { active = true, value = val }
            stepOut('fn') -- step out of the function, not just the last block we stepped into
        end,
        tunnelreturn = function()
            if choicesNeedDrain then
                -- stop the drain here; don't exit the tunnel before the user picks a choice
                choicesNeedDrain = false
                return
            end
            stepOut('tunnel')
        end,

        str = nodeUpdateOutValue,
        bool = nodeUpdateOutValue,
        int = nodeUpdateOutValue,
        float = nodeUpdateOutValue,
        ref = nodeUpdateOutValue,

        out = nodeUpdateOut,

        seq = function(n)
            local branch, branchIdx = seqPickBranch(n)
            if branch then
                outputBuffer:instr('outBlockStart')
            end
            return branch, branch and seqBranchAddr(n, branchIdx)
        end,

        call = function(n)
            getValue(n)
        end, -- ~ fn() -- call but ignore the result
        glue = function()
            outputBuffer:instr('glue')
        end,
        nl = function()
            outputBuffer:nl()
            if lineHadContent then
                table.insert(tagLines, pendingTags)
                pendingTags = {}
                lineHadContent = false
            elseif flushOptionTags and #pendingTags > 0 then
                -- first nl after a choice's option-only text: emit a placeholder so the
                -- option tag gets its own continue() call (before the body content starts)
                outputBuffer:add('\n')
                table.insert(tagLines, pendingTags)
                pendingTags = {}
            end
            flushOptionTags = false
        end, -- separates "a -> b" from "a\n -> b"
        stitch = function(n)
            currentStitch = n.name
            incrementSeenCounter(Path.of(n.name))
        end,
        ink = function(n)
            return n.nodes, nodesAddr(n)
        end,
        gather = function(n)
            if n.label then
                incrementSeenCounter(Path.label(currentKnot, currentStitch, n.label))
                -- TURNS_SINCE(-> label) uses bare label as the lookup key
                if currentKnot then
                    turnAtVisitSet(Path.of(n.label), turns)
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
        local savedPendingTags, savedLineHadContent, savedTagLines = pendingTags, lineHadContent, tagLines
        local savedFlushOptionTags = flushOptionTags
        pendingTags, lineHadContent, tagLines = {}, false, {}
        flushOptionTags = false
        evaluatingOptionText = true
        -- Evaluate sharedStartText and choiceOnlyText directly without a boundary frame so the callstack
        -- is empty when each block ends, preventing update() from escaping into
        -- the parent story context via the stepOut path.
        tree = option.sharedStartText
        pointer = 1
        currentAddr = sharedStartTextAddr(option)
        update()
        tree = option.choiceOnlyText
        pointer = 1
        currentAddr = choiceOnlyTextAddr(option)
        update()
        evaluatingOptionText = false
        local text = outputBuffer:popLine()
        tree, pointer, currentAddr = savedTree, savedPointer, savedAddr
        pendingTags, lineHadContent, tagLines = savedPendingTags, savedLineHadContent, savedTagLines
        flushOptionTags = savedFlushOptionTags
        reset(snapshot)
        return text
    end

    runThread = function(n)
        local savedTree, savedPointer, savedEnv, savedAddr = tree, pointer, env, currentAddr
        local savedKnot, savedStitch = currentKnot, currentStitch
        local mainCallstack = callstack
        local savedLastDivertDepth = lastDivertDepth
        local savedPendingTags, savedLineHadContent, savedTagLines = pendingTags, lineHadContent, tagLines
        local savedFlushOptionTags = flushOptionTags
        pendingTags, lineHadContent, tagLines = {}, false, {}
        flushOptionTags = false
        callstack = newStack()
        lastDivertDepth = 0

        goTo(n.target, n.args)

        local threadChoices = {}

        while true do
            if tree[pointer] and tree[pointer].location then
                lastTokenWithLocation = tree[pointer]
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
            elseif isNext('divert') and (tree[pointer].target[1] == 'DONE' or tree[pointer].target[1] == 'END') then
                break
            elseif isNext('tunnelreturnto') then
                local rtn = tree[pointer]
                stepOut('tunnel')
                goTo(rtn.target, rtn.args, nil)
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
                        -- save threadKnot/threadStitch so we can increment labeled counters correctly
                        table.insert(visible, {
                            text = text,
                            option = option,
                            gather = gather,
                            threadEnv = env,
                            threadKnot = currentKnot,
                            threadStitch = currentStitch,
                        })
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
                    log.die('unexpected node in thread', tree[pointer])
                end
                local nextStep, nextAddr = updateFn(tree[pointer])
                if nextStep then
                    local inlineFn = nodeType == 'seq' and 'seq-inline' or (nodeType == 'if' and 'inline' or nil)
                    local gatherEntryMarker = nodeType == 'gather' and nextStep or nil
                    stepInto(nextStep, nil, inlineFn, nextAddr, gatherEntryMarker)
                else
                    next()
                end
            end
        end

        local threadFrames = callstack.clear()
        callstack = mainCallstack
        lastDivertDepth = savedLastDivertDepth

        for _, c in ipairs(threadChoices) do
            if #threadFrames > 0 then
                c.threadFrames = threadFrames
            end
            table.insert(s.currentChoices, c)
            outputBuffer:instr('threadChoice')
        end

        tree, pointer, env, currentAddr = savedTree, savedPointer, savedEnv, savedAddr
        currentKnot, currentStitch = savedKnot, savedStitch
        pendingTags, lineHadContent, tagLines = savedPendingTags, savedLineHadContent, savedTagLines
        flushOptionTags = savedFlushOptionTags
    end

    local handleDivert = function()
        if choicesNeedDrain then
            local target = tree[pointer].target
            if target[1] ~= 'DONE' and target[1] ~= 'END' then
                choicesNeedDrain = false
                s.canContinue = canContinue()
                return
            end
        end
        goTo(tree[pointer].target, tree[pointer].args, tree[pointer].tunnel)
        update()
    end

    local handleTunnelReturnTo = function()
        local n = tree[pointer]
        stepOut('tunnel')
        goTo(n.target, n.args)
        update()
    end

    local hasVisibleNonFallback = function(opts)
        for _, opt in ipairs(opts) do
            if opt.fallback ~= 'fallback' then
                local sticky = opt.sticky == 'sticky'
                if (sticky or not isOptionUsed(opt)) and getOptionConditionsResult(opt) then
                    return true
                end
            end
        end
        return false
    end

    local handleChoice = function()
        s.canContinue = canContinue()
        if s.canContinue then
            -- Don't defer when mid-paragraph with only fallbacks: the fallback output belongs on the same line.
            local choiceNode = tree[pointer]
            local shouldDefer = outputBuffer.hadTrailingNl
                or choiceNode.gather
                or hasVisibleNonFallback(choiceNode.options)
            if shouldDefer then
                return
            end
            s.canContinue = false
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
                table.insert(s.currentChoices, {
                    text = text,
                    option = option,
                    gather = gather,
                    threadKnot = currentKnot,
                    threadStitch = currentStitch,
                })
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
            -- no gather and no fallback; if a gatherEntry frame exists above lastDivertDepth
            -- we're stranded inside a chosen option that has nowhere to go.
            for i = callstack.size(), lastDivertDepth + 1, -1 do
                local f = callstack.get(i)
                if f.gatherEntry then
                    -- gather body is {ink_node}; first content node gives inklecate's error line
                    local tokenWithLocation = lastTokenWithLocation
                    local inkNode = f.gatherEntry[1]
                    if inkNode and inkNode.nodes then
                        for _, n in ipairs(inkNode.nodes) do
                            if n.location and n.location.line then
                                tokenWithLocation = n
                                break
                            end
                        end
                    end
                    pendingDie = function()
                        log.dieRanOutOfContent(tokenWithLocation)
                    end
                    return
                end
            end
        end

        for i = lastDivertDepth + 1, callstack.size() do
            if callstack.get(i).fn == 'inline' or callstack.get(i).fn == 'seq-inline' then
                choicesNeedDrain = true
                break
            end
        end
        next()
        if choicesNeedDrain then
            update()
        end
    end

    local handleEndOfTree = function()
        --FIXME refactor so we don't need this if
        if not callstack.isEmpty() then
            local topFn = callstack.get(callstack.size()).fn
            local aboveBoundary = callstack.size() > lastDivertDepth
            local canStepOut = #s.currentChoices == 0
                or evaluatingOptionText
                or (choicesNeedDrain and aboveBoundary and topFn ~= 'fn' and topFn ~= 'tunnel')
            if canStepOut then
                local wasSeqInline = topFn == 'seq-inline'
                stepOut()
                if wasSeqInline then
                    outputBuffer:instr('outBlockEnd')
                end
                log.debug('step out at end')
                next()
                update()
                return
            end
        end
        if choicesNeedDrain then
            choicesNeedDrain = false
        end
        next()
        s.canContinue = canContinue()
    end

    update = function()
        log.debug('upd: ' .. pointer .. (tree[pointer] and tree[pointer].type or 'END'))

        if returnValue.active then
            -- do not proceed when returning from a (nested?) function call
            pointer = pointer - 1 -- FIXME what's going on here
            return
        end

        if tree[pointer] and tree[pointer].location then
            lastTokenWithLocation = tree[pointer].location
        end

        if not storyStarted and #getNotBindExternalFunctionNames() > 0 then
            -- first update call before the first continue is called
            -- the external functions are not bound yet
            return
        end

        if isNext('divert') then
            handleDivert()
            return
        end

        if isNext('tunnelreturnto') then
            handleTunnelReturnTo()
            return
        end

        if isNext('choice') then
            handleChoice()
            return
        end

        if isEnd() then
            handleEndOfTree()
            return
        end

        local nodeType = tree[pointer].type
        local updateFn = nodeUpdate[nodeType]
        if not updateFn then
            log.die('unexpected node', tree[pointer])
        end
        local nextStep, nextAddr = updateFn(tree[pointer])
        if nextStep then
            -- 'if' and 'seq' are the only nodeUpdate handlers that emit {outBlockStart} before stepping in
            local inlineFn = nodeType == 'seq' and 'seq-inline' or (nodeType == 'if' and 'inline' or nil)
            -- mark the gather-entry frame so discardGatherContinuations stops here (not at tunnel frames)
            local gatherEntryMarker = nodeType == 'gather' and nextStep or nil
            stepInto(nextStep, nil, inlineFn, nextAddr, gatherEntryMarker)
        else
            next()
        end
        update()
    end

    s.continue = function()
        -- first run
        if not storyStarted then
            local notBind = getNotBindExternalFunctionNames()
            if #notBind > 0 then
                log.dieMissingExternalBindings(getNotBindExternalFunctionNames())
            end
            storyStarted = true
            update() -- first call: process story before popping
        end

        -- flush a deferred error: the previous continue() returned buffered content first
        if pendingDie then
            pendingDie()
        end

        log.debug('out', outputBuffer.buffer)
        -- prePop() captures buffer state and pops any existing line before update() runs.
        -- Must happen first: handleChoice() checks isEmpty() to decide whether to defer choices.
        outputBuffer:prePop()
        if #s.currentChoices == 0 or choicesNeedDrain then
            update() -- advance to next output; skip if choices already populated (unless draining inline frames)
        end
        local result, newCanContinue = outputBuffer:popTurnLine({
            hasChoices = #s.currentChoices > 0,
        })
        s.currentTags = table.remove(tagLines, 1) or {}
        s.canContinue = newCanContinue
        if
            not newCanContinue
            and #s.currentChoices == 0
            and not hadCleanEnd
            and currentKnot
            and lastOutputTokenWithLocation
        then
            local t = lastOutputTokenWithLocation
            pendingDie = function()
                log.dieRanOutOfContent(t)
            end
        end
        if pendingDie then
            -- the caller will get this content first; the error fires on the next continue() call
            s.canContinue = true
        end
        return result .. log.drainCompatWarnings()
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

        turns = turns + 1
        if choice.option.label then
            local knot = choice.threadKnot
            local stitch = choice.threadStitch
            incrementSeenCounter(Path.label(knot, stitch, choice.option.label))
            -- TURNS_SINCE(-> label) uses bare label as the lookup key
            if knot then
                turnAtVisitSet(Path.of(choice.option.label), turns)
            end
        end
        markOptionUsed(choice.option)

        if choice.gather then
            -- choices bypass the gather node dispatch, so increment its label counter here
            if choice.gather.label then
                incrementSeenCounter(Path.label(choice.threadKnot, choice.threadStitch, choice.gather.label))
                -- TURNS_SINCE(-> label) uses bare label as the lookup key
                if choice.threadKnot then
                    turnAtVisitSet(Path.of(choice.gather.label), turns)
                end
            end
            returnToGather(choice.gather.body, bodyAddr(choice.gather))
        end

        returnTo(choice.option.body, bodyAddr(choice.option))
        returnTo(choice.option.bodyOnlyText, bodyOnlyTextAddr(choice.option))
        stepInto(choice.option.sharedStartText, nil, nil, sharedStartTextAddr(choice.option))

        s.currentChoices = {}
        choicesNeedDrain = false
        pendingTags = {}
        lineHadContent = false
        flushOptionTags = true
        outputBuffer:onNewChoice()
        update()
        -- canContinue() returns false when choices are present; force it so continue()
        -- is called to drain pending output or emit a paragraph break before choices.
        if outputBuffer:needsContinue(#s.currentChoices > 0) then
            s.canContinue = true
        end
    end

    s.choosePathString = function(knotName)
        goTo({ knotName })
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
    log.debug('tree: ', tree)
    --log.debug('lists:', listDefinitions)
    --log.debug('external:', externalDefs)
    --log.debug('state:', s.variablesState)

    return s
end
