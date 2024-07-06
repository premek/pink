local luaunit = require('test.lib.luaunit')
local pink = require('pink.pink')

function testExternal()
    local story = pink('test/external.ink')

    luaunit.assertError(function() story.continue() end)
    local called = false
    story.bindExternalFunction("ext", function() called = true end)
    story.continue()
    luaunit.assertTrue(called)
    -- TODO test parameters and return values
    luaunit.assertError(function() story.bindExternalFunction("undefined", function() end) end)
end

