local _debug = function(x) print( require('test/luaunit').prettystr(x) ) end

local is = function (what, node)
    return node ~= nil
        and (type(node) == "table" and node[1] == what)
end

return function (tree)
    local s = {
        globalTags = {},
        state = {
            visitCount = {},
        },
        variables = {
            FLOOR=math.floor,
            CEILING=math.ceil,
            INT=function(a) if tonumber(a)>0 then return math.floor(a) else return math.ceil(a) end end, -- FIXME
            ['+']=function(a,b) return a+b end,
            ['-']=function(a,b) return a-b end,
            ['*']=function(a,b) return a*b end,
            ['/']=function(a,b) return a/b end, -- FIXME integer division on integers
            ['==']=function(a,b) return a==b end, -- FIXME type coercion
        }
    }

    local pointer = 1
    local knots = {}
    local tags = {} -- maps (pointer to para) -> (list of tags)
    local tagsForContentAtPath = {}
    local currentChoicesPointers = {}

    -- TODO state should contain tree/pointer to be able to save / load



    local goToKnot = function(knotName)
        if knots[knotName] then
            s.state.visitCount[knotName] = s.state.visitCountAtPathString(knotName) + 1
            pointer = knots[knotName] + 1 -- go to the line after the knot
        else
            -- print('unknown knot', knotName) -- TODO check at compile time?
            pointer = #tree + 1 -- end
        end
    end

    local isNext = function (what)
        return is(what, tree[pointer])
    end

    local getValue
    getValue=function(val)
        -- _debug(val, val[2])
        if val[1] == 'ref' then
            local name = val[2]
            local var = s.variables[name]
            if var == nil then
                -- TODO log code location, need info from parser
                -- FIXME detect on compile time
                error('unresolved variable: ' .. name)
            end
            return getValue(var)

        elseif val[1] == 'str' or val[1] == 'int' or val[1] == 'float' then
            return val[2]

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

            local fn = s.variables[name]
            if fn == nil then
                -- TODO log code location, need info from parser
                -- FIXME detect on compile time
                error('unresolved function: ' .. name)
            end
            local arguments = {}
            for i=3, #val do
                table.insert(arguments, getValue(val[i]))
            end
            local returnValue = fn(table.unpack(arguments))
            return returnValue

        else
            error('unsupported value type: '..val[1])
        end
    end



    local update
    update = function ()

        -- if isNext('knot') then
        -- FIXME: we shouldn't continue to next knot automatically probably - how about stitches?
        --next = goToKnot(next[2])
        -- end

        if isNext('divert') then
            goToKnot(tree[pointer][2])
            update()
            return
        end

        if isNext('tag') then
            pointer = pointer + 1
            update()
            return
        end

        if isNext('var') then
            s.variables[tree[pointer][2]] = tree[pointer][3]
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

        if isNext('const') then
            s.variables[tree[pointer][2]] = tree[pointer][3] -- TODO const
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


        s.canContinue = isNext('para') or isNext('alt') or isNext('if') or isNext('call')-- FIXME

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
        local lastKnotName

        for p, n in ipairs(tree) do
            if is('knot', n) then -- FIXME stitches
                knots[n[2]] = p
                --print(v[2],k)
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

            if is('knot', n) or is('stitch', n) then
                lastKnotName = n[2]
                tagsForContentAtPath[lastKnotName] = {}
            end

            if is('para', n) then
                tags[p] = aboveTags
                aboveTags = {}
                -- lastPara = p
            end

        end
    end

    s.canContinue = nil


    local isTruthy = function(a)
        return not not a
    end
    s.continue = function()

        local res = ''
        if isNext('para') then
            res = tree[pointer][2]
            pointer = pointer + 1
            update()
            res = res .. s.continue()
        elseif isNext('alt') then
            res = getValue(tree[pointer][2])
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
        elseif isNext('glue') then
            pointer = pointer + 1
            update()
            res = res .. s.continue()
        end

        s.currentTags = tags[pointer] or {}
        return res;
    end

    s.currentChoices = {}

    s.chooseChoiceIndex = function(index)
        pointer = currentChoicesPointers[index]+1
        update()
    end

    s.choosePathString = function(knotName)
        goToKnot(knotName)
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
    --debug(tree)
    --debug(tags)

    -- debug
    s._tree = tree

    update()

    --_debug(s)
    return s
end
