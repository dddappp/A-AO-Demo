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


SagaInstances = SagaInstances and (
    function(old_data)
        -- May need to migrate old data
        return old_data
    end
)(SagaInstances) or {}

SagaIdSequence = SagaIdSequence and (
    function(old_data)
        -- May need to migrate old data
        return old_data
    end
)(SagaIdSequence) or { 0 }


local json = require("json")
local entity_coll = require("entity_coll")
local messaging = require("messaging")
local saga = require("saga")
local article_aggregate = require("article_aggregate")
local test_local_tx_service = require("test_local_tx_service")
local inventory_service = require("inventory_service")


saga.init(SagaInstances, SagaIdSequence)

article_aggregate.init(ArticleTable, ArticleIdSequence)

-- article_aggregate.set_logger({
--     log = function(msg)
--         ao.log(msg)
--     end
-- })

test_local_tx_service.init(article_aggregate) -- ArticleTable, article_aggregate)

inventory_service.init(saga,
    {
        get_target = function()
            return "ixer2JAwpnIWRDBXQbNZdOYrOs3Ab3kjmIzRUxdY7U4"
        end,
        get_get_inventory_item_action = function()
            return "GetInventoryItem"
        end
    },
    {
        get_target = function()
            return "ixer2JAwpnIWRDBXQbNZdOYrOs3Ab3kjmIzRUxdY7U4"
        end,
        get_create_single_line_in_out_action = function()
            return "CreateSingleLineInOut"
        end
    } -- todo
)

local function get_artilce(msg, env, response)
    local status, result = pcall((function()
        local cmd = json.decode(msg.Data)
        local state = entity_coll.get(ArticleTable, cmd.article_id)
        return state
    end))
    messaging.respond(status, result, msg)
end

local function create_article(msg, env, response)
    local status, result, commit = pcall((function()
        local cmd = json.decode(msg.Data)
        return article_aggregate.create(cmd, msg, env)
    end))
    messaging.handle_response_based_on_tag(status, result, commit, msg)
end

local function update_article_body(msg, env, response)
    local status, result, commit = pcall((function()
        local cmd = json.decode(msg.Data)
        return article_aggregate.update_body(cmd, msg, env)
    end))
    messaging.handle_response_based_on_tag(status, result, commit, msg)
end

local function test_update_and_create_articles(msg, env, response)
    local status, result, commit = pcall((function()
        local cmd = json.decode(msg.Data)
        return test_local_tx_service.test_update_and_create_articles(cmd, msg, env)
    end))
    messaging.handle_response_based_on_tag(status, result, commit, msg)
end



-- Send({ Target = "GJdFeMi7T2cQgUdJgVl5OMWS_EphtBz9USrEi_TQE0I", Tags = { Action = "GetSagaInstance" }, Data = json.encode({ saga_id = 1 }) })

Handlers.add(
    "get_sage_instance",
    Handlers.utils.hasMatchingTag("Action", "GetSagaInstance"),
    function(msg, env, response)
        local cmd = json.decode(msg.Data)
        local saga_id = cmd.saga_id
        local s = entity_coll.get(SagaInstances, saga_id)
        messaging.respond(true, s, msg)
    end
)


-- Send({ Target = "GJdFeMi7T2cQgUdJgVl5OMWS_EphtBz9USrEi_TQE0I", Tags = { Action = "GetSagaIdSequence" } })

Handlers.add(
    "get_sage_id_sequence",
    Handlers.utils.hasMatchingTag("Action", "GetSagaIdSequence"),
    function(msg, env, response)
        messaging.respond(true, SagaIdSequence, msg)
    end
)


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
        messaging.respond(true, count, msg)
    end
)

-- Send({ Target = "GJdFeMi7T2cQgUdJgVl5OMWS_EphtBz9USrEi_TQE0I", Tags = { Action = "GetArticleIdSequence" } })

Handlers.add(
    "get_article_id_sequence",
    Handlers.utils.hasMatchingTag("Action", "GetArticleIdSequence"),
    function(msg, env, response)
        messaging.respond(true, ArticleIdSequence, msg)
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

-- Send({ Target = "GJdFeMi7T2cQgUdJgVl5OMWS_EphtBz9USrEi_TQE0I", Tags = { Action = "TestUpdateAndCreateArticles" }, Data = json.encode({ article_id_to_update = 1, version = 29, body = "new_body_29", new_article_titile = "new_article_titile"}) })

Handlers.add(
    "test_update_and_create_articles",
    Handlers.utils.hasMatchingTag("Action", "TestUpdateAndCreateArticles"),
    test_update_and_create_articles
)

-- inventory_service_process_inventory_surplus_or_shortage

-- Send({ Target = "GJdFeMi7T2cQgUdJgVl5OMWS_EphtBz9USrEi_TQE0I", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage" }, Data = json.encode({ product_id = 1, location = "x", quantity = 100 }) })

Handlers.add(
    "inventory_service_process_inventory_surplus_or_shortage",
    Handlers.utils.hasMatchingTag("Action", inventory_service.ACTIONS.PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE),
    inventory_service.process_inventory_surplus_or_shortage
)

-- Send({ Target = "GJdFeMi7T2cQgUdJgVl5OMWS_EphtBz9USrEi_TQE0I", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_GetInventoryItem_Callback", ["X-SagaId"] = "19" }, Data = json.encode({ result = { product_id = 1, location = "x", version = 11, quantity = 110 } }) })

Handlers.add(
    "inventory_service_process_inventory_surplus_or_shortage_get_inventory_item_callback",
    Handlers.utils.hasMatchingTag("Action", inventory_service.ACTIONS.PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_GET_INVENTORY_ITEM_CALLBACK),
    inventory_service.process_inventory_surplus_or_shortage_get_inventory_item_callback
)
