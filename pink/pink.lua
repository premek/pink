local base_path = (...):match('(.-)[^%.]+$')
local runtime = require(base_path .. 'runtime')
local load = require(base_path .. 'loader')

return function(filename)
    local nodes = load(filename)
    return runtime(nodes)
end
