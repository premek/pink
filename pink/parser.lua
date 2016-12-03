require "util"
local lpeg = require "lpeg"
lpeg.locale(lpeg)
local S,C,Ct,Cc,Cg,Cf,P,V = lpeg.S, lpeg.C, lpeg.Ct, lpeg.Cc, lpeg.Cg, lpeg.Cf, lpeg.P, lpeg.V
local parserLogger = print

local sp = S" \t" ^0 + -1
local wh = S" \t\r\n" ^0 + -1
local nl = S"\r\n" ^1 + -1
local id = (lpeg.alpha + '_') * (lpeg.alnum + '_')^0
local addr = C(id) * ('.' * C(id))^-1

local todo = sp * 'TODO:' * sp * (1-nl)^0 / parserLogger * wh -- TODO log location
local commOL = sp * '//' * sp * (1-nl)^0 * wh
local commML = sp * '/*' * wh * (P(1)-'*/')^0 * '*/' * wh
local comm = commOL + commML + todo

local glue = P('<>')/'glue' *wh

local divertSym = '->' *wh
local divertEndSym = C('END') *wh
local divertEnd = divertSym * divertEndSym
local divertJump = Ct(divertSym/'divert' * addr * wh)
local divert = divertEnd + divertJump

local knotHead = P('=')^2/'knot' * wh * C(id) * wh * P('=')^0 * wh
local stitchHead = P('=')^1/'stitch' * wh * C(id) * wh * P('=')^0 * wh

local optionDiv = '[' * C((P(1) - ']')^0) * ']'

local ink = P({
 "lines",

 knott = Ct(knotHead * (V'line'-knotHead)^0 * wh),
 stitch = Ct(stitchHead * (V'line'-stitchHead)^0 * wh),

 stmt = glue + divert + V'knott' + V'stitch' + optionDiv + comm,
 text = C((1-nl-V'stmt')^1) *wh,

 optionHead = P'*'/'option' * sp * V'text' * (optionDiv * V'text')^-1 * wh,
 option = Ct(V'optionHead' * (V'line'-V'optionHead')^0 * wh),

 para = Ct(Cc('para') * V'text'),

 line = V'stmt' + V'option' + V'para',
 lines = Ct(V'line'^0)
})


return ink;
