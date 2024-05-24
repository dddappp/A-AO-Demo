local json = require("json")
local messaging = require("messaging")

--[[

    private SagaDefinition<CreateOrUpdateInventoryItemSagaData> sagaDefinition =
        step()
            .invokeParticipant(this::getInventoryItem)
            .onReply(InventoryItemStateDto.class, this::on_GetInventoryItem_Reply)
        .step()
            .invokeParticipant(this::createSingleLineInOut)
            .withCompensation(this::voidInOut)
        .step()
            .invokeLocal(this::doSomethingLocally)
        .step()
            .invokeParticipant(this::addInventoryItemEntry)
        .step()
            .invokeParticipant(this::completeInOut)
        .build();

]]
local inventory_service = {}


local ERRORS = {
    INVALID_MESSAGE = "INVALID_MESSAGE",
}

inventory_service.ERRORS = ERRORS

local ACTIONS = {
    PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE = "InventoryService_ProcessInventorySurplusOrShortage",
    PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_GET_INVENTORY_ITEM_CALLBACK =
    "InventoryService_ProcessInventorySurplusOrShortage_GetInventoryItem_Callback",
    PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_CREATE_SINGLE_LINE_IN_OUT_CALLBACK =
    "InventoryService_ProcessInventorySurplusOrShortage_CreateSingleLineInOut_Callback",
    PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_ADD_INVENTORY_ITEM_ENTRY_CALLBACK =
    "InventoryService_ProcessInventorySurplusOrShortage_AddInventoryItemEntry_Callback",
    PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_COMPLETE_IN_OUT_CALLBACK =
    "InventoryService_ProcessInventorySurplusOrShortage_CompleteInOut_Callback",
}

inventory_service.ACTIONS = ACTIONS

-- required components

local saga = require("saga")

local config = require("inventory_service_config")
local inventory_item_config = config.inventory_item;
local in_out_config = config.in_out;

-- function inventory_service.init(--_saga,
--     _inventory_item,
--     _in_out
-- )
--     -- saga = _saga;
--     inventory_item = _inventory_item;
--     in_out = _in_out;
-- end

-- process an inventory surplus or shortage
function inventory_service.process_inventory_surplus_or_shortage(msg, env, response)
    local cmd = json.decode(msg.Data)

    -- create or update inventory item
    local target = inventory_item_config.get_target()
    local tags = { Action = inventory_item_config.get_get_inventory_item_action() }
    local request = {
        product_id = cmd.product_id,
        location = cmd.location,
    }
    local status, request_or_error, commit, saga_id = pcall((function()
        local saga_id, commit = saga.create_saga_instance(ACTIONS.PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE, target, tags,
            cmd,
            {
                from = msg.From,
                response_action = msg.Tags[messaging.X_TAGS.RESPONSE_ACTION],
                no_response_required = msg.Tags[messaging.X_TAGS.NO_RESPONSE_REQUIRED],
            }
        )
        return request, commit, saga_id
    end))
    tags[messaging.X_TAGS.SAGA_ID] = tostring(saga_id) -- NOTE: It must be a string
    tags[messaging.X_TAGS.RESPONSE_ACTION] = ACTIONS.PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_GET_INVENTORY_ITEM_CALLBACK
    messaging.commit_send(status, request_or_error, commit, target, tags)
end

local function process_inventory_surplus_or_shortage_on_get_inventory_item_reply(context, result)
    context.item_version = result.item_version
    local on_hand_quantity = result.quantity
    local adjusted_quantity = context.quantity
    local movement_quantity = adjusted_quantity > on_hand_quantity and
        adjusted_quantity - on_hand_quantity or
        on_hand_quantity - adjusted_quantity
    context.movement_quantity = movement_quantity
    -- --------------------
    -- todo handle "adjusted_quantity = on_hand_quantity"
end

function inventory_service.process_inventory_surplus_or_shortage_get_inventory_item_callback(msg, env, response)
    local saga_id = tonumber(msg.Tags[messaging.X_TAGS.SAGA_ID])
    local saga_instance = saga.get_saga_instance_copy(saga_id)
    -- assert current_step == 1 and not compensating
    if (saga_instance.current_step ~= 1 or saga_instance.compensating) then
        error(ERRORS.INVALID_MESSAGE)
    end
    local context = saga_instance.context

    local data = json.decode(msg.Data)
    if (data.error) then
        return -- todo handle error, but no need to compensate
    end
    local result = data.result

    local target = in_out_config.get_target()
    local tags = { Action = in_out_config.get_create_single_line_in_out_action() }

    -- NOTE: on reply
    process_inventory_surplus_or_shortage_on_get_inventory_item_reply(context, result)

    -- create single line inbound or outbound order
    local request = {
        product_id = context.product_id,
        location = context.location,
        movement_quantity = context.movement_quantity,
    }
    local status, request_or_error, commit = pcall((function()
        local commit = saga.move_saga_instances_forward(saga_id, 1, target, tags, context)
        return request, commit
    end))
    tags[messaging.X_TAGS.SAGA_ID] = tostring(saga_id) -- NOTE: It must be a string
    tags[messaging.X_TAGS.RESPONSE_ACTION] = ACTIONS
        .PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_CREATE_SINGLE_LINE_IN_OUT_CALLBACK
    messaging.commit_send_or_error(status, request_or_error, commit, target, tags)
end

