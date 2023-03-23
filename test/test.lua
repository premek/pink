#!/usr/bin/env lua

local luaunit = require('test.luaunit')
local parser = require('pink.parser')
local runtime = require('pink.runtime')
local pink = require('pink.pink')


--- parser ---


function testEmpty() doTest('empty') end
function testBasic() doTest('basic') end
function testComments() doTest('comments') end
function testChoices() doTest('choices') end
function testNest() doTest('nested') end
function testNest2() doTest('nested2') end
function testKnot() doTest('knot') end
function testBranching() doTest('branching') end
function testGlue() doTest('glue') end
function testInclude() doTest('include') end
function testTags() doTest('tags') end
function testGather() doTest('gather') end


--- runtime ---

function testRBasic()
  local story = pink.getStory('test/runtime/hello.ink')
  luaunit.assertEquals(story.continue(), 'hello world')
  luaunit.assertFalse(story.canContinue)
end


function testRChoices()
  local story = pink.getStory('test/runtime/branching.ink')
  story.choosePathString('back_in_london');
  story.continue()
  luaunit.assertEquals(story.continue(), 'exactly')
  luaunit.assertFalse(story.canContinue)
  luaunit.assertEquals(#story.currentChoices, 3)
  story.chooseChoiceIndex(2)
  luaunit.assertEquals(story.continue(), 'My master clouted me firmly around the head')
  luaunit.assertEquals(#story.currentChoices, 2)
  story.chooseChoiceIndex(2)
  luaunit.assertEquals(story.continue(), 'huhu')
  luaunit.assertFalse(story.canContinue)
end


function testRVisitCount()
  local story = pink.getStory('test/runtime/branching.ink')
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
  local story = pink.getStory('test/runtime/include.ink')
  luaunit.assertEquals(story.continue(), 'hello world')
  luaunit.assertEquals(story.continue(), 'hello again')
  luaunit.assertFalse(story.canContinue)
end

function testRTags()
    -- TODO
  local story = pink.getStory('test/runtime/tags.ink')
  luaunit.assertEquals(story.globalTags, {"author: Joseph Humfrey", "title: My Wonderful Ink Story"})
  story.choosePathString('content');
  luaunit.assertEquals(story.continue(), 'This is the line of content. ')
  --luaunit.assertEquals(story.currentTags, {"the first tag", "the second tag", "the third tag"})
  story.continue()
  --luaunit.assertEquals(story.currentTags, {"not this one"})
  luaunit.assertFalse(story.canContinue)
  --luaunit.assertEquals(story.tagsForContentAtPath('Munich'), {"location: Germany", "overview: munich.ogg", "require: Train ticket"})
end

function testRInvisibleDiverts()
  local story = pink.getStory('test/runtime/branching.ink')
  story.choosePathString('hurry_outside')
  luaunit.assertEquals(story.continue(), "We hurried home to Savile Row as fast as we could.")
end


-----------------------------

function doTest(name)
  local test = require ('test.parser.'..name)
  local parsed = parser(test.ink, 'test.parser.'..name..'.ink')
  luaunit.assertEquals(parsed, test.expected)
end

os.exit( luaunit.LuaUnit.run() )
