local luaunit = require('test.luaunit')
local parser = require('pink.parser')
local runtime = require('pink.runtime')
local pink = require('pink.pink')

--- parser ---

function testEmpt() doTestS(
 "",
 {}
) end

function testText() doTestS(
 "Hello world",
 {{"para", "Hello world"}}
) end



function testBasic() doTest('basic') end
function testComments() doTest('comments') end
function testChoices() doTest('choices') end
function testNest() doTest('nested') end
function testNest2() doTest('nested2') end
function testKnot() doTest('knot') end
function testBranching() doTest('branching') end
function testGlue() doTest('glue') end
function testInclude() doTest('include') end
function testTagsP() doTest('tags') end


--- runtime ---

function testBasicR()
  local story = pink.getStory('test/runtime/hello.ink')
  luaunit.assertEquals(story.continue(), 'hello world')
  luaunit.assertFalse(story.canContinue)
end


function testVisitCount()
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

function testIncludeR()
  local story = pink.getStory('test/runtime/include.ink')
  luaunit.assertEquals(story.continue(), 'hello world')
  luaunit.assertEquals(story.continue(), 'hello again')
  luaunit.assertFalse(story.canContinue)
end

function testTags()
  local story = pink.getStory('test/runtime/tags.ink')
  luaunit.assertEquals(story.continue(), '')
  luaunit.assertEquals(story.continue(), '')
  luaunit.assertEquals(story.globalTags, {""})
  luaunit.assertFalse(story.canContinue)
end

function testInvisibleDiverts()
  local story = pink.getStory('test/runtime/branching.ink')
  story.choosePathString('hurry_outside')
  luaunit.assertEquals(story.continue(), "We hurried home to Savile Row as fast as we could.")
end


-- TODO test runtime more, test public pink API

function testCLI()
  -- note the different suffixes
  os.execute("lua pink/pink.lua parse test/runtime/include.ink > tmp_test.lua")
  local story = pink.getStory('tmp_test.ink')
  luaunit.assertEquals(story.continue(), 'hello world')
  luaunit.assertEquals(story.continue(), 'hello again')
  luaunit.assertFalse(story.canContinue)
  os.remove('tmp_test.lua')
end
-----------------------------

function doTestS(ink, expected)
    luaunit.assertEquals(parser:match(ink), expected)
end

function doTest(name)
  local test = require ('test.parser.'..name)
  local parsed = parser:match(test.ink)
  luaunit.assertEquals(parsed, test.expected)
end

os.exit( luaunit.LuaUnit.run() )
