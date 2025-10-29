-- Configuration storage (supports state persistence across reloads)
INVENTORY_SERVICE_INVENTORY_ITEM_TARGET_PROCESS_ID = INVENTORY_SERVICE_INVENTORY_ITEM_TARGET_PROCESS_ID or ""
INVENTORY_SERVICE_IN_OUT_TARGET_PROCESS_ID = INVENTORY_SERVICE_IN_OUT_TARGET_PROCESS_ID or ""

-- X-context embedding strategy configuration (supports runtime modification via Eval messages)
INVENTORY_SERVICE_INVENTORY_ITEM_X_CONTEXT_EMBEDDING = INVENTORY_SERVICE_INVENTORY_ITEM_X_CONTEXT_EMBEDDING or 1
INVENTORY_SERVICE_IN_OUT_X_CONTEXT_EMBEDDING = INVENTORY_SERVICE_IN_OUT_X_CONTEXT_EMBEDDING or 1

local config = {
    inventory_item = {
        get_target = function()
            return INVENTORY_SERVICE_INVENTORY_ITEM_TARGET_PROCESS_ID
        end,
        set_target = function(process_id)
            INVENTORY_SERVICE_INVENTORY_ITEM_TARGET_PROCESS_ID = process_id
        end,
        get_x_context_embedding = function()
            return INVENTORY_SERVICE_INVENTORY_ITEM_X_CONTEXT_EMBEDDING
        end,
        set_x_context_embedding = function(strategy)
            INVENTORY_SERVICE_INVENTORY_ITEM_X_CONTEXT_EMBEDDING = strategy
        end,
        get_get_inventory_item_action = function()
            return "GetInventoryItem"
        end,
        get_add_inventory_item_entry_action = function()
            return "AddInventoryItemEntry"
        end,
    },
    in_out = {
        get_target = function()
            return INVENTORY_SERVICE_IN_OUT_TARGET_PROCESS_ID
        end,
        set_target = function(process_id)
            INVENTORY_SERVICE_IN_OUT_TARGET_PROCESS_ID = process_id
        end,
        get_x_context_embedding = function()
            return INVENTORY_SERVICE_IN_OUT_X_CONTEXT_EMBEDDING
        end,
        set_x_context_embedding = function(strategy)
            INVENTORY_SERVICE_IN_OUT_X_CONTEXT_EMBEDDING = strategy
        end,
        get_create_single_line_in_out_action = function()
            return "CreateSingleLineInOut"
        end,
        get_complete_in_out_action = function()
            return "CompleteInOut"
        end,
        get_void_in_out_action = function()
            return "VoidInOut"
        end,
    }
}

-- Usage:
-- Set global variables directly via Eval messages (recommended):
-- Send({Target = "PROCESS", Action = "Eval", Data = "INVENTORY_SERVICE_INVENTORY_ITEM_TARGET_PROCESS_ID = 'your_process_id'"})
-- Send({Target = "PROCESS", Action = "Eval", Data = "INVENTORY_SERVICE_IN_OUT_TARGET_PROCESS_ID = 'your_process_id'"})
-- Send({Target = "PROCESS", Action = "Eval", Data = "INVENTORY_SERVICE_INVENTORY_ITEM_X_CONTEXT_EMBEDDING = 1"})  -- 1=DIRECT_PROPERTIES, 2=DATA_EMBEDDED
-- Send({Target = "PROCESS", Action = "Eval", Data = "INVENTORY_SERVICE_IN_OUT_X_CONTEXT_EMBEDDING = 1"})

return config

