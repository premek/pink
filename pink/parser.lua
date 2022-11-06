local debug = function(x) print( require('test/luaunit').prettystr(x) ) end

return function(tokenizer)

    local statements = {}

    local isAtEnd = function()
        return tokenizer.peek().type=='eof'
    end


    local addStatement = function(...)
        table.insert(statements, {...})
    end


    -- trim spaces at end.
    -- TODO get rid of this?
    local trimR = function(s)
        local trimmed = s:gsub("^%s+", ""):gsub("%s+$", "")
        return trimmed
    end


    while not isAtEnd() do
        local t = tokenizer.getNext()
        if t.type == 'knot' then
            addStatement('knot', trimR(tokenizer.getNext('text').text)) -- TODO get single word without spaces// the getNext must be able to set how to parse, not just check the type of what we are getting
            tokenizer.getNextIf('knot') -- eat closing knot if present// TODO eat single = also but only before end of line

        elseif t.type == 'text' then
            addStatement('para', t.text) 
        elseif t.type == 'glue' then -- TODO could be handled here?
            addStatement('glue')
        elseif t.type == 'divert' then
            addStatement('divert', trimR(tokenizer.getNext('text').text))
        elseif t.type == 'stitch' then
            addStatement('stitch', trimR(tokenizer.getNext('text').text))
        elseif t.type == 'tag' then
            addStatement('tag', tokenizer.getNext('text').text)
        elseif t.type == 'option' then
            local nesting = 1
            while tokenizer.getNextIf('option') do
                nesting = nesting + 1
            end
            local t1 = ''
            local t2 = ''
            local t3 = ''

            local t1Token = tokenizer.getNext() -- TODO expected only 'text' OR 'squareLeft'

            if t1Token.type=='text' then 
                t1 = trimR(t1Token.text)
            end

            if t1Token.type == 'squareLeft' or tokenizer.getNextIf('squareLeft') then -- FIXME method, token? naming
                local t2Token = tokenizer.getNextIf('text')
                if t2Token then
                    t2 = trimR(t2Token.text)
                end

                tokenizer.getNext('squareRight')
                local t3Token = tokenizer.getNextIf('text')
                if t3Token then
                    t3 = t3Token.text
                end
            end
            addStatement('option', nesting, t1, t2, t3)

        elseif t.type == 'gather' then
            local nesting = 1
            while tokenizer.getNextIf('gather') do
                nesting = nesting + 1
            end
            addStatement('gather', nesting, (tokenizer.getNext('text').text))

        elseif t.type == 'include' then
            addStatement('include', (tokenizer.getNext('text').text))
        elseif t.type == 'todo' then
            addStatement('todo', (tokenizer.getNext('text').text))
        end
    end

    return statements
end
