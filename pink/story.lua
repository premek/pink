local Story = {}

Story.new = function(env)
    return {
        globalTags = {},
        state = {
            visitCount = {},
            usedOptions = {}, -- [nodeId] = true
            seqState = {}, -- [nodeId] = {current, shuffleOrder}
        },
        variablesState = env,
        canContinue = true, -- true before first continue(), matching C# Ink API
        currentChoices = {},
        currentTags = {},
    }
end

return Story
