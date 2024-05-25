local config = require("inventory_service_config")
local inventory_item_config = config.inventory_item;
local in_out_config = config.in_out;

local messaging = require("messaging")

--[[

Send({ Target = "GJdFeMi7T2cQgUdJgVl5OMWS_EphtBz9USrEi_TQE0I", Tags = { Action = "GetSagaIdSequence" } })
-- New Message From GJd...E0I: Data = {"result":[25]}

Send({ Target = "GJdFeMi7T2cQgUdJgVl5OMWS_EphtBz9USrEi_TQE0I", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage", ["X-ResponseAction"] = "TEST_RESPONSE_ACTION" }, Data = json.encode({ product_id = 1, location = "x", quantity = 100 }) })

Send({ Target = "GJdFeMi7T2cQgUdJgVl5OMWS_EphtBz9USrEi_TQE0I", Tags = { Action = "GetSagaInstance" }, Data = json.encode({ saga_id = 26 }) })

Inbox[#Inbox]

]]


-- Send({ Target = "GJdFeMi7T2cQgUdJgVl5OMWS_EphtBz9USrEi_TQE0I", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_GetInventoryItem_Callback", ["X-SagaId"] = "24" }, Data = json.encode({ result = { product_id = 1, location = "x", version = 11, quantity = 110 } }) })

Handlers.add(
    inventory_item_config.get_get_inventory_item_action(),
    Handlers.utils.hasMatchingTag("Action", inventory_item_config.get_get_inventory_item_action()),
    function(msg, env, response)
        messaging.respond(
            true,
            { product_id = 1, location = "x", version = 11, quantity = 110 },
            msg
        )
    end
)


-- Send({ Target = "GJdFeMi7T2cQgUdJgVl5OMWS_EphtBz9USrEi_TQE0I", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_CreateSingleLineInOut_Callback", ["X-SagaId"] = "24" }, Data = json.encode({ result = { in_out_id = 1, version = 0 } }) })

Handlers.add(
    in_out_config.get_create_single_line_in_out_action(),
    Handlers.utils.hasMatchingTag("Action", in_out_config.get_create_single_line_in_out_action()),
    function(msg, env, response)
        messaging.respond(
            true,
            { in_out_id = 1, version = 0 },
            msg
        )
    end
)


-- Send({ Target = "GJdFeMi7T2cQgUdJgVl5OMWS_EphtBz9USrEi_TQE0I", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_AddInventoryItemEntry_Callback", ["X-SagaId"] = "24" }, Data = json.encode({ result = {} }) })

Handlers.add(
    inventory_item_config.get_add_inventory_item_entry_action(),
    Handlers.utils.hasMatchingTag("Action", inventory_item_config.get_add_inventory_item_entry_action()),
    function(msg, env, response)
        -- messaging.respond(true, {}, msg) -- success
        messaging.respond(false, "TEST_ERROR", msg) -- error
    end
)

-- Send({ Target = "GJdFeMi7T2cQgUdJgVl5OMWS_EphtBz9USrEi_TQE0I", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_CompleteInOut_Callback", ["X-SagaId"] = "24" }, Data = json.encode({ result = {} }) })

Handlers.add(
    in_out_config.get_complete_in_out_action(),
    Handlers.utils.hasMatchingTag("Action", in_out_config.get_complete_in_out_action()),
    function(msg, env, response)
        -- messaging.respond(true, {}, msg) -- success
        messaging.respond(false, "TEST_COMPLETE_IN_OUT_ERROR", msg) -- error
    end
)

Handlers.add(
    in_out_config.get_void_in_out_action(),
    Handlers.utils.hasMatchingTag("Action", in_out_config.get_void_in_out_action()),
    function(msg, env, response)
        messaging.respond(true, {}, msg) -- success
    end
)
