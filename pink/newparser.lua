local debug = function(x) print( require('test/luaunit').prettystr(x) ) end

return function(fileOrInk, fileReader)

    local start=1
    local current=1
    local line = 1
    local source = fileReader and fileReader(fileOrInk) or fileOrInk --FIXME
    local tokens = {}

    local isAtEnd = function()
        return current >= #source
    end

    local currentChar = function() return source:sub(current, current) end
    local next = function() current=current+1 end

    local advance = function()
        local char = currentChar()
        next()
        return char
    end

    local peek = function()
        if isAtEnd() then return '\0' end -- FIXME?
        return currentChar()
    end

    local addToken = function(tokenType, literal)
        table.insert(tokens, {tokenType, literal})
    end

    local string = function()
        while peek() ~= '\n' and not isAtEnd() do
            next()
        end

        addToken ('para', source:sub(start, current-1))
    end

    local knot = function()
        local leading = 1
        while peek() == '=' or peek() == ' ' do
            leading = leading + 1
            next()
        end
        while peek() ~= '=' and peek()~=' ' and peek() ~= '\n' do -- TODO must be single word 
            next() 
        end

        addToken ('knot', source:sub(start+leading, current-1))
        
        while peek() ~= '\n' and not isAtEnd() do -- check isAtEnd is everywhere so there are no infinite loops
            next() 
        end

    end

    local stitch = function()
        local leading = 1
        while peek() == ' ' do
            leading = leading + 1
            next()
        end

        while peek()~=' ' and peek() ~= '\n' do -- TODO must be single word 
            next() 
        end

        addToken('stitch', source:sub(start+leading, current-1))
    end


    while not isAtEnd() do
        start = current
        local c = advance()
        print(c)
        if c == ' ' or c == '\r' or c == '\t' then 
            -- nothing
        elseif c == '\n' then 
            line = line + 1
        elseif c == '=' then 
            if peek() == '=' then
                knot()
            else
                stitch()
            end
        else 
            string()
        end
    end
    -- addToken('eof')


    return tokens
end
