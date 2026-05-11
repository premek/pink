local Story = {}

Story.new = function(env)
    return {
        globalTags = {},
        state = {
            visitCount = {},
        },
        variablesState = env,
        canContinue = true, -- true before first continue(), matching C# Ink API
    }
end

return Story
