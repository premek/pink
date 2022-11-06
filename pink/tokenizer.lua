return function(source)

    local start=1
    local current=1
    local line = 1
    local column = 1
    local tokens = {}

    local isAtEnd = function()
        return current >= #source
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

    local advance = function()
        local char = currentChar()
        next()
        return char
    end

    local peek = function(chars)
        if isAtEnd() then return '\0' end -- FIXME?
        return currentChar(chars)
    end

    local consume = function(str)
        if str ~= source:sub(start, start+#str-1) then
            return false
        end

        next(#str-1)
        return true
    end

    local addTokenRaw = function(type, literal, tokenLine, tokenColumn, text)
        table.insert(tokens, {type=type, literal=literal, line=tokenLine, column=tokenColumn, text=text})
    end

    local addToken = function(type, literal)
        local text = source:sub(start, current-1)
        addTokenRaw(type, literal, line, column-#text, text)
    end

    local newline = function()
        line = line + 1
        column = 1
    end

    local skipSingleLineComment = function()
            while peek() ~= '\n' and not isAtEnd() do
                advance()
            end
    end

    local skipMultiLineComment = function()
            while peek(2) ~= '*/' and not isAtEnd() do
                if peek() == '\n' then
                    newline()
                end
                advance()
            end
            next(2)
            -- TODO consume('*/') -- TODO fail if its not there
    end

    local text = function()
        while peek() ~= '#'
            and peek(2) ~= '->'
            and peek(2) ~= '=='
            and peek(2) ~= '<>'
            and peek(2) ~= '//'
            and peek() ~= ']' -- TODO different kind of "text' when we are inside an option? normal text would not stop on these?
            and peek() ~= '['
            and peek(2) ~= '/*'
            and peek() ~= '\n'
            and not isAtEnd() do

            advance()
        end
        addToken('text')

    end

    local scanToken = function()
        start = current
        
        local c = advance()
        if c == ' ' or c == '\r' or c == '\t' then
            -- skip
        elseif c == '\n' then
            newline()
        elseif c == '#' then
            addToken('tag')
        elseif c == '*' then
            addToken('option')
        elseif consume('==') then
            while peek() == '=' do 
                advance() 
            end
            addToken('knot')
        elseif c == '=' then
            addToken('stitch')
        elseif consume('TODO:') then
            addToken('todo')
        elseif consume('INCLUDE') then
            addToken('include')
        elseif consume('->') then
            addToken('divert')
        elseif c == '-' then
            addToken('gather')            
        elseif consume('<>') then
            addToken('glue')
        elseif consume('[') then
            addToken('squareLeft')
        elseif consume(']') then
            addToken('squareRight')
        elseif consume('//') then
            skipSingleLineComment()
        elseif consume('/*') then
            skipMultiLineComment()
        else
           text()
        end

    end

    local scanAll = function()
        while not isAtEnd() do
            scanToken()
        end
        addTokenRaw('eof', nil, line, column, '')

    end

    local scanSome = function()
        while #tokens == 0 do
            if not isAtEnd() then
                scanToken()
            else
                addTokenRaw('eof', nil, line, column, '')
            end
        end
    end

    return {
        getAll = function ()
            scanAll()
            return tokens
        end,

        peek = function() 
            if #tokens == 0 then
                scanSome()
            end
            return tokens[1]
        end,

        -- expectedType optional
        -- if provided the next token must be of the given type - error otherwise
        -- the token is removed from the queue and returned
        -- if no expected type, the next token is removed and returned whatever type it is

        getNext = function(expectedType)
            if #tokens == 0 then
                scanSome()
            end
            if expectedType then
                assert(tokens[1].type == expectedType, "expected: "..expectedType..", got: "..tokens[1].type.." at line "..tokens[1].line..", col "..tokens[1].column)
            end
            return table.remove(tokens, 1)
        end,

        -- if the next token is of the given type it's removed from the queue and returned.
        -- Otherwise the next token stays in the queue and nil is returned
        -- expectedType required

        getNextIf = function(expectedType)
            if #tokens == 0 then
                scanSome()
            end
            if tokens[1].type == expectedType then
                return table.remove(tokens, 1)
            end
            return nil
        end
    }
end
