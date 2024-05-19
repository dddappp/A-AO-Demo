local article = require("article")

local article_create_logic = {}

function article_create_logic.verify(cmd, msg, env)
    return article.new_article_created(cmd.article_id, cmd.title, cmd.body, cmd.owner)
end

function article_create_logic.new(event, msg, env)
    -- print("event.title" .. tostring(event.title))
    return article.new(event.title, event.body, event.owner)
end

return article_create_logic
