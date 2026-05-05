local base_path = (...):match('(.-)[^%.]+$')
local node = require(base_path .. 'node')
local logging = require(base_path .. 'logging')
local err = logging.error
local _debug = logging.debug
local requireType = node.requireType
local is = node.is

local list = {
    defs = {}, -- FIXME support multiple instances!
}

local iterateElements = function(lst, callback)
    for listName, els in pairs(lst.elements) do
        for elName, _ in pairs(els) do
            callback(node.el(listName, elName))
        end
    end
end

local listValueInt = function(a)
    requireType(a, 'el', 'list')

    if is('el', a) then
        local listName, elementName = a.listName, a.elName
        if not listName then
            err('ambiguous list element: ' .. elementName)
        end
        return list.defs[listName].byName[elementName]
    elseif is('list', a) then
        local result = 0
        for listName, els in pairs(a.elements) do
            for elementName, _ in pairs(els) do
                result = list.defs[listName].byName[elementName]
                -- do not break, use the last one that is set to true
            end
        end
        return result
    end
end

list.value = function(a)
    return node.int(listValueInt(a))
end

list.contains = function(lst, el)
    requireType(lst, 'list')
    requireType(el, 'el')

    local listName, elName = el.listName, el.elName
    return lst.elements[listName] ~= nil and lst.elements[listName][elName] ~= nil
end
list.containsAll = function(hay, needles)
    requireType(hay, 'list')
    requireType(needles, 'list')

    local empty = true -- no lists contain the empty list
    local res = true
    iterateElements(needles, function(needle)
        empty = false
        res = res and list.contains(hay, needle)
    end)
    return empty or res
end

list.elByValue = function(listName, elementValue)
    return node.el(listName, list.defs[listName].byValue[elementValue])
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
        requireType(el, 'el')
        local listName, elName = el.listName, el.elName
        if listName == nil then
            err('ambiguous list element: ' .. elName)
        end

        elements[listName] = elements[listName] or {}
        elements[listName][elName] = 1
    end
    -- elements: {[listName1] = {elName1=1, elName2=1}, [listName2] = {...}, ...}
    return elements
end

list.fromEls = function(els, knownListNames)
    return node.list(getListElements(els, knownListNames))
end

list.fromLit = function(listLiteral, getEnv) -- FIXME env
    requireType(listLiteral, 'listlit')
    local els = {}
    for _, elName in ipairs(listLiteral.elements) do
        local el = getEnv(elName)
        table.insert(els, el)
    end
    return list.fromEls(els, {})
end
list.empty = function()
    return node.list({})
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
    requireType(lst, 'list')
    requireType(el, 'el')
    lst.elements[el.listName] = lst.elements[el.listName] or {}
    lst.elements[el.listName][el.elName] = internalValue -- just a placeholder value, we're using keys, nil to unset
end
local listAdd = function(lst, el)
    listSetInternal(lst, el, 1)
end
local listRemove = function(lst, el)
    listSetInternal(lst, el, nil)
end

-- TODO name list functions
list.plus = function(a, b)
    requireType(a, 'list')
    requireType(b, 'el', 'list')

    local new = listCopy(a)
    if is('el', b) then
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

local minusEl = function(lst, el)
    requireType(lst, 'list')
    requireType(el, 'el')

    local new = listCopy(lst)
    listRemove(new, el)
    return new
end

list.minus = function(a, b)
    requireType(a, 'list')
    requireType(b, 'el', 'list')

    if is('list', b) then
        local l = a
        iterateElements(b, function(el)
            l = minusEl(l, el)
        end)
        return l
    else
        return minusEl(a, b)
    end
end

list.set = function(lst, new)
    requireType(lst, 'list')
    requireType(new, 'list', 'el')

    local els
    if is('el', new) then
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

-- set all to false, except the element (element does not have to be from the same list)
local listSetValue = function(lst, value)
    for listName, _ in pairs(lst.elements) do
        local elName = list.defs[listName].byValue[value]
        if elName then
            list.set(lst, node.el(listName, elName)) --FIXME
        end
    end
