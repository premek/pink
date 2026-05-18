local base_path = (...):match('(.-)[^%.]+$')
local logging = require(base_path .. 'logging')
local _debug = logging.debug

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
    local trimStack = {} -- {savedLineHasContent, hadOutput}
    for _, e in ipairs(buffer) do
        if e == '\n' then
            table.insert(t, e)
            lineHasContent = false
        elseif e['nl'] then
            if lineHasContent then
                table.insert(t, '\n')
                lineHasContent = false
            end
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
            if trim(e) ~= '' and #trimStack > 0 then
                trimStack[#trimStack].hadOutput = true
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
            for j = i - 1, 0, -1 do
                if buffer[j] and buffer[j]['trim'] then -- FIXME eh?
                    break
                end
                if buffer[j] and type(buffer[j]) == 'string' then
                    if buffer[j] ~= '\n' then
                        table.insert(t, { glue = true })
                    end
                    break
                end
            end
        else
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

local joinToLines = function(buffer, midExpressionEnd)
    local t = { '' }
    for _, e in ipairs(buffer) do
        if e ~= '\n' then
            t[#t] = t[#t] .. e
        else
            t[#t], _ = t[#t]:gsub(' +', ' '):gsub('\n +', '\n')
            table.insert(t, e)
            table.insert(t, '')
        end
    end
    while t[#t] == '' do -- eh
        table.remove(t, #t) -- remove the last empty placeholder
    end
    if t[#t] == ' ' then -- eh
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
    local hadTrailingNl
    if result[#result] == '\n' then
        hadTrailingNl = true
        table.remove(result, #result)
    else
        -- no trailing '\n' means no natural paragraph break; suppress trailing '\n' only
        -- when ->END explicitly cut the line short (midExpressionEnd), otherwise keep it
        -- (e.g. ->DONE in option body, or source file without trailing newline)
        hadTrailingNl = not midExpressionEnd
    end
    return result, hadTrailingNl
end

-- TODO refactor
return function()
    return {
        buffer = {},
        hadTrailingGlue = false,
        -- true when collect() found a trailing '\n' in the buffer (natural paragraph break)
        hadTrailingNl = false,
        -- set by goTo('END') to suppress the trailing '\n' on the final line
        midExpressionEnd = false,
        -- prevents a second collect() from re-running and overwriting hadTrailingNl
        needsCollect = false,
        instr = function(self, instr)
            self.needsCollect = true
            table.insert(self.buffer, { [instr] = true })
        end,
        add = function(self, text)
            _debug('OUT add:', text)
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
            _debug(self.buffer)
            local buf = self.buffer
            buf = resolveNlInstructions(buf)
            buf = insertOutBlockGlue(buf)
            buf = applyGlue(buf)
            buf = applyTrimEnd(buf)
            buf = removeEmptyTrim(buf)
            buf = collapseDoubleNewlines(buf)
            buf, self.hadTrailingNl = joinToLines(buf, self.midExpressionEnd)
            self.buffer = buf
            self.midExpressionEnd = false
            _debug('collect end', self.buffer)
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
        clear = function(self)
            local snapshot = { buffer = self.buffer, needsCollect = self.needsCollect }
            self.buffer = {}
            self.hadTrailingNl = false
            self.midExpressionEnd = false
            self.needsCollect = false
            return snapshot
        end,
        reset = function(self, snapshot)
            self.buffer = snapshot.buffer
            self.needsCollect = snapshot.needsCollect
        end,
        isEmpty = function(self)
            -- scan raw buffer for trailing glue before collect() consumes the instruction;
            -- skip trailing '\n's since glue absorbs them
            for i = #self.buffer, 1, -1 do
                local e = self.buffer[i]
                if type(e) == 'string' and e ~= '\n' then
                    break -- real content before any glue: no trailing glue
                elseif e['glue'] then
                    self.hadTrailingGlue = true
                    break
                end
            end
            self:collect()
            return #self.buffer == 0
        end,
    }
end
