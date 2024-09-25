local article = require("article")

local article_update_body_logic = {}

--- Verify article create command
-- @param _state table The current state of the article
-- @param body string The content body of the article
-- @param cmd table The command
-- @param msg any The original message
-- @param env any The environment context
-- @return table The event, can use `article.new_article_body_updated` to create it
function article_update_body_logic.verify(_state, body, cmd, msg, env)
    return article.new_article_body_updated(_state, body)
end

--- Update the body of an article
-- @param state table The current state of the article
-- @param event table The event
-- @param msg any The original message
-- @param env any The environment context
-- @return table The updated state of the article
function article_update_body_logic.mutate(state, event, msg, env)
    -- Applies the event to the current state and returns the updated state
    state.body = event.body
    return state
    -- Or just return article.new(event.title, event.body, event.owner)
end

return article_update_body_logic
