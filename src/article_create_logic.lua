local article = require("article")

local article_create_logic = {}

--- Verify article create command
-- @param article_id number The unique identifier for the article
-- @param title string The title of the article
-- @param body string The content body of the article
-- @param owner string The owner of the article
-- @param cmd table The command
-- @param msg any The original message
-- @param env any The environment context
-- @return table The event, can use `article.new_article_created` to create it
function article_create_logic.verify(article_id, title, body, cmd, msg, env)
    return article.new_article_created(article_id, title, body, msg.Owner)
end

--- Create a new article
-- @param event table The event
-- @param msg any The original message
-- @param env any The environment context
-- @return table The state of the article
function article_create_logic.new(event, msg, env)
    return article.new(event.title, event.body, event.owner)
end

return article_create_logic
