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

    -- true if the 'current' pointer points *after* the last character of the input
    local isAtEnd = function()
        return current >= inputLength + 1
    end

    local nextLine = function()
        line = line + 1
        column = 1
    end

    local next = function()
        column = column + 1
        current = current + 1
    end

    local peek = function(chars)
        if isAtEnd() then
            return nil
        end
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

    local wordCharAhead = function()
        local char = peek(1)
        return char ~= nil and isWordChar(char)
    end

    local digitAhead = function()
        return aheadAnyOf(unpack(digits))
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

    -- 2 or more equal signs
    local scanEqualEqual = function()
        if not ahead('==') then
            return
        end
        local start = current
        local location = getLocation()
        while ahead('=') do
            next()
        end
        return token('==', location, currentText(start))
    end

    -- string of 0-9s
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

    -- a symbol that could have a meaning
    local scanSymbol = function()
        for _, s in ipairs(symbols) do
            if ahead(s) then
                local location = getLocation()
                for _ = 1, #s do
                    next()
                end
                return token(s, location)
            end
        end
    end

    -- could be an identifier, keyword, output
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
        return token('word', location, currentText(start))
    end

    -- anything else - not a recognised symbol, cannot be a part of identifier
    -- Scan one by one to keep it simple
    local scanText = function()
        local location = getLocation()
        local t = peek(1)
        next()
        return token('text', location, t)
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
        for _, scanner in ipairs(scanners) do
            local t = scanner()
            if t then
                table.insert(tokens, t)
                break
            end
        end
    end
    table.insert(tokens, token('eof', getLocation()))

    log.debug(input)
    -- debug(tokens)
    -- log.debug(tokens)
    return tokens
end
