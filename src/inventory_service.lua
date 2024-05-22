local json = require("json")
local utils = require("utils")

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
    local target = "ixer2JAwpnIWRDBXQbNZdOYrOs3Ab3kjmIzRUxdY7U4" -- todo get from inventory_item component
    local tags = { Action = "GetInventoryItem" }
    local status, result, commit = pcall((function()
        local cmd = json.decode(msg.Data)
        local req = {
            product_id = cmd.product_id,
            location = cmd.location,
        }
        local _, c = saga.create_saga_instance("InventoryService_ProcessInventorySurplusOrShortage", target, tags)
        -- return req, function()
        -- end
        return req, c
    end))
    utils.commit_send(status, result, commit, target, tags)

    -- -- create single line inbound or outbound order
    -- local inOutState = in_out.createSingleLineInOut(inventoryItem, inOut);
    -- -- add inventory item entry
    -- inventory_item.addInventoryItemEntry(inventoryItem, inOut, inventoryItemState, inOutState);
    -- -- complete in/out
    -- in_out.completeInOut(inOut, inOutState);
end

return inventory_service
