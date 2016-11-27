require "util"
local lpeg = require "lpeg"
lpeg.locale(lpeg)
local S,C,Ct,P = lpeg.S, lpeg.C, lpeg.Ct, lpeg.P
local parserLogger = print

local sp = S" \t" ^0 + -1
local wh = S" \t\r\n" ^0 + -1
local nl = S"\r\n" ^1 + -1
local id = (lpeg.alpha + '_') * (lpeg.alnum + '_')^0

local todo = sp * 'TODO:' * sp * (1-nl)^0 / parserLogger * wh -- TODO log location
local commOL = sp * '//' * sp * (1-nl)^0 * wh -- TODO comment that does not start at the line beginning
local commML = sp * '/*' * wh * (P(1)-'*/')^0 * '*/' * wh
local comm = commOL + commML + todo
local para = C(((1-nl-'*') * (1-nl)^1)) *wh -- hm

local knot = P('=')^2 * wh * C(id) * wh * P('=')^0 * wh
local choiceAnswer = '*' * sp * para/"CHOICE: %1"
local choiceBlock = Ct(choiceAnswer * para^0)
local choices = Ct(choiceBlock^1)
--local statement =  * (comm + choices + para) *n
--local prog = ((n * lpeg.Ct((statement*n)^0)) )* -1
--local ink = prog

--test(ink, 'content')
test(choices, 'choices')
--r=choices:match('*ans\nsss\nsss\n*second\n*second\n*second')
--print (to_string( (r)))
--tprint(r)
