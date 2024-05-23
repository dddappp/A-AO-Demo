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
    "InventoryService_ProcessInventorySurplusOrShortage_GetInventoryItem_Callback",
    PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_CREATE_SINGLE_LINE_IN_OUT_CALLBACK =
    "InventoryService_ProcessInventorySurplusOrShortage_CreateSingleLineInOut_Callback",
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
    -- create or update inventory item
    local target = inventory_item.get_target()
    local tags = { Action = inventory_item.get_get_inventory_item_action() }
    local cmd = json.decode(msg.Data)
    local request = {
        product_id = cmd.product_id,
        location = cmd.location,
    }
    local status, commit, saga_id = pcall((function()
        local saga_id, commit = saga.create_saga_instance(ACTIONS.PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE, target, tags,
            cmd)
        return commit, saga_id
    end))
    tags[messaging.X_TAGS.SAGA_ID] = tostring(saga_id) -- NOTE: It must be a string
    tags[messaging.X_TAGS.RESPONSE_ACTION] = ACTIONS.PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_GET_INVENTORY_ITEM_CALLBACK
    messaging.commit_send(status, request, commit, target, tags)
end

function inventory_service.process_inventory_surplus_or_shortage_get_inventory_item_callback(msg, env, response)
    -- create single line inbound or outbound order
    local saga_id = tonumber(msg.Tags[messaging.X_TAGS.SAGA_ID])
    local saga_instance = saga.get_saga_instance_copy(saga_id)
    local context = saga_instance.context
    local target = in_out.get_target()
    local tags = { Action = in_out.get_create_single_line_in_out_action() }
    local data = json.decode(msg.Data)
    if (data.error) then
        -- error(data.error)
        return
        -- todo handle error
    end
    local result = data.result

    -- NOTE: on reply
    context.item_version = result.item_version
    local on_hand_quantity = result.quantity
    local adjusted_quantity = context.quantity
    local movement_quantity = adjusted_quantity > on_hand_quantity and
        adjusted_quantity - on_hand_quantity or
        on_hand_quantity - adjusted_quantity
    context.movement_quantity = movement_quantity
    -- todo handle "adjusted_quantity = on_hand_quantity"
    -- --------------------
    local request = {
        product_id = context.product_id,
        location = context.location,
        movement_quantity = context.movement_quantity,
    }
    local status, commit = pcall((function()
        local commit = saga.move_saga_instances_forward(saga_id, target, tags, context)
        return commit
    end))
    tags[messaging.X_TAGS.SAGA_ID] = tostring(saga_id) -- NOTE: It must be a string
    tags[messaging.X_TAGS.RESPONSE_ACTION] = ACTIONS
        .PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_CREATE_SINGLE_LINE_IN_OUT_CALLBACK
    messaging.commit_send_or_error(status, request, commit, target, tags)
end

-- -- add inventory item entry
-- inventory_item.addInventoryItemEntry(inventoryItem, inOut, inventoryItemState, inOutState);
-- -- complete in/out
-- in_out.completeInOut(inOut, inOutState);

return inventory_service
