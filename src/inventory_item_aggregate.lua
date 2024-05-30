local entity_coll = require("entity_coll")
local json = require("json")
local inventory_item_id = require("inventory_item_id")
local inventory_item_add_inventory_item_entry_logic = require("inventory_item_add_inventory_item_entry_logic")

local inventory_item_aggregate = {}

local ERRORS = {
    NIL_ENTITY_ID_SEQUENCE = "NIL_ENTITY_ID_SEQUENCE",
    ENTITY_ID_MISMATCH = "ENTITY_ID_MISMATCH",
    CONCURRENCY_CONFLICT = "CONCURRENCY_CONFLICT",
    VERSION_MISMATCH = "VERSION_MISMATCH",
}

inventory_item_aggregate.ERRORS = ERRORS

local inventory_item_table

function inventory_item_aggregate.init(t)
    inventory_item_table = t
end

-- function inventory_item_aggregate.get_inventory_item(_inventory_item_id)
--     return entity_coll.get(InventoryItemTable, json.encode(inventory_item_id.to_key_array(_inventory_item_id)))
-- end

function inventory_item_aggregate.add_inventory_item_entry(cmd, msg, env)
    --
    -- Create new instances on demand
    --

    -- local _inventory_item_id = inventory_item_id.new(
    --     cmd.product_id,
    --     cmd.location,
    --     cmd.inventory_attribute_set
    -- )
    local _inventory_item_id = cmd.inventory_item_id
    local inventory_item_id_key = json.encode(inventory_item_id.to_key_array(_inventory_item_id))
    local state = entity_coll.get_copy_or_else_nil(inventory_item_table, inventory_item_id_key)
    -- local state = entity_coll.get(article_table, cmd.article_id)
    if (state and state.version ~= cmd.version) then
        error(ERRORS.CONCURRENCY_CONFLICT)
    end
    -- local _inventory_item_id = state.inventory_item_id
    if (state) then
        state.inventory_item_id = _inventory_item_id
    end
    local version = state and state.version or nil
    local event = inventory_item_add_inventory_item_entry_logic.verify(state, _inventory_item_id, cmd.movement_quantity,
        cmd, msg, env)
    if (event.inventory_item_id ~= _inventory_item_id) then
        error(ERRORS.ENTITY_ID_MISMATCH)
    end
    if (version and (event.version ~= version)) then
        error(ERRORS.VERSION_MISMATCH)
    end
    local new_state = inventory_item_add_inventory_item_entry_logic.mutate(state, event, msg, env)
    new_state.inventory_item_id = _inventory_item_id
    new_state.version = version and (version + 1) or 0
    local commit = function()
        entity_coll.add_or_update(inventory_item_table, inventory_item_id_key, new_state)
    end
    return event, commit
end

return inventory_item_aggregate
