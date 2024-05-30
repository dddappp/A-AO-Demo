local inventory_item = require("inventory_item")

local inventory_item_add_inventory_item_entry_logic = {}


function inventory_item_add_inventory_item_entry_logic.verify(state, inventory_item_id, movement_quantity, cmd, msg, env)
    return inventory_item.new_inventory_item_entry_added(inventory_item_id, state, movement_quantity)
end

function inventory_item_add_inventory_item_entry_logic.mutate(state, event, msg, env)
    if (not state) then
        state = inventory_item.new(event.inventory_item_id, event.movement_quantity)
    else
        state.quantity = (state.quantity or 0) + event.movement_quantity
    end
    if (not state.entries) then
        state.entries = {}
    end
    local entry = {
        movement_quantity = event.movement_quantity,
    }
    state.entries[#state.entries + 1] = entry
    return state
end

return inventory_item_add_inventory_item_entry_logic
