local luaunit = require('test.lib.luaunit')
local pink = require('pink.pink')

function testExternal()
    local story = pink('test/external.ink')
    luaunit.assertTrue(story.canContinue)
    luaunit.assertErrorMsgContains('ext', function()
        story.continue()
    end)
    luaunit.assertErrorMsgContains('ext2', function()
        story.continue()
    end)
    local called = false
    story.bindExternalFunction('ext', function()
        called = true
    end)
    story.bindExternalFunction('ext2', function() end)

    -- update called automatically in bind, is that ok?
    luaunit.assertTrue(story.canContinue)
    luaunit.assertEquals(story.continue(), 'Hello\n')

    luaunit.assertTrue(called)
    -- TODO test parameters and return values
    luaunit.assertError(function()
        story.bindExternalFunction('undefined', function() end)
    end)
end
