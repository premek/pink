local base_path = (...):match('(.-)[^%.]+$')
local parser = require(base_path .. 'parser')

local resolveIncludes
resolveIncludes = function(nodes, dir, reader)
    local result = {}
    for _, t in ipairs(nodes) do
        if t.type == 'include' then
            local includedNodes = parser(reader(dir .. '/' .. t.filename), t.filename)
            for _, includedNode in ipairs(resolveIncludes(includedNodes, dir, reader)) do
                table.insert(result, includedNode)
            end
        elseif t.nodes then
            t.nodes = resolveIncludes(t.nodes, dir, reader)
            table.insert(result, t)
        else
            table.insert(result, t)
        end
    end
    return result
end

return resolveIncludes
