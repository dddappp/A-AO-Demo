local article = require("article")

local article_update_logic = {}


function article_update_logic.verify(_state, title, body, cmd, msg, env)
    return article.new_article_updated(_state, title, body)
end

function article_update_logic.mutate(state, event, msg, env)
    -- Applies the event to the current state and returns the updated state
    state.title = event.title
    state.body = event.body
    return state
end

return article_update_logic
