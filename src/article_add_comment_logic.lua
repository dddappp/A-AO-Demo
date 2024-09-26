local article = require("article")

local article_add_comment_logic = {}


function article_add_comment_logic.verify(_state, commenter, body, cmd, msg, env)
    _state.comment_seq_id_generator = (_state.comment_seq_id_generator or 0) + 1
    return article.new_comment_added(_state, _state.comment_seq_id_generator, commenter, body)
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
