-- usage:
-- local debug = require('debug')
-- debug.enabled = true
-- debug(foo, bar, {foo=bar}
-- note: every time it's required the same instance is used, so the enabled flag is shared

local dump = require('test/lib/luaunit').prettystr

local debug = {
    enabled = false,

    __call = function(self, ...)
        if not self.enabled then return end
        local args = {...}
        if #args == 0 then
            print('(nil)')
        end
        for _, x in ipairs(args) do
            print(dump(x))
        end
    end
}

setmetatable(debug, debug)
return debug
