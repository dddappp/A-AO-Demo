local article = {}

local ERRORS = {
}

article.ERRORS = ERRORS


function article.new(title, body, owner)
    local state = {
        version = 0,
        title = title,
        body = body,
        owner = owner,
    }
    return state
end

function article.new_article_body_updated(_state, body)
    local event = {}
    event.event_type = "ArticleBodyUpdated"
    event.article_id = _state.article_id
    event.version = _state.version
    event.body = body
    return event
end

function article.new_article_created(article_id, title, body, owner)
    local event = {}
    event.event_type = "ArticleCreated"
    event.article_id = article_id
    event.title = title
    event.body = body
    event.owner = owner
    return event
end

function article.new_article_updated(_state, title, body)
    local event = {}
    event.event_type = "ArticleUpdated"
    event.article_id = _state.article_id
    event.version = _state.version
    event.title = title
    event.body = body
    return event
end

function article.new_comment_added(_state, comment_seq_id, commenter, body)
    local event = {}
    event.event_type = "CommentAdded"
    event.article_id = _state.article_id
    event.version = _state.version
    event.comment_seq_id = comment_seq_id
    event.commenter = commenter
    event.body = body
    return event
end

function article.new_comment_updated(_state, comment_seq_id, commenter, body)
    local event = {}
    event.event_type = "CommentUpdated"
    event.article_id = _state.article_id
    event.version = _state.version
    event.comment_seq_id = comment_seq_id
    event.commenter = commenter
    event.body = body
    return event
end

function article.new_comment_removed(_state, comment_seq_id)
    local event = {}
    event.event_type = "CommentRemoved"
    event.article_id = _state.article_id
    event.version = _state.version
    event.comment_seq_id = comment_seq_id
    return event
end

return article
