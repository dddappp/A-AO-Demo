local article = require("article")

local article_remove_comment_logic = {}


function article_remove_comment_logic.verify(_state, comment_seq_id, cmd, msg, env)
    return article.new_comment_removed(_state, comment_seq_id)
end

function article_remove_comment_logic.mutate(state, event, msg, env)
    if not state.comments then
        error(string.format("COMMENT_NOT_FOUND (article_id: %s, comment_seq_id: %s)",
            tostring(state.article_id), tostring(event.comment_seq_id)))
    end
    state.comments[event.comment_seq_id] = nil
    return state
end

return article_remove_comment_logic
