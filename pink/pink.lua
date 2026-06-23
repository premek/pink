local base_path = (...):match('(.-)[^%.]+$')
local runtime = require(base_path .. 'runtime')
local resolveIncludes = require(base_path .. 'includes')

return function(filename)
    local nodes = resolveIncludes(filename) -- TODO rename
    return runtime(nodes)
end
