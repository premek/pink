require('util') -- XXX

local is = function (what, node)
  return node ~= nil
    and (type(node) == "table" and node[1] == what)
    or (type(node) == "string" and node == what)
end

local getPara = function (node)
  if is('para', node) then return node[2] end
end

return function (tree)
  --print(to_string(tree))
  local s = {}

  local pointer = nil
  local tab = {}

  local knots = {}

  local process = function ()
    for _, v in ipairs(tree) do
      if is('knot', v) then
        knots[v[2]] = v
      end
    end
  end

  local update = function ()
    local next = tab[pointer]

    if is('knot', next) then
      tab = next
      pointer = 3
      next = tab[pointer]
    end

    if is('divert', next) then
      tab = knots[next[2]]
      pointer = 3
      next = tab[pointer]
    end

    s.canContinue = is('para', next)

    s.currentChoices = {}
    if is('choice', next) then
      for i=2, #next do
        --print(to_string(next[i]))
        table.insert(s.currentChoices, {
          text = (next[i][2] or '') .. (next[i][3] or ''),
          choiceText = next[i][2] .. (next[i][4] or ''),
        })
      end
    end
  end


  local step = function ()
    pointer = pointer + 1
    update()
    return tab[pointer]
  end

  local stepTo = function (table, pos)
    tab = table
    pointer = pos
    update()
    return tab[pointer]
  end

  s.canContinue = nil

  s.continue = function()
    local res = getPara(tab[pointer])
    local next = step()

    if is('glue', next) then
      step()
      res = res .. s.continue()
    end

    return res;
  end

  s.currentChoices = nil

  s.chooseChoiceIndex = function(index)
    s.currentChoices = {}
    local choice = tab[pointer]
    local option = choice[1 + index]
    stepTo(option, 5)
  end

  s.choosePathString = function(knotName) end
  s.variablesState = {}
  -- s.state.ToJson();s.state.LoadJson(savedJson);

  stepTo(tree, 1)
  process()
  return s
end
