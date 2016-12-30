local luaunit = require('luaunit')
local parser = require('pink.parser')
local pink = require('pink.pink')


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


function testVisitCount()
  local story = pink.getStory('test/branching.lua')
  story.choosePathString('hurry_outside');
  luaunit.assertEquals(story.state.visitCountAtPathString('as_fast_as_we_could'), 0)
  while story.canContinue do story.continue() end
  luaunit.assertEquals(story.state.visitCountAtPathString('as_fast_as_we_could'), 1)
  story.choosePathString('hurry_outside');
  while story.canContinue do story.continue() end
  luaunit.assertEquals(story.state.visitCountAtPathString('as_fast_as_we_could'), 2)
  luaunit.assertEquals(story.state.visitCountAtPathString('as_fast_as_we_could'), 2)
end


-- TODO test runtime more, test public pink API

-----------------------------

function doTestS(ink, expected)
    luaunit.assertEquals(parser:match(ink), expected)
end

function doTest(name)
  local test = require ('test.'..name)
  local parsed = parser:match(test.ink)
  luaunit.assertEquals(parsed, test.expected)
end

os.exit( luaunit.LuaUnit.run() )
