local _debug = function(x) print( require('test/luaunit').prettystr(x) ) end

return function(input, source)
    source = source or 'unknown source'

    local current=1
    local line = 1
    local column = 1
    local statements = {}

    local isAtEnd = function()
        return current >= #input
    end

    local newline = function()
        line = line + 1
        column = 1
    end

    local addStatement = function(...)
        table.insert(statements, {...})
    end

    local next = function(chars)
        chars = chars or 1
        column = column + chars
        current = current + chars -- todo error on unexpected eof
    end

    local peek = function(chars)
        if isAtEnd() then return nil end -- FIXME?
        return input:sub(current, current+chars-1)
    end

    local ahead = function(str)
        return str == peek(#str)
    end

    local aheadAnyOf = function(...)
        for _, str in ipairs{...} do
            if ahead(str) then
                return true
            end
        end
        return false
    end

    local whitespaceAhead = function()
        return aheadAnyOf(' ', '\r', '\t')
    end

    local eolAhead = function()
        return ahead('\n') or isAtEnd()
    end


    local errorAt = function(msg, ...)
        local formattedMsg = string.format(msg, ...)
        error(string.format(formattedMsg .. " at '%s', line %s, column %s", source, line, column))
    end

    local consume = function(str)
        if not ahead(str) then
            errorAt("expected '%s'", str)
        end
        next(#str)
    end

    local consumeAll = function(c)
        while ahead(c) do
            next()
        end
    end

    local consumeIfAhead = function(str) -- TODO better name?
        if not ahead(str) then
            return false
    end
    consume(str)
    return true
    end




    local singleLineComment = function()
        while not eolAhead() do
            next()
        end
    end

    local multiLineComment = function()
        while not ahead('*/') and not isAtEnd() do
            if ahead('\n') then
                newline()
            end
            next()
        end
        consume('*/')
    end


    local currentText = function(s)
        return input:sub(s, current-1)
    end


    local text = function()
        local s = current

        -- TODO different kind of "text' when we are inside an option?
        -- or treat text differently than other tokens?
        while not aheadAnyOf('#', '->', '==', '<>', '//', ']', '[', '{', '/*', '\n') and not isAtEnd() do
            next()
        end
        return currentText(s)
    end


    local para = function()
        local s = current
        local t = text()
        if current > s then
            addStatement('para', t)
        end
    end

    local textLine = function()
        local s = current
        while not eolAhead() do
            next()
        end
        return currentText(s)
    end

    local filename = function()
        return textLine()
    end

    local identifier = function()
        local s = current
        -- TODO list allowed chars instead!
        while not aheadAnyOf(' ', '}', ',') and not eolAhead() do
            next()
        end
        return currentText(s)
    end

    local stringValue = function()
        consume('"')
        local s = current
        while not ahead('"') and not eolAhead() do
            next()
        end
        local val = currentText(s)
        consume('"')
        return {'str', val}
    end

    local intValue = function()
        local s = current
        while aheadAnyOf('0','1', '2','3','4','5','6','7','8','9') do
            next()
        end
        local val = currentText(s)
        return {'int', val}
    end

    local value = function()
        if ahead('"') then
            return stringValue()
        end
        if aheadAnyOf('0','1', '2','3','4','5','6','7','8','9') then -- TODO
            return intValue()
        end
        return {'ref', identifier()}
    end

    local consumeWhitespace = function()
        while whitespaceAhead() do
            next()
        end
    end

    local include = function()
        consume("INCLUDE")
        consumeWhitespace()
        addStatement('include', filename())
    end

    local todo = function()
        consume("TODO:")
        consumeWhitespace()
        addStatement('todo', textLine())
    end

    local glue = function()
        consume("<>")
        addStatement('glue')
        para() -- don't ignore whitespace after glue
    end

    local divert = function()
        consume("->")
        consumeWhitespace()
        addStatement('divert', identifier())
    end

    local knot = function()
        consume("==")
        consumeAll('=')
        consumeWhitespace()
        addStatement('knot', identifier())
        consumeWhitespace()
        consumeAll('=')
    end

    local stitch = function()
        consume("=")
        consumeWhitespace()
        addStatement('stitch', identifier())
    end

    local option = function()
        local nesting = 0
        while ahead("*") do
            consume("*")
            nesting = nesting + 1
            consumeWhitespace()
        end

        local t1 = text()

        local t2 = ""
        if ahead('[') then
            next()
            t2 = text()
            consume(']')
        end
        local t3 = text()


        addStatement('option', nesting, t1, t2, t3)
    end

    local gather = function()
        local nesting = 0
        while ahead("-") do
            consume("-")
            nesting = nesting + 1
            consumeWhitespace()
        end

        addStatement('gather', nesting, text())
    end


    local tag = function()
        consume("#")
        consumeWhitespace()
        addStatement('tag', text())
    end

    local constant = function()
        consume("CONST")
        consumeWhitespace()
        local name = identifier()
        consumeWhitespace()
        consume("=")
        consumeWhitespace()
        addStatement('const', name, value())
    end

    local variable = function()
        consume("VAR")
        consumeWhitespace()
        local name = identifier()
        consumeWhitespace()
        consume("=")
        consumeWhitespace()
        addStatement('var', name, value())
    end

    local list = function()
        consume("LIST")
        consumeWhitespace()
        local name = identifier()
        consumeWhitespace()
        consume("=")
        consumeWhitespace()
        local values = {value()}
        while not eolAhead() do
            consumeWhitespace()
            consume(",")
            consumeWhitespace()
            table.insert(values, value())
        end
        addStatement('list', name, table.unpack(values))
    end

    local alternative = function() --TODO name? used for sequences, variable printing, conditional text
        consume("{")
        local vals = {}

        repeat
            table.insert(vals, value())
        until not consumeIfAhead('|') -- TODO more readable?

        -- TODO other types
        consume("}")
        addStatement('alt', table.unpack(vals)) -- TODO name
    end


    local maxIter = 3000 -- just for debugging -- TODO better safety catch

    local last = -1

    for i=1, maxIter do
        -- check something was consumend in last loop -- TODO
        if last==current then
            errorAt("nothing consumed")
        end
        last = current


        if i == maxIter then
            error('parser error? or input too long') -- FIXME
        end

        if isAtEnd() then
            --        addStatement('eof', nil, line, column, '')
            break
        end

        consumeWhitespace()

        if ahead('\n') then
            next()
            newline()
        elseif ahead('//') then
            singleLineComment()
        elseif ahead('/*') then
            multiLineComment()
        elseif ahead('TODO:') then
            todo()
        elseif ahead('INCLUDE') then
            include()
        elseif ahead('<>') then
            glue()
        elseif ahead('->') then
            divert()
        elseif ahead('==') then
            knot()
        elseif ahead('=') then
            stitch()
        elseif ahead('*') then
            option()
        elseif ahead('-') then
            gather()
        elseif ahead('#') then
            tag()
        elseif ahead('CONST') then
            constant()
        elseif ahead('VAR') then
            variable()
        elseif ahead('LIST') then
            list()
        elseif ahead('{') then
            alternative()
        else
            para()
        end
    end

    return statements
end
