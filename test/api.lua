#!/usr/bin/env lua

local luaunit = require('test.lib.luaunit')
local pink = require('pink.pink')

require('test.external')

function testBasic()
    local story = pink('test/hello.ink')
    luaunit.assertEquals(story.continue(), 'hello world\n')
    luaunit.assertFalse(story.canContinue)
end

function testOutputEachLineSeparately()
    local story = pink('test/twolines.ink')
    luaunit.assertEquals(story.continue(), 'hello\n')
    luaunit.assertEquals(story.continue(), 'world\n')
    luaunit.assertFalse(story.canContinue)
end

function testRVisitCount()
    local story = pink('test/branching.ink')
    luaunit.assertEquals(story.state.visitCountAtPathString('as_fast_as_we_could'), 0)
    story.choosePathString('hurry_outside')
    while story.canContinue do
        story.continue()
    end
    luaunit.assertEquals(story.state.visitCountAtPathString('as_fast_as_we_could'), 1)
    story.choosePathString('hurry_outside')
    while story.canContinue do
        story.continue()
    end
    luaunit.assertEquals(story.state.visitCountAtPathString('as_fast_as_we_could'), 2)
end

function testRInclude()
    --local story = pink('test/include.ink')
    --luaunit.assertEquals(story.continue(), 'hello world')
    --luaunit.assertEquals(story.continue(), 'hello again')
    --luaunit.assertFalse(story.canContinue)
end

function testAbsoluteIncludePath()
    local deepPath = os.tmpname() .. '.ink'
    local midPath = os.tmpname() .. '.ink'
    local mainPath = os.tmpname() .. '.ink'
    local f = io.open(deepPath, 'w')
    f:write('deep\n')
    f:close()
    f = io.open(midPath, 'w')
    f:write('INCLUDE ' .. deepPath .. '\nmid\n')
    f:close()
    f = io.open(mainPath, 'w')
    f:write('INCLUDE ' .. midPath .. '\nmain\n')
    f:close()
    local ok, result = pcall(function()
        local story = pink(mainPath)
        luaunit.assertEquals(story.continue(), 'deep\n')
        luaunit.assertEquals(story.continue(), 'mid\n')
        luaunit.assertEquals(story.continue(), 'main\n')
    end)
    os.remove(deepPath)
    os.remove(midPath)
    os.remove(mainPath)
    if not ok then
        error(result)
    end
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

function testTwoSimultaneousStories()
    local s1 = pink('test/twolines.ink')
    local s2 = pink('test/twolines.ink')
    luaunit.assertEquals(s1.continue(), 'hello\n')
    luaunit.assertEquals(s2.continue(), 'hello\n')
    luaunit.assertEquals(s1.continue(), 'world\n')
    luaunit.assertEquals(s2.continue(), 'world\n')
end

function testTwoStoriesWithLists()
    local s1 = pink('test/list_red.ink')
    local s2 = pink('test/list_blue.ink')
    luaunit.assertEquals(s1.continue(), 'red, green\n')
    luaunit.assertEquals(s2.continue(), 'blue, yellow\n')
end

-----------------------------

os.exit(luaunit.LuaUnit.run())
