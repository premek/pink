local luaunit = require('luaunit')
local parser = require('peg')


function testText() doTestS("Hello world", {{"para", "Hello world"}}) end
function testDev() doTest('dev') end



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

