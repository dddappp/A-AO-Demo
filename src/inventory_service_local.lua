--[[
    private SagaDefinition<CreateOrUpdateInventoryItemSagaData> sagaDefinition =
        step()
            .prepareRequest()
            .invokeParticipant(this::getInventoryItem)
            .onReply(InventoryItemStateDto.class, this::on_GetInventoryItem_Reply)
        .step()
            .invokeParticipant(this::createSingleLineInOut)
            .withCompensation(this::voidInOut)
        .step()
            .invokeLocal(this::doSomethingLocally)
            .withCompensation()
        .step()
            .invokeParticipant(this::addInventoryItemEntry)
        .step()
            .invokeParticipant(this::completeInOut)
        .build();

]]

-- function inventory_service.init(--_saga,
--     _inventory_item,
--     _in_out
-- )
--     -- saga = _saga;
--     inventory_item = _inventory_item;
--     in_out = _in_out;
-- end

local inventory_service_local = {}


-- function inventory_service_local.process_inventory_surplus_or_shortage_start_with_local_call(context)
--     -- return the result and a "commit" function
--     return {}, function()
--     end
-- end

-- function inventory_service_local.process_inventory_surplus_or_shortage_compensate_start_with_local_call(context)
--     -- return the result and a "commit" function
--     return {}, function()
--     end
-- end


function inventory_service_local.process_inventory_surplus_or_shortage_prepare_get_inventory_item_request(context)
    -- return the request
    local _inventory_item_id = {
        product_id = context.product_id,
        location = context.location,
    }
    context.inventory_item_id = _inventory_item_id
    return _inventory_item_id
end

function inventory_service_local.process_inventory_surplus_or_shortage_on_get_inventory_item_reply(context, result)
    -- local short_circuited = false --  short-circuit if necessary
    -- local is_error = false
    -- -- If the original request requires a result, provide one here if a short-circuit occurs.
    -- local result_or_error = {}
    -- return short_circuited, is_error, result_or_error

    context.item_version = result.version -- NOTE: The name of the field IS "version"!
    local on_hand_quantity = result.quantity
    local adjusted_quantity = context.quantity

    -- ------------------------------------------
    if (adjusted_quantity == on_hand_quantity) then -- NOTE: short-circuit if no changed
        local short_circuited = true
        local is_error = false
        -- If the original request requires a result, provide one here if a short circuit occurs.
        local result_or_error = "adjusted_quantity == on_hand_quantity"
        return short_circuited, is_error, result_or_error
    end
    -- ------------------------------------------

    local movement_quantity = adjusted_quantity > on_hand_quantity and
        adjusted_quantity - on_hand_quantity or
        on_hand_quantity - adjusted_quantity
    context.movement_quantity = movement_quantity
end

function inventory_service_local.process_inventory_surplus_or_shortage_do_something_locally(context)
    -- returns result and a "commit" function
    -- error("TEST_INVOKE_LOCAL_ERROR")
    return {}, function()
    end
end

function inventory_service_local.process_inventory_surplus_or_shortage_compensate_do_something_locally(context)
    -- returns result and a "commit" function
    return {}, function()
    end
end

function inventory_service_local.process_inventory_surplus_or_shortage_do_something_else_locally(context)
    -- error("TEST_INVOKE_LOCAL_ERROR")
    return {}, function()
    end
end

return inventory_service_local
