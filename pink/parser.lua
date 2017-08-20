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

local optStar = sp * C'*'
local optStars = wh * Ct(optStar * optStar^0)/table.getn
local gatherMark = sp * C'-'
local gatherMarks = wh * Ct(gatherMark * gatherMark^0)/table.getn

local hash = P('#')
local tag = hash * wh * V'text'
local tagGlobal = Ct(Cc'tag' * Cc'global' * tag * wh)
local tagAbove = Ct(Cc'tag' * Cc'above' * tag * wh)
local tagEnd = Ct(Cc'tag' * Cc'end' * tag * sp)

local ink = P({
 "lines",

 stmt = glue + divert + knot + stitch + V'option' + optDiv + comm + V'include',
 text = C((1-nl-V'stmt'-hash)^1),
 textEmptyCapt = C((1-nl-V'stmt'-hash)^0),

 optAnsWithDiv    = V'textEmptyCapt' * sp * optDiv * V'text'^0 * wh,
 optAnsWithoutDiv = V'textEmptyCapt' * sp * Cc ''  * Cc ''     * wh, -- huh?
 optAns = V'optAnsWithDiv' + V'optAnsWithoutDiv',

 option = Ct(Cc'option' * optStars * sp * V'optAns'),
 gather = Ct(Cc'gather' * gatherMarks * sp * V'text'),




 include = Ct(P('INCLUDE')/'include' * wh * V'text' * wh),

 para = tagAbove^0 * Ct(Cc'para' * V'text') * tagEnd^0 * wh  +  tagGlobal,

 line = V'stmt' + V'gather'+ V'para' ,
 lines = Ct(V'line'^0)
})


return ink;
