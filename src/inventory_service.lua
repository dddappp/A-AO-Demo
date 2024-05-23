local json = require("json")
local messaging = require("messaging")

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

local ACTIONS = {
    PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE = "InventoryService_ProcessInventorySurplusOrShortage",
    PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_GET_INVENTORY_ITEM_CALLBACK =
    "InventoryService_ProcessInventorySurplusOrShortage_GetInventoryItemCallback",
}

inventory_service.ACTIONS = ACTIONS

-- required components

local saga
local inventory_item;
local in_out;

function inventory_service.init(_saga, _inventory_item, _in_out)
    saga = _saga;
    inventory_item = _inventory_item;
    in_out = _in_out;
end

-- process an inventory surplus or shortage
function inventory_service.process_inventory_surplus_or_shortage(msg, env, response)
    -- -- create or update inventory item
    -- local inventoryItemState = inventory_item.getInventoryItem(inventoryItem);
    local target = inventory_item.get_target()
    local tags = { Action = inventory_item.get_get_inventory_item_action() }
    local status, request, commit, saga_id = pcall((function()
        local cmd = json.decode(msg.Data)
        local req = {
            product_id = cmd.product_id,
            location = cmd.location,
        }
        local saga_id, commit = saga.create_saga_instance(ACTIONS.PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE, target, tags,
            cmd)
        return req, commit, saga_id
    end))
    -- tags[messaging.X_TAGS.SAGA_ID] = saga_id
    tags[messaging.X_TAGS.RESPONSE_ACTION] = ACTIONS.PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_GET_INVENTORY_ITEM_CALLBACK
    messaging.commit_send(status, request, commit, target, tags)

    -- -- create single line inbound or outbound order
    -- local inOutState = in_out.createSingleLineInOut(inventoryItem, inOut);
    -- -- add inventory item entry
    -- inventory_item.addInventoryItemEntry(inventoryItem, inOut, inventoryItemState, inOutState);
    -- -- complete in/out
    -- in_out.completeInOut(inOut, inOutState);
end

return inventory_service
