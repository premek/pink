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

    local peekCode = function()
        if isAtEnd() then return nil end
        return input:byte(current, current)
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

    local consumeIfAnyOf = function(...)
        for _, str in ipairs{...} do
            if ahead(str) then
                consume(str)
                return true, str
            end
        end
        return false, nil

    end

    local consumeWhitespace = function()
        while whitespaceAhead() do
            next()
        end
    end

    local consumeWhitespaceAndNewlines
    consumeWhitespaceAndNewlines = function()
        consumeWhitespace()
        if ahead('\n') then
            next()
            newline()
            consumeWhitespaceAndNewlines()
        end
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
        return input:sub(s, current-1):gsub("%s+", " ")
    end


    local text = function()
        local s = current

        -- TODO different kind of "text' when we are inside an option?
        -- or treat text differently than other tokens?
        -- TODO list allowed chars only
        while not aheadAnyOf('#', '->', '==', '<>', '//', ']', '[', '{', '}', '|', '/*', '\n') and not isAtEnd() do
            next()
        end
        return currentText(s)
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
        -- FIXME: https://github.com/inkle/ink/blob/master/Documentation/WritingWithInk.md#part-6-international-character-support-in-identifiers
        local c = peekCode()
        local first = true
        while c ~= nil and (
            -- TODO
            c==95 -- _
            or c==46 -- .
            or (c>=65 and c<=90) -- A-Z
            or (c>=97 and c<=122) -- a-z
            or (not first and c>=48 and c<=57)
            ) do -- TODO!


            next()
            c = peekCode()
            first = false
        end
        if s == current then -- nothing consumed
            errorAt('identifier expected')
        end
        return currentText(s)
    end

    local stringLiteral = function()
        consume('"')
        local s = current
        while not ahead('"') and not eolAhead() do
            next()
        end
        local val = currentText(s)
        consume('"')
        return {'str', val}
    end

    local number = function()
        local s = current
        if ahead('-') then
            next()
        end
        while aheadAnyOf('0','1', '2','3','4','5','6','7','8','9') do -- TODO
            next()
        end
        return currentText(s)
    end

    local floatLiteral = function(intPart)
        consume('.')
        return {'float', intPart..'.'..number()} -- TODO cast
    end

    local intLiteral = function()
        local val = number()
        if ahead('.') then
            return floatLiteral(val)
        end
        return {'int', val}
    end

    local term, expression; -- cross dependency, must be defined earlier

    local functionCall = function(functionName)
        consume('(')
        local result = {'call', functionName}
        while not ahead(')') do
            table.insert(result, expression())
            consumeWhitespace()
            if ahead(',') then
                consume(",")
                consumeWhitespace()
            end
        end
        consume(')')
        return result
    end


    term = function()
        if ahead('"') then
            return stringLiteral()
        end
        if aheadAnyOf('-', '0','1', '2','3','4','5','6','7','8','9') then -- TODO
            return intLiteral()
        end
        local id = identifier()
        consumeWhitespace()
        if ahead('(') then
            return functionCall(id)
        end
        return {'ref', id} -- FIXME same name as function argument passed as a reference
    end

    expression = function()
        local first = term()
        consumeWhitespace()
        local consumedAny, operator = consumeIfAnyOf('+', '-', '*', '/', '==')
        if consumedAny then
            consumeWhitespace()
            local second = term()
            return {'call', operator, first, second}
        end
        return first
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

    local divert = function()
        consume("->")
        consumeWhitespace()
        addStatement('divert', identifier())
    end

    local fn = function()
        consumeWhitespace()
        local res = {'fn', identifier()}
        if ahead('(') then
            consume('(')
            consumeWhitespace()
            if not ahead(')') then
                local param = {'param', identifier()}
                if param[2] == 'ref' then
                    consumeWhitespace()
                    param[2] = identifier()
                    param[3] = 'ref'
                end
                table.insert(res, param)
                consumeWhitespace()
                while ahead(',') do
                    consume(',')
                    consumeWhitespace()
                    -- FIXME duplicate
                    local param = {'param', identifier()}
                    if param[2] == 'ref' then
                        consumeWhitespace()
                        param[2] = identifier()
                        param[3] = 'ref'
                    end
                    table.insert(res, param)
                    consumeWhitespace()
                end
            end
            consume(')')
        end

        addStatement(table.unpack(res)) -- TODO unpack??
        consumeWhitespace()
        consumeAll('=')
    end

    local knot = function()
        consume("==")
        consumeAll('=')
        consumeWhitespace()
        local id = identifier()
        if id == 'function' then
            return fn()
        end

        addStatement('knot', id)
        consumeWhitespace()
        consumeAll('=')
        consumeWhitespaceAndNewlines()
    end

    local stitch = function()
        consume("=")
        consumeWhitespace()
        addStatement('stitch', identifier())
        consumeWhitespaceAndNewlines()
    end

    local option = function()
        local nesting = 0
        while ahead("*") do
            consume("*")
            nesting = nesting + 1
            consumeWhitespace()
        end

        local t1 = text()
        local t1EndWithWhitespace = t1:sub(-1) == ' '

        local t2 = ""
        if ahead('[') then
            consume('[')
            if t1EndWithWhitespace then
                consumeWhitespace()
            end

            t2 = text()
            consume(']')
        end

        if t1EndWithWhitespace then
            consumeWhitespace()
        end
        local t3 = text()


        addStatement('option', nesting, t1, t2, t3)
        consumeWhitespaceAndNewlines()
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
        addStatement('const', name, expression())
        consumeWhitespaceAndNewlines()
    end

    local variable = function()
        consume("VAR")
        consumeWhitespace()
        local name = identifier()
        consumeWhitespace()
        consume("=")
        consumeWhitespace()
        addStatement('var', name, expression())
        consumeWhitespaceAndNewlines()
    end

    local tempVariable = function()
        consume("temp")
        consumeWhitespace()
        local name = identifier()
        consumeWhitespace()
        consume("=")
        consumeWhitespace()
        addStatement('tempvar', name, expression()) --TODO better name? local var? var?
        consumeWhitespaceAndNewlines()
    end

    local list = function()
        consume("LIST")
        consumeWhitespace()
        local name = identifier()
        consumeWhitespace()
        consume("=")
        consumeWhitespace()

        local list = {'list', name, expression()}
        while not eolAhead() do
            consumeWhitespace()
            consume(",")
            consumeWhitespace()
            table.insert(list, expression())
        end
        addStatement(list)
        consumeWhitespaceAndNewlines()
    end

    local para = function()
        local t = text()
        if #t > 0 then
            addStatement('str', t)
        end
    end

    local alternative = function() --TODO name? used for sequences, variable printing, conditional text
        consume("{")
        consumeWhitespaceAndNewlines()
        local first = expression()

        if ahead(':') then
            consume(':')
            consumeWhitespaceAndNewlines()
            local ifTrue = text() -- FIXME ink text
            consumeWhitespaceAndNewlines()
            local ifFalse = nil
            if ahead('|') then
                consume('|')
                ifFalse = text() -- FIXME ink text
            end
            addStatement('if', first, ifTrue, ifFalse)

        elseif ahead('|') then
            local vals = {first}
            while ahead('|') do
                consume('|')
                table.insert(vals, expression())
            end
            addStatement('alt', table.unpack(vals))
        else
            addStatement('alt', first) -- TODO name - variable printing
        end
        -- TODO other types
        consume("}")
        para() -- don't ignore whitespace (TODO, same like glue)

    end


    local glue = function()
        consume("<>")
        addStatement('glue')
        if ahead('\n') then
            newline()
            next()
        end
        para() -- don't ignore whitespace after glue
    end

    local returnStatement = function()
        consume('return')
        consumeWhitespace()
        if eolAhead() then
            addStatement('return')
        else
            addStatement('return', expression())
        end
    end

    local statement = function()
        consume("~")
        consumeWhitespace()
        if ahead('return') then
            returnStatement()
        elseif ahead('temp') then
            tempVariable()
        else
            local id = identifier()
            consumeWhitespace()
            if ahead('(') then
                addStatement(table.unpack(functionCall(id))) -- TODO unpack??
                return
            elseif ahead('++') then
                consume('++')
                addStatement('call', '++', id)
                return
            elseif ahead('--') then
                consume('--')
                addStatement('call', '--', id)
                return
            elseif ahead('=') then
                consume('=')
                consumeWhitespace()
                addStatement('assign', id, expression())
                return
            end

            errorAt('unexpected statement near ' .. id)
        end
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
            addStatement('nl')
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
        elseif ahead('~') then
            statement()
        else
            para()
        end
    end

     --_debug(statements)
    return statements
end

