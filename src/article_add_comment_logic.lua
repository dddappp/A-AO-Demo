local article = require("article")

local article_add_comment_logic = {}


function article_add_comment_logic.verify(_state, commenter, body, cmd, msg, env)
    _state.comment_seq_id_generator = (_state.comment_seq_id_generator or 0) + 1
    return article.new_comment_added(_state, _state.comment_seq_id_generator, commenter, body)
end

function article_add_comment_logic.mutate(state, event, msg, env)
    if not state.comments then
        error(string.format("COMMENTS_NOT_SET (article_id: %s)", tostring(state.article_id)))
    end
    if state.comments:contains(event.comment_seq_id) then
        error(string.format("COMMENT_ALREADY_EXISTS (article_id: %s, comment_seq_id: %s)",
            tostring(state.article_id), tostring(event.comment_seq_id)))
    end
    state.comments:add(event.comment_seq_id, {
        commenter = event.commenter,
        body = event.body,
    })
    return state
end

return article_add_comment_logic
