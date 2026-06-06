local base_path = (...):match('(.-)[^%.]+$')
local node = require(base_path .. 'node')
return function()
    local listDefinitions = {}

    listDefinitions.define = function(listName, elDefs, env)
        local elements = {}
        local children = {}
        listDefinitions[listName] = { byName = {}, byValue = {} }
        for _, elDef in pairs(elDefs) do
            local elName, elSet, elValue = elDef.name, elDef.set, elDef.value
            local el = node.el(listName, elName)
            if env[elName] == nil then
                env[elName] = el
            else
                -- multiple lists have an element with the same name: unqualified name is ambiguous
                env[elName].listName = nil
            end
            -- fresh node so ambiguity mutations on env[elName] don't affect _children
            children[elName] = node.el(listName, elName)
            listDefinitions[listName].byName[elName] = elValue
            listDefinitions[listName].byValue[elValue] = elName
            if elSet then
                table.insert(elements, el)
            end
        end
        local listNode = node.listFromEls(elements, { listName })
        listNode._children = children
        env[listName] = listNode
    end

    return listDefinitions
end
