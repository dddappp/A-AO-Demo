local article = require("article")

local article_update_comment_logic = {}


function article_update_comment_logic.verify(_state, comment_seq_id, commenter, body, cmd, msg, env)
    return article.new_comment_updated(_state, comment_seq_id, commenter, body)
end

function article_update_comment_logic.mutate(state, event, msg, env)
    if not state.comments then
        error(string.format("COMMENTS_NOT_SET (article_id: %s)", tostring(state.article_id)))
    end
    if not state.comments:contains(event.comment_seq_id) then
        error(string.format("COMMENT_NOT_FOUND (article_id: %s, comment_seq_id: %s)",
            tostring(state.article_id), tostring(event.comment_seq_id)))
    end
    state.comments:update(event.comment_seq_id, {
        commenter = event.commenter,
        body = event.body,
    })
    return state
end

return article_update_comment_logic
