local inventory_item = {}

local ERRORS = {
}

inventory_item.ERRORS = ERRORS


function inventory_item.new(inventory_item_id, quantity)
    local state = {
        inventory_item_id = inventory_item_id,
        version = 0,
        quantity = quantity,
    }
    return state
end

--- 
-- @param inventory_item_id table The InventoryItemId of the InventoryItem
-- @param _state table The current state of the InventoryItem
-- @param movement_quantity number 
-- @return table
function inventory_item.new_inventory_item_entry_added(inventory_item_id, _state, movement_quantity)
    local event = {}
    event.event_type = "InventoryItemEntryAdded"
    event.inventory_item_id = inventory_item_id
    event.version = _state and _state.version or nil
    event.movement_quantity = movement_quantity
    return event
end

return inventory_item
