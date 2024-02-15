return function(input, source, debug)

        local _debug = function(x)
            if not debug then return end
            print( require('test/luaunit').prettystr(x) )
        end

        source = source or 'unknown source'

        local current=1
        local line = 1
        local column = 1


        local errorAt = function(msg, ...)
            local formattedMsg = string.format(msg, ...)
            error(
                string.format(formattedMsg .. "\n\tat '%s', line %s, column %s", source, line, column)
                .. '\n\t...\n\t' .. input:sub(math.max(0, current - 100), current)
                .. '\n\t' .. '<<somewhere around here>>'
                .. '\n\t' .. input:sub(current+1, current + 100)
                .. '...\n\t'
            )
        end


        local mark

        local setMark = function()
            mark={current=current,
                line = line,
                column = column,
            }
        end

        local removeMark = function()
            mark = nil
        end

        local resetToMark = function()
            if mark == nil then
                errorAt('mark not set')
            end
            current=mark.current
            line = mark.line
            column = mark.column
            mark = nil
        end

        local isAtEnd = function()
            return current >= #input
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
            if isAtEnd() then return nil end -- FIXME?
            return input:sub(current, current+chars-1)
        end

        local peekCode = function()
            if isAtEnd() then return nil end
            return input:byte(current, current)
        end


        local ahead = function(str)
            return str == peek(#str)
        end

        local aheadAnyOf = function(...)
            for _, str in ipairs{...} do
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
                return "newline"
            else
                return "'"..s.."'"
            end
        end

        local consume = function(str)
            if not ahead(str) then
                errorAt("expected " .. readable(str))
            end
            next(#str)
        end

        local consumeAll = function(c)
            while ahead(c) do
                next()
            end
        end

        local consumeAnyOf = function(...)
            for _, str in ipairs{...} do
                if ahead(str) then
                    consume(str)
                    return str
                end
            end
            errorAt("expected any of " .. table.concat(..., ", "))

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

        local token = function(...)
            local t = {...}
            t.location = {source, line, column}
            return t
        end

        local nl = function()
            if not ahead('\n') then return end
            next()
            newline()
            consumeWhitespace()
            return token('nl')
        end



        local singleLineComment = function()
            if not ahead('//') then return end
            consume('//')
            while not eolAhead() do
                next()
            end
            -- we have to return something so the caller does not stop here
            return token('nop') -- TODO or a comment token??
        end

        local multiLineComment = function()
            if not ahead('/*') then return end
            consume('/*')
            while not ahead('*/') and not isAtEnd() do
                if ahead('\n') then
                    newline()
                end
                next()
            end
            consume('*/')
            -- we have to return something so the caller does not stop here
            return token('nop')
        end


        local currentText = function(startPos)
            local result, _ = input:sub(startPos, current-1):gsub("%s+", " ")
            return result
        end


        local text
        text = function(opts)
            local s = current
            local result = ""

            -- TODO different kind of "text' when we are inside an option?
            -- or treat text differently than other tokens?
            -- TODO list allowed chars only?
            -- FIXME this is wierd
            --
            --
            while not aheadAnyOf('#', '->', '==', '<>', '//', ']', '[', '{', '}', '|', '/*', '\n')
                and not isAtEnd()
                and not (opts and opts.stopAtQuote and ahead('"')) do -- FIXME hack or not?
                if ahead('\\') then
                    result = result .. currentText(s)
                    next() -- skip the backslash
                    result = result .. peek(1)
                    next()
                    s = current
                end
                next()
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
            local s = current
            -- FIXME: https://github.com/inkle/ink/blob/master/Documentation
            -- /WritingWithInk.md#part-6-international-character-support-in-identifiers
            local c = peekCode()
            local first = true
            while c ~= nil and (
                -- TODO
                c==95 -- _
                or c==46 -- .
                or (c>=65 and c<=90) -- A-Z
                or (c>=97 and c<=122) -- a-z
                or (not first and c>=48 and c<=57)
                ) do -- TODO!


                next()
                c = peekCode()
                first = false
            end
            if s == current then -- nothing consumed
                errorAt('identifier expected')
            end
            return currentText(s)
        end


        -- cross dependency, must be defined earlier
        local term, expression, divert, inkText, knotBody, optionBody, gatherBody, branchInkText;

        local stringLiteral = function()
            consume('"')
            -- string defined in ink can contain ink - although it will always evaluate to a string.
            local result = inkText{stopAtQuote=true} -- TODO more tests
            consume('"')
            return result
        end

        local number = function()
            local s = current
            if ahead('-') then
                next()
            end
            while aheadAnyOf('0','1', '2','3','4','5','6','7','8','9') do -- TODO
                next()
            end
            return currentText(s)
        end

        local floatLiteral = function(intPart)
            consume('.')
            return token('float', tonumber(intPart..'.'..number()))
        end

        local intLiteral = function()
            local val = number()
            if ahead('.') then
                return floatLiteral(val)
            end
            return token('int', tonumber(val))
        end

        local argument = function()
            if ahead('->') then
                return divert()
            end
            return expression()
        end

        -- Arguments are the actual values or expressions passed to the function when calling it
        local arguments = function()
            if not ahead('(') then
                return {}
            end
            local args = {}
            consume('(')
            consumeWhitespace()
            while not ahead(')') do
                table.insert(args, argument())
                consumeWhitespace()
                if ahead(',') then
                    consume(",")
                    consumeWhitespace()
                end
            end
            consume(')')

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

                table.insert(params, {paramName, paramType})
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



        local functionCall = function(functionName)
            local argumentExpressions = arguments()
            return token('call', functionName, argumentExpressions)
        end


        term = function()
            if ahead('"') then
                return stringLiteral()
            end
            if aheadAnyOf('-', '0','1', '2','3','4','5','6','7','8','9') then -- TODO
                return intLiteral()
            end

            if ahead('(') then -- TODO this is expression and not term?
                consume('(')
                consumeWhitespace()
                local exp = expression()
                consumeWhitespace()
                consume(')')
                return exp
            end

            if ahead('true') then
                consume('true')
                return token('bool', true)
            end
            if ahead('false') then
                consume('false')
                return token('bool', false)
            end
            if aheadAnyOf('!', 'not') then
                consumeAnyOf('!', 'not');
                consumeWhitespace()
                return {'call', 'not', {expression()}}
            end

            local id = identifier()
            consumeWhitespace()
            if ahead('(') then
                return functionCall(id)
            end
            return token('ref', id) -- FIXME same name as function argument passed as a reference
        end


        -- precedence from lowest to highest
        local operatorList = {
            {'?'},
            {'or', '||', 'and', '&&'},
            {'!=', '=='},
            {'<=', '>=', '>', '<'},
            {'-', '+'},
            {'mod', '%', '/', '*'},
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

            while aheadAnyOf(table.unpack(operators)) do
                local operator = consumeAnyOf(table.unpack(operators))
                consumeWhitespace()

                while operatorStack[#operatorStack] ~= nil
                    and precedence[operator] <= precedence[operatorStack[#operatorStack]] do

                    local right = table.remove(operandStack)
                    local left = table.remove(operandStack)
                    local operatorFromStack = table.remove(operatorStack)
                    table.insert(operandStack, {'call', operatorFromStack, {left, right}})
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
                table.insert(operandStack, {'call', operatorFromStack, {left, right}})
            end

            if #operandStack > 1 then
                errorAt('expression parsing error')
            end

            return operandStack[1]
        end


        local include = function()
            if not ahead('INCLUDE') then return end
            consume("INCLUDE")
            consumeWhitespace()
            return token('include', filename())
        end

        local todo = function()
            if not ahead('TODO:') then return end
            consume("TODO:")
            consumeWhitespace()
            return token('todo', textLine())
        end

        divert = function()
            if not ahead('->') then return end
            consume("->")
            consumeWhitespace()
            local targetName = identifier()
            consumeWhitespace()
            local args = arguments()
            return token('divert', targetName, args)
        end

        -- == function add(x,y) ==
        local fnction = function()
            consumeWhitespace()
            local name = identifier()
            local params = parameters()

            consumeWhitespace()
            consumeAll('=')
            --local body = functionBody();
            return token('fn', name, params)
        end

        local knotOrFunction = function()
            if not ahead('==') then return end
            consume("==")
            consumeAll('=')
            consumeWhitespace()
            local id = identifier()
            if id == 'function' then
                return fnction()
            end

            consumeWhitespace()
            local params = parameters()
            consumeAll('=')
            consumeWhitespaceAndNewlines()
            local body = knotBody()
            -- TODO are they the same? use functions for knots? what about stitches
            return token('knot', id, params, body)
        end

        local stitch = function()
            if not ahead('=') then return end
            consume("=")
            consumeWhitespace()
            local id = identifier()
            consumeWhitespace()
            consume('\n')
            consumeWhitespaceAndNewlines()
            return token('stitch', id)
        end

        local gather = function(minNesting)
            if not ahead('-') then return end

            setMark()
            local nesting = 0
            while ahead("-") and not ahead("->") do
                consume("-")
                nesting = nesting + 1
                consumeWhitespace()
            end
            -- TODO test unbalanced option/gather nesting
            if nesting < minNesting then
                resetToMark()
                return
            end
            removeMark()

            local label = nil
            if ahead('(') then
                consume('(')
                label = identifier()
                consume(')')
                consumeWhitespace()
            end
            return token('gather', nesting, {gatherBody(minNesting)}, label) -- TODO inkText in a table??
        end



        -- minNesting: options with this or higher (deeper) nesting will be included in the body,
        -- options with lower nesting will not be parsed (to jump up one level)
        --
        local option = function(minNesting)
            if not (ahead('*') or ahead('+')) then return end
            local bulletSymbol = peek(1)
            local sticky = (bulletSymbol == '+') and "sticky" or nil

            setMark()
            local nesting = 0
            while ahead(bulletSymbol) do
                consume(bulletSymbol)
                nesting = nesting + 1
                consumeWhitespace()
            end
            if nesting < minNesting then
                resetToMark()
                return
            end
            removeMark()

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

            local t1 = text()

            local t2 = ""
            if ahead('[') then
                consume('[')
                t2 = text()
                consume(']')
            end

            local t3 = text()

            consumeWhitespaceAndNewlines()

            local body = optionBody(nesting+1) -- the parameter will come back to this function as minNesting
            if #t1 > 0 or #t3 > 0 then
                -- FIXME
                local str = t1
                if t3:sub(1,1) == ' ' and t1:sub(-1) == ' ' then
                    str = str:sub(1, -2)
                end
                str = str .. t3
                table.insert(body, 1, {'str', str}) -- FIXME
                table.insert(body, 2, {'nl'}) -- FIXME I034
            end
            -- TODO use named arguments or some other mechanism
            return token('option', nesting, t1, t2, t3, name, sticky, conditions, body)
        end

        -- choice wraps multiple options + an optional gather
        -- All those are at the same nesting level, options could have sub-choices (nested options)
        local choice = function(minNesting, opts)
            if not (ahead('*') or ahead('+')) then return end
            local options = {}
            while not isAtEnd() do
                local node = option(minNesting)
                if node == nil then
                    break
                end
                table.insert(options, node)
            end
            -- TODO this might be simpler if we were parsing "tokens"
            -- where we would see the 'depth' already
            if #options == 0 then return end

            local gatherNode = nil
            if not opts or not opts.gatherNotAllowed then
                gatherNode = gather(minNesting)
            end

            return token('choice', options, gatherNode)

        end

        local tag = function()
            if not ahead('#') then return end
            consume("#")
            consumeWhitespace()
            return token('tag', text())
        end

        local constant = function()
            if not ahead('CONST') then return end
            consume("CONST")
            consumeWhitespace()
            local name = identifier()
            consumeWhitespace()
            consume("=")
            consumeWhitespace()
            local value = expression()
            consumeWhitespaceAndNewlines()
            return token('const', name, value)
        end

        local variable = function()
            if not ahead('VAR') then return end
            consume("VAR")
            consumeWhitespace()
            local name = identifier()
            consumeWhitespace()
            consume("=")
            consumeWhitespace()
            local value = expression()
            consumeWhitespaceAndNewlines()
            return token('var', name, value)
        end

        local tempVariable = function()
            if not ahead('temp') then return end

            consume("temp")
            consumeWhitespace()
            local name = identifier()
            consumeWhitespace()
            consume("=")
            consumeWhitespace()
            local value = expression()
            consumeWhitespaceAndNewlines()
            return token('tempvar', name, value) --TODO better name? local var? var?
        end

        local list = function()
            if not ahead('LIST') then return end
            consume("LIST")
            consumeWhitespace()
            local name = identifier()
            consumeWhitespace()
            consume("=")
            consumeWhitespace()

            local list = {'list', name, expression()}
            while not eolAhead() do
                consumeWhitespace()
                consume(",")
                consumeWhitespace()
                table.insert(list, expression())
            end
            consumeWhitespaceAndNewlines()
            return list
        end

        local para = function(opts)
            local t = text(opts)
            if #t > 0 then
                return token('str', t)
            end
        end

        --TODO name? used for sequences, variable printing, conditional text, cond. option
        local alternative = function()
            if not ahead('{') then return end

            consume("{")
            consumeWhitespaceAndNewlines()

            -- Cycles are like sequences, but they loop their content.
            if ahead('&') then
                consume('~')
                -- TODO same as seq below, extract to a function
                consumeWhitespaceAndNewlines()
                local result = {inkText()}
                while ahead('|') do
                    consume('|')
                    local element = inkText()
                    if element ~= nil then
                        table.insert(result, element)
                    end
                end
                consume("}")
                return {'cycle', result}
            end

            -- Once-only alternatives are like sequences, but when they
            -- run out of new content to display, they display nothing.
            -- (as a sequence with a blank last entry.)
            if ahead('!') then
                consume('!')
                -- TODO same as seq below, extract to a function
                consumeWhitespaceAndNewlines()
                local result = {inkText()}
                while ahead('|') do
                    consume('|')
                    local element = inkText()
                    if element ~= nil then
                        table.insert(result, element)
                    end
                end
                consume("}")
                return {'once', result}
            end

            -- shuffle (randomised output)
            if ahead('~') then
                consume('~')
                -- TODO same as seq below, extract to a function
                consumeWhitespaceAndNewlines()
                local result = {inkText()}
                while ahead('|') do
                    consume('|')
                    local element = inkText()
                    if element ~= nil then
                        table.insert(result, element)
                    end
                end
                consume("}")
                return {'shuf', 'cycle', result}
            end

            -- Sequence: go through the alternatives, and stick on last
            if ahead('stopping') then
                consume('stopping')
                -- TODO extract to a function
                consumeWhitespaceAndNewlines()
                consume(':')
                consumeWhitespaceAndNewlines()
                local result = {}
                while ahead('-') do
                    consume('-')
                    consumeWhitespaceAndNewlines()
                    local element = branchInkText()
                    if element ~= nil then
                        table.insert(result, {element}) -- TODO inkText in a table?
                    end
                end
                consume("}")
                return {'seq', result}
            end

            -- Shuffle: show one at random
            if ahead('shuffle') then
                consume('shuffle')
                -- TODO extract to a function
                consumeWhitespaceAndNewlines()
                local shuffleType = 'cycle'
                if ahead('once') then
                    shuffleType = 'once'
                    consume('once')
                    consumeWhitespaceAndNewlines()
                end
                if ahead('stopping') then
                    shuffleType = 'stopping'
                    consume('stopping')
                    consumeWhitespaceAndNewlines()
                end
                consume(':')
                consumeWhitespaceAndNewlines()
                local result = {}
                while ahead('-') do
                    consume('-')
                    consumeWhitespaceAndNewlines() -- ?
                    local element = branchInkText()
                    if element ~= nil then
                        table.insert(result, {element}) -- TODO inkText in a table?
                    end
                end
                consume("}")
                return {'shuf', shuffleType, result}
            end

            -- Cycle: show each in turn, and then cycle
            if ahead('cycle') then
                consume('cycle')
                -- TODO extract to a function
                consumeWhitespaceAndNewlines()
                consume(':')
                consumeWhitespaceAndNewlines()
                local result = {}
                while ahead('-') do
                    consume('-')
                    consumeWhitespaceAndNewlines()
                    local element = branchInkText()
                    if element ~= nil then
                        table.insert(result, {element}) -- TODO inkText in a table?
                    end
                end
                consume("}")
                return {'cycle', result}
            end

            -- Once-only alternatives are like sequences, but when they
            -- run out of new content to display, they display nothing.
            -- (as a sequence with a blank last entry.)
            if ahead('once') then
                consume('once')
                -- TODO extract to a function
                consumeWhitespaceAndNewlines()
                consume(':')
                consumeWhitespaceAndNewlines()
                local result = {}
                while ahead('-') do
                    consume('-')
                    consumeWhitespaceAndNewlines()
                    local element = branchInkText()
                    if element ~= nil then
                        table.insert(result, {element}) -- TODO inkText in a table?
                    end
                end
                consume("}")
                return {'once', result}
            end



            local beginning = current

            if ahead('-') and not ahead('->') then
                consume('-')
            end
            consumeWhitespaceAndNewlines()

            local first = expression()
            consumeWhitespaceAndNewlines()

            if ahead('}') then
                -- variable printing: {expression}
                consume("}")
                return first

            elseif ahead(':') then
                -- Conditional block: {expr:textIfTrue}
                -- or {expr:textIfTrue|textIfFalse}
                consume(':')
                consumeWhitespaceAndNewlines()
                local branches = {}
                if ahead('-') and not ahead('->') then
                    -- switch: {x: -0: zero -1: one}
                    while ahead('-') do
                        consume('-')
                        consumeWhitespaceAndNewlines()
                        if ahead('else') then
                            consume('else')
                            consumeWhitespaceAndNewlines()
                            consume(':')
                            consumeWhitespaceAndNewlines()
                            table.insert(branches, {{'bool', true}, {branchInkText()}})
                        else
                            local condition = {'call', '==', {first, expression()}}
                            consumeWhitespace()
                            consume(':')
                            consumeWhitespaceAndNewlines()
                            table.insert(branches, {condition, {branchInkText()}})
                        end
                    end

                else
                    table.insert(branches, {first, {branchInkText()}}) -- TODO wrap
                    consumeWhitespaceAndNewlines()
                    if ahead('|') then
                        consume('|')
                        -- else branch, the condition is always true
                        table.insert(branches, {{'bool', true}, {branchInkText()}})
                    elseif ahead('-') then
                        while ahead('-') do
                            consume('-')
                            consumeWhitespaceAndNewlines()
                            if ahead('else') then
                                consume('else')
                                consumeWhitespaceAndNewlines()
                                consume(':')
                                consumeWhitespaceAndNewlines()
                                table.insert(branches, {{'bool', true}, {branchInkText()}})
                            else
                                local condition = expression()
                                consumeWhitespace()
                                consume(':')
                                consumeWhitespaceAndNewlines()
                                table.insert(branches, {condition, {branchInkText()}})
                            end
                        end
                    end
                end

                consume("}")
                return token('if', branches) -- TODO wrapping
            end

            -- reset parser pointer back after the opening '{'
            -- and read the first element again, this time as ink text
            current = beginning --TODO use mark
            first = inkText()
            consumeWhitespace()

            if ahead('|') then
                -- A sequence (or a "stopping block") is a set of alternatives that tracks
                -- how many times its been seen, and each time, shows the next element along.
                -- When it runs out of new content it continues the show the final element.
                -- {text|text|...}
                local result = {{first}} -- TODO too much wrapping?
                while ahead('|') do
                    consume('|')
                    local element = {inkText()} -- TODO too much wrapping?
                    if element ~= nil then
                        table.insert(result, element)
                    end
                end
                consume("}")
                return {'seq', result}
            end
            -- TODO other types
            errorAt('invalid alternative')
        end


        local glue = function()
            if not ahead('<>') then return end

            consume("<>")
            return token('glue')
        end

        local returnStatement = function()
            consume('return')
            consumeWhitespace()
            if eolAhead() then
                return token('return')
            else
                return token('return', expression())
            end
        end

        local statement = function()
            if not ahead('~') then return end

            consume("~")
            consumeWhitespace()
            if ahead('return') then
                return returnStatement()
            elseif ahead('temp') then
                return tempVariable()
            else
                local id = identifier()
                consumeWhitespace()
                if ahead('(') then
                    return functionCall(id)
                elseif ahead('++') then
                    consume('++')
                    return token('call', '++', {{'ref', id}})
                elseif ahead('--') then
                    consume('--')
                    return token('call', '--', {{'ref', id}})
                elseif ahead('=') then
                    consume('=')
                    consumeWhitespace()
                    return token('assign', id, expression())
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
            elseif ahead('==') then
                return knotOrFunction()
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
            elseif ahead('==') then
                return nil------------------------
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
            elseif ahead('==') then
                return nil------------------------
            elseif ahead('=') then
                return nil------------------------
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
            elseif ahead('==') then
                return nil------------------------
            elseif ahead('=') then
                return nil------------------------
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
            elseif ahead('==') then
                return nil------------------------
            elseif ahead('=') then
                return nil------------------------
            elseif ahead('*') or ahead('+') then
                return choice(1, {gatherNotAllowed = true})
            elseif ahead('-') then -- new branch start
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


        knotBody = function(opts)
            local result = {} -- TODO just table or 'block'?

            while not isAtEnd() do
                local node = knotBodyNode(opts)
                if node == nil then
                    break
                end
                table.insert(result, node)
            end
            return result
        end

        optionBody = function(minNesting, opts)
            local result = {} -- TODO just table or 'block'?

            while not isAtEnd() do
                local node = optionBodyNode(minNesting, opts)
                if node == nil then
                    break
                end
                table.insert(result, node)
            end
            return result
        end


        gatherBody = function(minNesting, opts)
            local result = {} -- TODO just table or 'block'?

            while not isAtEnd() do
                local node = gatherBodyNode(minNesting, opts)
                if node == nil then
                    break
                end
                table.insert(result, node)
            end
            return {'ink', result}
        end

        -- used in sequences / conditionals ("multiline blocks"?)
        -- where a dash means a branch start, not a gather
        branchInkText = function(opts)
            local result = {} -- TODO just table or 'block'?

            while not isAtEnd() do
                local node = branchInkNode(opts)
                if node == nil then
                    break
                end
                table.insert(result, node)
            end
            return {'ink', result}
        end

        inkText = function(opts)
            local result = {} -- TODO just table or 'block'?

            while not isAtEnd() do

                local startCursor = current

                local node = inkNode(opts)
                if node ~= nil then
                    table.insert(result, node)
                end

                if current == startCursor then
                    break
                    --errorAt("nothing consumed") --FIXME
                end

            end
            return {'ink', result}
        end




        local statements = {inkText()}
        --_debug(statements)
        return statements
end

