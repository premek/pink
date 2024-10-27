local Story = {}

Story.new = function(env)
    return {
        globalTags = {},
        state = {
            visitCount = {},
        },
        variablesState = env,
        canContinue = false,
    }
end

return Story
