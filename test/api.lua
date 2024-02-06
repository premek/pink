#!/usr/bin/env lua

local luaunit = require('test.luaunit')
local pink = require('pink.pink')

function testBasic()
    local story = pink('test/hello.ink')
    luaunit.assertEquals(story.continue(), 'hello world')
    luaunit.assertFalse(story.canContinue)
end

function testInvalidKnot()
    local story = pink('test/branching.ink')
    luaunit.assertErrorMsgContains('unknown path: nonexistent', function()
        story.choosePathString('nonexistent');
    end)
end


function testRVisitCount()
    local story = pink('test/branching.ink')
    story.choosePathString('hurry_outside');
    luaunit.assertEquals(story.state.visitCountAtPathString('as_fast_as_we_could'), 0)
    while story.canContinue do story.continue() end
    luaunit.assertEquals(story.state.visitCountAtPathString('as_fast_as_we_could'), 1)
    story.choosePathString('hurry_outside');
    while story.canContinue do story.continue() end
    luaunit.assertEquals(story.state.visitCountAtPathString('as_fast_as_we_could'), 2)
    luaunit.assertEquals(story.state.visitCountAtPathString('as_fast_as_we_could'), 2)
end

function testRInclude()
    local story = pink('test/include.ink')
    luaunit.assertEquals(story.continue(), 'hello world')
    luaunit.assertEquals(story.continue(), 'hello again')
    luaunit.assertFalse(story.canContinue)
end

function testRTags()
--local story = pink('test/tags.ink')
--luaunit.assertEquals(story.globalTags, {"author: Joseph Humfrey", "title: My Wonderful Ink Story"})
--luaunit.assertEquals(story.continue(), 'This is the line of content. ')
--luaunit.assertEquals(story.currentTags, {"the first tag", "the second tag", "the third tag"})
--story.continue()
--luaunit.assertEquals(story.currentTags, {"not this one"})
--luaunit.assertFalse(story.canContinue)
--luaunit.assertEquals(story.tagsForContentAtPath('Munich'),
--{"location: Germany", "overview: munich.ogg", "require: Train ticket"})
end


-----------------------------

os.exit( luaunit.LuaUnit.run() )
