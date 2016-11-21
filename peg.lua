require "util"
local lpeg = require "lpeg"

local function node(p)
  return p / function(left, op, right)
    return { op, left, right }
  end
end

local sp = lpeg.S" \t" ^0
local wh = lpeg.S" \t\r\n" ^0
local nl = lpeg.S"\r\n" ^1

local textLine = (lpeg.P(1)-nl)^1
local para = lpeg.C(textLine)

--local id = lpeg.R("az", "AZ")^1 * sp)^1


local commOL = '//' * sp * lpeg.C((lpeg.P(1)-nl)^0) -- TODO comment that does not start at the line beginning
local commML = '/*' * wh * lpeg.C((lpeg.P(1)-'*/')^0) * '*/'
local comm = (commOL + commML) / function (i) return "comment:"..i; end

local line = wh * (comm + para) * wh

local prog = ((wh * lpeg.Ct((line*wh)^0)) )* -1

local ink = prog
print(to_string(ink:match(" asd\naa")))
print(to_string(ink:match(" // asd a\ta\naa")))
print(to_string(ink:match("/* \tas \n\n \tda\n */")))

print(to_string(ink:match("// \n \tsome text\n// and some comment\n\n\t\n")))
print(to_string(ink:match(" \n \t/* \ndemment \n\t comment\n\n\t  */ \n")))
print(to_string(ink:match("  \t\t \t ")))
print(to_string(ink:match("\n\n  \t\n\t \t \n")))

print(to_string(ink:match("hello\nworld\n//comme nt\ntest\n/*demm*/")))
print(to_string(ink:match(" \nFc oh\n")))
print(to_string(ink:match(" \nF\tc \n ooo")))
print(to_string(ink:match("\"What do you make of this?\" she asked. \n\n// Something unprintable...\n\n\"I couldn't possibly comment,\" I replied.\n/*\n    ... or an unlimited block of text\n*/")))
