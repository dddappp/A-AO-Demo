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
    COMPENSATION_FAILED = "COMPENSATION_FAILED",
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
    PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_CREATE_SINGLE_LINE_IN_OUT_COMPENSATION_CALLBACK =
    "InventoryService_ProcessInventorySurplusOrShortage_CreateSingleLineInOut_Compensation_Callback",
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


local function respond_original_requester(saga_instance, result_or_error, is_error)
    local original_message_from = saga_instance.original_message and saga_instance.original_message.from or nil
    local tags = {}
    if (saga_instance.original_message and saga_instance.original_message.response_action) then
        tags[messaging.X_TAGS.RESPONSE_ACTION] = saga_instance.original_message.response_action
    end
    if (saga_instance.original_message and saga_instance.original_message.no_response_required) then
        tags[messaging.X_TAGS.NO_RESPONSE_REQUIRED] = saga_instance.original_message.no_response_required
    end
    if is_error and not result_or_error then
        result_or_error = saga_instance.error or "INTERNAL_ERROR"
    end
    messaging.handle_response_based_on_tag(not is_error, result_or_error, function() end, {
        From = original_message_from,
        Tags = tags,
    })
end

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
    local status, request_or_error, commit, _ = pcall((function()
        local saga_id, commit = saga.create_saga_instance(ACTIONS.PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE, target, tags,
            cmd,
            {
                from = msg.From,
                response_action = msg.Tags[messaging.X_TAGS.RESPONSE_ACTION],
                no_response_required = msg.Tags[messaging.X_TAGS.NO_RESPONSE_REQUIRED],
            }
        )
        tags[messaging.X_TAGS.SAGA_ID] = tostring(saga_id) -- NOTE: It must be a string
        tags[messaging.X_TAGS.RESPONSE_ACTION] = ACTIONS
            .PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_GET_INVENTORY_ITEM_CALLBACK
        return request, commit, saga_id
    end))
    messaging.commit_send_or_error(status, request_or_error, commit, target, tags)
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

    -- NOTE: on reply
    process_inventory_surplus_or_shortage_on_get_inventory_item_reply(context, result)

    -- create single line inbound or outbound order
    local target = in_out_config.get_target()
    local tags = { Action = in_out_config.get_create_single_line_in_out_action() }
    local request = {
        product_id = context.product_id,
        location = context.location,
        movement_quantity = context.movement_quantity,
    }
    local status, request_or_error, commit = pcall((function()
        local commit = saga.move_saga_instance_forward(saga_id, 1, target, tags, context)
        tags[messaging.X_TAGS.SAGA_ID] = tostring(saga_id) -- NOTE: It must be a string
        tags[messaging.X_TAGS.RESPONSE_ACTION] = ACTIONS
            .PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_CREATE_SINGLE_LINE_IN_OUT_CALLBACK
        return request, commit
    end))
    messaging.commit_send_or_error(status, request_or_error, commit, target, tags)
end

function inventory_service.process_inventory_surplus_or_shortage_create_single_line_in_out_compensation_callback(msg, env,
                                                                                                                 response)
    local saga_id = tonumber(msg.Tags[messaging.X_TAGS.SAGA_ID])
    local saga_instance = saga.get_saga_instance_copy(saga_id)
    if (saga_instance.current_step ~= 2 or not saga_instance.compensating) then
        error(ERRORS.INVALID_MESSAGE)
    end
    local context = saga_instance.context

    local data = json.decode(msg.Data)
    if (data.error) then
        error(ERRORS.COMPENSATION_FAILED)
    end
    local result = data.result

    -- local status, result_or_error, commit = pcall((function()
    local commit = saga.rollback_saga_instance(saga_id, 2 - 1, nil, nil, nil, nil)
    -- return {
    -- }, commit
    --end))
    commit()
    respond_original_requester(saga_instance, nil, true)
end

local function process_inventory_surplus_or_shortage_compensate_create_single_line_in_out(saga_id, context, error,
                                                                                          local_compensations)
    local local_step = 0
    local local_commits = {}
    if (local_compensations) then
        for i = 1, #local_compensations, 1 do
            local local_compensation = local_compensations[i]
            if local_compensation then
                -- invoke local
                local local_status, local_result_or_error, local_commit = pcall((function()
                    return local_compensation(context)
                end))
                if (not local_status) then
                    error(local_result_or_error) -- NOTE: just throw error
                end
                local_commits[#local_commits + 1] = local_commit
            end
            local_step = local_step + 1
        end
    end

    -- -- If no remote compensations
    -- local commit = saga.rollback_saga_instance(saga_id, 4 - local_step - 1, nil, nil, nil, error)
    -- total_commit = (function()
    --     commit()
    --     total_commit()
    -- end)
    -- total_commit()
    -- -- return

    -- void InOut
    local target = in_out_config.get_target()
    local tags = { Action = in_out_config.get_void_in_out_action() }
    local request = {
        in_out_id = context.in_out_id,
        version = context.in_out_version,
    }
    local status, request_or_error, commit = pcall((function()
        local commit = saga.rollback_saga_instance(saga_id, local_step + 1, target, tags, context, error)
        tags[messaging.X_TAGS.SAGA_ID] = tostring(saga_id) -- NOTE: It must be a string
        tags[messaging.X_TAGS.RESPONSE_ACTION] = ACTIONS
            .PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_CREATE_SINGLE_LINE_IN_OUT_COMPENSATION_CALLBACK
        return request, commit
    end))
    local total_commit = function()
        for _, local_commit in ipairs(local_commits) do
            local_commit()
        end
        commit()
    end
    messaging.commit_send_or_error(status, request_or_error, total_commit, target, tags)
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
        local commit = saga.move_saga_instance_forward(saga_id, 2, target, tags, context)
        tags[messaging.X_TAGS.SAGA_ID] = tostring(saga_id) -- NOTE: It must be a string
        tags[messaging.X_TAGS.RESPONSE_ACTION] = ACTIONS
            .PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_ADD_INVENTORY_ITEM_ENTRY_CALLBACK
        return request, commit
    end))
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
        process_inventory_surplus_or_shortage_compensate_create_single_line_in_out(saga_id, context, data.error, {
            process_inventory_surplus_or_shortage_compensate_do_something_locally
        })
        return
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
        local commit = saga.move_saga_instance_forward(saga_id, 1, target, tags, context)
        tags[messaging.X_TAGS.SAGA_ID] = tostring(saga_id) -- NOTE: It must be a string
        tags[messaging.X_TAGS.RESPONSE_ACTION] = ACTIONS
            .PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_COMPLETE_IN_OUT_CALLBACK
        return request, commit
    end))
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
        process_inventory_surplus_or_shortage_compensate_create_single_line_in_out(saga_id, context, data.error, {
            nil, -- no local compensation
            process_inventory_surplus_or_shortage_compensate_do_something_locally
        })
        return
    end
    local result = data.result -- NOTE: last step result?

    -- local status, result_or_error, commit = pcall((function()
    local commit = saga.complete_saga_instance(saga_id, context)
    --     return {
    --     }, commit
    -- end))
    commit()
    respond_original_requester(saga_instance, result, false)
end

return inventory_service
