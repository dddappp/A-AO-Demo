ArticleTable = ArticleTable and (
    function(old_data)
        -- May need to migrate old data
        return old_data
    end
)(ArticleTable) or {}

ArticleIdSequence = ArticleIdSequence and (
    function(old_data)
        -- May need to migrate old data
        return old_data
    end
)(ArticleIdSequence) or { 0 }

InventoryItemTable = InventoryItemTable and (
    function(old_data)
        -- May need to migrate old data
        return old_data
    end
)(InventoryItemTable) or {}


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
local inventory_item_id = require("inventory_item_id")
local article_aggregate = require("article_aggregate")
local inventory_item_aggregate = require("inventory_item_aggregate")
local inventory_service = require("inventory_service")

article_aggregate.init(ArticleTable, ArticleIdSequence)

inventory_item_aggregate.init(InventoryItemTable)

saga.init(SagaInstances, SagaIdSequence)


local function get_article(msg, env, response)
    local status, result = pcall((function()
        local article_id = json.decode(msg.Data)
        local _state = entity_coll.get(ArticleTable, article_id)
        return _state
    end))
    messaging.respond(status, result, msg)
end

local function update_article_body(msg, env, response)
    local status, result, commit = pcall((function()
        local cmd = json.decode(msg.Data)
        return article_aggregate.update_body(cmd, msg, env)
    end))
    messaging.handle_response_based_on_tag(status, result, commit, msg)
end

local function create_article(msg, env, response)
    local status, result, commit = pcall((function()
        local cmd = json.decode(msg.Data)
        return article_aggregate.create(cmd, msg, env)
    end))
    messaging.handle_response_based_on_tag(status, result, commit, msg)
end

local function get_inventory_item(msg, env, response)
    local status, result = pcall((function()
        local _inventory_item_id = json.decode(msg.Data)
        local _key = json.encode(inventory_item_id.to_key_array(_inventory_item_id))
        local _state = entity_coll.get(InventoryItemTable, _key)
        return _state
    end))
    messaging.respond(status, result, msg)
end

local function add_inventory_item_entry(msg, env, response)
    local status, result, commit = pcall((function()
        local cmd = json.decode(msg.Data)
        return inventory_item_aggregate.add_inventory_item_entry(cmd, msg, env)
    end))
    messaging.handle_response_based_on_tag(status, result, commit, msg)
end

Handlers.add(
    "get_article",
    Handlers.utils.hasMatchingTag("Action", "GetArticle"),
    get_article
)

Handlers.add(
    "get_article_count",
    Handlers.utils.hasMatchingTag("Action", "GetArticleCount"),
    function(msg, env, response)
        local count = 0
        for _ in pairs(ArticleTable) do
            count = count + 1
        end
        messaging.respond(true, count, msg)
    end
)

Handlers.add(
    "get_article_id_sequence",
    Handlers.utils.hasMatchingTag("Action", "GetArticleIdSequence"),
    function(msg, env, response)
        messaging.respond(true, ArticleIdSequence, msg)
    end
)

Handlers.add(
    "update_article_body",
    Handlers.utils.hasMatchingTag("Action", "UpdateArticleBody"),
    update_article_body
)

Handlers.add(
    "create_article",
    Handlers.utils.hasMatchingTag("Action", "CreateArticle"),
    create_article
)

Handlers.add(
    "get_inventory_item",
    Handlers.utils.hasMatchingTag("Action", "GetInventoryItem"),
    get_inventory_item
)

Handlers.add(
    "get_inventory_item_count",
    Handlers.utils.hasMatchingTag("Action", "GetInventoryItemCount"),
    function(msg, env, response)
        local count = 0
        for _ in pairs(InventoryItemTable) do
            count = count + 1
        end
        messaging.respond(true, count, msg)
    end
)

Handlers.add(
    "get_inventory_item_table_keys",
    Handlers.utils.hasMatchingTag("Action", "GetInventoryItemTableKeys"),
    function(msg, env, response)
        local keys = {}
        local n = 0
        for k, v in pairs(InventoryItemTable) do
            n = n + 1
            keys[n] = k
        end
        messaging.respond(true, keys, msg)
    end
)

Handlers.add(
    "add_inventory_item_entry",
    Handlers.utils.hasMatchingTag("Action", "AddInventoryItemEntry"),
    add_inventory_item_entry
)


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


Handlers.add(
    "get_sage_id_sequence",
    Handlers.utils.hasMatchingTag("Action", "GetSagaIdSequence"),
    function(msg, env, response)
        messaging.respond(true, SagaIdSequence, msg)
    end
)


Handlers.add(
    "inventory_service_process_inventory_surplus_or_shortage",
    Handlers.utils.hasMatchingTag("Action", inventory_service.ACTIONS.PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE),
    inventory_service.process_inventory_surplus_or_shortage
)

Handlers.add(
    "inventory_service_process_inventory_surplus_or_shortage_get_inventory_item_callback",
    Handlers.utils.hasMatchingTag("Action",
        inventory_service.ACTIONS.PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_GET_INVENTORY_ITEM_CALLBACK),
    inventory_service.process_inventory_surplus_or_shortage_get_inventory_item_callback
)

Handlers.add(
    "inventory_service_process_inventory_surplus_or_shortage_create_single_line_in_out_callback",
    Handlers.utils.hasMatchingTag("Action",
        inventory_service.ACTIONS.PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_CREATE_SINGLE_LINE_IN_OUT_CALLBACK),
    inventory_service.process_inventory_surplus_or_shortage_create_single_line_in_out_callback
)

Handlers.add(
    "inventory_service_process_inventory_surplus_or_shortage_create_single_line_in_out_compensation_callback",
    Handlers.utils.hasMatchingTag("Action",
        inventory_service.ACTIONS.PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_CREATE_SINGLE_LINE_IN_OUT_COMPENSATION_CALLBACK),
    inventory_service.process_inventory_surplus_or_shortage_create_single_line_in_out_compensation_callback
)

Handlers.add(
    "inventory_service_process_inventory_surplus_or_shortage_add_inventory_item_entry_callback",
    Handlers.utils.hasMatchingTag("Action",
        inventory_service.ACTIONS.PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_ADD_INVENTORY_ITEM_ENTRY_CALLBACK),
    inventory_service.process_inventory_surplus_or_shortage_add_inventory_item_entry_callback
)

Handlers.add(
    "inventory_service_process_inventory_surplus_or_shortage_complete_in_out_callback",
    Handlers.utils.hasMatchingTag("Action",
        inventory_service.ACTIONS.PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_COMPLETE_IN_OUT_CALLBACK),
    inventory_service.process_inventory_surplus_or_shortage_complete_in_out_callback
)

