local debugOn = false
local _debug = function(...)
    if not debugOn then return end
    local args = {...}
    if #args == 0 then
        print('(nil)')
    end
    for _, x in ipairs(args) do
        print( require('test/lib/luaunit').prettystr(x) )
    end
end






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
local outNewLine = function(ctx)
    table.insert(output, {indent=ctx.indent})
end

local ctxWith = function(ctx, newValues)
    local newCtx = {}
    for key, oldValue in pairs(ctx) do
        newCtx[key] = oldValue
    end
    for key, newValue in pairs(newValues) do
        newCtx[key] = newValue
    end
    return newCtx
end
local resetIndent = function(ctx)
    output[#output].indent = ctx.indent
end

local outputToString = function()
    local o = {}
    for _, line in ipairs(output) do
        table.insert(line, 1, string.rep(' ', line.indent))
        table.insert(o, table.concat(line, ''))
    end
    return table.concat(o, '\n')
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

local binaryCallFormatter = function(name, args, ctx)
    out('(')
    format({args[1]}, ctx)
    out(') ', name, ' (')
    format({args[2]}, ctx)
    out(')')
end

local callFormatters = {
    ['=='] = binaryCallFormatter,
    ['>'] = binaryCallFormatter,
    ['>='] = binaryCallFormatter,
    ['<'] = binaryCallFormatter,
    ['<='] = binaryCallFormatter,
    ['mod'] = binaryCallFormatter,
    ['/'] = binaryCallFormatter,
    ['*'] = binaryCallFormatter,
    ['+'] = binaryCallFormatter,
    ['-'] = binaryCallFormatter
}


format = function(tree, ctx)



    for _, node in ipairs(tree) do
        _debug(node)
        local its = function(what)
            return is(node, what)
        end

        if its('ink') then
            format(node[2], ctx)
        elseif its('str') then
            out(node[2])
        elseif its('knot') then
            resetIndent(ctxWith(ctx, {indent=0}))
            outNewLine(ctxWith(ctx, {indent=0}))
            outNewLine(ctxWith(ctx, {indent=0}))
            out('=== ', node[2], ' ===')
            outNewLine(ctxWith(ctx, {indent=0}))
            format(node[4], ctxWith(ctx, {indent=0}))
        elseif its('fn') then
            resetIndent(ctxWith(ctx, {indent=0}))
            outNewLine(ctxWith(ctx, {indent=0}))
            outNewLine(ctxWith(ctx, {indent=0}))
            out('=== function ', node[2])
            if #node[3] > 0 then
                out('(')
            end
            for _, parameter in ipairs(node[3]) do
                -- TODO ref
                out(parameter[1])
            end
            if #node[3] > 0 then
                out(')')
            end
            out(' ===')
            outNewLine(ctxWith(ctx, {indent=0}))
            format(node[4], ctxWith(ctx, {indent=0}))
        elseif its('choice') then
            format(node[2], ctx)
        elseif its('option') then
            outNewLine(ctx)
            out(string.rep('*', node[2]))
            out('  ')
            format(node[3], ctx)
            out('[')
            format(node[4], ctx)
            out(']')
            format(node[5], ctx)
            format(node[9], ctxWith(ctx, {indent=ctx.indent+node[2]+2}))
        elseif its('divert') then
            out('-> ', node[2])
        elseif its('glue') then
            out('<>')
        elseif its('nl') then
            outNewLine(ctx)
        elseif its('comment') then
            out('// ', node[2])
        elseif its('out') then
            out('{')
            format({node[2]}, ctxWith(ctx, {mode='ev'}))
            out('}')
        elseif its('call') then
            if ctx.mode == 'out' then
                out('~ ')
            end
            local formatter = callFormatters[node[2]] or fnCallFormatter
            formatter(node[2], node[3], ctx)
        elseif its('if') then
            out('{')
            outNewLine(ctx+2)
            for _, branch in ipairs(node[2]) do
                _debug(branch)
                out('-  ')
                format({branch[1]}, ctxWith(ctx, {indent=ctx.indent+2}))
                out(':')
                outNewLine(ctxWith(ctx, {indent=ctx.indent+2}))
                format(branch[2], ctxWith(ctx, {indent=ctx.indent+2}))
            end

            outNewLine(ctx)
            out('}')

        elseif its('ref') then
            out(node[2]) --FIXME ref?
        elseif its('bool') or its('int') or its('float') or its('string') then
            out(tostring(node[2]))
        elseif its('const') then
            out('CONST ', node[2], ' = ')
            format({node[3]}, ctx)
            outNewLine(ctx)
        elseif its('var') then
            out('VAR ', node[2], ' = ')
            format({node[3]}, ctx)
            outNewLine(ctx)
        elseif its('tempvar') then
            if ctx.mode == 'out' then
                out('~ ')
            end
            out('temp ', node[2], ' = ')
            format({node[3]}, ctx)
            outNewLine(ctx)
        elseif its('assign') then
            if ctx.mode == 'out' then
                out('~ ')
            end

            out(node[2], ' = ')
            format({node[3]}, ctx)
            outNewLine(ctx)
        else
            _debug(node)
            err('unknown node')
        end
    end

end

return function (globalTree, debuggg)
    debugOn = debuggg
    _debug("in", globalTree)
    format(globalTree, {indent=0, mode='out'})
    _debug("out", output)
    return outputToString()
end
