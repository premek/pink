local base_path = (...):match('(.-)[^%.]+$')
local logging = require(base_path .. 'logging')
local log = logging.newLogger()
local node = require(base_path .. 'node')

local unpack = table.unpack or unpack

-- identifier could be a keyword too (e.g. "once", but not VAR)
local allowedAsIdentifiers = {
    'word',
    'digits',
    'TODO',
    'INCLUDE',
    'EXTERNAL',
    'stopping',
    'shuffle',
    'once',
    'cycle',
    'or',
    'and',
    'hasnt',
    'has',
    'mod',
    'ref',
}

return function(tokens)
    local current = 1 -- pointing to the token waiting to be parsed

    local errorAt = function(msg, ...)
        log.debug(tokens[current])
        local formattedMsg = string.format(msg, ...)
        local location = tokens[current].location
        error(
            string.format(
                formattedMsg .. "\n\tat '%s', line %s, column %s",
                location.source,
                location.line,
                location.column
            )
        )
    end

    local next = function()
        current = current + 1
    end

    local peek = function()
        return tokens[current]
    end

    local peekNext = function()
        return tokens[current + 1]
    end

    local isType = function(token, type)
        return token and token.type == type
    end

    local ahead = function(type)
        return isType(peek(), type)
    end

    local nextAhead = function(type)
        return isType(peekNext(), type)
    end

    local aheadAnyOf = function(...)
        for _, type in ipairs({ ... }) do
            if ahead(type) then
                return true
            end
        end
        return false
    end

    local whitespaceAhead = function()
        return aheadAnyOf('whitespace')
    end

    local isAtEnd = function()
        return ahead('eof')
    end

    local eolAhead = function()
        return ahead('newline') or isAtEnd()
    end

    --
    -- TODO is this needed?
    local isLineStart = function()
        for i = current - 1, 1, -1 do
            local t = tokens[i]
            if t.type == 'newline' then
                return true
            elseif t.type == 'whitespace' then
                local _ -- keepSearching
            else
                -- non-whitespace characters between newline and 'current' position
                return false
            end
        end
        return true -- start of the first line
    end

    local consume = function(type)
        if not ahead(type) then
            errorAt('expected ' .. type)
        end
        next()
    end

    local consumeAnyOf = function(...)
        for _, type in ipairs({ ... }) do
            if ahead(type) then
                consume(type)
                return type
            end
        end
        errorAt('expected any of ' .. table.concat(..., ', '))
    end

    local consumeWhitespace = function()
        while whitespaceAhead() do
            next()
        end
    end

    local consumeWhitespaceAndNewlines = function()
        while aheadAnyOf('whitespace', 'newline') do
            consumeAnyOf('whitespace', 'newline')
        end
    end

    local currentText = function(fromIndex)
        local result = ''
        for i = fromIndex, current - 1 do
            local t = tokens[i]
            if t.type == 'text' or t.type == 'word' or t.type == 'digits' or t.type == 'whitespace' then
                result = result .. t.literal
            else
                result = result .. t.type
            end
        end
        return result
    end

    local token = function(n)
        n.location = tokens[current].location
        return n
    end
    local nl = function()
        next()
        consumeWhitespace()
        return token(node.nl())
    end

    local text = function(opts)
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
                if aheadAnyOf('#', '->', '->->', '<-', '==', '<>', '{', '}', '|', '||') then
                    break
                end
                if opts and opts.stopAt and aheadAnyOf(unpack(opts.stopAt)) then
                    break
                end
            end
            if ahead('\\') then
                -- skip the backslash
                result = result .. currentText(s)
                next()
                s = current

                if not eolAhead() then
                    next()
                    result = result .. currentText(s)
                    s = current
                end
            else
                next()
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

    local identifier = function()
        if not aheadAnyOf(unpack(allowedAsIdentifiers)) then
            errorAt('identifier expected')
        end
        local s = current
        while aheadAnyOf(unpack(allowedAsIdentifiers)) do
            next()
        end
        -- FIXME: https://github.com/inkle/ink/blob/master/Documentation
        -- /WritingWithInk.md#part-6-international-character-support-in-identifiers
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
        consume('digits')
        return currentText(s)
    end

    local numberLiteral = function()
        local beforeNumber = current
        local intPart = number()
        if ahead('.') and nextAhead('digits') then
            consume('.')
            local fracPart = number()
            return token(node.float(tonumber(intPart .. '.' .. fracPart)))
        end
        if aheadAnyOf('keyword', 'word') then
            -- identifiers: 512x2, 2VAR, etc
            current = beforeNumber
            return token(node.ref(path()))
        end
        return token(node.int(tonumber(intPart)))
    end

    -- Arguments are the actual values or expressions passed to the function when calling it
    local argument = function()
        if ahead('->') then
            return divert()
        end
        return expression()
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
    --
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

        if ahead('-') then
            consume('-')
            consumeWhitespace()
            return token(node.call('neg', { expression() }))
        end

        if ahead('digits') then
            return numberLiteral()
        end

        if ahead('(') then -- TODO this is expression and not term?
            local mark = current
            consume('(')
            consumeWhitespace()
            if ahead(')') then
                current = mark
                return listLiteral()
            end

            local exp = expression()
            consumeWhitespace()

            if exp.type == 'ref' and ahead(',') then
                current = mark
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
            -- function names are always simple (no dots)
            if #id > 1 then
                errorAt('unexpected path')
            end
            return functionCall(id[1])
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
        if not ahead('TODO') then
            return
        end
        consume('TODO')
        consumeWhitespace()
        if ahead(':') then
            consume(':')
            consumeWhitespace()
        end
        return token(node.todo(text({ onlyStopAt = { '//' } })))
    end

    local tunnelReturn = function()
        if not ahead('->->') then
            return
        end
        consume('->->')
        consumeWhitespace()
        if eolAhead() then
            return token(node.tunnelreturn())
        end
        local targetName = path()
        consumeWhitespace()
        local args = listOf(argument)
        return token(node.tunnelreturnto(targetName, args))
    end

    divert = function()
        if not ahead('->') then
            return
        end
        consume('->')
        consumeWhitespace()
        local targetName = path()
        consumeWhitespace()
        local args = listOf(argument)
        local tunnel = nil
        if ahead('->') then
            local mark = current
            consume('->')
            consumeWhitespace()
            tunnel = 'tunnel'
            -- FIXME J119 {! ->intro->}
            if not eolAhead() then
                -- Tunnels can be chained together, or finish on a normal divert
                -- -> tunnel -> tunnel -> divert
                current = mark
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
        if ahead('==') then
            consume('==')
        end
        consumeWhitespace()
        consume('newline')
        consumeWhitespaceAndNewlines()
        local body = functionBody()
        return token(node.fndef(name, params, body))
    end

    local knotOrFunction = function()
        if not ahead('==') then
            return
        end
        consume('==')
        consumeWhitespace()
        local id = identifier()
        if id == 'function' then
            return fnction()
        end

        consumeWhitespace()
        local params = parameters()
        consumeWhitespace()
        if ahead('==') then
            consume('==')
            consumeWhitespace()
        end
        consume('newline')
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
        consumeWhitespaceAndNewlines()
        return token(node.stitch(id, params))
    end

    local gather = function(minNesting)
        if not ahead('-') then
            return
        end

        local mark = current
        local nesting = 0
        while ahead('-') do
            consume('-')
            nesting = nesting + 1
            consumeWhitespace()
        end
        -- TODO test unbalanced option/gather nesting
        if nesting < minNesting then
            current = mark
            return
        end

        local label = nil
        if ahead('(') then
            consume('(')
            label = identifier()
            consume(')')
        end
        consumeWhitespaceAndNewlines()
        return token(node.gather(nesting, { gatherBody(minNesting) }, label)) -- TODO inkText in a table??
    end

    -- minNesting: options with this or higher (deeper) nesting will be included in the body,
    -- options with lower nesting will not be parsed (to jump up one level)
    --
    local option = function(minNesting)
        if not (ahead('*') or ahead('+')) then
            return
        end
        local bulletSymbol = peek().type
        local sticky = (bulletSymbol == '+') and 'sticky' or nil
        local fallback = nil

        local mark = current
        local nesting = 0
        while ahead(bulletSymbol) do
            consume(bulletSymbol)
            nesting = nesting + 1
            consumeWhitespace()
        end
        if nesting < minNesting then
            current = mark
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

        if aheadAnyOf('->', '->->') then
            fallback = 'fallback'
            -- A fallback choice is simply a "choice without choice text"
            -- * -> out_of_options
            --
            -- a default choice with content in it, using an "choice then arrow" (consume the arrow)
            -- * ->
            --   text

            if ahead('->') then
                local beforeArrow = current
                consume('->')
                consumeWhitespace()
                if not ahead('newline') then
                    current = beforeArrow
                    -- this will be parsed as a normal divert later
                end
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

        --local insertNl = ahead('newline')
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

        local afterLeadingBranchDash = current

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
                -- switch
                -- {expr:
                --   -val1:text
                --   -val2:text
                -- }
                condition = token(node.call('==', { first, branchCaseExpression }))
                consume(':')
                consumeWhitespaceAndNewlines()
                body = { branchInkText() }
            else
                -- {expr:
                --   -textiftrue
                --   -textiffalse
                -- }
                current = afterLeadingBranchDash

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
        while aheadAnyOf('|', '||') do
            if ahead('|') then
                consume('|')
                local element = { inkText() } -- TODO too much wrapping?
                if element ~= nil then
                    table.insert(result, element)
                end
            elseif ahead('||') then
                consume('||')
                table.insert(result, token(node.ink({})))
                local element = { inkText() } -- TODO too much wrapping?
                if element ~= nil then
                    table.insert(result, element)
                end
            end
        end
        return result
    end

    local seqBranches = function()
        consume(':')
        consumeWhitespaceAndNewlines()
        if ahead('-') then
            local result = {}
            while ahead('-') do
                consume('-')
                consumeWhitespace()
                local element = branchInkText()
                if element ~= nil then
                    table.insert(result, { element }) -- TODO inkText in a table?
                end
            end
            return result
        end
        return seqSeparatedBranches()
    end

    --TODO name? used for sequences, variable printing, conditional text, cond. option
    local alternative = function()
        local opts = {}

        consume('{')
        consumeWhitespaceAndNewlines()

        local afterOpeningBrace = current

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
        if aheadAnyOf('stopping', 'shuffle', 'once', 'cycle') then
            local location = peek().location
            while aheadAnyOf('stopping', 'shuffle', 'once', 'cycle') do
                local keyword = consumeAnyOf('stopping', 'shuffle', 'once', 'cycle')
                opts[keyword] = true
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
                log.die('Sequence type combination not supported: ' .. table.concat(nonShuffleNames, ', '), location)
            end
            if opts.shuffle and not opts.stopping and not opts.once and not opts.cycle then
                opts.cycle = true -- plain {shuffle:} defaults to cycle
            end
            if ahead(':') then
                local branches = seqBranches()
                consume('}')
                return token(node.seq(opts, branches))
            end
            -- maybe printing a variable like {once}
            current = afterOpeningBrace
        end

        if ahead('-') then
            local beforeMinus = current
            consume('-')
            if not whitespaceAhead() then
                current = beforeMinus -- unary minus or negative literal; let expression parser handle it
            end
        end
        consumeWhitespaceAndNewlines()

        -- {a||b} must parse as a 3-branch stopping sequence, not boolean OR.
        -- {x < 10 || x > 20: ...} is an expression (`:` follows, not `}`).
        -- Guard: if `||` was consumed by the expression parser, `|` was eaten —
        -- fall through to re-parse the whole thing as a sequence instead.
        local firstExpressionParsed, first = pcall(expression)
        consumeWhitespaceAndNewlines()

        if firstExpressionParsed and ahead('}') then
            -- TODO ?
            local hadDoublePipe = false
            for i = afterOpeningBrace, current - 1 do
                if tokens[i].type == '||' then
                    hadDoublePipe = true
                end
            end
            log.debug(firstExpressionParsed, first, hadDoublePipe)

            if not hadDoublePipe then
                -- variable printing: {expression}
                consume('}')
                return token(node.out(first, opts))
            end
            -- || was consumed - fall through to re-parse as sequence
            current = afterOpeningBrace
        end

        if firstExpressionParsed and ahead(':') then
            consume(':')

            local afterColon = current
            consumeWhitespaceAndNewlines()
            local branches = {}
            if ahead('-') then
                -- newlines after the first ':' ignored
                while ahead('-') do
                    table.insert(branches, branch(first, #branches == 0))
                end
            else
                -- Conditional block: {expr:textIfTrue}
                -- newlines after the first ':' significant
                current = afterColon
                consumeWhitespace()
                table.insert(branches, { cond = first, body = { branchInkText() } })
                consumeWhitespaceAndNewlines()
                if ahead('|') then
                    -- {expr:textIfTrue|textIfFalse}
                    consume('|')
                    -- else branch, the condition is always true
                    table.insert(branches, { cond = token(node.bool(true)), body = { branchInkText() } })
                elseif ahead('-') then
                    while ahead('-') do
                        table.insert(branches, branch(token(node.bool(true)), false))
                    end
                end
            end

            consume('}')
            return token(node['if'](branches, opts))
        end

        -- read the first element after the '{' again, this time as ink text
        current = afterOpeningBrace
        first = inkText()
        consumeWhitespace()

        if aheadAnyOf('|', '||') then -- FIXME hack: || two separators with empty string in between
            -- {text|text|...}
            -- A sequence (or a "stopping block") is a set of alternatives that tracks
            -- how many times its been seen, and each time, shows the next element along.
            -- When it runs out of new content it continues the show the final element.
            opts.stopping = true
            local result = { { first } } -- TODO too much wrapping?
            while aheadAnyOf('|', '||') do
                if ahead('|') then
                    consume('|')
                    local element = { inkText() } -- TODO too much wrapping?
                    if element ~= nil then
                        table.insert(result, element)
                    end
                elseif ahead('||') then
                    consume('||')
                    table.insert(result, token(node.ink({})))
                    local element = { inkText() } -- TODO too much wrapping?
                    if element ~= nil then
                        table.insert(result, element)
                    end
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
        if ahead('newline') then
            return nl()
        elseif ahead('TODO') then
            return todo()
        elseif ahead('INCLUDE') then
            return include()
        elseif ahead('<>') then
            return glue()
        elseif ahead('->->') then
            return tunnelReturn()
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
        if ahead('newline') then
            return nl()
        elseif ahead('TODO') then
            return todo()
        elseif ahead('INCLUDE') then
            return include()
        elseif ahead('<>') then
            return glue()
        elseif ahead('->->') then
            return tunnelReturn()
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
        if ahead('newline') then
            return nl()
        elseif ahead('TODO') then
            return todo()
        elseif ahead('INCLUDE') then
            return include()
        elseif ahead('<>') then
            return glue()
        elseif ahead('->->') then
            return nil
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
        if ahead('newline') then
            return nil --nl()
        elseif ahead('TODO') then
            return todo()
        elseif ahead('INCLUDE') then
            return include()
        elseif ahead('<>') then
            return glue()
        elseif ahead('->->') then
            return nil
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
        if ahead('newline') then
            return nl()
        elseif ahead('TODO') then
            return todo()
        elseif ahead('INCLUDE') then
            return include()
        elseif ahead('<>') then
            return glue()
        elseif ahead('->->') then
            return tunnelReturn()
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

            local mark = current
            local n = 0
            while ahead('-') do
                consume('-')
                n = n + 1
                consumeWhitespace()
            end
            current = mark
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
        if ahead('newline') then
            return nl()
        elseif ahead('TODO') then
            return todo()
        elseif ahead('INCLUDE') then
            return include()
        elseif ahead('<>') then
            return glue()
        elseif ahead('->->') then
            return tunnelReturn()
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
        if ahead('newline') then
            return nl()
        elseif ahead('TODO') then
            return todo()
        elseif ahead('INCLUDE') then
            return include()
        elseif ahead('<>') then
            return glue()
        elseif ahead('->->') then
            return tunnelReturn()
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

    -- log.debug(tokens)
    local statements = { inkText() }
    --log.debug(statements)
    return statements
end
