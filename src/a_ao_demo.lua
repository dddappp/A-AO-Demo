ArticleTable = ArticleTable and (
    function(old_data)
        -- May need to migrate old data
        return old_data
    end
)(ArticleTable) or {}

ArticleIdSequence = ArticleIdSequence and (
    function(old_data)
        -- May need to migrate old data
        if type(old_data) ~= "table" then
            return { 100000 }
        end
        return old_data
    end
)(ArticleIdSequence) or { 0 }

local X_TAGS = {
    NO_RESPONSE_REQUIRED = "X-NoResponseRequired",
    RESPONSE_ACTION = "X-ResponseAction",
}

local MESSAGE_PASS_THROUGH_TAGS = {
    "X-SAGA_ID",
}

local json = require("json")
local entity_coll = require("entity_coll")
local utils = require("utils")
local article_aggregate = require("article_aggregate")
local test_local_tx_service = require("test_local_tx_service")

article_aggregate.init(ArticleTable, ArticleIdSequence)

-- article_aggregate.set_logger({
--     log = function(msg)
--         ao.log(msg)
--     end
-- })

test_local_tx_service.init(article_aggregate) -- ArticleTable, article_aggregate)

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
    if request_msg.Tags[X_TAGS.RESPONSE_ACTION] then
        tags["Action"] = request_msg.Tags[X_TAGS.RESPONSE_ACTION]
    end
    ao.send({
        Target = request_msg.From,
        Data = json.encode(data),
        Tags = tags
    })
end

local function handle_response_based_on_tag(status, result_or_error, commit, request_msg)
    if status then
        commit()
    end
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
    local status, result, commit = pcall((function()
        local cmd = json.decode(msg.Data)
        return article_aggregate.create(cmd, msg, env)
    end))
    handle_response_based_on_tag(status, result, commit, msg)
end

local function update_article_body(msg, env, response)
    local status, result, commit = pcall((function()
        local cmd = json.decode(msg.Data)
        return article_aggregate.update_body(cmd, msg, env)
    end))
    handle_response_based_on_tag(status, result, commit, msg)
end

local function test_update_and_create_articles(msg, env, response)
    local status, result, commit = pcall((function()
        local cmd = json.decode(msg.Data)
        return test_local_tx_service.test_update_and_create_articles(cmd, msg, env)
    end))
    handle_response_based_on_tag(status, result, commit, msg)
end


-- Send({ Target = "GJdFeMi7T2cQgUdJgVl5OMWS_EphtBz9USrEi_TQE0I", Tags = { Action = "GetArticle" }, Data = json.encode({ article_id = 1 }) })

Handlers.add(
    "get_artilce",
    Handlers.utils.hasMatchingTag("Action", "GetArticle"),
    get_artilce
)

Handlers.add(
    "get_artilce_count",
    Handlers.utils.hasMatchingTag("Action", "GetArticleCount"),
    function(msg, env, response)
        local count = 0
        for _ in pairs(ArticleTable) do
            count = count + 1
        end
        respond(true, count, msg)
    end
)

-- Send({ Target = "GJdFeMi7T2cQgUdJgVl5OMWS_EphtBz9USrEi_TQE0I", Tags = { Action = "GetArticleIdSequence" } })

Handlers.add(
    "get_article_id_sequence",
    Handlers.utils.hasMatchingTag("Action", "GetArticleIdSequence"),
    function(msg, env, response)
        respond(true, ArticleIdSequence, msg)
    end
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

-- Send({ Target = "GJdFeMi7T2cQgUdJgVl5OMWS_EphtBz9USrEi_TQE0I", Tags = { Action = "TestUpdateAndCreateArticles" }, Data = json.encode({ article_id_to_update = 1, version = 15, body = "new_body_15", new_article_titile = "new_article_titile"}) })

Handlers.add(
    "test_update_and_create_articles",
    Handlers.utils.hasMatchingTag("Action", "TestUpdateAndCreateArticles"),
    test_update_and_create_articles
)
