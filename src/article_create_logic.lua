local article = require("article")

local article_create_logic = {}

function article_create_logic.verify(article_id, title, body, owner, cmd, msg, env)
    return article.new_article_created(article_id, title, body, owner)
end

function article_create_logic.new(event, msg, env)
    -- print("event.title" .. tostring(event.title))
    return article.new(event.title, event.body, event.owner)
end

return article_create_logic
