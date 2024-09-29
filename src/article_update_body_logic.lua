--- Updates the body of an article
--
-- @module article_update_body_logic

local article = require("article")

local article_update_body_logic = {}


--- Verifies the Article.UpdateBody command.
-- @param _state table The current state of the Article
-- @param body string 
-- @param cmd table The command
-- @param msg any The original message. Properties of an AO msg may include `Timestamp`, `Block-Height`, `Owner`, `Nonce`, etc.
-- @param env table The environment context
-- @return table The event, can use `article.new_article_body_updated` to create it
function article_update_body_logic.verify(_state, body, cmd, msg, env)
    if type(body) ~= "string" or body == "" then
        error("Invalid body: must be a non-empty string")
    end
    
    if not _state or type(_state) ~= "table" then
        error("Invalid state: must be a table")
    end
    
    return article.new_article_body_updated(
        _state, -- type: table
        body -- type: string
    )
end

--- Applies the event to the current state and returns the updated state.
-- @param state table The current state of the Article
-- @param event table The event
-- @param msg any The original message. Properties of an AO msg may include `Timestamp`, `Block-Height`, `Owner`, `Nonce`, etc.
-- @param env any The environment context
-- @return table The updated state of the Article
function article_update_body_logic.mutate(state, event, msg, env)
    state.body = event.body
    return state
end

return article_update_body_logic
