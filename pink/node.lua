local base_path = (...):match('(.-)[^%.]+$')
local logging = require(base_path .. 'logging')
local random = require(base_path .. 'random')
local err = logging.error
local _debug = logging.debug

local node = {}

-- ── Value constructors ────────────────────────────────────────────────────────

node.int = function(n)
    return { type = 'int', value = n }
end
node.float = function(n)
    return { type = 'float', value = n }
end
node.bool = function(b)
    if type(b) ~= 'boolean' then
        err('node.bool requires a boolean, got ' .. type(b))
    end
    return { type = 'bool', value = b }
end
node.str = function(s)
    return { type = 'str', value = s }
end
node.divert = function(target, args, tunnel)
    return { type = 'divert', target = target, args = args, tunnel = tunnel }
end
node.ref = function(name)
    return { type = 'ref', name = name }
end
node.el = function(listName, elName)
    return { type = 'el', listName = listName, elName = elName }
end
node.list = function(elements)
    return { type = 'list', elements = elements }
end
node.fn = function(params, body)
    return { type = 'fn', params = params, body = body }
end
node.native = function(fn)
    return { type = 'native', fn = fn }
end
node.externalFn = function(fn)
    return { type = 'external', fn = fn }
end

-- ── AST node constructors ─────────────────────────────────────────────────────
-- No location — parser attaches it via token() after calling these.

node.knot = function(name, params, body)
    return { type = 'knot', name = name, params = params, body = body }
end
node.stitch = function(name, args)
    return { type = 'stitch', name = name, args = args }
end
node.fndef = function(name, params, body)
    return { type = 'fndef', name = name, params = params, body = body }
end
node.external = function(name, params)
    return { type = 'external', name = name, params = params }
end
node.var = function(name, value)
    return { type = 'var', name = name, value = value }
end
node.const = function(name, value)
    return { type = 'const', name = name, value = value }
end
node.tempvar = function(name, value)
    return { type = 'tempvar', name = name, value = value }
end
node.assign = function(name, expr)
    return { type = 'assign', name = name, expr = expr }
end
node.ret = function(value)
    return { type = 'return', value = value }
end
node.tag = function(text)
    return { type = 'tag', text = text }
end
node.include = function(filename)
    return { type = 'include', filename = filename }
end
node.listdef = function(name, elements)
    return { type = 'listdef', name = name, elements = elements }
end
node.ink = function(nodes)
    return { type = 'ink', nodes = nodes }
end
node.listlit = function(elements)
    return { type = 'listlit', elements = elements }
end
node.todo = function(text)
    return { type = 'todo', text = text }
end
node.glue = function()
    return { type = 'glue' }
end
node.tunnelreturn = function()
    return { type = 'tunnelreturn' }
end
node.nl = function()
    return { type = 'nl' }
end
node.option = function(nesting, t1, t2, t3, label, sticky, conditions, body, fallback)
    return {
        type = 'option',
        nesting = nesting,
        t1 = t1,
        t2 = t2,
        t3 = t3,
        label = label,
        sticky = sticky,
        conditions = conditions,
        body = body,
        fallback = fallback,
    }
end
node.gather = function(nesting, body, label)
    return { type = 'gather', nesting = nesting, body = body, label = label }
end
node.seq = function(opts, branches)
    return { type = 'seq', opts = opts, branches = branches }
end
node.choice = function(options, gather)
    return { type = 'choice', options = options, gather = gather }
end
node.comment = function(text)
    return { type = 'comment', text = text }
end
node.fork = function(target, args)
    return { type = 'fork', target = target, args = args }
end
node.out = function(content, opts)
    return { type = 'out', content = content, opts = opts }
end
node['if'] = function(branches, opts)
    return { type = 'if', branches = branches, opts = opts }
end
node.call = function(name, args)
    return { type = 'call', name = name, args = args }
end

-- ── Type checks ───────────────────────────────────────────────────────────────

node.is = function(what, n)
    return n ~= nil and type(n) == 'table' and n.type == what
end

node.isNum = function(a)
    return a.type == 'int' or a.type == 'float'
end

