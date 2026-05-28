local base_path = (...):match('(.-)[^%.]+$')
local node = require(base_path .. 'node')
local is = node.is

-- TODO(save/load): compiled output is the static half; reload from source on restore

return function(globalTree, env, noKnot, listDefinitions)
    local knots = { [noKnot] = {} }
    local externalDefs = {}
    local globalTags = {}
    local lastKnot = noKnot
    local lastStitch = nil
    local nodeById = {} -- [nodeId] = node, for callstack frame reconstruction on save/load
    local nodeIdCounter = 0

    local assignNode, assignIds

    -- Assigns a stable nodeId to every AST node reachable from the given array.
    assignIds = function(nodes)
        if type(nodes) ~= 'table' then
            return
        end
        for _, n in ipairs(nodes) do
            assignNode(n)
        end
    end

    -- Assigns a stable nodeId to a single node and recurses into all child nodes.
    assignNode = function(n)
        if type(n) ~= 'table' or not n.type then
            return
        end
        nodeIdCounter = nodeIdCounter + 1
        n.nodeId = nodeIdCounter
        nodeById[n.nodeId] = n
        -- array fields
        assignIds(n.nodes)
        assignIds(n.body)
        assignIds(n.options)
        assignIds(n.sharedStartText)
        assignIds(n.choiceOnlyText)
        assignIds(n.bodyOnlyText)
        assignIds(n.conditions)
        assignIds(n.args)
        assignIds(n.elements)
        -- single-node expression fields (can contain nested seq/if evaluated via getValue)
        assignNode(n.value)
        assignNode(n.content)
        assignNode(n.expr)
        assignNode(n.gather)
        -- branches: if-style {cond, body} or seq-style plain arrays of nodes
        if n.branches then
            for _, branch in ipairs(n.branches) do
                if branch.body then
                    assignNode(branch.cond)
                    assignIds(branch.body)
                else
                    assignIds(branch)
                end
            end
        end
    end

    assignIds(globalTree)

    local evalVarInit = function(val)
        if is('ref', val) then
            val = env[val.name]
        end
        if is('el', val) then
            return node.listFromEls({ val }, {})
        elseif is('listlit', val) then
            return node.listFromLit(val, function(name)
                return env[name]
            end)
        end
        return val
    end

    local preProcess
    preProcess = function(t)
        -- collect leading global tags at the top of each included tree
        local i = 1
        while t[i] and is('tag', t[i]) do
            table.insert(globalTags, t[i].text)
            i = i + 1
        end

        -- 1st pass: register vars/consts/lists so they can reference each other in any order
        for _, n in ipairs(t) do
            if is('var', n) then
                env[n.name] = n.value
            end
            if is('const', n) then
                env[n.name] = n.value
            end
            if is('listdef', n) then
                listDefinitions.define(n.name, n.elements, env)
            end
        end

        -- 2nd pass: build knots/stitches/labels, register functions
        for p, n in ipairs(t) do
            if is('ink', n) then
                n.nodes = preProcess(n.nodes)
            end
            if is('gather', n) then
                n.body = preProcess(n.body)
            end
            if is('choice', n) then
                n.options = preProcess(n.options)
                if n.gather then
                    n.gather = preProcess({ n.gather })[1]
                end
                -- Link the gather to labeled option knot entries so goTo can set up the
                -- gather continuation when a divert jumps directly to an option label.
                if n.gather then
                    for _, option in ipairs(n.options) do
                        if option.label then
                            local optEntry
                            if lastStitch then
                                optEntry = knots[lastKnot]
                                    and knots[lastKnot][lastStitch]
                                    and knots[lastKnot][lastStitch][option.label]
                            else
                                optEntry = knots[lastKnot] and knots[lastKnot][option.label]
                            end
                            if optEntry then
                                optEntry.gather = n.gather
                            end
                        end
                    end
                end
            end

            if is('knot', n) then
                knots[n.name] = { tree = n.body, params = n.params, nodeId = n.nodeId }
                env[n.name] = node.int(0)
                lastKnot = n.name
                lastStitch = nil
                n.body = preProcess(n.body)
            end
            if is('stitch', n) then
                knots[lastKnot][n.name] = { pointer = p, tree = t, params = n.args }
                if lastKnot ~= noKnot then
                    env[lastKnot]._children = env[lastKnot]._children or {}
                    env[lastKnot]._children[n.name] = node.int(0)
                else
                    env[n.name] = node.int(0)
                end
                lastStitch = n.name
            end
            if is('gather', n) and n.label then
                if lastStitch then
                    knots[lastKnot][lastStitch][n.label] = { pointer = p, tree = t }
                    if lastKnot ~= noKnot then
                        env[lastKnot]._children = env[lastKnot]._children or {}
                        env[lastKnot]._children[lastStitch] = env[lastKnot]._children[lastStitch] or node.int(0)
                        env[lastKnot]._children[lastStitch]._children = env[lastKnot]._children[lastStitch]._children
                            or {}
                        env[lastKnot]._children[lastStitch]._children[n.label] = node.int(0)
                    else
                        env[n.label] = node.int(0)
                    end
                else
                    knots[lastKnot][n.label] = { pointer = p, tree = t }
                    if lastKnot ~= noKnot then
                        env[lastKnot]._children = env[lastKnot]._children or {}
                        env[lastKnot]._children[n.label] = node.int(0)
                    else
                        env[n.label] = node.int(0)
                    end
                end
            end
            if is('option', n) then
                if n.body then
                    n.body = preProcess(n.body)
                end
                if n.label then
                    if lastStitch then
                        knots[lastKnot][lastStitch][n.label] = { pointer = p, tree = t }
                        if lastKnot ~= noKnot then
                            env[lastKnot]._children = env[lastKnot]._children or {}
                            env[lastKnot]._children[lastStitch] = env[lastKnot]._children[lastStitch] or node.int(0)
                            local stitchEntry = env[lastKnot]._children[lastStitch]
                            stitchEntry._children = stitchEntry._children or {}
                            stitchEntry._children[n.label] = node.int(0)
                        else
                            env[n.label] = node.int(0)
                        end
                    else
                        knots[lastKnot][n.label] = { pointer = p, tree = t }
                        if lastKnot ~= noKnot then
                            env[lastKnot]._children = env[lastKnot]._children or {}
                            env[lastKnot]._children[n.label] = node.int(0)
                        else
                            env[n.label] = node.int(0)
                        end
                    end
                end
            end

            if is('fndef', n) then
                -- function declarations can appear after their call sites in source
                table.insert(n.body, node.ret(nil)) -- ensure every function has a return at the end
                local fnVal = node.fn(n.params, n.body)
                fnVal.nodeId = n.nodeId -- for callstack frame reconstruction
                env[n.name] = fnVal
            end

            if is('external', n) then
                -- store signature; binding must happen after story construction but before play
                externalDefs[n.name] = n.params
            end
        end

        -- 3rd pass: resolve var/const initial values (literals or refs to list elements)
        for _, n in ipairs(t) do
            if is('var', n) then
                env[n.name] = evalVarInit(n.value)
            end
            if is('const', n) then
                env[n.name] = evalVarInit(n.value)
            end
        end

        return t
    end

    preProcess(globalTree)

    return {
        knots = knots,
        nodeById = nodeById,
        externalDefs = externalDefs,
        globalTags = globalTags,
    }
end
