local Story = {}

Story.new = function(env)
    return {
        globalTags = {},
        state = {
            visitCount = {},
        },
        variablesState = env,
        canContinue = true,
    }
end

return Story