node.requirePinkType = function(a)
    if a == nil then
        err('null not allowed')
    end
    if type(a) ~= 'table' then
        _debug(a)
        err('table expected, got ' .. type(a))
    end
    if type(a.type) ~= 'string' then
        error('pink type expected')
    end
    assert(a, 'pink type expected')
end

node.requireType = function(a, ...)
    node.requirePinkType(a)
    local t = a.type
    for _, requiredType in ipairs({ ... }) do
        if t == requiredType then
            return
        end
    end
    err('unexpected type: ' .. t .. ', expected one of: ' .. table.concat({ ... }, ', '), a)
end

-- ── Type conversions ──────────────────────────────────────────────────────────

local intToStr = function(a)
    node.requireType(a, 'int')
    return tostring(math.floor(a.value))
end
local floatToStr = function(a)
    node.requireType(a, 'float')
    local formatted, _ = string.format('%.7f', a.value):gsub('%.?0+$', '')
    return formatted
end
local boolToStr = function(a)
    node.requireType(a, 'bool')
    return tostring(a.value)
end

node.toInt = function(a)
    node.requirePinkType(a)
    if a.type == 'int' then
        return a
    elseif a.type == 'bool' then
        return node.int(a.value and 1 or 0)
    else
        err('cannot convert to int', a)
    end
end

node.toFloat = function(a)
    node.requirePinkType(a)
    if a.type == 'float' then
        return a
    elseif a.type == 'int' then
        return node.float(a.value)
    elseif a.type == 'bool' then
        return node.float(a.value and 1 or 0)
    else
        err('cannot convert to float', a)
    end
end

node.toStr = function(a)
    node.requirePinkType(a)
    if a.type == 'str' then
        return a
    elseif a.type == 'int' then
        return node.str(intToStr(a))
    elseif a.type == 'float' then
        return node.str(floatToStr(a))
    elseif a.type == 'bool' then
        return node.str(boolToStr(a))
    else
        err('cannot convert to str', a)
    end
end

