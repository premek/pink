require('util') -- XXX

local isPara = function (node)
  return node ~= nil and type(node) == "table" and node[1] == "para"
end

local getPara = function (node)
  return isPara(node) and node[2]
end


return function (tree)

  local p = {} -- private
  p.pointer = 1

  local s = {}
  s.canContinue = true
  s.continue = function()
--print(to_string(tree))
    local res = getPara(tree[p.pointer])
    p.pointer = p.pointer + 1
    s.canContinue = isPara(tree[p.pointer])
    return res;
  end
  s.currentChoices = {}--{{text='yes',choiceText='i said yes'},{text='no',choiceText='nono'}}
  s.chooseChoiceIndex = function()
    s.currentChoices = {}
  end
  s.choosePathString = function(knotName) end
  s.variablesState = {}
  -- s.state.ToJson();s.state.LoadJson(savedJson);
  return s
end
