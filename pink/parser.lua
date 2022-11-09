local debug = function(x) print( require('test/luaunit').prettystr(x) ) end

return function(source)
    local start=1
    local current=1
    local line = 1
    local column = 1
    local statements = {}

    local isAtEnd = function()
        return current >= #source
    end

    local newline = function()
        line = line + 1
        column = 1
    end


    local addStatement = function(...)
        table.insert(statements, {...})
    end

    local currentChar = function(chars)
        chars = chars or 1
        return source:sub(current, current+chars-1)
    end

    local next = function(chars)
        chars = chars or 1
        column = column + chars
        current = current + chars
    end

    local peek = function(chars)
        if isAtEnd() then return nil end -- FIXME?
        return currentChar(chars)
    end
    local ahead = function(str)
        return str == peek(#str)
    end

    local errorAt = function(msg, ...)
        local formattedMsg = string.format(msg, unpack(...)) -- unpack must be last argument
        error(string.format(formattedMsg .. " at line %s, column %s", line, column))
    end

    local consume = function(str)
        if str ~= source:sub(current, current+#str-1) then
            errorAt("expected '%s'", str)
        end
        next(#str)
    end

    local consumeAll = function(c)
        while ahead(c) do
            next()
        end
    end




    local singleLineComment = function()
        while peek() ~= '\n' and not isAtEnd() do
            next()
        end
    end

    local multiLineComment = function()
        while peek(2) ~= '*/' and not isAtEnd() do
            if peek() == '\n' then
                newline()
            end
            next()
        end
        consume('*/')
    end


    local currentText = function(s)
        s = s or start
        return source:sub(s, current-1)
    end


    local text = function()
        local s = current

        while peek() ~= '#'
            and peek(2) ~= '->'
            and peek(2) ~= '=='
            and peek(2) ~= '<>'
            and peek(2) ~= '//'
            and peek() ~= ']' -- TODO different kind of "text' when we are inside an option?
            and peek() ~= '['
            and peek(2) ~= '/*'
            and peek() ~= '\n'
            and not isAtEnd() do

            next()
        end
        return currentText(s)
    end


    local para = function()
        addStatement('para', text())
    end


    local textLine = function()
        local s = current
        while peek() ~= '\n' and not isAtEnd() do --FIXME -- TODO make sure isAtEnd is not forgotten in any loop
            next()
        end
        return currentText(s)
    end

    local filename = function()
        return textLine()
    end

    local identifier = function()
        local s = current
        --FIXME -- TODO make sure isAtEnd is not forgotten in any loop
        while peek() ~= '\n' and peek() ~= ' ' and not isAtEnd() do
            next()
        end
        return currentText(s)
    end


    local consumeWhitespace = function()
        while true do
            local c = peek()
            if c == ' ' or c == '\r' or c == '\t' then
                next()
            else
                return
            end
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
        repeat
            consume("*")
            nesting = nesting + 1
            consumeWhitespace()
        until not ahead("*")

        local t1 = text()
        if ahead('[') then next() end
        local t2 = text()
        if ahead(']') then next() end
        local t3 = text()


        addStatement('option', nesting, t1, t2, t3)
    end

    local gather = function()
        local nesting = 0
        repeat
            consume("-")
            nesting = nesting + 1
            consumeWhitespace()
        until not ahead("-")

        addStatement('gather', nesting, text())
    end


    local tag = function()
        consume("#")
        consumeWhitespace()
        addStatement('tag', text())
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

        start = current

        local c = peek() --FIXME peek or advance
        --print(c)

        if c == ' ' or c == '\r' or c == '\t' then
            next()
            -- skip
        elseif c == '\n' then
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
            glue() -- TODO should probably be handled inside text(), to preserve whitespace? or not?
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
        else
            para()
        end
    end

    return statements
end
