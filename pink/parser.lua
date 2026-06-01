local base_path = (...):match('(.-)[^%.]+$')
local logging = require(base_path .. 'logging')
local log = logging.newLogger()
local node = require(base_path .. 'node')

local unpack = table.unpack or unpack

return function(input, source)
    log.debug(input)

    source = source or 'unknown source'

    local current = 1
    local line = 1
    local column = 1

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

    local newMark = function()
        return {
            current = current,
            line = line,
            column = column,
        }
    end

    local resetTo = function(mark)
        current = mark.current
        line = mark.line
        column = mark.column
    end

    -- true if the 'current' pointer points *after* the last character of the input
    local isAtEnd = function()
        return current >= #input + 1
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
        if isAtEnd() then
            return nil
        end -- FIXME?
        return input:sub(current, current + chars - 1)
    end

    -- one char at position 'pos'
    local peekAt = function(pos)
        return input:sub(pos, pos)
    end

    -- TODO is this needed?
    local isLineStart = function()
        for i = current - 1, 1, -1 do
            local char = peekAt(i)
            if char == '\n' then
                return true
            elseif char == ' ' or char == '\t' then
                local _ -- keepSearching
            else
                -- non-whitespace characters between newline and 'current' position
                return false
            end
        end
        return true -- start of the first line
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
        return aheadAnyOf(' ', '\r', '\t')
    end

    local eolAhead = function()
        return ahead('\n') or isAtEnd()
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

    local consumeAll = function(c)
        while ahead(c) do
            next()
        end
    end

    local consumeAnyOf = function(...)
        for _, str in ipairs({ ... }) do
            if ahead(str) then
                consume(str)
                return str
            end
        end
        errorAt('expected any of ' .. table.concat(..., ', '))
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

    local token = function(n)
        n.location = { source, line, column }
        return n
    end
    local nl = function()
        next()
        newline()
        consumeWhitespace()
        return token(node.nl())
    end

    local currentText = function(startPos)
        return input:sub(startPos, current - 1)
    end

    local text -- forward declaration; defined below after singleLineComment

    local singleLineComment = function()
        consume('//')
        consumeWhitespace()
        local commentText = text({ onlyStopAt = {} })
        consumeWhitespace()
        return token(node.comment(commentText))
    end

    local multiLineComment = function()
        if not ahead('/*') then
            return
        end
        consume('/*')
        consumeWhitespace()
        local s = current
        while not ahead('*/') and not isAtEnd() do
            if ahead('\n') then
                newline()
            end
            next()
        end
        local commentText = currentText(s)
        consume('*/')
        consumeWhitespaceAndNewlines()
        -- we have to return something so the caller does not stop here
        return token(node.comment(commentText))
    end

    text = function(opts)
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
                if aheadAnyOf('#', '->', '<-', '==', '<>', '//', '{', '}', '|', '/*') then
                    break
                end
                if opts and opts.stopAt and aheadAnyOf(unpack(opts.stopAt)) then
                    break
                end
            end
            if not ahead('\\') then
                next()
            else
                -- skip the backslash
                result = result .. currentText(s)
                next()
                s = current

                -- a comment will be a comment anyway
                if not aheadAnyOf('//', '/*') then
                    -- if not a comment, get the escaped character
                    result = result .. peek(1)
                    next()
                    s = current
                end
            end
        end
        return result .. currentText(s)
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

    local charsRange = function(tbl, from, to)
        for i = string.byte(from), string.byte(to or from) do
            tbl[string.char(i)] = true
        end
    end
    local identifierChars = {}
    charsRange(identifierChars, '_')
    charsRange(identifierChars, 'A', 'Z')
    charsRange(identifierChars, 'a', 'z')
    charsRange(identifierChars, '0', '9')

    local identifierCharAhead = function()
        local char = peek(1)
        return char ~= nil and (identifierChars[char] or string.byte(char) > 127)
    end

    local identifier = function()
        if not identifierCharAhead() then
            errorAt('identifier expected')
        end
        local s = current
        -- FIXME: https://github.com/inkle/ink/blob/master/Documentation
        -- /WritingWithInk.md#part-6-international-character-support-in-identifiers
        while identifierCharAhead() do
            next()
        end

        return currentText(s)
    end

    local path = function()
        local parts = { identifier() }
        while ahead('.') do
            next()
            table.insert(parts, identifier())
        end
        return parts
    end

    -- cross dependency, must be defined earlier
    local term, expression, divert, inkText, knotBody, functionBody, optionText, optionBody, gatherBody, branchInkText

    local stringLiteral = function()
        consume('"')
        -- string defined in ink can contain ink - although it will always evaluate to a string.
        local result = inkText({ stopAt = { '"' } }) -- TODO more tests
        consume('"')
        return result
    end

    local number = function()
        local s = current
        if ahead('-') then
            next()
        end
        while aheadAnyOf('0', '1', '2', '3', '4', '5', '6', '7', '8', '9') do -- TODO
            next()
        end
        return currentText(s)
    end

    local floatLiteral = function(intPart)
        consume('.')
        return token(node.float(tonumber(intPart .. '.' .. number())))
    end

    -- TODO name!
    local intLiteral = function()
        local mark = newMark()
        local val = number()
        if ahead('.') then
            return floatLiteral(val)
        end
        if identifierCharAhead() then
            resetTo(mark)
            return token(node.ref(path()))
        end
        return token(node.int(tonumber(val)))
    end

    -- Arguments are the actual values or expressions passed to the function when calling it
    local argument = function()
        if ahead('->') then
            return divert()
        end
        return expression()
    end

    -- (element, element, ...)
    local listOf = function(elementParser)
        local args = {}
        if ahead('(') then
            consume('(')
            consumeWhitespace()
            while not ahead(')') do
                table.insert(args, elementParser())
                consumeWhitespace()
                if ahead(',') then
                    consume(',')
                    consumeWhitespace()
                end
            end
            consume(')')
            consumeWhitespace()
        end
        return args
    end

    -- Parameters are the placeholders defined in the function or knot definition
    local parameters = function()
        if not ahead('(') then
            return {}
        end
        local params = {}
        consume('(')
        consumeWhitespace()
        while not ahead(')') do
            local paramType = nil
            if aheadAnyOf('ref', '->') then
                paramType = consumeAnyOf('ref', '->')
                consumeWhitespace()
            end
            local paramName = identifier()

            table.insert(params, { name = paramName, ref = paramType })
            consumeWhitespace()
            if ahead(',') then
                consume(',')
                consumeWhitespace()
            end
        end
        consume(')')
        consumeWhitespace()
        return params
    end

    local listLiteral = function()
        if not ahead('(') then
            return
        end
        return token(node.listlit(listOf(identifier)))
    end

    local functionCall = function(functionName)
        local argumentExpressions = listOf(argument)
        return token(node.call(functionName, argumentExpressions))
    end

    term = function()
        if ahead('->') then
            return divert()
        end

        if ahead('"') then
            return stringLiteral()
        end
        if aheadAnyOf('-', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9') then -- TODO
            return intLiteral()
        end

        if ahead('(') then -- TODO this is expression and not term?
            local mark = newMark()
            consume('(')
            consumeWhitespace()
            if ahead(')') then
                resetTo(mark)
                return listLiteral()
            end

            local exp = expression()
            consumeWhitespace()

            if exp.type == 'ref' and ahead(',') then
                resetTo(mark)
                return listLiteral()
            end
            consume(')')
            return exp
        end

        if ahead('true') then
            consume('true')
            return token(node.bool(true))
        end
        if ahead('false') then
            consume('false')
            return token(node.bool(false))
        end
        if aheadAnyOf('!', 'not') then
            consumeAnyOf('!', 'not')
            consumeWhitespace()
            return token(node.call('not', { expression() }))
        end

        local id = path()
        consumeWhitespace()
        if ahead('(') then
            return functionCall(id[1]) -- function names are always simple (no dots)
        end
        return token(node.ref(id)) -- FIXME same name as function argument passed as a reference
    end

    -- precedence from lowest to highest
    local operatorList = {
        { 'or', '||', 'and', '&&' },
        { '!=', '==' },
        { '<=', '>=', '>', '<' },
        { '?', '!?', '^', 'hasnt', 'has' },
        { '-', '+' },
        { 'mod', '%', '/', '*' },
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
        -- The shunting yard algorithm
        local operandStack = {}
        local operatorStack = {}

        table.insert(operandStack, term())
        consumeWhitespace()

        while aheadAnyOf(unpack(operators)) do
            if ahead('//') then
                break
            end -- '/' vs '//' -- FIXME not needed if we had tokens
            if ahead('->') then
                break
            end -- '-' vs '->' -- FIXME not needed if we had tokens
            local operator = consumeAnyOf(unpack(operators))
            consumeWhitespace()

            while
                operatorStack[#operatorStack] ~= nil
                and precedence[operator] <= precedence[operatorStack[#operatorStack]]
            do
                local right = table.remove(operandStack)
                local left = table.remove(operandStack)
                local operatorFromStack = table.remove(operatorStack)
                table.insert(operandStack, token(node.call(operatorFromStack, { left, right })))
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
            table.insert(operandStack, token(node.call(operatorFromStack, { left, right })))
        end

        if #operandStack > 1 then
            errorAt('expression parsing error')
        end

        return operandStack[1]
    end

    local include = function()
        if not ahead('INCLUDE') then
            return
        end
        consume('INCLUDE')
        consumeWhitespace()
        return token(node.include(filename()))
    end

    local todo = function()
        if not ahead('TODO:') then
            return
        end
        consume('TODO:')
        consumeWhitespace()
        return token(node.todo(text({ onlyStopAt = { '//' } })))
    end

    divert = function()
        if not ahead('->') then
            return
        end
        consume('->')
        if ahead('->') then
            consume('->')
            consumeWhitespace()
            if eolAhead() then
                return token(node.tunnelreturn())
            end
            local targetName = path()
            consumeWhitespace()
            local args = listOf(argument)
            return token(node.tunnelreturnto(targetName, args))
        end
        consumeWhitespace()
        local targetName = path()
        consumeWhitespace()
        local args = listOf(argument)
        local tunnel = nil
        if ahead('->') then
            local mark = newMark()
            consume('->')
            consumeWhitespace()
            tunnel = 'tunnel'
            if not eolAhead() then
                -- Tunnels can be chained together, or finish on a normal divert
                -- -> tunnel -> tunnel -> divert
                resetTo(mark)
                -- set the current one as a tunnel but parse the arrow again as part of the next one
                -- the final '->' will stay consumed in this case: -> tunnel ->  \n
            end
        end

        return token(node.divert(targetName, args, tunnel))
    end

    -- fork into a thread
    local fork = function()
        if not ahead('<-') then
            return
        end
        consume('<-')
        consumeWhitespace()
        local targetName = path()
        consumeWhitespace()
        local args = listOf(argument)
        return token(node.fork(targetName, args))
    end

    -- == function add(x,y) ==
    -- functions are knots, with the following limitations and features: (TODO)
    -- cannot contain stitches
    -- cannot use diverts or offer choices
    -- can call other functions
    -- can include printed content
    -- can return a value of any type
    -- can recurse safely
    local fnction = function()
        consumeWhitespace()
        local name = identifier()
        consumeWhitespace()
        local params = parameters()

        consumeWhitespace()
        consumeAll('=')
        consumeWhitespace()
        consume('\n')
        newline()
        consumeWhitespaceAndNewlines()
        local body = functionBody()
        return token(node.fndef(name, params, body))
    end

    local knotOrFunction = function()
        if not ahead('==') then
            return
        end
        consume('==')
        consumeAll('=')
        consumeWhitespace()
        local id = identifier()
        if id == 'function' then
            return fnction()
        end

        consumeWhitespace()
        local params = parameters()
        consumeAll('=')
        consumeWhitespace()
        consume('\n')
        newline()
        consumeWhitespaceAndNewlines()
        local body = knotBody()
        -- TODO are they the same? use functions for knots? what about stitches
        return token(node.knot(id, params, body))
    end

    local stitch = function()
        if not ahead('=') then
            return
        end
        consume('=')
        consumeWhitespace()
        local id = identifier()
        consumeWhitespace()
        local params = parameters()
        return token(node.stitch(id, params))
    end

    local gather = function(minNesting)
        if not ahead('-') then
            return
        end

        local mark = newMark()
        local nesting = 0
        while ahead('-') and not ahead('->') do
            consume('-')
            nesting = nesting + 1
            consumeWhitespace()
        end
        -- TODO test unbalanced option/gather nesting
        if nesting < minNesting then
            resetTo(mark)
            return
        end

        local label = nil
        if ahead('(') then
            consume('(')
            label = identifier()
            consume(')')
            consumeWhitespace()
        end
        return token(node.gather(nesting, { gatherBody(minNesting) }, label)) -- TODO inkText in a table??
    end

    -- minNesting: options with this or higher (deeper) nesting will be included in the body,
    -- options with lower nesting will not be parsed (to jump up one level)
    --
    local option = function(minNesting)
        if not (ahead('*') or ahead('+')) then
            return
        end
        local bulletSymbol = peek(1)
        local sticky = (bulletSymbol == '+') and 'sticky' or nil
        local fallback = nil

        local mark = newMark()
        local nesting = 0
        while ahead(bulletSymbol) do
            consume(bulletSymbol)
            nesting = nesting + 1
            consumeWhitespace()
        end
        if nesting < minNesting then
            resetTo(mark)
            return
        end

        local name = nil
        if ahead('(') then
            consume('(')
            name = identifier()
            consume(')')
            consumeWhitespaceAndNewlines()
        end

        local conditions = {}
        while ahead('{') do
            consume('{')
            consumeWhitespace()
            table.insert(conditions, expression())
            consumeWhitespace()
            consume('}')
            consumeWhitespaceAndNewlines()
        end

        if ahead('->') then
            fallback = 'fallback'
            -- A fallback choice is simply a "choice without choice text"
            -- * -> out_of_options
            --
            -- a default choice with content in it, using an "choice then arrow" (consume the arrow)
            -- * ->
            --   text
            local mark2 = newMark()
            consume('->')
            consumeWhitespace()
            if not ahead('\n') then
                resetTo(mark2)
                -- this will be parsed as a normal divert later
            end
        end

        local sharedStartText = optionText({ stopAt = { '[' } })

        local choiceOnlyText = nil
        if ahead('[') then
            consume('[')
            choiceOnlyText = optionText({ stopAt = { ']' } })
            consume(']')
        end

        local bodyOnlyText = optionText()

        consumeWhitespace()

        --local insertNl = ahead('\n')
        --consumeWhitespaceAndNewlines()

        local body = optionBody(nesting + 1) -- the parameter will come back to this function as minNesting
        -- TODO use named arguments or some other mechanism
        return token(
            node.option(
                nesting,
                { sharedStartText },
                { choiceOnlyText },
                { bodyOnlyText },
                name,
                sticky,
                conditions,
                body,
                fallback
            )
        )
    end

    -- choice wraps multiple options + an optional gather
    -- All those are at the same nesting level, options could have sub-choices (nested options)
    local choice = function(minNesting, opts)
        if not (ahead('*') or ahead('+')) then
            return
        end
        local options = {}
        while not isAtEnd() do
            local n = option(minNesting)
            if n == nil then
                break
            end
            table.insert(options, n)
        end
        -- TODO this might be simpler if we were parsing "tokens"
        -- where we would see the 'depth' already
        if #options == 0 then
            return
        end

        local gatherNode = nil
        if not opts or not opts.gatherNotAllowed then
            gatherNode = gather(minNesting)
        end

        return token(node.choice(options, gatherNode))
    end

    local tag = function(opts)
        consume('#')
        consumeWhitespace()
        return token(node.tag(text(opts)))
    end

    local constant = function()
        consume('CONST')
        consumeWhitespace()
        local name = identifier()
        consumeWhitespace()
        consume('=')
        consumeWhitespace()
        local value
        if ahead('->') then
            value = divert()
        else
            value = term()
        end
        consumeWhitespaceAndNewlines()
        return token(node.const(name, value))
    end

    local variable = function()
        consume('VAR')
        consumeWhitespace()
        local name = identifier()
        consumeWhitespace()
        consume('=')
        consumeWhitespace()
        local value
        if ahead('->') then
            value = divert()
        elseif ahead('(') then
            value = listLiteral()
        else
            value = term()
        end
        consumeWhitespaceAndNewlines()
        return token(node.var(name, value))
    end

    local tempVariable = function()
        consume('temp')
        consumeWhitespace()
        local name = identifier()
        consumeWhitespace()
        consume('=')
        consumeWhitespace()
        local value = expression()
        consumeWhitespace()
        return token(node.tempvar(name, value)) --TODO better name? local var? var?
    end

    local external = function()
        consume('EXTERNAL')
        consumeWhitespace()
        local name = identifier()
        consumeWhitespace()
        local params = parameters()
        consumeWhitespaceAndNewlines()
        return token(node.external(name, params))
    end

    local list = function()
        consume('LIST')
        consumeWhitespace()
        local name = identifier()
        consumeWhitespace()
        consume('=')
        consumeWhitespaceAndNewlines()

        local elements = {}
        local elementValue = 1
        while not eolAhead() do
            local elementPresent = false
            local parenOpen = false
            if ahead('(') then
                consume('(')
                consumeWhitespace()
                elementPresent = true
                parenOpen = true
            end
            local elementName = identifier()
            consumeWhitespace()
            -- ')' could be before '=' or after
            if parenOpen and ahead(')') then
                consume(')')
                consumeWhitespace()
                parenOpen = false
            end
            if ahead('=') then
                consume('=')
                consumeWhitespace()
                elementValue = assert(tonumber(number()))
                consumeWhitespace()
            end
            table.insert(elements, { name = elementName, set = elementPresent, value = elementValue })
            elementValue = elementValue + 1
            if parenOpen then
                consume(')')
                consumeWhitespace()
            end
            if ahead(',') then
                consume(',')
                consumeWhitespaceAndNewlines()
            end
        end
        consumeWhitespaceAndNewlines()
        return token(node.listdef(name, elements))
    end

    local para = function(opts)
        local t = text(opts)
        if #t > 0 then
            return token(node.str(t))
        end
    end

    local branch = function(first, isFirstBranch)
        consume('-')
        consumeWhitespaceAndNewlines()
        local mark = newMark()

        local condition, body
        if ahead('else') then
            consume('else')
            consumeWhitespaceAndNewlines()
            consume(':')
            consumeWhitespaceAndNewlines()
            condition = token(node.bool(true))
            body = { branchInkText() }
        else
            -- try to parse expression which would be followed by a ":"
            -- otherwise jump back and parse branch ink text
            -- FIXME without pcall?
            local expressionParsed, branchCaseExpression = pcall(expression)
            consumeWhitespace()

            if expressionParsed and ahead(':') then
                -- switch {expr:\n -val1:text\n -val2:text\n}
                condition = token(node.call('==', { first, branchCaseExpression }))

                consume(':')
                consumeWhitespaceAndNewlines()

                -- TODO would be nicer without this if
                if ahead('-') and not ahead('->') then
                    -- empty branch body, but the condition should be evaluated
                    body = {}
                else
                    body = { branchInkText() }
                end
            else
                -- {expr:
                --   -textiftrue
                --   -textiffalse
                -- }
                resetTo(mark) -- jump after the '-' of the current branch

                body = { branchInkText() }
                if isFirstBranch then
                    -- first branch (the iftrue)
                    condition = first
                else
                    -- else branch (iffalse)
                    condition = token(node.bool(true))
                end
            end
        end
        return { cond = condition, body = body }
    end

    local seqSeparatedBranches = function()
        consumeWhitespaceAndNewlines()
        local result = { { inkText() } }
        while ahead('|') do
            consume('|')
            local element = inkText()
            if element ~= nil then
                table.insert(result, { element })
            end
        end
        return result
    end

    local seqBranches = function()
        consumeWhitespaceAndNewlines()
        consume(':')
        consumeWhitespaceAndNewlines()
        local result = {}
        while ahead('-') and not ahead('->') do
            consume('-')
            consumeWhitespace()
            local element = branchInkText()
            if element ~= nil then
                table.insert(result, { element }) -- TODO inkText in a table?
            end
        end
        return result
    end

    --TODO name? used for sequences, variable printing, conditional text, cond. option
    local alternative = function()
        local opts = {}

        consume('{')
        consumeWhitespaceAndNewlines()

        -- Cycles are like sequences, but they loop their content.
        -- Once-only: when they run out of content, display nothing (as a sequence with a blank last entry).
        -- Shuffle: randomised output.
        -- Any combination/order of symbols (no spaces), e.g. ~! = shuffle once.
        if ahead('&') or ahead('!') or ahead('~') then
            while ahead('&') or ahead('!') or ahead('~') do
                if ahead('~') then
                    consume('~')
                    opts.shuffle = true
                elseif ahead('!') then
                    consume('!')
                    opts.once = true
                elseif ahead('&') then
                    consume('&')
                    opts.cycle = true
                end
            end
            if opts.shuffle and not opts.once and not opts.cycle then
                opts.cycle = true -- plain ~ defaults to cycle
            end
            local branches = seqSeparatedBranches()
            consume('}')
            return token(node.seq(opts, branches))
        end

        -- Sequence: go through alternatives and stick on last (stopping), cycle, once-only, shuffle.
        -- Any order/combination of keywords, e.g. {stopping shuffle:} = {shuffle stopping:}.
        if ahead('stopping') or ahead('shuffle') or ahead('once') or ahead('cycle') then
            local seqStartLine = line
            while ahead('stopping') or ahead('shuffle') or ahead('once') or ahead('cycle') do
                if ahead('stopping') then
                    consume('stopping')
                    opts.stopping = true
                elseif ahead('shuffle') then
                    consume('shuffle')
                    opts.shuffle = true
                elseif ahead('once') then
                    consume('once')
                    opts.once = true
                elseif ahead('cycle') then
                    consume('cycle')
                    opts.cycle = true
                end
                consumeWhitespaceAndNewlines()
            end
            local nonShuffleNames = {}
            if opts.stopping then
                nonShuffleNames[#nonShuffleNames + 1] = 'Stopping'
            end
            if opts.once then
                nonShuffleNames[#nonShuffleNames + 1] = 'Once'
            end
            if opts.cycle then
                nonShuffleNames[#nonShuffleNames + 1] = 'Cycle'
            end
            if #nonShuffleNames > 1 then
                log.die(
                    'Sequence type combination not supported: ' .. table.concat(nonShuffleNames, ', '),
                    { source, seqStartLine, 1 }
                )
            end
            if opts.shuffle and not opts.stopping and not opts.once and not opts.cycle then
                opts.cycle = true -- plain {shuffle:} defaults to cycle
            end
            local branches = seqBranches()
            consume('}')
            return token(node.seq(opts, branches))
        end

        if ahead('-') and not ahead('->') then
            local beforeMinus = newMark()
            consume('-')
            if not whitespaceAhead() then
                resetTo(beforeMinus) -- unary minus or negative literal; let expression parser handle it
            end
        end
        consumeWhitespaceAndNewlines()

        local afterOpeningBrace = newMark()

        -- {a||b} must parse as a 3-branch stopping sequence, not boolean OR.
        -- {x < 10 || x > 20: ...} is an expression (`:` follows, not `}`).
        -- Guard: if `||` was consumed by the expression parser, `|` was eaten —
        -- fall through to re-parse the whole thing as a sequence instead.
        local firstExpressionParsed, first = pcall(expression)
        consumeWhitespaceAndNewlines()

        if firstExpressionParsed and ahead('}') then
            local exprText = input:sub(afterOpeningBrace.current, current - 1)
            if not exprText:find('|', 1, true) then
                -- variable printing: {expression}
                consume('}')
                return token(node.out(first, opts))
            end
            -- `|` was consumed as part of `||` — fall through to re-parse as sequence
            resetTo(afterOpeningBrace)
        end

        if firstExpressionParsed and ahead(':') then
            consume(':')
            local afterColon = newMark()
            consumeWhitespaceAndNewlines()
            local branches = {}
            if ahead('-') and not ahead('->') then
                -- newlines after the first ':' ignored
                while ahead('-') and not ahead('->') do
                    table.insert(branches, branch(first, #branches == 0))
                end
            else
                -- Conditional block: {expr:textIfTrue}
                -- newlines after the first ':' significant
                resetTo(afterColon)
                consumeWhitespace()
                table.insert(branches, { cond = first, body = { branchInkText() } })
                consumeWhitespaceAndNewlines()
                if ahead('|') then
                    -- {expr:textIfTrue|textIfFalse}
                    consume('|')
                    -- else branch, the condition is always true
                    table.insert(branches, { cond = token(node.bool(true)), body = { branchInkText() } })
                elseif ahead('-') and not ahead('->') then
                    while ahead('-') and not ahead('->') do
                        table.insert(branches, branch(token(node.bool(true)), false))
                    end
                end
            end

            consume('}')
            return token(node['if'](branches, opts))
        end

        -- read the first element after the '{' again, this time as ink text
        resetTo(afterOpeningBrace)
        first = inkText()
        consumeWhitespace()

        if ahead('|') then
            -- {text|text|...}
            -- A sequence (or a "stopping block") is a set of alternatives that tracks
            -- how many times its been seen, and each time, shows the next element along.
            -- When it runs out of new content it continues the show the final element.
            opts.stopping = true
            local result = { { first } } -- TODO too much wrapping?
            while ahead('|') do
                consume('|')
                local element = { inkText() } -- TODO too much wrapping?
                if element ~= nil then
                    table.insert(result, element)
                end
            end
            consume('}')
            return token(node.seq(opts, result))
        end
        errorAt('failed to parse an alternative')
    end

    local glue = function()
        consume('<>')
        return token(node.glue())
    end

    local returnStatement = function()
        consume('return')
        consumeWhitespace()
        if eolAhead() then
            return token(node.ret(nil))
        else
            return token(node.ret(expression()))
        end
    end

    local statement = function()
        consume('~')
        consumeWhitespace()
        if ahead('return') then -- TODO only in function
            return returnStatement()
        elseif ahead('temp') then
            return tempVariable()
        else
            local id = path()[1] -- assignment targets and function names are always simple
            consumeWhitespace()
            if ahead('(') then
                return functionCall(id)
            elseif ahead('++') then
                consume('++')
                consumeWhitespaceAndNewlines()
                -- TODO do not generate code here, formatter needs the original representation
                -- and ++ does not return a value in ink
                return token(node.assign(id, token(node.call('+', { token(node.ref({ id })), token(node.int(1)) }))))
            elseif ahead('--') then
                consume('--')
                consumeWhitespaceAndNewlines()
                return token(node.assign(id, token(node.call('-', { token(node.ref({ id })), token(node.int(1)) }))))
            elseif ahead('-=') then
                consume('-=')
                consumeWhitespace()
                local expr = expression()
                consumeWhitespaceAndNewlines()
                return token(node.assign(id, token(node.call('-', { token(node.ref({ id })), expr }))))
            elseif ahead('+=') then
                consume('+=')
                consumeWhitespace()
                local expr = expression()
                consumeWhitespaceAndNewlines()
                return token(node.assign(id, token(node.call('+', { token(node.ref({ id })), expr }))))
            elseif ahead('=') then
                consume('=')
                consumeWhitespace()

                -- FIXME! W3.5.002 - have call in expression?
                -- ~ x = lerp(2, 8, 0.3)

                local expr = expression()
                consumeWhitespaceAndNewlines()
                return token(node.assign(id, expr))
            end

            errorAt('unexpected statement near ' .. id)
        end
    end

    local inkNode = function(opts)
        if ahead('\n') then
            return nl()
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
        elseif ahead('<-') then
            return fork()
        elseif ahead('==') then
            return knotOrFunction()
        elseif ahead('=') then
            return stitch()
        elseif ahead('*') or ahead('+') then
            return choice(1)
        elseif ahead('-') then -- TODO must be on new line?
            return gather(1) -- labelled gathers could exist without choices
        elseif ahead('#') then
            return tag()
        elseif ahead('CONST') then -- TODO must be on new line?
            return constant()
        elseif ahead('VAR') then
            return variable()
        elseif ahead('EXTERNAL') then
            return external()
        elseif ahead('LIST') then
            return list()
        elseif ahead('{') then
            return alternative()
        elseif ahead('~') then
            return statement()
        else
            return para(opts)
        end
    end

    local knotBodyNode = function(opts)
        if ahead('\n') then
            return nl()
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
        elseif ahead('<-') then
            return fork()
        elseif ahead('==') then
            return nil ------------------------
        elseif ahead('=') then
            return stitch()
        elseif ahead('*') or ahead('+') then
            return choice(1)
        elseif ahead('-') then
            return gather(1) -- labelled gathers could exist without choices
        elseif ahead('#') then
            return tag()
        elseif ahead('CONST') then -- TODO must be on new line?
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
            return para(opts)
        end
    end
    local functionBodyNode = function(opts)
        if ahead('\n') then
            return nl()
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
            return nil --------divert()
        elseif ahead('<-') then
            return nil ---fork()
        elseif ahead('==') then
            return nil ------------------------
        elseif ahead('=') then
            return nil ----------------
        elseif ahead('*') or ahead('+') then
            return nil -----------choice(1)
        elseif ahead('-') then
            return gather(1) -- labelled gathers could exist without choices
        elseif ahead('#') then
            return tag()
        elseif ahead('CONST') then -- TODO must be on new line?
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
            return para(opts)
        end
    end

    local optionTextNode = function(opts)
        if ahead('\n') then
            return nil --nl()
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
            return nil ---divert()
        elseif ahead('<-') then
            return nil ---fork()
        elseif ahead('==') then
            return nil ------------------------
        elseif ahead('=') then
            return nil ------------------------
        elseif ahead('*') or ahead('+') then
            return nil -- choice(minNesting)
        elseif ahead('#') then
            return tag(opts)
        elseif ahead('CONST') then -- TODO must be on new line?
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
            return para(opts)
        end
    end

    local optionBodyNode = function(minNesting, opts)
        if ahead('\n') then
            return nl()
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
        elseif ahead('<-') then
            return fork()
        elseif ahead('==') then
            return nil ------------------------
        elseif ahead('=') then
            return nil ------------------------
        elseif ahead('*') or ahead('+') then
            return choice(minNesting)
        elseif ahead('-') then
            -- peek at gather nesting: absorb gathers at >= minNesting (inside this option),
            -- stop for gathers at < minNesting (they belong to an outer scope)
            local mark = newMark()
            local n = 0
            while ahead('-') and not ahead('->') do
                consume('-')
                n = n + 1
                consumeWhitespace()
            end
            resetTo(mark)
            if n >= minNesting then
                return gather(n)
            else
                return nil
            end
        elseif ahead('#') then
            return tag()
        elseif ahead('CONST') then -- TODO must be on new line?
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
            return para(opts)
        end
    end

    local gatherBodyNode = function(minNesting, opts)
        if ahead('\n') then
            return nl()
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
        elseif ahead('<-') then
            return fork()
        elseif ahead('==') then
            return nil ------------------------
        elseif ahead('=') then
            return nil ------------------------
        elseif ahead('*') or ahead('+') then
            return choice(minNesting)
        elseif ahead('-') then
            return nil ----------------gather()
        elseif ahead('#') then
            return tag()
        elseif ahead('CONST') then -- TODO must be on new line?
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
            return para(opts)
        end
    end
    local branchInkNode = function(opts)
        if ahead('\n') then
            return nl()
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
        elseif ahead('<-') then
            return fork()
        elseif ahead('-') and isLineStart() then ----------TODO
            return nil -- new branch
        elseif ahead('==') then
            return nil ------------------------
        elseif ahead('=') then
            return nil ------------------------
        elseif ahead('*') or ahead('+') then
            return choice(1, { gatherNotAllowed = true })
            --elseif ahead('-') athen -- new branch start
            --stay in 'para'
            --    return nil ----------------gather()
        elseif ahead('#') then
            return tag()
        elseif ahead('CONST') then -- TODO must be on new line?
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
            return para(opts)
        end
    end

    knotBody = function(opts)
        local result = {} -- TODO just table or 'block'?

        while not isAtEnd() do
            local n = knotBodyNode(opts)
            if n == nil then
                break
            end
            table.insert(result, n)
        end
        return result
    end

    -- TODO this is getting ridiculous
    functionBody = function(opts)
        local result = {} -- TODO just table or 'block'?

        while not isAtEnd() do
            local n = functionBodyNode(opts)
            if n == nil then
                break
            end
            table.insert(result, n)
        end
        return result
    end

    optionText = function(opts)
        local result = {} -- TODO just table or 'block'?

        while not isAtEnd() do
            local n = optionTextNode(opts)
            if n == nil then
                break
            end
            table.insert(result, n)
        end
        return token(node.ink(result))
    end

    optionBody = function(minNesting, opts)
        local result = {} -- TODO just table or 'block'?

        while not isAtEnd() do
            local n = optionBodyNode(minNesting, opts)
            if n == nil then
                break
            end
            table.insert(result, n)
        end
        return result
    end

    gatherBody = function(minNesting, opts)
        local result = {} -- TODO just table or 'block'?

        while not isAtEnd() do
            local n = gatherBodyNode(minNesting, opts)
            if n == nil then
                break
            end
            table.insert(result, n)
        end
        return token(node.ink(result))
    end

    -- used in sequences / conditionals ("multiline blocks"?)
    -- where a dash means a branch start, not a gather
    branchInkText = function(opts)
        local result = {} -- TODO just table or 'block'?

        while not isAtEnd() do
            local n = branchInkNode(opts)
            if n == nil then
                break
            end
            table.insert(result, n)
        end
        return token(node.ink(result))
    end

    inkText = function(opts)
        local result = {} -- TODO just table or 'block'?

        consumeWhitespaceAndNewlines()
        while not isAtEnd() do
            local startCursor = current

            local n = inkNode(opts)
            if n ~= nil then
                table.insert(result, n)
            end

            if current == startCursor then
                break
                --errorAt("nothing consumed") --FIXME
            end
        end
        return token(node.ink(result))
    end

    local statements = { inkText() }
    --log.debug(statements)
    return statements
end