node.toBool = function(a)
    node.requirePinkType(a)
    if a.type == 'bool' then
        return a
    elseif a.type == 'int' or a.type == 'float' then
        return node.bool(a.value ~= 0)
    elseif a.type == 'str' then
        return node.bool(#a.value ~= 0)
    elseif a.type == 'list' then
        -- TODO: use lists.isEmpty once node no longer needs to be lists-agnostic
        local hasEl = false
        for _, els in pairs(a.elements) do
            if next(els) then
                hasEl = true
                break
            end
        end
        return node.bool(hasEl)
    elseif a.type == 'el' then
        return node.bool(true)
    else
        err('cannot convert to bool', a)
    end
end

node.isTruthy = function(a)
    return node.toBool(a).value
end

-- ── Output ────────────────────────────────────────────────────────────────────

node.makeOutput = function(listDefinitions)
    return function(a)
        node.requirePinkType(a)
        if a.type == 'str' then
            return a.value
        elseif a.type == 'int' then
            return intToStr(a)
        elseif a.type == 'float' then
            return floatToStr(a)
        elseif a.type == 'bool' then
            return boolToStr(a)
        elseif a.type == 'el' then
            return a.elName
        elseif a.type == 'list' then
            return node.listOutput(a, listDefinitions)
        else
            err('cannot output', a)
        end
    end
end

-- ── List operations ───────────────────────────────────────────────────────────

local iterateElements = function(lst, callback)
    for listName, els in pairs(lst.elements) do
        for elName, _ in pairs(els) do
            callback(node.el(listName, elName))
        end
    end
end

local listValueInt = function(a, listDefinitions)
    node.requireType(a, 'el', 'list')

    if node.is('el', a) then
        local listName, elementName = a.listName, a.elName
        if not listName then
            err('ambiguous list element: ' .. elementName)
        end
        return listDefinitions[listName].byName[elementName]
    elseif node.is('list', a) then
        local result = 0
        for listName, els in pairs(a.elements) do
            for elementName, _ in pairs(els) do
                result = listDefinitions[listName].byName[elementName]
                -- do not break, use the last one that is set to true
            end
        end
        return result
    end
end

local listGetElements = function(lst)
    local els = {}
    iterateElements(lst, function(el)
        table.insert(els, el)
    end)
    return els
end

local getListElements = function(els, knownListNames)
    local elements = {}
    for _, listName in ipairs(knownListNames) do
        elements[listName] = {}
    end
    for _, el in ipairs(els) do
        node.requireType(el, 'el')
        local listName, elName = el.listName, el.elName
        if listName ~= nil then
            elements[listName] = elements[listName] or {}
            elements[listName][elName] = 1
        else
            err('ambiguous list element: ' .. elName)
        end
    end
    -- elements: {[listName1] = {elName1=1, elName2=1}, [listName2] = {...}, ...}
    return elements
end

local listCopy = function(lst)
    local res = {}
    for listName, els in pairs(lst.elements) do
        res[listName] = res[listName] or {}
        for elName, _ in pairs(els) do
            res[listName][elName] = 1
        end
    end
    return node.list(res)
end

local listSetInternal = function(lst, el, internalValue)
    node.requireType(lst, 'list')
    node.requireType(el, 'el')
    lst.elements[el.listName] = lst.elements[el.listName] or {}
    lst.elements[el.listName][el.elName] = internalValue -- just a placeholder value, we're using keys, nil to unset
end
local listAdd = function(lst, el)
    listSetInternal(lst, el, 1)
end
local listRemove = function(lst, el)
    listSetInternal(lst, el, nil)
end

local minusEl = function(lst, el)
    node.requireType(lst, 'list')
    node.requireType(el, 'el')

    local new = listCopy(lst)
    listRemove(new, el)
    return new
end

local listCountNumber = function(a)
    node.requireType(a, 'list')

    local count = 0
    iterateElements(a, function()
        count = count + 1
    end)
    return count
end

local listSetValue = function(lst, value, listDefinitions)
    for listName, _ in pairs(lst.elements) do
        local elName = listDefinitions[listName].byValue[value]
        if elName then
            node.listSet(lst, node.el(listName, elName)) --FIXME
        end
    end
end

-- pure list operations

node.listContains = function(lst, el)
    node.requireType(lst, 'list')
    node.requireType(el, 'el')

    local listName, elName = el.listName, el.elName
    return lst.elements[listName] ~= nil and lst.elements[listName][elName] ~= nil
end
node.listContainsAll = function(hay, needles)
    node.requireType(hay, 'list')
    node.requireType(needles, 'list')

    local empty = true -- no lists contain the empty list
    local res = true
    iterateElements(needles, function(needle)
        empty = false
        res = res and node.listContains(hay, needle)
    end)
    return empty or res
end

node.listFromEls = function(els, knownListNames)
    return node.list(getListElements(els, knownListNames))
end

node.listFromLit = function(listLiteral, getEnv) -- FIXME env
    node.requireType(listLiteral, 'listlit')
    local els = {}
    for _, elName in ipairs(listLiteral.elements) do
        local el = getEnv(elName)
        table.insert(els, el)
    end
    return node.listFromEls(els, {})
end
node.listEmpty = function()
    return node.list({})
end

-- TODO name list functions
node.listPlus = function(a, b)
    node.requireType(a, 'list')
    node.requireType(b, 'el', 'list')

    local new = listCopy(a)
    if node.is('el', b) then
        listAdd(new, b)
    else
        for listName, els in pairs(b.elements) do
            for elName, _ in pairs(els) do
                listAdd(new, node.el(listName, elName))
            end
        end
    end
    return new
end

node.listMinus = function(a, b)
    node.requireType(a, 'list')
    node.requireType(b, 'el', 'list')

    if node.is('list', b) then
        local l = a
        iterateElements(b, function(el)
            l = minusEl(l, el)
        end)
        return l
    else
        return minusEl(a, b)
    end
end

node.listSet = function(lst, new)
    node.requireType(lst, 'list')
    node.requireType(new, 'list', 'el')

    local els
    if node.is('el', new) then
        els = { new }
    else
        -- TODO -- rename functions
        els = listGetElements(new)
    end
    if #els == 0 then
        -- keep the known lists
        iterateElements(lst, function(el)
            lst.elements[el.listName] = {}
        end)
    else
        lst.elements = getListElements(els, {}) --FIXME known lists
    end
end

node.listCount = function(a)
    return node.int(listCountNumber(a))
end

node.listIsEmpty = function(a)
    node.requireType(a, 'list')
    return listCountNumber(a) == 0
end

node.listRandom = function(a)
    node.requireType(a, 'list')

    local els = listGetElements(a)
    if #els == 0 then
        return node.list({})
    end
    table.sort(els, function(x, y)
        return x.listName .. '.' .. x.elName < y.listName .. '.' .. y.elName
    end)
    return els[random.int(1, #els)]
end

node.listIntersection = function(a, b)
    node.requireType(a, 'list')
    node.requireType(b, 'list')
    local els = {}
    iterateElements(b, function(el)
        if node.listContains(a, el) then
            table.insert(els, el)
        end
    end)
    return node.listFromEls(els, {})
end

-- list operations requiring definitions

node.listValue = function(a, listDefinitions)
    return node.int(listValueInt(a, listDefinitions))
end

node.listElByValue = function(listName, elementValue, listDefinitions)
    return node.el(listName, listDefinitions[listName].byValue[elementValue])
end

node.listOutput = function(lst, listDefinitions)
    local outEls = listGetElements(lst)
    table.sort(outEls, function(a, b)
        local val = listValueInt(a, listDefinitions) - listValueInt(b, listDefinitions)
        return val == 0 and a.listName < b.listName or val < 0
    end)

    local names = {}
    for _, el in ipairs(outEls) do
        table.insert(names, el.elName)
    end
    return table.concat(names, ', ')
end

-- sets the present value of the list 'a' times to the next element
-- empty list stays empty
-- list with elements from different listDefinitions: undefined??? --TODO
node.listInc = function(lst, a, listDefinitions)
    local new = listCopy(lst)
    local value = listValueInt(new, listDefinitions) + a
    listSetValue(new, value, listDefinitions)
    return new
end

node.listAll = function(a, listDefinitions)
    node.requireType(a, 'el', 'list') -- TODO is 'el' just a 'list' with one element?
    local listNames = {}
    if a.type == 'el' then
        table.insert(listNames, a.listName)
    else
        -- collect "known" lists
        for listName, _ in pairs(a.elements) do
            table.insert(listNames, listName)
        end
    end
    local els = {}

    for _, listName in ipairs(listNames) do
        for elName, _ in pairs(listDefinitions[listName].byName) do
            table.insert(els, node.el(listName, elName))
        end
    end

    return node.listFromEls(els, listNames)
end

-- TODO simplify
node.listMax = function(a, listDefinitions)
    node.requireType(a, 'list')

    local name = nil
    local max = -1
    for listName, els in pairs(a.elements) do
        for elementName, _ in pairs(els) do
            local elementValue = listDefinitions[listName].byName[elementName]
            if elementValue >= max then
                max = elementValue
                name = listName
            end
        end
    end

    if name == nil then
        return node.list({})
    end

    return node.listElByValue(name, max, listDefinitions)
end

node.listMin = function(a, listDefinitions)
    node.requireType(a, 'list')

    local name = nil
    local min = nil
    for listName, els in pairs(a.elements) do
        for elementName, _ in pairs(els) do
            local elementValue = listDefinitions[listName].byName[elementName]
            if min == nil or elementValue < min then
                min = elementValue
                name = listName
            end
        end
    end

    if name == nil then
        return node.list({})
    end

    return node.listElByValue(name, min, listDefinitions)
end

node.listInvert = function(lst, listDefinitions)
    local new = node.listAll(lst, listDefinitions)
    for listName, els in pairs(lst.elements) do
        for elName, _ in pairs(els) do
            listRemove(new, node.el(listName, elName))
        end
    end
    return new
end

node.listRange = function(lst, minIncl, maxIncl, listDefinitions)
    if node.is('el', minIncl) then
        minIncl = node.listValue(minIncl, listDefinitions)
    end
    if node.is('el', maxIncl) then
        maxIncl = node.listValue(maxIncl, listDefinitions)
    end
    node.requireType(minIncl, 'int')
    node.requireType(maxIncl, 'int')

    local els = {}
    local listNames = {}
    iterateElements(lst, function(el)
        table.insert(listNames, el.listName)
        local val = listValueInt(el, listDefinitions)
        if minIncl.value <= val and val <= maxIncl.value then
            table.insert(els, el)
        end
    end)
    return node.listFromEls(els, listNames)
end

return node
