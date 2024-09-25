local article = require("article")

local article_add_comment_logic = {}


function article_add_comment_logic.verify(_state, comment_seq_id, commenter, body, cmd, msg, env)
    return article.new_comment_added(_state, comment_seq_id, commenter, body)
end

function article_add_comment_logic.mutate(state, event, msg, env)
    state.comments = state.comments or {}
    state.comments[event.comment_seq_id] = {
        commenter = event.commenter,
        body = event.body,
    }
    return state
end

return article_add_comment_logic
