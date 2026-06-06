local base_path = (...):match('(.-)[^%.]+$')
local logging = require(base_path .. 'logging')
local log = logging.newLogger()

local output = { { indent = 0 } }

local out = function(...)
    for _, str in ipairs({ ... }) do
        table.insert(output[#output], str)
    end
end
local outNewLine = function(indent)
    table.insert(output, { indent = indent })
end

local resetIndent = function(indent)
    output[#output].indent = indent
end

local format

local fnCallFormatter = function(name, args, ctx)
    out(name, '(')
    if #args > 0 then
        format({ args[1] }, ctx)
        for i = 2, #args do
            out(', ')
            format({ args[i] }, ctx)
        end
    end
    out(')')
end

local binaryCallFormatter = function(name, l, r, ctx)
    format({ l }, ctx)
    out(' ', name, ' ')
    format({ r }, ctx)
end

--stylua: ignore
local binaryOperators ={
    'or', '||', 'and', '&&',
    '!=', '==',
    '<=', '>=', '>', '<',
    '?', '!?', '^',
    '-', '+',
    'mod', '%', '/', '*'
}
local isBinaryOperator = {}
for _, operator in ipairs(binaryOperators) do
    isBinaryOperator[operator] = true
end

local callFormatter = function(node, ctx)
    if isBinaryOperator[node.name] then
        binaryCallFormatter(node.name, node.args[1], node.args[2], ctx)
    else
        if ctx.mode == 'out' then
            out('~ ')
        end
        fnCallFormatter(node.name, node.args, ctx)
    end
end

local nodeFormatters = {
    ink = function(node, ctx)
        format(node.nodes, ctx)
    end,

    str = function(node, ctx)
        if ctx.mode == 'ev' then
            out('"')
        end
        out(node.value)
        if ctx.mode == 'ev' then
            out('"')
        end
    end,
    knot = function(node, ctx)
        resetIndent(0)
        outNewLine(0)
        outNewLine(0)
        out('=== ', node.name, ' ===')
        outNewLine(0)
        format(node.body, ctx:with({ indent = 0 }))
    end,
    stitch = function(node, ctx)
        resetIndent(0)
        outNewLine(0)
        out('= ', node.name, ' =')
        outNewLine(0)
        format(node.args, ctx:with({ indent = 0 }))
    end,
    fndef = function(node, ctx)
        resetIndent(0)
        outNewLine(0)
        outNewLine(0)
        out('=== function ', node.name)
        out('(')
        for _, parameter in ipairs(node.params) do
            -- TODO ref
            out(parameter.name)
        end
        out(')')
        out(' ===')
        outNewLine(0)
        format(node.body, ctx:with({ indent = 0 }))
    end,
    choice = function(node, ctx)
        format(node.options, ctx)
        if node.gather then
            format({ node.gather }, ctx)
        end
    end,
    option = function(node, ctx)
        outNewLine(ctx.indent)
        out(string.rep('*', node.nesting))
        out('  ')
        format(node.sharedStartText, ctx)
        if #node.choiceOnlyText > 0 then
            out('[')
            format(node.choiceOnlyText, ctx)
            out(']')
        end
        format(node.bodyOnlyText, ctx)
        format(node.body, ctx:with({ indent = ctx.indent + node.nesting + 2 }))
    end,
    gather = function(node, ctx)
        outNewLine(ctx.indent)
        out(string.rep('- ', node.nesting))
        if node.label then
            out('(', node.label, ')')
        end
        format(node.body, ctx)
    end,
    divert = function(node, _ctx)
        out('-> ', node.target)
        --if #node.args > 0 then
        --   for _, _arg in ipairs(node.args) do
        -- TODO
        --  end
        --end
        if node.tunnel then
            out(' ->')
        end
    end,
    fork = function(node, _ctx)
        out('<- ', node.target)
        --if #node[3] > 0 then
        --for _, _arg in ipairs(node[3]) do
        -- TODO
        --end
        --end
    end,
    glue = function(_node, _ctx)
        out('<>')
    end,
    nl = function(_node, ctx)
        outNewLine(ctx.indent)
    end,
    comment = function(node, _ctx)
        out('// ', node.text)
    end,
    out = function(node, ctx)
        out('{')
        format({ node.content }, ctx:with({ mode = 'ev' }))
        out('}')
    end,
    call = callFormatter,
    ['if'] = function(node, ctx)
        out('{')
        for _, branch in ipairs(node.branches) do
            outNewLine(ctx.indent + 2)
            out('-  ')
            format({ branch.cond }, ctx)
            out(':')
            outNewLine(ctx.indent + 3)
            format(branch.body, ctx:with({ indent = ctx.indent + 3 }))
        end

        resetIndent(ctx.indent)
        out('}')
    end,
    seq = function(node, ctx)
        out('{')
        if node.opts.once then
            out('once:')
            -- TODO
        end
        for _, el in ipairs(node.branches) do
            outNewLine(ctx.indent + 2)
            out('- ')
            format(el, ctx:with({ indent = ctx.indent + 2 }))
        end
        out('}')
    end,
    ref = function(node, _ctx)
        out(table.concat(node.path, '.'))
    end,
    bool = function(node, _ctx)
        out(tostring(node.value))
    end,
    int = function(node, _ctx)
        out(tostring(node.value))
    end,
    float = function(node, _ctx)
        out(tostring(node.value))
    end,
    include = function(node, _ctx)
        out('INCLUDE ', node.filename)
    end,
    const = function(node, ctx)
        out('CONST ', node.name, ' = ')
        format({ node.value }, ctx:with({ mode = 'ev' }))
        outNewLine(ctx.indent)
    end,
    var = function(node, ctx)
        out('VAR ', node.name, ' = ')
        format({ node.value }, ctx:with({ mode = 'ev' }))
        outNewLine(ctx.indent)
    end,
    tempvar = function(node, ctx)
        if ctx.mode == 'out' then
            out('~ ')
        end
        out('temp ', node.name, ' = ')
        format({ node.value }, ctx:with({ mode = 'ev' }))
        outNewLine(ctx.indent)
    end,
    assign = function(node, ctx)
        if ctx.mode == 'out' then
            out('~ ')
        end

        out(node.name, ' = ')
        format({ node.expr }, ctx:with({ mode = 'ev' }))
        outNewLine(ctx.indent)
    end,
    ['return'] = function(node, ctx)
        if ctx.mode == 'out' then
            out('~ ')
        end
        out('return ')
        format({ node.value }, ctx:with({ mode = 'ev' }))
    end,
    tunnelreturn = function(_node, _ctx)
        out('->->')
    end,
    tunnelreturnto = function(n, _ctx)
        out('->-> ', n.target)
    end,
    tag = function(node, _ctx)
        out('#', node.text)
    end,
    listlit = function(_node, _ctx)
        out('()') -- TODO
    end,
    listdef = function(node, _ctx)
        out('LIST ', node.name) -- TODO
    end,
}

format = function(tree, ctx)
    for _, node in ipairs(tree) do
        log.debug(node)

        local nodeFormatter = nodeFormatters[node.type]
        if not nodeFormatter then
            log.debug(node)
            log.die('unknown node')
        end
        nodeFormatter(node, ctx)
    end
end

local newCtx = function()
    return {
        indent = 0,
        mode = 'out',
        with = function(self, newValues)
            local ctx = {}
            for key, oldValue in pairs(self) do
                ctx[key] = oldValue
            end
            for key, newValue in pairs(newValues) do
                ctx[key] = newValue
            end
            return ctx
        end,
    }
end

local outputToString = function()
    local o = {}
    for _, line in ipairs(output) do
        table.insert(line, 1, string.rep(' ', line.indent))
        table.insert(o, table.concat(line, ''))
    end
    return table.concat(o, '\n')
end

return function(globalTree)
    log.debug('in', globalTree)
    format(globalTree, newCtx())
    log.debug('out', output)
    return outputToString()
end