end

list.output = function(lst)
    local outEls = listGetElements(lst)
    table.sort(outEls, function(a, b)
        local val = listValueInt(a) - listValueInt(b)
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
-- list with elements from different list.defs: undefined??? --TODO
list.inc = function(lst, a)
    local new = listCopy(lst)
    local value = listValueInt(new) + a
    listSetValue(new, value)
    return new
end

list.all = function(a)
    requireType(a, 'el', 'list') -- TODO is 'el' just a 'list' with one element?
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
        for elName, _ in pairs(list.defs[listName].byName) do
            table.insert(els, node.el(listName, elName))
        end
    end

    return list.fromEls(els, listNames)
end

-- TODO simplify
list.max = function(a)
    requireType(a, 'list')

    local name = nil
    local max = -1
    for listName, els in pairs(a.elements) do
        for elementName, _ in pairs(els) do
            local elementValue = list.defs[listName].byName[elementName]
            if elementValue >= max then
                max = elementValue
                name = listName
            end
        end
    end

    if name == nil then
        return node.list({})
    end

    return list.elByValue(name, max)
end

local listCountNumber = function(a)
    requireType(a, 'list')

    local count = 0
    iterateElements(a, function()
        count = count + 1
    end)
    return count
end

list.count = function(a)
    return node.int(listCountNumber(a))
end

list.isEmpty = function(a)
    requireType(a, 'list')
    return listCountNumber(a) == 0
end

list.random = function(a)
    requireType(a, 'list')

    local els = listGetElements(a)
    if #els == 0 then
        return node.list({})
    end
    return els[math.random(1, #els)]
end

list.min = function(a)
    requireType(a, 'list')

    local name = nil
    local min = nil
    for listName, els in pairs(a.elements) do
        for elementName, _ in pairs(els) do
            local elementValue = list.defs[listName].byName[elementName]
            if min == nil or elementValue < min then
                min = elementValue
                name = listName
            end
        end
    end

    if name == nil then
        return node.list({})
    end

    return list.elByValue(name, min)
end

list.invert = function(lst)
    local new = list.all(lst)
    for listName, els in pairs(lst.elements) do
        for elName, _ in pairs(els) do
            listRemove(new, node.el(listName, elName))
        end
    end
    return new
end

list.range = function(lst, minIncl, maxIncl)
    if is('el', minIncl) then
        minIncl = list.value(minIncl)
    end
    if is('el', maxIncl) then
        maxIncl = list.value(maxIncl)
    end
    requireType(minIncl, 'int')
    requireType(maxIncl, 'int')

    local els = {}
    local listNames = {}
    iterateElements(lst, function(el)
        table.insert(listNames, el.listName)
        local val = listValueInt(el)
        if minIncl.value <= val and val <= maxIncl.value then
            table.insert(els, el)
        end
    end)
    return list.fromEls(els, listNames)
end

list.intersection = function(a, b)
    requireType(a, 'list')
    requireType(b, 'list')
    local els = {}
    iterateElements(b, function(el)
        if list.contains(a, el) then
            table.insert(els, el)
        end
    end)
    return list.fromEls(els, {})
end

list.listDef = function(listName, elDefs, env)
    local elements = {}
    list.defs[listName] = { byName = {}, byValue = {} }
    for _, elDef in pairs(elDefs) do
        local elName, elSet, elValue = elDef.name, elDef.set, elDef.value
        local el = node.el(listName, elName)
        if env[elName] == nil then
            env[elName] = el
        else
            -- multiple lists has an element with the same name
            env[elName].listName = nil
        end
        -- TODO do we need both
        list.defs[listName].byName[elName] = elValue
        list.defs[listName].byValue[elValue] = elName

        if elSet then
            table.insert(elements, el)
        end
    end
    env[listName] = list.fromEls(elements, { listName })
end

return list
