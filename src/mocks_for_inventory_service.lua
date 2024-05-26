local config = require("inventory_service_config")
local inventory_item_config = config.inventory_item;
local in_out_config = config.in_out;

local messaging = require("messaging")


--[[
-- ------------------ aos test commands ------------------

json = require("json")

Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "GetSagaIdSequence" } })
-- New Message From GJd...E0I: Data = {"result":[25]}

Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage", ["X-ResponseAction"] = "TEST_RESPONSE_ACTION" }, Data = json.encode({ product_id = 1, location = "x", quantity = 100 }) })

Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "GetSagaIdSequence" } })

Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "GetSagaInstance" }, Data = json.encode({ saga_id = 26 }) })

Inbox[#Inbox]

]]


-- Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_GetInventoryItem_Callback", ["X-SagaId"] = "24" }, Data = json.encode({ result = { product_id = 1, location = "x", version = 11, quantity = 110 } }) })

Handlers.add(
    inventory_item_config.get_get_inventory_item_action(),
    Handlers.utils.hasMatchingTag("Action", inventory_item_config.get_get_inventory_item_action()),
    function(msg, env, response)
        messaging.respond(true,
            -- { product_id = 1, location = "x", version = 11, quantity = 110 },
            {
                product_id = 1,
                location = "x",
                version = 11,
                quantity = 100, -- Test short-circuited logic, return quantity equal to "quantity" in the original request
            },
            msg
        )
        -- messaging.respond(false, "TEST_GET_INVENTORY_ITEM_ERROR", msg) -- error
    end
)


-- Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_CreateSingleLineInOut_Callback", ["X-SagaId"] = "24" }, Data = json.encode({ result = { in_out_id = 1, version = 0 } }) })

Handlers.add(
    in_out_config.get_create_single_line_in_out_action(),
    Handlers.utils.hasMatchingTag("Action", in_out_config.get_create_single_line_in_out_action()),
    function(msg, env, response)
        messaging.respond(true,
            {
                in_out_id = 1,
                version = 0,
            },
            msg
        )
        -- messaging.respond(false, "TEST_CREATE_SINGLE_LINE_IN_OUT_ERROR", msg) -- error
    end
)


-- Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_AddInventoryItemEntry_Callback", ["X-SagaId"] = "24" }, Data = json.encode({ result = {} }) })

Handlers.add(
    inventory_item_config.get_add_inventory_item_entry_action(),
    Handlers.utils.hasMatchingTag("Action", inventory_item_config.get_add_inventory_item_entry_action()),
    function(msg, env, response)
        -- success:
        messaging.respond(true,
            {
            },
            msg
        )
        -- error:
        -- messaging.respond(false, "TEST_ADD_INVENTORY_ITEM_ENTRY_ERROR", msg)
    end
)

-- Send({ Target = "WIuQznUy0YKKWhTc16QmgeyutSkLXLc1EfV2Ao_dYK0", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_CompleteInOut_Callback", ["X-SagaId"] = "24" }, Data = json.encode({ result = {} }) })

Handlers.add(
    in_out_config.get_complete_in_out_action(),
    Handlers.utils.hasMatchingTag("Action", in_out_config.get_complete_in_out_action()),
    function(msg, env, response)
        messaging.respond(true, {}, msg) -- success
        -- messaging.respond(false, "TEST_COMPLETE_IN_OUT_ERROR", msg) -- error
    end
)

Handlers.add(
    in_out_config.get_void_in_out_action(),
    Handlers.utils.hasMatchingTag("Action", in_out_config.get_void_in_out_action()),
    function(msg, env, response)
        messaging.respond(true, {}, msg) -- success
    end
)
