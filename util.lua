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

function tprint (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      print(formatting .. 'table:')
      tprint(v, indent+1)
    elseif type(v) == 'boolean' then
      print(formatting .. tostring(v))
    else
      print(formatting .. v)
    end
  end
end

function read(file)
    local f = io.open(file, "rb")
    local content = f:read("*all")
    f:close()
    return content
end

function test(p, file)
  print ('\n=== '..file..' ===')
  tprint(p:match(read('test/'..file..'.ink')))
end
