require('util') -- XXX

local is = function (what, node)
  return node ~= nil and type(node) == "table" and node[1] == what
end

local getPara = function (node)
  if is('para', node) then return node[2] end
end


return function (tree)
  --print(to_string(tree))
  local s = {}

  local pointer = 1
  local tab = tree

  local update = function ()
    local next = tab[pointer]

    s.canContinue = is('para', next)

    s.currentChoices = {}
    if is('choice', next) then
      for i=2, #next do
        --print(to_string(next[i]))
        table.insert(s.currentChoices, {
          text = next[i][2] .. (next[i][3] or ''),
          choiceText = next[i][2] .. (next[i][4] or ''),
        })
      end
    end
  end

  s.canContinue = true

  s.continue = function()
    local res = getPara(tab[pointer])
    pointer = pointer + 1
    update()
    return res;
  end

  s.currentChoices = {}

  s.chooseChoiceIndex = function(index)
    s.currentChoices = {}
    local choice = tab[pointer]
    local option = choice[1 + index]
    tab = option
    pointer = 5
    update()
  end

  s.choosePathString = function(knotName) end
  s.variablesState = {}
  -- s.state.ToJson();s.state.LoadJson(savedJson);
  return s
end
