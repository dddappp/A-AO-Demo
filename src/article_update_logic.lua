local article = require("article")

local article_update_logic = {}


function article_update_logic.verify(_state, title, body, cmd, msg, env)
    -- TODO return article.new_article_updated( ...
end

function article_update_logic.mutate(state, event, msg, env)
    -- Applies the event to the current state and returns the updated state
    -- TODO: state. ... = event. ...
    -- return state
    -- Or just return article.new( ...
end

return article_update_logic
