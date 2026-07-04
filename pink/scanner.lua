--
-- A homemade scanner
--
local base_path = (...):match('(.-)[^%.]+$')
local logging = require(base_path .. 'logging')
local log = logging.newLogger()

local unpack = table.unpack or unpack

local charsRange = function(tbl, from, to)
    for i = string.byte(from), string.byte(to or from) do
        tbl[string.char(i)] = true
    end
end

local whitespace = { ' ', '\r', '\t' }

local digits = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' }

local symbols = {
    '->->',
    '>=',
    '<>',
    '<=',
    '<-',
    '//',
    '/*',
    '*/',
    '!=',
    '!?',
    '->',
    '+=',
    '-=',
    '||',
    '++',
    '--',
    '&&',
    --longer first
    '.',
    '~',
    '>',
    '=',
    '<',
    '+',
    '^',
    '%',
    '#',
    '/',
    '\\',
    '*',
    '}',
    '{',
    ']',
    '[',
    ')',
    '(',
    '?',
    '!',
    '&',
    ',',
    '-',
    '|',
    ':',
    '"',
}
local keywords = {
    'VAR',
}
local softkeywords = {
    'TODO',
    'INCLUDE',
    'CONST',
    'EXTERNAL',
    'LIST',
    'false',
    'true',
    'temp',
    'return',
    'else',
    'stopping',
    'shuffle',
    'once',
    'cycle',
    'not',
    'or',
    'and',
    'hasnt',
    'has',
    'mod',
    'ref',
}

-- words could be identifiers, keywords or just words to output
local wordChars = {}
charsRange(wordChars, '_')
charsRange(wordChars, 'A', 'Z')
charsRange(wordChars, 'a', 'z')
charsRange(wordChars, '0', '9')

local keywordsLookup = {}
for _, keyword in ipairs(keywords) do
    keywordsLookup[keyword] = true
end

local softKeywordsLookup = {}
for _, softKeyword in ipairs(softkeywords) do
    softKeywordsLookup[softKeyword] = true
end

local isWordChar = function(char)
    return wordChars[char] or string.byte(char) > 127
end

local debug = function(tokens)
    if not logging.debugEnabled then
        return
    end
    log.debug('DEBUG TOKENS')
    for _, token in ipairs(tokens) do
        if token.type == 'newline' then
            print()
        elseif token.type == 'whitespace' or token.type == 'word' or token.type == 'text' then
            io.stdout:write(token.literal)
            io.stdout:write('•')
        else
            local lit = ''
            if token.literal then
                lit = ':' .. token.literal
            end
            io.stdout:write(token.type .. lit)
            io.stdout:write('◦')
        end
    end
    print()
end

