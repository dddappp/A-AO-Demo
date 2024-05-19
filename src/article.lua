local article = {}


local ERRORS = {
    -- NIL_ARTICLE_ID_SEQUENCE = "NIL_ARTICLE_ID_SEQUENCE"
}

article.ERRORS = ERRORS

--local articles = require("articles")
-- article.ARTICLES = articles.new()
-- local article_id_sequence


-- function article.init(seq)
--     article_id_sequence = seq
-- end

-- function article.current_article_id()
--     if (article_id_sequence == nil) then
--         error(ERRORS.NIL_ARTICLE_ID_SEQUENCE)
--     end
--     return article_id_sequence[1]
-- end

-- function article.next_article_id()
--     if (article_id_sequence == nil) then
--         error(ERRORS.NIL_ARTICLE_ID_SEQUENCE)
--     end
--     article_id_sequence[1] = article_id_sequence[1] + 1
--     return article_id_sequence[1]
-- end

-- class table
-- local Article = {
--     title = "No title" -- set default values?
-- }

-- function article.create(title, body, owner)
--     local self = article.new(title, body, owner)
--     self.article_id = article.current_article_id()
--     article.ARTICLES:add(self)
--     return self
-- end

function article.new(title, body, owner)
    local state = {}
    -- setmetatable(self, { __index = Article })
    -- state.article_id = article_id -- or article:next_article_id()??
    state.version = 0
    state.title = title
    state.body = body
    state.owner = owner
    return state
end

-- local ArticleCreated = {}
-- BoundedContext.GetEventTypeDiscriminatorName

function article.new_article_created(article_id, title, body, owner)
    local event = {}
    -- setmetatable(self, { __index = ArticleCreated })
    event.event_type = "ArticleCreated"
    event.article_id = article_id
    event.title = title
    event.body = body
    event.owner = owner
    return event
end

-- local ArticleBodyUpdated = {}

function article.new_article_body_updated(_state, body)
    local event = {}
    -- setmetatable(self, { __index = ArticleBodyUpdated })
    event.event_type = "ArticleBodyUpdated"
    event.article_id = _state.article_id
    event.version = _state.version
    event.body = body
    return event
end

return article
