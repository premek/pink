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
    lineHasContent = false,
    trimStack = {}, -- tracks function call output: [{savedLineHasContent, hadOutput}]
    instr = function(self, instr)
        table.insert(self.buffer, { [instr] = true })
        if instr == 'trim' then
            table.insert(self.trimStack, { saved = self.lineHasContent, hadOutput = false })
        elseif instr == 'trimEnd' then
            local frame = table.remove(self.trimStack)
            if frame.hadOutput then
                self.lineHasContent = true
                if #self.trimStack > 0 then
                    self.trimStack[#self.trimStack].hadOutput = true
                end
            else
                self.lineHasContent = frame.saved
            end
        end
    end,
    add = function(self, text)
        _debug('OUT add:', text)
        table.insert(self.buffer, text)
        self.lineHasContent = true
        if #self.trimStack > 0 and trim(text) ~= '' then
            self.trimStack[#self.trimStack].hadOutput = true
        end
    end,
    nl = function(self)
        if self.lineHasContent then
            table.insert(self.buffer, '\n')
            self.lineHasContent = false
        end
    end,
    collect = function(self)
        _debug(self.buffer)

        -- if {out} / if / seq is not at a line start then insert glue
        local t = {}
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
        if self.buffer[#self.buffer] == '\n' then
            table.remove(self.buffer, #self.buffer)
        end

        _debug('collect end', self.buffer)
    end,
    popLine = function(self)
        self:collect()
        if #self.buffer < 1 then
            error('no line to pop')
        end
        local result = trim(self.buffer[1])
        table.remove(self.buffer, 1)
        if self.buffer[1] == '\n' then
            table.remove(self.buffer, 1)
        end
        local trailingGlue = self.hadTrailingGlue
        self.hadTrailingGlue = false
        return result, trailingGlue
    end,
    clear = function(self)
        self.buffer = {}
        self.lineHasContent = false
        self.trimStack = {}
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
