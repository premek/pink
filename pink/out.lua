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

-- TODO refactor
return {
    buffer = {},
    hadTrailingGlue = false,
    -- true unless midExpressionEnd cut the line short; returned by popLine() so continue() knows whether to append '\n'
    hadTrailingNl = false,
    -- set by goTo when ->END fires inside an inline if/seq branch; line is incomplete, suppress trailing '\n'
    midExpressionEnd = false,
    -- prevents a second collect() from re-running and overwriting hadTrailingNl/midExpressionEnd
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

        -- resolve {nl}: emit '\n' only when the current logical line has non-whitespace content.
        -- trim/trimEnd pairs bracket inline function calls; we save lineHasContent on entry and
        -- restore it on exit unless the function produced non-whitespace output (hadOutput).
        -- this ensures outer-level whitespace counts for lineHasContent but function-body-only
        -- whitespace does not propagate out to affect the surrounding line's nl decisions.
        local t = {}
        local lineHasContent = false
        local trimStack = {} -- {savedLineHasContent, hadOutput}
        for _, e in ipairs(self.buffer) do
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
        self.buffer = t

        -- if {out} / if / seq is not at a line start then insert glue
        t = {}
        for i = 1, #self.buffer do
            if self.buffer[i]['outBlockStart'] then
                for j = i - 1, 0, -1 do
                    if self.buffer[j] and self.buffer[j]['trim'] then -- FIXME eh?
                        break
                    end
                    if self.buffer[j] and type(self.buffer[j]) == 'string' then
                        if self.buffer[j] ~= '\n' then
                            table.insert(t, { glue = true })
                        end
                        break
                    end
                end
            else
                table.insert(t, self.buffer[i])
            end
        end
        self.buffer = t

        t = {}
        local glue = false
        for _, e in ipairs(self.buffer) do
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
        self.buffer = t

        t = {}
        for i, e in ipairs(self.buffer) do
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
        self.buffer = t

        t = {}
        for _, e in ipairs(self.buffer) do
            if not e['trim'] and e ~= '' then
                table.insert(t, e)
            end
        end
        self.buffer = t

        t = {}
        for _, e in ipairs(self.buffer) do
            if e == '\n' and t[#t] == '\n' then
                local _
                -- remove double newlines
            else
                table.insert(t, e)
            end
        end
        self.buffer = t

        t = { '' }
        for _, e in ipairs(self.buffer) do
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

        self.buffer = t

        _debug(t)
        local str = table.concat(t)
        self.buffer = {}
        local s = str
        while #s > 0 do
            local nl = s:find('\n', 1, true)
            if nl then
                table.insert(self.buffer, s:sub(1, nl - 1))
                table.insert(self.buffer, '\n')
                s = s:sub(nl + 1)
            else
                table.insert(self.buffer, s)
                s = ''
            end
        end
        -- line is terminated if it had an explicit {nl}, or ended normally (no mid-expression divert)
        if self.buffer[#self.buffer] == '\n' then
            self.hadTrailingNl = true
            table.remove(self.buffer, #self.buffer)
        else
            self.hadTrailingNl = not self.midExpressionEnd
        end
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
        self.buffer = {}
        self.hadTrailingNl = false
        self.midExpressionEnd = false
        self.needsCollect = false
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
