local base_path = (...):match('(.-)[^%.]+$')
local node = require(base_path .. 'node')
return function()
    local listDefinitions = {}

    listDefinitions.define = function(listName, elDefs, env)
        local elements = {}
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
            env[listName .. '.' .. elName] = node.el(listName, elName) -- always available as qualified name
            -- TODO do we need both
            listDefinitions[listName].byName[elName] = elValue
            listDefinitions[listName].byValue[elValue] = elName
            if elSet then
                table.insert(elements, el)
            end
        end
        env[listName] = node.listFromEls(elements, { listName })
    end

    return listDefinitions
end
