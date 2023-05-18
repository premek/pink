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
    local readable = function(s)
        if s == '\n' then
            return "newline"
        else
            return "'"..s.."'"
        end
    end

    local consume = function(str)
        if not ahead(str) then
            errorAt("expected " .. readable(str))
        end
        next(#str)
    end

    local consumeAll = function(c)
        while ahead(c) do
            next()
        end
    end

    local consumeAnyOf = function(...)
        for _, str in ipairs{...} do
            if ahead(str) then
                consume(str)
                return str
            end
        end
        errorAt("expected any of " .. table.concat(..., ", "))

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
        local result, _ = input:sub(s, current-1):gsub("%s+", " ")
        return result
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
        -- FIXME: https://github.com/inkle/ink/blob/master/Documentation
        -- /WritingWithInk.md#part-6-international-character-support-in-identifiers
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
        return {'float', tonumber(intPart..'.'..number())}
    end

    local intLiteral = function()
        local val = number()
        if ahead('.') then
            return floatLiteral(val)
        end
        return {'int', tonumber(val)}
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

        if ahead('(') then
            consume('(')
            consumeWhitespace()
            local exp = expression()
            consumeWhitespace()
            consume(')')
            return exp
        end

        if ahead('true') then
            consume('true')
            return {'bool', true}
        end
        if ahead('false') then
            consume('false')
            return {'bool', false}
        end



        local id = identifier()
        consumeWhitespace()
        if ahead('(') then
            return functionCall(id)
        end
        return {'ref', id} -- FIXME same name as function argument passed as a reference
    end

    local unary = {'not', '!'}

    -- precedence from lowest to highest
    local operatorList = {
        {'?'},
        {'or', '||', 'and', '&&'},
        {'!=', '=='},
        {'<=', '>=', '>', '<'},
        {'-', '+'},
        {'mod', '%', '/', '*'},
    }
    local operators = {}
    local precedence = {}
    for operatorPrecedence, operatorGroup in ipairs(operatorList) do
        for _, operator in ipairs(operatorGroup) do
            precedence[operator] = operatorPrecedence
            table.insert(operators, operator)
        end
    end

    expression = function()
        if aheadAnyOf(table.unpack(unary)) then
            local operator = consumeAnyOf(table.unpack(unary))
            consumeWhitespace()
            return {'call', operator, expression()}
        end

        -- The shunting yard algorithm
        local operandStack = {}
        local operatorStack = {}

        table.insert(operandStack, term())
        consumeWhitespace()

        while aheadAnyOf(table.unpack(operators)) do
            local operator = consumeAnyOf(table.unpack(operators))
            consumeWhitespace()

            while operatorStack[#operatorStack] ~= nil
                and precedence[operator] <= precedence[operatorStack[#operatorStack]] do

                local right = table.remove(operandStack)
                local left = table.remove(operandStack)
                local operatorFromStack = table.remove(operatorStack)
                table.insert(operandStack, {'call', operatorFromStack, left, right})
            end

            table.insert(operatorStack, operator)

            table.insert(operandStack, term())
            consumeWhitespace()
        end

        -- TODO cleanup
        while operatorStack[#operatorStack] ~= nil do
            local right = table.remove(operandStack)
            local left = table.remove(operandStack)
            local operatorFromStack = table.remove(operatorStack)
            table.insert(operandStack, {'call', operatorFromStack, left, right})
        end

        if #operandStack ~= 1 or #operatorStack ~= 0 then
            errorAt('expression parsing error')
        end

        return operandStack[1]
    end


    local include = function()
        consume("INCLUDE")
        consumeWhitespace()
        return {'include', filename()}
    end

    local todo = function()
        consume("TODO:")
        consumeWhitespace()
        {'todo', textLine()}
    end

    local divert = function()
        consume("->")
        consumeWhitespace()
        return {'divert', identifier()}
    end

    -- == function add(x,y) ==
    local fn = function()
        consumeWhitespace()
        local name = identifier()
        local result = {'fn', name}

        if ahead('(') then
            consume('(')
            consumeWhitespace()
            while not ahead(')') do
                local paramName = identifier()
                local passedByReference = false
                if paramName == 'ref' then
                    -- === function alter(ref x, k) ===
                    consumeWhitespace()
                    paramName = identifier()
                    passedByReference = true
                end
                table.insert(result, {'param', paramName, passedByReference})
                consumeWhitespace()
                if ahead(',') then
                    consume(',')
                    consumeWhitespace()
                end
            end
            consume(')')
        end

        consumeWhitespace()
        consumeAll('=')
        return result
    end

    local knot = function()
        consume("==")
        consumeAll('=')
        consumeWhitespace()
        local id = identifier()
        if id == 'function' then
            return fn()
        end

        consumeWhitespace()
        consumeAll('=')
        consumeWhitespaceAndNewlines()
        return {'knot', id}
    end

    local stitch = function()
        consume("=")
        consumeWhitespace()
        local id = identifier()
        consumeWhitespace()
        consume('\n')
        consumeWhitespaceAndNewlines()
        return {'stitch', id}
    end

    local option = function(bulletSymbol)
        local nesting = 0
        local sticky = (bulletSymbol == '+') and "sticky" or "nonstick"
        local conditions = {}

        while ahead(bulletSymbol) do
            consume(bulletSymbol)
            nesting = nesting + 1
            consumeWhitespace()
        end

        -- FIXME { or ( first?
        local label = nil
        if ahead('(') then
            consume('(')
            label = identifier()
            consume(')')
            consumeWhitespace()
        end

        while ahead('{') do
            consume('{')
            consumeWhitespace()
            table.insert(conditions, expression())
            consumeWhitespace()
            consume('}')
            consumeWhitespaceAndNewlines()
        end

        local t1 = text():match "(.-)%s*$" -- right trim

        local t2 = ""
        if ahead('[') then
            consume('[')
            t2 = text()
            consume(']')
        end

        local t3 = text()

        consumeWhitespaceAndNewlines()
        return {'option', nesting, t1, t2, t3, label, sticky, table.unpack(conditions)}
    end

    local gather = function()
        local nesting = 0
        while ahead("-") do
            consume("-")
            nesting = nesting + 1
            consumeWhitespace()
        end

        local label = nil
        if ahead('(') then
            consume('(')
            label = identifier()
            consume(')')
            consumeWhitespace()
        end
        return {'gather', nesting, text(), label}
    end


    local tag = function()
        consume("#")
        consumeWhitespace()
        return {'tag', text()}
    end

    local constant = function()
        consume("CONST")
        consumeWhitespace()
        local name = identifier()
        consumeWhitespace()
        consume("=")
        consumeWhitespace()
        local value = expression()
        consumeWhitespaceAndNewlines()
        return {'const', name, value}
    end

    local variable = function()
        consume("VAR")
        consumeWhitespace()
        local name = identifier()
        consumeWhitespace()
        consume("=")
        consumeWhitespace()
        local value = expression()
        consumeWhitespaceAndNewlines()
        return {'var', name, value}
    end

    local tempVariable = function()
        consume("temp")
        consumeWhitespace()
        local name = identifier()
        consumeWhitespace()
        consume("=")
        consumeWhitespace()
        local value = expression()
        consumeWhitespaceAndNewlines()
        return {'tempvar', name, value} --TODO better name? local var? var?
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
        consumeWhitespaceAndNewlines()
        return list
    end

    local para = function()
        local t = text()
        if #t > 0 then
            return {'str', t}
        end
    end

    local alternative = function() --TODO name? used for sequences, variable printing, conditional text, cond. option
        consume("{")
        consumeWhitespaceAndNewlines()
        local first = expression()
        local result -- FIXME

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
            result = {'if', first, ifTrue, ifFalse}

        elseif ahead('|') then
            local vals = {first}
            while ahead('|') do
                consume('|')
                table.insert(vals, expression())
            end
            result= {'alt', table.unpack(vals)}
        else
            result={'alt', first} -- TODO name - variable printing
        end
        -- TODO other types
        consumeWhitespace()
        consume("}")
        para() -- don't ignore whitespace (TODO, same like glue)
        return result
    end


    local glue = function()
        consume("<>")
        if ahead('\n') then
            newline()
            next()
        end
        para() -- don't ignore whitespace after glue TODO
        return {'glue'}
    end

    local returnStatement = function()
        consume('return')
        consumeWhitespace()
        if eolAhead() then
            return {'return'}
        else
            return {'return', expression()}
        end
    end

    local statement = function()
        consume("~")
        consumeWhitespace()
        if ahead('return') then
            return returnStatement()
        elseif ahead('temp') then
            return tempVariable()
        else
            local id = identifier()
            consumeWhitespace()
            if ahead('(') then
                return functionCall(id)
            elseif ahead('++') then
                consume('++')
                return {'call', '++', id}
            elseif ahead('--') then
                consume('--')
                return {'call', '--', id}
            elseif ahead('=') then
                consume('=')
                consumeWhitespace()
                return {'assign', id, expression()}
            end

            errorAt('unexpected statement near ' .. id)
        end
    end

    local inkText = function()
        if isAtEnd() then
            return
        end

        local startCursor = current

        consumeWhitespace()

        if ahead('\n') then
            next()
            newline()
            return {'nl'}
        elseif ahead('//') then
            return singleLineComment()
        elseif ahead('/*') then
            return multiLineComment()
        elseif ahead('TODO:') then
            return todo()
        elseif ahead('INCLUDE') then
            return include()
        elseif ahead('<>') then
            return glue()
        elseif ahead('->') then
            return divert()
        elseif ahead('==') then
            return knot()
        elseif ahead('=') then
            return stitch()
        elseif ahead('*') then
            return option('*')
        elseif ahead('+') then
            return option('+')
        elseif ahead('-') then
            return gather()
        elseif ahead('#') then
            return tag()
        elseif ahead('CONST') then
            return constant()
        elseif ahead('VAR') then
            return variable()
        elseif ahead('LIST') then
            return list()
        elseif ahead('{') then
            return alternative()
        elseif ahead('~') then
            return statement()
        else
            return para()
        end

        if current == startCursor then
            errorAt("nothing consumed")
        end
    end

    local maxIter = 3000 -- just for debugging -- TODO better safety catch

    for i=1, maxIter do
        if i == maxIter then
            error('parser error? or input too long') -- FIXME
        end

        if isAtEnd() then
            --        addStatement('eof', nil, line, column, '')
            break
        end

        local node = inkText()
        table.insert(statements, node)

    end

    --_debug(statements)
    return statements
end

