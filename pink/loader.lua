local base_path = (...):match('(.-)[^%.]+$')
local read = require(base_path .. 'reader')
local parse = require(base_path .. 'parser')
local scan = require(base_path .. 'scanner')
local preprocess = require(base_path .. 'preprocessor')

local function isAbsolute(path)
    return path:sub(1, 1) == '/'
end

local function toAbsolute(filename, dir)
    return isAbsolute(filename) and filename or (dir .. '/' .. filename)
end

local function basedir(str)
    return string.gsub(str, '(.*)(/.*)', '%1')
end

return function(filename)
    local resolveIncludes, load

    resolveIncludes = function(nodes, dir)
        local result = {}
        for _, t in ipairs(nodes) do
            if t.type == 'include' then
                local included = load(toAbsolute(t.filename, dir))
                for _, n in ipairs(included) do
                    table.insert(result, n)
                end
            elseif t.nodes then
                t.nodes = resolveIncludes(t.nodes, dir)
                table.insert(result, t)
            else
                table.insert(result, t)
            end
        end
        return result
    end

    load = function(file)
        local content = read(file)
        local preprocessed = preprocess(content)
        local tokens = scan(preprocessed, filename)
        local parsed = parse(tokens)
        return resolveIncludes(parsed, basedir(file))
    end

    return load(filename)
end
