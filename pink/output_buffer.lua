local base_path = (...):match('(.-)[^%.]+$')
local logging = require(base_path .. 'logging')
local log = logging.newLogger()

local rtrim = function(s)
    return s:match('(.-)%s*$')
end
--[[
local ltrim = function(s)
return s:match("^%s*(.-)")
end]]
local trim = function(s)
    return s:match('^%s*(.-)%s*$')
end

local resolveNlInstructions = function(buffer)
    local t = {}
    local lineHasContent = false
    local lineHadEmptyBlock = false
    local trimStack = {} -- {savedLineHasContent, hadOutput}
    local outBlockContentStack = {} -- tracks whether each nested seq block had content
    for _, e in ipairs(buffer) do
        if e == '\n' then
            table.insert(t, e)
            lineHasContent = false
            lineHadEmptyBlock = false
        elseif e['nl'] then
            if lineHasContent then
                table.insert(t, '\n')
                lineHasContent = false
                lineHadEmptyBlock = false
            elseif lineHadEmptyBlock then
                -- standalone empty seq block on this line: emit a blank-line marker
                table.insert(t, { blankLine = true })
                lineHadEmptyBlock = false
            end
        elseif e['outBlockStart'] then
            table.insert(outBlockContentStack, false)
            table.insert(t, e)
        elseif e['outBlockEnd'] then
            local hadContent = table.remove(outBlockContentStack)
            if not hadContent and not lineHasContent then
                lineHadEmptyBlock = true
            end
            table.insert(t, e)
        elseif e['trim'] then
            table.insert(trimStack, { saved = lineHasContent, hadOutput = false })
            lineHasContent = false
            table.insert(t, e)
        elseif e['trimEnd'] then
            local frame = table.remove(trimStack)
            if frame.hadOutput then
                lineHasContent = true
                if #trimStack > 0 then
                    trimStack[#trimStack].hadOutput = true
                end
            else
                lineHasContent = frame.saved
            end
            table.insert(t, e)
        elseif type(e) == 'string' then
            lineHasContent = true
            lineHadEmptyBlock = false
            if trim(e) ~= '' then
                if #trimStack > 0 then
                    trimStack[#trimStack].hadOutput = true
                end
                if #outBlockContentStack > 0 then
                    outBlockContentStack[#outBlockContentStack] = true
                end
            end
            table.insert(t, e)
        else
            table.insert(t, e)
        end
    end
    return t
end

local insertOutBlockGlue = function(buffer)
    local t = {}
    for i = 1, #buffer do
        if buffer[i]['outBlockStart'] then
            -- For seq blocks: look ahead for a matching outBlockEnd with no real content
            -- between them (empty branch). If so, skip glue insertion.
            -- If-blocks have no outBlockEnd, so they always take the glue path.
            local hasOutBlockEnd = false
            local hasContent = false
            local depth = 1
            for j = i + 1, #buffer do
                if buffer[j]['outBlockStart'] then
                    depth = depth + 1
                elseif buffer[j]['outBlockEnd'] then
                    depth = depth - 1
                    if depth == 0 then
                        hasOutBlockEnd = true
                        break
                    end
                elseif type(buffer[j]) == 'string' and trim(buffer[j]) ~= '' then
                    hasContent = true
                    break
                end
            end
            if not hasOutBlockEnd or hasContent then
                for j = #t, 1, -1 do
                    if t[j] and t[j]['trim'] then
                        break -- don't insert glue across function scope boundaries
                    end
                    if t[j] and type(t[j]) == 'string' then
                        if t[j] ~= '\n' then
                            table.insert(t, { glue = true })
                        end
                        break
                    end
                end
            end
        elseif not buffer[i]['outBlockEnd'] then
            table.insert(t, buffer[i])
        end
    end
    return t
end

local applyGlue = function(buffer)
    local t = {}
    local glue = false
    for _, e in ipairs(buffer) do
        if e['glue'] then
            glue = true
            for i = #t, 1, -1 do
                if t[i] == '\n' then
                    table.remove(t, i)
                elseif type(t[i]) == 'string' and trim(t[i]) == '' then
                    local _ -- keep spaces, but keep glueing
                elseif type(t[i]) == 'string' or t[i]['trim'] then
                    break
                end
            end
        elseif glue and e == '\n' then
            local _
            -- ignore newlines after glue
        else
            table.insert(t, e)
            if type(e) == 'string' or e['trimEnd'] then -- TODO
                glue = false
            end
        end
    end
    return t
end

local applyTrimEnd = function(buffer)
    local t = {}
    for i, e in ipairs(buffer) do
        if e['trimEnd'] then
            for j = i - 1, 1, -1 do
                if t[j] then
                    if t[j]['trim'] then
                        table.remove(t, j)
                        break
                    end
                    t[j] = rtrim(t[j])
                    if #t[j] > 0 then
                        break
                    end
                end
            end
        else
            table.insert(t, e)
        end
    end
    return t
end

local removeEmptyTrim = function(buffer)
    local t = {}
    for _, e in ipairs(buffer) do
        if not e['trim'] and e ~= '' then
            table.insert(t, e)
        end
    end
    return t
end

local collapseDoubleNewlines = function(buffer)
    local t = {}
    for _, e in ipairs(buffer) do
        if e == '\n' and t[#t] == '\n' then
            local _
            -- remove double newlines
        else
            table.insert(t, e)
        end
    end
    return t
end

local joinToLines = function(buffer)
    local t = { '' }
    for i, e in ipairs(buffer) do
        if type(e) == 'table' and e['blankLine'] then
            -- Only emit when this is the sole blankLine between two pieces of content.
            -- Adjacent blankLines (multiple consecutive empty seq branches, e.g. once-seq
            -- with empty middle items) must be suppressed entirely.
            local prevIsBlank = i > 1 and type(buffer[i - 1]) == 'table' and buffer[i - 1]['blankLine']
            local nextIsBlank = i < #buffer and type(buffer[i + 1]) == 'table' and buffer[i + 1]['blankLine']
            if not prevIsBlank and not nextIsBlank then
                local hasContentAfter = false
                for j = i + 1, #buffer do
                    if type(buffer[j]) == 'string' and trim(buffer[j]) ~= '' then
                        hasContentAfter = true
                        break
                    end
                end
                if hasContentAfter then
                    table.insert(t, '\n')
                    table.insert(t, '')
                end
            end
        elseif e ~= '\n' then
            t[#t] = t[#t] .. e
        else
            t[#t] = (t[#t]:gsub(' +', ' '):gsub('\n +', '\n'))
            table.insert(t, e)
            table.insert(t, '')
        end
    end
    while t[#t] == '' do -- eh
        table.remove(t, #t) -- remove the last empty placeholder
    end
    if t[#t] and t[#t] ~= '\n' and trim(t[#t]) == '' then
        table.remove(t, #t)
    end
    local str = table.concat(t)
    local result = {}
    local s = str
    while #s > 0 do
        local nl = s:find('\n', 1, true)
        if nl then
            table.insert(result, s:sub(1, nl - 1))
            table.insert(result, '\n')
            s = s:sub(nl + 1)
        else
            table.insert(result, s)
            s = ''
        end
    end
    local hadTrailingNl = result[#result] == '\n'
    if hadTrailingNl then
        table.remove(result, #result)
    end
    return result, hadTrailingNl
end

-- Returns true if buffer ends with a glue instruction (ignoring trailing '\n's).
-- Must be called on the raw buffer before collect() consumes the glue instruction.
local hasTrailingGlue = function(buffer)
    for i = #buffer, 1, -1 do
        local e = buffer[i]
        if type(e) == 'string' and e ~= '\n' then
            return false -- real content before any glue
        elseif e['glue'] then
            return true
        end
    end
    return false
end

return function()
    return {
        buffer = {},
        hadTrailingGlue = false,
        -- true when collect() found a trailing '\n' in the buffer (natural paragraph break)
        hadTrailingNl = false,
        -- prevents a second collect() from re-running and overwriting hadTrailingNl
        needsCollect = false,
        -- set when a terminalDivert instruction (->END/DONE) was seen during collect()
        terminalDivert = false,
        -- set when a threadChoice instruction is collected; cleared by onNewChoice()
        threadChoiceAdded = false,
        -- true once any text is produced since the last onNewChoice() call
        hadOutput = false,
        -- true after at least one onNewChoice() call; guards first-interaction paragraph breaks
        pastFirstChoice = false,
        -- set by collect() when an outBlockStart (if-conditional entry) is in the buffer this turn
        hadOutBlockThisTurn = false,
        -- pre-pop state: captured by prePop() before the second update() in continue()
        preRes = '',
        preTrailingGlue = false,
        preHadNl = true,
        preBufferWasEmpty = true,
        preRawHadContent = false,
        instr = function(self, instr)
            self.needsCollect = true
            table.insert(self.buffer, { [instr] = true })
        end,
        add = function(self, text)
            log.debug('OUT add:', text)
            self.needsCollect = true
            table.insert(self.buffer, text)
        end,
        nl = function(self)
            self.needsCollect = true
            table.insert(self.buffer, { nl = true })
        end,
        collect = function(self)
            if not self.needsCollect then
                return
            end
            self.needsCollect = false
            log.debug(self.buffer)
            local buf = self.buffer
            -- extract meta-instructions before the pipeline
            local cleaned = {}
            for _, e in ipairs(buf) do
                if type(e) == 'table' and e['terminalDivert'] then
                    self.terminalDivert = true
                elseif type(e) == 'table' and e['threadChoice'] then
                    self.threadChoiceAdded = true
                else
                    table.insert(cleaned, e)
                end
            end
            buf = cleaned
            -- detect if-block entry: if has unmatched outBlockStart (seq always has matching outBlockEnd)
            local outBlockDepth = 0
            for _, e in ipairs(buf) do
                if type(e) == 'table' then
                    if e['outBlockStart'] then
                        outBlockDepth = outBlockDepth + 1
                    elseif e['outBlockEnd'] then
                        outBlockDepth = outBlockDepth - 1
                    end
                end
            end
            if outBlockDepth > 0 then
                self.hadOutBlockThisTurn = true
            end
            self.hadTrailingGlue = hasTrailingGlue(buf)
            buf = resolveNlInstructions(buf) -- convert {nl} markers to '\n'; must run first to establish line state
            buf = insertOutBlockGlue(buf) -- insert glue before output blocks; needs resolved newlines
            buf = applyGlue(buf) -- remove newlines before glued items; needs glue inserted
            buf = applyTrimEnd(buf) -- rtrim at function scope exits; needs glue applied first
            buf = removeEmptyTrim(buf) -- drop orphaned {trim} markers remaining after applyTrimEnd
            buf = collapseDoubleNewlines(buf) -- prevent consecutive '\n\n'; final cleanup
            buf, self.hadTrailingNl = joinToLines(buf) -- produce [string, '\n', ...] sequence for popLine()
            self.buffer = buf
            log.debug('collect end', self.buffer)
        end,
        popLine = function(self)
            self:collect()
            if #self.buffer < 1 then
                error('no line to pop')
            end
            local result = trim(self.buffer[1])
            table.remove(self.buffer, 1)
            local hadNl
            if self.buffer[1] == '\n' then
                hadNl = true
                table.remove(self.buffer, 1)
            else
                -- last line: use flag set by collect() when it stripped the trailing '\n'
                hadNl = self.hadTrailingNl
                self.hadTrailingNl = false
            end
            local trailingGlue = self.hadTrailingGlue
            self.hadTrailingGlue = false
            return result, trailingGlue, hadNl
        end,
        -- Resets per-choice tracking state; called from chooseChoiceIndex().
        onNewChoice = function(self)
            self.hadOutput = false
            self.threadChoiceAdded = false
            self.terminalDivert = false
            self.pastFirstChoice = true
            self.hadOutBlockThisTurn = false
        end,
        -- Captures buffer state before the second update() in continue(); must be called
        -- before update() so that handleChoice() sees an empty buffer and processes choices.
        prePop = function(self)
            self.preRawHadContent = #self.buffer > 0
            self.preBufferWasEmpty = self:isEmpty() -- calls collect()
            self.preRes, self.preTrailingGlue, self.preHadNl = '', false, true
            if not self.preBufferWasEmpty then
                self.preRes, self.preTrailingGlue, self.preHadNl = self:popLine()
            end
        end,
        -- Formats one continue() result using pre-pop state (from prePop()) and current buffer.
        -- ctx: { hasChoices }
        -- Returns (formattedText, producedOutput, canContinue).
        popTurnLine = function(self, ctx)
            local res, trailingGlue, hadNl, bufferWasEmpty =
                self.preRes, self.preTrailingGlue, self.preHadNl, self.preBufferWasEmpty
            -- if update() added content to a truly empty buffer, pop it now
            if res == '' and not self.preRawHadContent and not self:isEmpty() then
                res, trailingGlue, hadNl = self:popLine()
                bufferWasEmpty = false
            end
            local endedByDivert = self.terminalDivert
            local canContinue = not self:isEmpty()
            if res == '' then
                if not bufferWasEmpty and not endedByDivert then
                    return '\n', false, canContinue -- whitespace-only line → blank line
                elseif ctx.hasChoices then
                    -- when thread choices are present and a turn has been taken with no text output,
                    -- emit an extra blank line (the thread transition creates a paragraph break)
                    local hasThreadChoices = self.pastFirstChoice and not self.hadOutput and self.threadChoiceAdded
                    return hasThreadChoices and '\n\n' or '\n', false, canContinue
                else
                    return '', false, canContinue -- story ended with no output
                end
            elseif trailingGlue or canContinue then
                self.hadOutput = true
                return res .. '\n', true, canContinue
            elseif not ctx.hasChoices then
                -- story ended; natural EOF always gets \n; ->END/DONE only gets \n if buffer had one
                self.hadOutput = true
                return res .. ((hadNl or not endedByDivert) and '\n' or ''), true, canContinue
            else
                self.hadOutput = true
                return res .. ((hadNl or self.hadOutBlockThisTurn) and '\n\n' or '\n'), true, canContinue
            end
        end,
        clear = function(self)
            local snapshot = {
                buffer = self.buffer,
                needsCollect = self.needsCollect,
                terminalDivert = self.terminalDivert,
                threadChoiceAdded = self.threadChoiceAdded,
                hadOutput = self.hadOutput,
                pastFirstChoice = self.pastFirstChoice,
                hadOutBlockThisTurn = self.hadOutBlockThisTurn,
                preRes = self.preRes,
                preTrailingGlue = self.preTrailingGlue,
                preHadNl = self.preHadNl,
                preBufferWasEmpty = self.preBufferWasEmpty,
                preRawHadContent = self.preRawHadContent,
            }
            self.buffer = {}
            self.hadTrailingNl = false
            self.needsCollect = false
            self.terminalDivert = false
            self.threadChoiceAdded = false
            -- hadOutput and pastFirstChoice intentionally NOT cleared:
            -- option text evaluation snapshots are within a single choice period
            self.hadOutBlockThisTurn = false
            self.preRes, self.preTrailingGlue, self.preHadNl = '', false, true
            self.preBufferWasEmpty = true
            self.preRawHadContent = false
            return snapshot
        end,
        reset = function(self, snapshot)
            self.buffer = snapshot.buffer
            self.needsCollect = snapshot.needsCollect
            self.terminalDivert = snapshot.terminalDivert
            self.threadChoiceAdded = snapshot.threadChoiceAdded
            self.hadOutput = snapshot.hadOutput
            self.pastFirstChoice = snapshot.pastFirstChoice
            self.hadOutBlockThisTurn = snapshot.hadOutBlockThisTurn
            self.preRes = snapshot.preRes
            self.preTrailingGlue = snapshot.preTrailingGlue
            self.preHadNl = snapshot.preHadNl
            self.preBufferWasEmpty = snapshot.preBufferWasEmpty
            self.preRawHadContent = snapshot.preRawHadContent
        end,
        isEmpty = function(self)
            self:collect()
            return #self.buffer == 0
        end,
        -- Returns true if continue() must be called after chooseChoiceIndex() to drain
        -- pending output or emit a paragraph break before presenting choices.
        needsContinue = function(self, hasChoices)
            return not self:isEmpty() or self.threadChoiceAdded or hasChoices
        end,
    }
end
