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
local ch = lpeg.P(1)

local para = lpeg.C((ch-nl)^1) *nl^0

local commOL = '//' * sp * (ch-nl)^0 -- TODO comment that does not start at the line beginning
local commML = '/*' * wh * (ch-'*/')^0 * '*/'
local comm = commOL + commML

local choiceAnswer = '*'* sp * para
local flowBlock = para -choiceAnswer
local choice = choiceAnswer * (flowBlock)^1
local choices = lpeg.Ct(choice^1)

local statement = wh * (comm + choices + para) * wh

local prog = ((wh * lpeg.Ct((statement*wh)^0)) )* -1

local ink = prog

test(ink, 'content')
test(ink, 'choices')
