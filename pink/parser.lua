local lpeg = require "lpeg"
lpeg.locale(lpeg)
local S,C,Ct,Cc,Cg,Cb,Cf,Cmt,P,V =
  lpeg.S, lpeg.C, lpeg.Ct, lpeg.Cc, lpeg.Cg, lpeg.Cb, lpeg.Cf, lpeg.Cmt,
  lpeg.P, lpeg.V

local concat = function (p)
  return Cf(p, function (a,b) return a..b end)
end

local parserLogger = print
local eof = -1
local sp = S" \t" ^0 + eof
local wh = S" \t\r\n" ^0 + eof
local nl = S"\r\n" ^1 + eof
local id = (lpeg.alpha + '_') * (lpeg.alnum + '_')^0
local addr = C(id) * ('.' * C(id))^-1

local todo = sp * 'TODO:' * sp * (1-nl)^0 / parserLogger * wh -- TODO log location
local commOL = sp * '//' * sp * (1-nl)^0 * wh
local commML = sp * '/*' * wh * (P(1)-'*/')^0 * '*/' * wh
local comm = commOL + commML + todo

local glue = P'<>'/'glue' *wh -- FIXME do not consume spaces after glue

local divertSym = '->' *wh
local divertEndSym = C('END') *wh
local divertEnd = divertSym * divertEndSym
local divertJump = Ct(divertSym/'divert' * addr * wh)
local divert = divertEnd + divertJump

local knotHead = P('=')^2/'knot' * wh * C(id) * wh * P('=')^0 * wh
local stitchHead = P('=')^1/'stitch' * wh * C(id) * wh * P('=')^0 * wh

local optDiv = '[' * C((P(1) - ']')^0) * ']'

local optStars = concat(wh * C(P'*') * (sp * C'*')^0)
local optStarsSameIndent = Cmt(Cb("indent") * optStars,
  function (s, i, a, b) return a == b end)
local optStarsLEIndent = Cmt(Cb("indent") * optStars,
    function (s, i, backtrack, this)
      return string.len(this) <= string.len(backtrack)
    end)


local ink = P({
 "lines",

 knotKnot = Ct(knotHead * (V'line'-knotHead)^0 * wh),
 knotStitch = Ct(stitchHead * (V'line'-stitchHead)^0 * wh),
 knot = V'knotKnot' + V'knotStitch',

 stmt = glue + divert + V'knot' + optDiv + comm,
 text = C((1-nl-V'stmt')^1) *wh,
 textE = C((1-nl-V'stmt')^0) *wh,

 optAnsWithDiv    = V'textE' * optDiv * V'textE' * wh,
 optAnsWithoutDiv = V'textE' * Cc ''* Cc ''* wh, -- huh?
 optAns = V'optAnsWithDiv' + V'optAnsWithoutDiv',

-- TODO clean this
 opt = Cg(optStars,'indent') *
                 Ct(Cc'option'                      * sp * V'optAns'    * (V'line'-V'optLEIndent'-V'knot')^0 * wh),  --TODO which can by toplevel only?
 optSameIndent = Ct(Cc'option' * optStarsSameIndent * sp * V'optAns'    * (V'line'-V'optLEIndent'-V'knot')^0 * wh),
 optLEIndent   = Ct(Cc'option' * optStarsLEIndent   * sp * V'optAns'    * (V'line'-V'optLEIndent'-V'knot')^0 * wh),

 opts = (V'opt'*V'optSameIndent'^0),

 choice = Ct(Cc'choice' * V'opts')/function(t) t.indent=nil; return t end,

 para = Ct(Cc'para' * V'text'),

 line = V'stmt' + V'choice' + V'para',
 lines = Ct(V'line'^0)
})


return ink;
