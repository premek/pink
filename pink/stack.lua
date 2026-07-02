return function(initialItems)
    local items = initialItems or {}
    return {
        push = function(item)
            table.insert(items, item)
        end,
        pop = function()
            return table.remove(items)
        end,
        isEmpty = function()
            return #items == 0
        end,
        size = function()
            return #items
        end,
        get = function(i)
            return items[i]
        end,
        clear = function()
            local savedItems = items
            items = {}
            return savedItems
        end,
    }
end
