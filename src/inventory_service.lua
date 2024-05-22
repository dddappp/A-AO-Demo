--[[

    private SagaDefinition<CreateOrUpdateInventoryItemSagaData> sagaDefinition =
        step()
            .invokeParticipant(this::getInventoryItem)
            .onReply(InventoryItemStateDto.class, this::getInventoryItemOnReply)
        .step()
            .invokeParticipant(this::createSingleLineInOut)
            .withCompensation(this::voidInOut)
        .step()
            .invokeParticipant(this::addInventoryItemEntry)
        .step()
            .invokeParticipant(this::completeInOut)
        .build();

]]
local inventory_service = {}

-- required components

local inventory_item;
local in_out;

function inventory_service.init(_inventory_item, _in_out)
    inventory_item = _inventory_item;
    in_out = _in_out;
end

-- process an inventory surplus or shortage
function inventory_service.process_inventory_surplus_or_shortage(cmd, msg, env)
    -- -- create or update inventory item
    -- local inventoryItemState = inventory_item.getInventoryItem(inventoryItem);
    -- -- create single line inbound or outbound order
    -- local inOutState = in_out.createSingleLineInOut(inventoryItem, inOut);
    -- -- add inventory item entry
    -- inventory_item.addInventoryItemEntry(inventoryItem, inOut, inventoryItemState, inOutState);
    -- -- complete in/out
    -- in_out.completeInOut(inOut, inOutState);
    
end

return inventory_service