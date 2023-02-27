local debug = function(x) print( require('test/luaunit').prettystr(x) ) end

local is = function (what, node)
    return node ~= nil
    and (type(node) == "table" and node[1] == what)
end

return function (tree)
    local s = {
        globalTags = {},
        state = {
            visitCount = {},
        }
    }

    local pointer = 1
    local knots = {}
    local tags = {} -- maps (pointer to para) -> (list of tags)
    local tagsForContentAtPath = {}
    local currentChoicesPointers = {}

    -- TODO state should contain tree/pointer to be able to save / load

    local preProcess = function ()

        local aboveTags = {}
        local lastPara = {}
        local lastKnotName

        for p, n in ipairs(tree) do
            if is('knot', n) then -- FIXME stitches
                knots[n[2]] = p
                --print(v[2],k)
            end

            --  if is('tag', n) then
            --if n[2] == 'global' then 
            --      table.insert(s.globalTags, n[3])
            --    end
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
                lastPara = p
            end

        end
    end

    local goToKnot = function(knotName)
        if knots[knotName] then
            s.state.visitCount[knotName] = s.state.visitCountAtPathString(knotName) + 1
            pointer = knots[knotName] + 1 -- go to the line after the knot
        else
            print('unknown knot', knotName)
        end
    end

    local isNext = function (what)
        return is(what, tree[pointer])
    end

    local getPara = function ()
        if isNext('para') then return tree[pointer][2] end
    end

    local update
    update = function ()

        if isNext('knot') then
            -- FIXME: we shouldn't continue to next knot automatically probably - how about stitches?
            --next = goToKnot(next[2])
        end

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

        s.canContinue = isNext('para')

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

    local step = function ()
    end

    s.canContinue = nil

    s.continue = function()

        local res = getPara()
        s.currentTags = tags[pointer] or {}

        pointer = pointer + 1
        update()

        if isNext('glue') then
            pointer = pointer + 1
            update()
            res = res .. s.continue()
        end

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

    return s
end
