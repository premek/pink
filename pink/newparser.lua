local debug = function(x) print( require('test/luaunit').prettystr(x) ) end

return function(source)

    local start=1
    local current=1
    local line = 1
    local tokens = {}

    local isAtEnd = function()
        return current >= #source
    end

    local currentChar = function(chars) 
        chars = chars or 1
        return source:sub(current, current+chars-1)
    end
    
    local next = function(chars) current=current+(chars or 1) end

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
        if str ~= source:sub(start, start+str:len()-1) then
            return false
        end

        next(str:len()-1)
        return true
    end

    local addToken = function(...)
        table.insert(tokens, {...})
    end

    local para = function()
        while peek() ~= '\n' and peek() ~= '#' and peek(2) ~= '->' and not isAtEnd() do -- TODO -> might be needed elsewhere too
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

    local tag = function()
        local leading = 1
        while peek() == ' ' do
            leading = leading + 1
            next()
        end

        while peek() ~= '\n' and peek() ~= '#' do 
            next()
        end

        addToken('tag', source:sub(start+leading, current-1))

    end

    local option = function()
        local nested = 1
        local leading = 1
        while peek() == ' ' or peek()=='\t' or peek() == '*' do -- TODO peek whitespace
            leading = leading + 1
            if peek()=='*' then
                nested = nested + 1
            end
            next()
        end
        -- TODO eh

        while peek() ~= '[' and peek() ~= '\n' and peek() ~= '#' and not isAtEnd() do 
            next()
        end
        
        local part1 = source:sub(start+leading, current-1)

        if peek() == '[' then
            next()
        end

        local part2start = current

        while peek() ~= ']'  and peek() ~= '\n' and peek() ~= '#' and not isAtEnd()  do 
            next()
        end

        local part2 = source:sub(part2start, current-1)

        if peek() == ']' then
            next()
        end

        local part3start = current
        
        while peek() ~= '\n' and peek() ~= '#' and peek(2) ~= '->' and not isAtEnd() do  -- TODO -> everywhere
            next()
        end
        local part3 = source:sub(part3start, current-1)


        addToken('option', nested, part1, part2, part3)
    end

    local include = function()
        while peek() == ' ' do -- TODO peek whitespace
            next()
        end
        local includeStart = current
        while peek() ~= '\n' and not isAtEnd() do 
            next()
        end

        addToken('include', source:sub(includeStart, current-1))
    end

    local divert = function()
        while peek() == ' ' do -- TODO peek whitespace
            next()
        end
        local s = current
        while peek() ~= '\n' and peek() ~= ' ' and not isAtEnd() do 
            next()
        end

        addToken('divert', source:sub(s, current-1))
    end




    while not isAtEnd() do
        start = current
        local c = advance()
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
        elseif c == '#' then
            tag()
        elseif c == '*' then
            option()
        elseif c == 'I' and consume('INCLUDE') then -- TODO
            include()
        elseif c == '-' and consume('->') then -- TODO
            divert()
        else 
            para()
        end
    end
    -- addToken('eof')


    return tokens
end
