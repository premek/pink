--
-- Removes /*block*/ comments and then //line comments from input
--

return function(input)
    local inputLength, output, current

    local reset = function(str)
        input = str
        inputLength = #str
        current = 1
        output = {}
    end

    -- true if the 'current' pointer points *after* the last character of the input
    local isAtEnd = function()
        return current >= inputLength + 1
    end

    local peek = function(chars)
        return input:sub(current, current + chars - 1)
    end

    local skip = function()
        current = current + 1
    end

    local ahead = function(str)
        return str == peek(#str)
    end

    local eolAhead = function()
        return ahead('\n') or isAtEnd()
    end

    local out = function()
        table.insert(output, peek(1))
        skip()
    end

    local skipBlockComment = function()
        while not isAtEnd() do
            if ahead('/*') then
                while not ahead('*/') do
                    if eolAhead() then
                        out()
                    else
                        skip()
                    end
                end
                skip()
                skip()
            else
                out()
            end
        end
    end

    local skipLineComment = function()
        while not isAtEnd() do
            if ahead('//') then
                while not eolAhead() do
                    skip()
                end
            else
                out()
            end
        end
    end

    reset(input)
    skipBlockComment()
    reset(table.concat(output))
    skipLineComment()
    return table.concat(output)
end
