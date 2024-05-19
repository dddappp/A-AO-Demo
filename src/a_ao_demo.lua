ArticleTable = ArticleTable and (
    function(old_data)
        -- May need to do some migration of old data
        return old_data
    end
)(ArticleTable) or {}

ArticleIdSequence = ArticleIdSequence and (
    function(old_data)
        -- May need to do some migration of old data
        if type(old_data) ~= "table" then
            return { 100000 }
        end
        return old_data
    end
)(ArticleIdSequence) or { 0 }

local X_TAGS = {
    NO_RESPONSE_REQUIRED = "X-NoResponseRequired",
}

local json = require("json")
local entity_coll = require("entity_coll")
local utils = require("utils")
local article_aggregate = require("article_aggregate")

article_aggregate.init(ArticleTable, ArticleIdSequence)

article_aggregate.set_logger({
    log = function(msg)
        ao.log(msg)
    end
})

local function extract_error_code(err)
    return tostring(err):match("([^ ]+)$") or "UNKNOWN_ERROR"
end

local function get_artilce(msg, env, response)
    local status, result = pcall((function()
        local cmd = json.decode(msg.Data)
        local state = entity_coll.get(ArticleTable, cmd.article_id)
        return state
    end))
    ao.send({
        Target = msg.From,
        Data = json.encode(status and { state = result } or
            { error = extract_error_code(result) })
    })
end

local function create_article(msg, env, response)
    local status, result = pcall((function()
        local cmd = json.decode(msg.Data)
        local event = article_aggregate.create(cmd, msg, env)
        return event
    end))
    if (not utils.convert_to_boolean(msg.Tags[X_TAGS.NO_RESPONSE_REQUIRED])) then
        ao.send({
            Target = msg.From,
            Data = json.encode(status and { event = result } or
                { error = extract_error_code(result) })
        })
    else
        if not status then
            error(result)
        end
    end
end

local function update_article_body(msg, env, response)
    local status, result = pcall((function()
        local cmd = json.decode(msg.Data)
        local event = article_aggregate.update_body(cmd, msg, env)
        return event
    end))
    if (not utils.convert_to_boolean(msg.Tags[X_TAGS.NO_RESPONSE_REQUIRED])) then
        ao.send({
            Target = msg.From,
            Data = json.encode(status and { event = result } or
                { error = extract_error_code(result) })
        })
    else
        if not status then
            error(result)
        end
    end
end


-- Send({ Target = "GJdFeMi7T2cQgUdJgVl5OMWS_EphtBz9USrEi_TQE0I", Tags = { Action = "GetArticle" }, Data = json.encode({ article_id = 1 }) })

Handlers.add(
    "get_artilce",
    Handlers.utils.hasMatchingTag("Action", "GetArticle"),
    get_artilce
)

-- Send({ Target = "GJdFeMi7T2cQgUdJgVl5OMWS_EphtBz9USrEi_TQE0I", Tags = { Action = "CreateArticle" }, Data = json.encode({ title = "title_1", body = "body_1" }) })

Handlers.add(
    "create_article",
    Handlers.utils.hasMatchingTag("Action", "CreateArticle"),
    create_article
)

-- Send({ Target = "GJdFeMi7T2cQgUdJgVl5OMWS_EphtBz9USrEi_TQE0I", Tags = { Action = "UpdateArticleBody" }, Data = json.encode({ article_id = 1, version = 3, body = "new_body_1" }) })
-- Send({ Target = "GJdFeMi7T2cQgUdJgVl5OMWS_EphtBz9USrEi_TQE0I", Tags = { Action = "UpdateArticleBody", ["X-NoResponseRequired"] = "true" }, Data = json.encode({ article_id = 1, version = 8,  body = "new_body_u" }) })

Handlers.add(
    "update_article_body",
    Handlers.utils.hasMatchingTag("Action", "UpdateArticleBody"),
    update_article_body
)
