function table_print (tt, done)
  done = done or {}
  if type(tt) == "table" then
    local sb = {}
    for key, value in pairs (tt) do
      table.insert(sb, " ") -- indent it
      if type (value) == "table" and not done [value] then
        done [value] = true
        table.insert(sb, "{");
        table.insert(sb, table_print (value, done))
        table.insert(sb, " ") -- indent it
        table.insert(sb, "} ");
      elseif "number" == type(key) then
        table.insert(sb, string.format("%s,", tostring(value)))
      else
        table.insert(sb, string.format(
            "%s = %s,", tostring (key), tostring(value)))
       end
    end
    return table.concat(sb)
  else
    return tt .. "\n"
  end
end

function to_string( tbl )
    if  "nil"       == type( tbl ) then
        return tostring(nil)
    elseif  "table" == type( tbl ) then
        return table_print(tbl)
    elseif  "string" == type( tbl ) then
        return tbl
    else
        return tostring(tbl)
    end
end









local lpeg = require("lpeg")
local white = lpeg.S(" \t\r\n") ^ 0

local integer = white * lpeg.R("09") ^ 1 / tonumber
local muldiv = white * lpeg.C(lpeg.S("/*"))
local addsub = white * lpeg.C(lpeg.S("+-"))

local function node(p)
  return p / function(left, op, right)
    return { op, left, right }
  end
end



local lst = function(fold, new)
  println(fold, new)
  if typeof(fold) ~= "table" then return {new}
  else table.insert(fold, new); return fold; end
end

local sp = lpeg.S" \t" ^0
local wh = lpeg.S" \n\t" ^0

local text = sp * (lpeg.R("az", "AZ")^1 * sp)^1
local para = wh * lpeg.C(text) * wh

local commOL = '//' * sp * text
local commML = '/*' * wh * text * wh * '*/'
local comm = commOL + commML

local exp = para + comm

local any = lpeg.Ct(exp^1) * -1

local ink = any


print(to_string(ink:match("hello\nworld\n//comment")))
print(to_string(ink:match(" \nFc oh\n")))
print(to_string(ink:match(" \nF\tc \n ooo")))
print(to_string(ink:match(" \nFc \n")))
