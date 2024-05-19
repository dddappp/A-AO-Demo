local article = require("article")

local article_update_body_logic = {}

function article_update_body_logic.verify(state, cmd, msg, env)
    return article.new_article_body_updated(state, cmd.body)
end

function article_update_body_logic.mutate(state, event, msg, env)
    -- return article.new(event.title, event.body, event.owner)
    state.body = event.body
    return state
end

return article_update_body_logic
