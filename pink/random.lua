-- Park-Miller LCG (Linear Congruential Generator).
-- Not cryptographic, but deterministic and portable across all Lua versions —
-- suitable for games and interactive stories.
--
-- state_{n+1} = (16807 * state_n) mod 2147483647
-- m = 2147483647 (Mersenne prime 2^31-1), a = 16807 (primitive root of m)
-- Cycle length: 2147483646 (all non-zero 31-bit states).
-- Safe with Lua doubles: max intermediate value 16807*(m-1) ≈ 3.6e13 < 2^53.

local M = 2147483647
local A = 16807
local state = 1

local random = {}

random.seed = function(n)
    n = math.floor(math.abs(n))
    state = (n % (M - 1)) + 1 -- maps any input to 1..M-1
end

random.int = function(minInclusive, maxInclusive)
    state = (A * state) % M
    return minInclusive + math.floor((state / M) * (maxInclusive - minInclusive + 1))
end

return random
