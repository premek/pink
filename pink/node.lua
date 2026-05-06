local base_path = (...):match('(.-)[^%.]+$')
local list = function()
    return require(base_path .. 'list')
end -- avoid cyclic dependency -- FIXME
local logging = require(base_path .. 'logging')
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
    else
        return node.str(node.output(a))
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
        return node.bool(not list().isEmpty(a))
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

node.output = function(a)
    node.requirePinkType(a)
    if a.type == 'str' then
        return a.value
    elseif a.type == 'int' then
        return tostring(math.floor(a.value))
    elseif a.type == 'float' then
        local formatted, _ = string.format('%.7f', a.value):gsub('%.?0+$', '')
        return formatted
    elseif a.type == 'bool' then
        return tostring(a.value)
    elseif a.type == 'el' then
        return a.elName
    elseif a.type == 'list' then
        return list().output(a)
    else
        err('cannot output', a)
    end
end

return node
