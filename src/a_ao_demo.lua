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

local MESSAGE_PASS_THROUGH_TAGS = {
    "X-SAGA_ID",
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

local function respond(status, result_or_error, request_msg)
    local data = status and { result = result_or_error } or { error = extract_error_code(result_or_error) };
    local tags = {}
    for _, tag in ipairs(MESSAGE_PASS_THROUGH_TAGS) do
        if request_msg.Tags[tag] then
            tags[tag] = request_msg.Tags[tag]
        end
    end
    ao.send({
        Target = request_msg.From,
        Data = json.encode(data),
        Tags = tags
    })
end

local function handle_response_based_on_tag(status, result_or_error, request_msg)
    if (not utils.convert_to_boolean(request_msg.Tags[X_TAGS.NO_RESPONSE_REQUIRED])) then
        respond(status, result_or_error, request_msg)
    else
        if not status then
            error(result_or_error)
        end
    end
end


local function get_artilce(msg, env, response)
    local status, result = pcall((function()
        local cmd = json.decode(msg.Data)
        local state = entity_coll.get(ArticleTable, cmd.article_id)
        return state
    end))
    respond(status, result, msg)
end

local function create_article(msg, env, response)
    local status, result = pcall((function()
        local cmd = json.decode(msg.Data)
        local event = article_aggregate.create(cmd, msg, env)
        return event
    end))
    handle_response_based_on_tag(status, result, msg)
end

local function update_article_body(msg, env, response)
    local status, result = pcall((function()
        local cmd = json.decode(msg.Data)
        local event = article_aggregate.update_body(cmd, msg, env)
        return event
    end))
    handle_response_based_on_tag(status, result, msg)
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
-- Send({ Target = "GJdFeMi7T2cQgUdJgVl5OMWS_EphtBz9USrEi_TQE0I", Tags = { Action = "UpdateArticleBody", ["X-NoResponseRequired"] = "false", ["X-SAGA_ID"] = "TEST_SAGA_ID" }, Data = json.encode({ article_id = 1, version = 13,  body = "new_body_13" }) })

Handlers.add(
    "update_article_body",
    Handlers.utils.hasMatchingTag("Action", "UpdateArticleBody"),
    update_article_body
)
