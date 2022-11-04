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
            and peek(2) ~= '/*'
            and peek() ~= '\n'
            and not isAtEnd() do

            advance()
        end
        addToken('text')

    end

    local scanToken = function()
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
        elseif consume('//') then
            skipSingleLineComment()
        elseif consume('/*') then
            skipMultiLineComment()
        else
           text()
        end

    end

    while not isAtEnd() do
        start = current
        scanToken()
    end
    addTokenRaw('eof', nil, line, column, '')


    return tokens
end
