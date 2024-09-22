local base_path = (...):match("(.-)[^%.]+$")
local out = require(base_path .. 'out')
local _debug = require(base_path .. 'debug')



local lastLocation = nil
local getLocation = function(location)
    return location[1] .. ', line ' .. location[2] .. ', column ' .. location[3]
end

local getLogMessage = function (message, token)
    local location = ''
    if token and token.location then
        location = '\n\tsomewhere around ' .. getLocation(token.location)
    elseif lastLocation then
        location = '\n\tsomewhere after ' .. getLocation(lastLocation)
    end
    if token and type(token) == "table" and #token > 0 then
        location = location .. ', node type: ' .. token[1]
    end
    return message..location
end
local err = function(message, token)
    error(getLogMessage(message, token))
end

local is = function (node, what)
    return node ~= nil
        and (type(node) == "table" and node[1] == what)
end


local output = {{indent=0}}

local out = function(...)
    for _, str in ipairs({...}) do
        table.insert(output[#output], str)
    end
end
local outNewLine = function(indent)
    table.insert(output, {indent=indent})
end

local resetIndent = function(indent)
    output[#output].indent = indent
end




local format



local fnCallFormatter = function(name, args, ctx)
    out(name, '(')
    if #args > 0 then
        format({args[1]}, ctx)
        for i=2, #args do
            out(', ')
            format({args[i]}, ctx)
        end
    end
    out(')')
end

local binaryCallFormatter = function(name, l, r, ctx)
    format({l}, ctx)
    out(' ', name, ' ')
    format({r}, ctx)
end

local binaryOperators ={
    'or', '||', 'and', '&&',
    '!=', '==',
    '<=', '>=', '>', '<',
    '?', '!?', '^',
    '-', '+',
    'mod', '%', '/', '*'
}
local isBinaryOperator = {}
for _, operator in ipairs(binaryOperators) do isBinaryOperator[operator]=true end



local callFormatter = function(node, ctx)
    if isBinaryOperator[node[2]] then
        binaryCallFormatter(node[2], node[3][1], node[3][2], ctx)
    else
        if ctx.mode == 'out' then
            out('~ ')
        end
        fnCallFormatter(node[2], node[3], ctx)
    end
end


local nodeFormatters = {
    ink = function(node, ctx)
        format(node[2], ctx)
    end,

    str = function(node, ctx)
        if ctx.mode == 'ev' then
            out('"')
        end
        out(node[2])
        if ctx.mode == 'ev' then
            out('"')
        end
    end,
    knot = function(node, ctx)
        resetIndent(0)
        outNewLine(0)
        outNewLine(0)
        out('=== ', node[2], ' ===')
        outNewLine(0)
        format(node[4], ctx:with{indent=0})

    end,
    stitch = function(node, ctx)
        resetIndent(0)
        outNewLine(0)
        out('= ', node[2], ' =')
        outNewLine(0)
        format(node[3], ctx:with{indent=0})

    end,
    fn = function(node, ctx)
        resetIndent(0)
        outNewLine(0)
        outNewLine(0)
        out('=== function ', node[2])
        out('(')
        for _, parameter in ipairs(node[3]) do
            -- TODO ref
            out(parameter[1])
        end
        out(')')
        out(' ===')
        outNewLine(0)
        format(node[4], ctx:with{indent=0})

    end,
    choice = function(node, ctx)
        format(node[2], ctx)
        if node[3] then
            format({node[3]}, ctx)
        end

    end,
    option = function(node, ctx)
        outNewLine(ctx.indent)
        out(string.rep('*', node[2]))
        out('  ')
        format(node[3], ctx)
        if #node[4]>0 then
            out('[')
            format(node[4], ctx)
            out(']')
        end
        format(node[5], ctx)
        format(node[9], ctx:with{indent=ctx.indent+node[2]+2})

    end,
    gather = function(node, ctx)
        outNewLine(ctx.indent)
        out(string.rep('- ', node[2]))
        if node[4] then
            out('(', node[4], ')')
        end
        format(node[3], ctx)
    end,
    divert = function(node, ctx)
        out('-> ', node[2])
        if #node[3] > 0 then
            for _, arg in ipairs(node[3]) do
            -- TODO
            end
        end
        if node[4] then
            out(' ->')
        end
    end,
    fork = function(node, ctx)
        out('<- ', node[2])
        if #node[3] > 0 then
            for _, arg in ipairs(node[3]) do
            -- TODO
            end
        end
    end,
    glue = function(node, ctx)
        out('<>')

    end,
    nl = function(node, ctx)
        outNewLine(ctx.indent)

    end,
    comment = function(node, ctx)
        out('// ', node[2])

    end,
    out = function(node, ctx)
        out('{')
        format({node[2]}, ctx:with{mode='ev'})
        out('}')

    end,
    call = callFormatter,
    ['if'] = function(node, ctx)
        out('{')
        for _, branch in ipairs(node[2]) do
            outNewLine(ctx.indent+2)
            out('-  ')
            format({branch[1]}, ctx)
            out(':')
            outNewLine(ctx.indent+3)
            format(branch[2], ctx:with{indent=ctx.indent+3})
        end

        resetIndent(ctx.indent)
        out('}')


    end,
    seq = function(node, ctx)
        out('{')
        if node[2].once then
            out('once:')
            -- TODO
        end
        for _, el in ipairs(node[3]) do
            outNewLine(ctx.indent+2)
            out('- ')
            format(el, ctx:with{indent=ctx.indent+2})
        end
        out('}')
    end,
    ref = function(node, ctx)
        out(node[2]) --FIXME ref?

    end,
    bool=function(node, ctx)
        out(tostring(node[2]))
    end,
    int=function(node, ctx)
        out(tostring(node[2]))
    end,
    float =function(node, ctx)
        out(tostring(node[2]))
    end,
    include= function(node, ctx)
        out('INCLUDE ', node[2])
    end,
    const= function(node, ctx)
        out('CONST ', node[2], ' = ')
        format({node[3]}, ctx:with{mode='ev'})
        outNewLine(ctx.indent)
    end,
    var = function(node, ctx)
        out('VAR ', node[2], ' = ')
        format({node[3]}, ctx:with{mode='ev'})
        outNewLine(ctx.indent)
    end,
    tempvar = function(node, ctx)
        if ctx.mode == 'out' then
            out('~ ')
        end
        out('temp ', node[2], ' = ')
        format({node[3]}, ctx:with{mode='ev'})
        outNewLine(ctx.indent)

    end,
    assign = function(node, ctx)
        if ctx.mode == 'out' then
            out('~ ')
        end

        out(node[2], ' = ')
        format({node[3]}, ctx:with{mode='ev'})
        outNewLine(ctx.indent)

    end,
    ['return'] = function(node, ctx)
        if ctx.mode == 'out' then
            out('~ ')
        end
        out('return ')
        format({node[2]}, ctx:with{mode='ev'})
    end,
    tunnelreturn = function(node, ctx)
        out('->->')
    end,
    tag = function(node, ctx)
        out('#', node[2])
    end,
    listlit = function(node, ctx)
        out('()')-- TODO
    end,
    listdef = function(node, ctx)
        out('LIST ', node[2]) -- TODO
    end,

}

format = function(tree, ctx)

    for _, node in ipairs(tree) do
        _debug(node)

        local nodeFormatter = nodeFormatters[node[1]]
        if not nodeFormatter then
            _debug(node)
            err('unknown node')
        end
        nodeFormatter(node, ctx)
    end
end

local newCtx = function()
    return {
        indent=0,
        mode='out',
        with=function(self, newValues)
            local newCtx = {}
            for key, oldValue in pairs(self) do
                newCtx[key] = oldValue
            end
            for key, newValue in pairs(newValues) do
                newCtx[key] = newValue
            end
            return newCtx

        end
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

return function (globalTree)
    _debug("in", globalTree)
    format(globalTree, newCtx())
    _debug("out", output)
    return outputToString()
end
