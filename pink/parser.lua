local lpeg = require "lpeg"
lpeg.locale(lpeg)
local S,C,Ct,Cc,Cg,Cb,Cf,Cmt,P,V =
  lpeg.S, lpeg.C, lpeg.Ct, lpeg.Cc, lpeg.Cg, lpeg.Cb, lpeg.Cf, lpeg.Cmt,
  lpeg.P, lpeg.V

local eof = -1
local sp = S" \t" ^0 + eof
local wh = S" \t\r\n" ^0 + eof
local nl = S"\r\n" ^1 + eof
local id = (lpeg.alpha + '_') * (lpeg.alnum + '_')^0
local addr = C(id) * ('.' * C(id))^-1

local todo = Ct(sp * 'TODO:'/"todo" * sp * C((1-nl)^0)) * wh
local commOL = Ct(sp * '//'/"comment" * sp * C((1-nl)^0)) * wh
local commML = Ct(sp * '/*'/"comment" * wh * C((P(1)-'*/')^0)) * '*/' * wh
local comm = commOL + commML + todo

local glue = Ct(P'<>'/'glue') *wh -- FIXME do not consume spaces after glue

local divertSym = '->' *wh
local divertEnd = Ct(divertSym/'end' * 'END' * wh)
local divertJump = Ct(divertSym/'divert' * addr * wh)
local divert = divertEnd + divertJump

local knot = Ct(P('=')^2/'knot' * wh * C(id) * wh * P('=')^0) * wh
local stitch = Ct(P('=')^1/'stitch' * wh * C(id) * wh * P('=')^0) * wh

local optDiv = '[' * C((P(1) - ']')^0) * ']'

local optStars = wh * Ct(C'*' * (sp * C'*')^0)/table.getn

local tag = Ct(wh * P('#')/'tag' * wh * V'text' * wh)



local ink = P({
 "lines",

 stmt = glue + divert + knot + stitch + V'option' + optDiv + comm + V'include' + tag,
 text = C((1-nl-V'stmt')^1) *wh,
 textE = C((1-nl-V'stmt')^0) *wh,

 optAnsWithDiv    = V'textE' * optDiv * V'textE' * wh,
 optAnsWithoutDiv = V'textE' * Cc ''* Cc ''* wh, -- huh?
 optAns = V'optAnsWithDiv' + V'optAnsWithoutDiv',

 option = Ct(Cc'option' * optStars * sp * V'optAns'),




 include = Ct(P('INCLUDE')/'include' * wh * V'text' * wh),

 para = Ct(Cc'para' * V'text'),

 line = V'stmt' + V'para',
 lines = Ct(V'line'^0)
})


return ink;
