local luaunit = require('luaunit')
local parser = require('pink.parser')


function testEmpt() doTestS(
 "",
 {}
) end

function testText() doTestS(
 "Hello world",
 {{"para", "Hello world"}}
) end

function testOptS() doTestS(
 '*   "I am somewhat tired[."]," I repeated.',
 {{"option", '"I am somewhat tired', '."', '," I repeated.'}}
) end

function testBasic() doTest('basic') end
function testChoices() doTest('choices') end



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
