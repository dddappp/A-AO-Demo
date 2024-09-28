local article = require("article")

local article_create_logic = {}


--- Verify Article.Create command
-- @param article_id number The ArticleId of the Article
-- @param title string 
-- @param body string 
-- @param cmd table The command
-- @param msg any The original message
-- @param env table The environment context
-- @return table The event, can use `article.new_article_created` to create it
function article_create_logic.verify(article_id, title, body, cmd, msg, env)
    return article.new_article_created(article_id, title, body, msg.Owner)
end

--- Create a new Article
-- @param event table The event
-- @param msg any The original message
-- @param env any The environment context
-- @return table The state of the Article
function article_create_logic.new(event, msg, env)
    return article.new(event.title, event.body, event.owner)
end

return article_create_logic
