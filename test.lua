local luaunit = require('luaunit')
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

function testOpt1() doTestS(
 '*   "I am somewhat tired[."]," I repeated.',
 {{'choice', {"option", '"I am somewhat tired', '."', '," I repeated.'}}}
) end


function testBasic() doTest('basic') end
function testChoices() doTest('choices') end
function testNest() doTest('nested') end
function testNest2() doTest('nested2') end
function testKnot() doTest('knot') end
function testBranching() doTest('branching') end
function testGlue() doTest('glue') end
function testInclude() doTest('include') end


--- runtime ---

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
