#!/usr/bin/env lua

local luaunit = require('test.lib.luaunit')
local random = require('pink.random')

function testDeterministic()
    random.seed(42)
    local a = random.int(1, 1000)
    local b = random.int(1, 1000)
    random.seed(42)
    luaunit.assertEquals(random.int(1, 1000), a)
    luaunit.assertEquals(random.int(1, 1000), b)
end

function testRange()
    random.seed(1)
    for _ = 1, 1000 do
        local v = random.int(3, 7)
        luaunit.assertTrue(v >= 3 and v <= 7)
    end
end

function testMinEqualsMax()
    random.seed(1)
    luaunit.assertEquals(random.int(7, 7), 7)
    luaunit.assertEquals(random.int(7, 7), 7)
end

function testDifferentSeeds()
    random.seed(1)
    local a = random.int(1, 1000000)
    random.seed(2)
    local b = random.int(1, 1000000)
    luaunit.assertNotEquals(a, b)
end

function testKnownValues()
    -- precomputed: seed(1) → state=16807; each call advances the LCG
    random.seed(1)
    luaunit.assertEquals(random.int(1, 10), 1)
    luaunit.assertEquals(random.int(1, 10), 3)
    luaunit.assertEquals(random.int(1, 10), 6)
    luaunit.assertEquals(random.int(1, 10), 10)
    luaunit.assertEquals(random.int(1, 10), 1)
end

function testSeedZero()
    random.seed(0)
    local v = random.int(1, 10)
    luaunit.assertTrue(v >= 1 and v <= 10)
end

function testSeedNegative()
    random.seed(-5)
    -- negative seed treated as abs(-5)=5, same as seed(5)
    local v1 = random.int(1, 10)
    random.seed(5)
    local v2 = random.int(1, 10)
    luaunit.assertEquals(v1, v2)
end

os.exit(luaunit.LuaUnit.run())