local function process_inventory_surplus_or_shortage_compensate_create_single_line_in_out(context)
    -- todo invoke remote void_in_out
    return {}, function()
        -- commit
    end
end


local function process_inventory_surplus_or_shortage_do_something_locally(context)
    -- todo do something locally
    return {}, function()
        -- commit
    end
end

local function process_inventory_surplus_or_shortage_compensate_do_something_locally(context)
    -- todo compensate do_something_locally
    return {}, function()
        -- commit
    end
end


function inventory_service.process_inventory_surplus_or_shortage_create_single_line_in_out_callback(msg, env, response)
    local saga_id = tonumber(msg.Tags[messaging.X_TAGS.SAGA_ID])
    local saga_instance = saga.get_saga_instance_copy(saga_id)
    if (saga_instance.current_step ~= 2 or saga_instance.compensating) then
        error(ERRORS.INVALID_MESSAGE)
    end
    local context = saga_instance.context

    local data = json.decode(msg.Data)
    if (data.error) then
        return -- todo handle error, but no need to compensate
    end
    local result = data.result

    -- invoke local
    local local_status_1, local_result_or_error_1, local_commit_1 = pcall((function()
        return process_inventory_surplus_or_shortage_do_something_locally(context)
    end))
    if (not local_status_1) then
        error(local_result_or_error_1) -- NOTE: just throw error
    end

    -- add inventory item entry
    local target = inventory_item_config.get_target()
    local tags = { Action = inventory_item_config.get_add_inventory_item_entry_action() }

    context.in_out_id = result.in_out_id
    context.in_out_version = result.version

    local request = {
        product_id = context.product_id,
        location = context.location,
        version = context.item_version,
        movement_quantity = context.movement_quantity,
    }
    local status, request_or_error, commit = pcall((function()
        local commit = saga.move_saga_instances_forward(saga_id, 2, target, tags, context)
        return request, commit
    end))
    tags[messaging.X_TAGS.SAGA_ID] = tostring(saga_id) -- NOTE: It must be a string
    tags[messaging.X_TAGS.RESPONSE_ACTION] = ACTIONS
        .PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_ADD_INVENTORY_ITEM_ENTRY_CALLBACK
    local total_commit = function()
        local_commit_1()
        commit()                                                                         -- commit saga instance update
    end
    messaging.commit_send_or_error(status, request_or_error, total_commit, target, tags) -- commit
end

function inventory_service.process_inventory_surplus_or_shortage_add_inventory_item_entry_callback(msg, env, response)
    local saga_id = tonumber(msg.Tags[messaging.X_TAGS.SAGA_ID])
    local saga_instance = saga.get_saga_instance_copy(saga_id)
    if (saga_instance.current_step ~= 4 or saga_instance.compensating) then
        error(ERRORS.INVALID_MESSAGE)
    end
    local context = saga_instance.context

    local data = json.decode(msg.Data)
    if (data.error) then
        --todo process_inventory_surplus_or_shortage_compensate_create_single_line_in_out(context)
        return
        -- todo handle error
    end
    local result = data.result

    -- complete in/out
    local target = in_out_config.get_target()
    local tags = { Action = in_out_config.get_complete_in_out_action() }

    local request = {
        in_out_id = context.in_out_id,
        version = context.in_out_version,
    }
    local status, request_or_error, commit = pcall((function()
        local commit = saga.move_saga_instances_forward(saga_id, 1, target, tags, context)
        return request, commit
    end))
    tags[messaging.X_TAGS.SAGA_ID] = tostring(saga_id) -- NOTE: It must be a string
    tags[messaging.X_TAGS.RESPONSE_ACTION] = ACTIONS
        .PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_COMPLETE_IN_OUT_CALLBACK
    messaging.commit_send_or_error(status, request_or_error, commit, target, tags)
end

function inventory_service.process_inventory_surplus_or_shortage_complete_in_out_callback(msg, env, response)
    local saga_id = tonumber(msg.Tags[messaging.X_TAGS.SAGA_ID])
    local saga_instance = saga.get_saga_instance_copy(saga_id)
    if (saga_instance.current_step ~= 5 or saga_instance.compensating) then
        error(ERRORS.INVALID_MESSAGE)
    end
    local context = saga_instance.context

    local data = json.decode(msg.Data)
    if (data.error) then
        -- error(data.error)
        return
        -- todo handle error
    end
    local result = data.result -- NOTE: last step result

    local original_message_from = saga_instance.original_message and saga_instance.original_message.from or nil
    local tags = {}
    if (saga_instance.original_message and saga_instance.original_message.response_action) then
        tags[messaging.X_TAGS.RESPONSE_ACTION] = saga_instance.original_message.response_action
    end
    if (saga_instance.original_message and saga_instance.original_message.no_response_required) then
        tags[messaging.X_TAGS.NO_RESPONSE_REQUIRED] = saga_instance.original_message.no_response_required
    end

    local status, result_or_error, commit = pcall((function()
        local commit = saga.complete_saga_instance(saga_id, context) -- NOTE: tags?
        return {
            -- NOTE: return result to original requestor?
        }, commit
    end))
    -- tags[messaging.X_TAGS.SAGA_ID] = tostring(saga_id) -- NOTE: It must be a string
    messaging.handle_response_based_on_tag(status, result_or_error, commit, {
        From = original_message_from,
        Tags = tags,
    })
end

return inventory_service