return function(input, source)
    source = source or 'unknown source'

    local inputLength = #input

    local current = 1
    local line = 1
    local column = 1

    local tokens = {}

    local errorAt = function(msg, ...)
        local formattedMsg = string.format(msg, ...)
        error(
            string.format(formattedMsg .. "\n\tat '%s', line %s, column %s", source, line, column)
                .. '\n\t...\n\t'
                .. input:sub(math.max(0, current - 100), current)
                .. '\n\t'
                .. '<<somewhere around here>>'
                .. '\n\t'
                .. input:sub(current + 1, current + 100)
                .. '...\n\t'
        )
    end

    -- true if the 'current' pointer points *after* the last character of the input
    local isAtEnd = function()
        return current >= inputLength + 1
    end

    local nextLine = function()
        line = line + 1
        column = 1
    end

    local next = function(chars)
        chars = chars or 1
        column = column + chars
        current = current + chars -- todo error on unexpected eof
    end

    local peek = function(chars)
        if isAtEnd() then
            return nil
        end -- FIXME?
        return input:sub(current, current + chars - 1)
    end

    local ahead = function(str)
        return str == peek(#str)
    end

    local aheadAnyOf = function(...)
        for _, str in ipairs({ ... }) do
            if ahead(str) then
                return true
            end
        end
        return false
    end

    local whitespaceAhead = function()
        return aheadAnyOf(unpack(whitespace))
    end

    local eolAhead = function()
        return ahead('\n') or isAtEnd()
    end
    local wordCharAhead = function()
        local char = peek(1)
        return char ~= nil and isWordChar(char)
    end

    local digitAhead = function()
        return aheadAnyOf(unpack(digits))
    end

    local readable = function(s)
        if s == '\n' then
            return 'newline'
        else
            return "'" .. s .. "'"
        end
    end

    local consume = function(str)
        if not ahead(str) then
            errorAt('expected ' .. readable(str))
        end
        next(#str)
    end

    local currentText = function(startPos)
        return input:sub(startPos, current - 1)
    end

    local consumeWhitespace = function()
        local start = current
        while whitespaceAhead() do
            next()
        end
        return currentText(start)
    end

    local getLocation = function()
        return { source = source, line = line, column = column }
    end

    local token = function(type, location, literal)
        return {
            type = type,
            literal = literal,
            location = location,
        }
    end

    local getText = function(opts) -- TODO cleanup
        local s = current
        local result = ''
        -- TODO list allowed chars only?
        -- FIXME this is wierd
        --
        --
        while not eolAhead() do
            -- opts.onlyStopAt replaces the default stop list entirely (eol always stops)
            if opts and opts.onlyStopAt then
                if aheadAnyOf(unpack(opts.onlyStopAt)) then
                    break
                end
            else
                if aheadAnyOf(unpack(symbols)) or wordCharAhead() or whitespaceAhead() then
                    break
                end
                if opts and opts.stopAt and aheadAnyOf(unpack(opts.stopAt)) then
                    break
                end
            end
            next()
        end
        return result .. currentText(s)
    end

    local scanText = function()
        local location = getLocation()
        local t = getText()
        if #t > 0 then
            return token('text', location, t)
        end
    end

    local scanWord = function()
        if not wordCharAhead() then
            return
        end
        local start = current
        local location = getLocation()
        -- FIXME: https://github.com/inkle/ink/blob/master/Documentation
        -- /WritingWithInk.md#part-6-international-character-support-in-identifiers
        while wordCharAhead() do
            next()
        end
        local t = currentText(start)
        if keywordsLookup[t] then
            return token(t, location)
        end
        if softKeywordsLookup[t] then
            return token('softkeyword', location, t)
        end
        return token('word', location, currentText(start))
    end

    local scanDigits = function()
        if not digitAhead() then
            return
        end
        local start = current
        local location = getLocation()
        while digitAhead() do
            next()
        end
        return token('digits', location, currentText(start))
    end

    -- 2 or more equal signs
    local scanEqualEqual = function()
        if not ahead('==') then
            return
        end
        local start = current
        local location = getLocation()
        consume('==')
        while ahead('=') do
            next()
        end
        return token('==', location, currentText(start)) -- TODO stores location of the end of token, not beginning
    end

    local scanSymbol = function()
        for _, s in ipairs(symbols) do
            if ahead(s) then
                local location = getLocation()
                consume(s)
                return token(s, location)
            end
        end
    end

    local scanWhitespace = function()
        if whitespaceAhead() then
            local location = getLocation()
            return token('whitespace', location, consumeWhitespace())
        end
    end

    local scanNewline = function()
        if ahead('\n') then
            local location = getLocation()
            next()
            nextLine()
            return token('newline', location)
        end
    end

    local scanners = {
        scanWhitespace,
        scanNewline,
        scanEqualEqual,
        scanDigits,
        scanSymbol,
        scanWord,
        scanText,
    }

    while not isAtEnd() do
        local loopStart = current

        for _, scanner in ipairs(scanners) do
            local t = scanner()
            if t then
                table.insert(tokens, t)
                break
            end
        end

        if loopStart == current then
            log.debug(tokens)
            errorAt('nothing consumed')
        end
    end
    table.insert(tokens, token('eof', getLocation()))

    log.debug(input)
    debug(tokens)
    log.debug(tokens)
    return tokens
end
