require "util"
local lpeg = require "lpeg"
local S,C,P = lpeg.S, lpeg.C, lpeg.P

local parserLogger = print

local function prefix(pref, p)
  return p / function(i)
    return pref..": "..i
  end
end

local sp = S" \t" ^0
local wh = S" \t\r\n" ^0
local nl = S"\r\n" ^1
local ch = P(1)

local todo = 'TODO:' * sp * (ch-nl)^0 / parserLogger -- TODO log location
local commOL = '//' * sp * (ch-nl)^0 -- TODO comment that does not start at the line beginning
local commML = '/*' * wh * (ch-'*/')^0 * '*/'
local comm = commOL + commML + todo

local para = (C((ch-nl)^1) *nl^0)-comm

local choiceAnswer = '*' * sp * prefix("CHOICE", para)
local choiceBlock = choiceAnswer * lpeg.Ct( (para- choiceAnswer)^0)
local choices = lpeg.Ct(choiceBlock^1)

local statement = wh * (comm + choices + para) * wh

local prog = ((wh * lpeg.Ct((statement*wh)^0)) )* -1

local ink = prog

test(ink, 'content')
test(ink, 'choices')
