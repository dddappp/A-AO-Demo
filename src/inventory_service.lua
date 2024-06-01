local json = require("json")
local messaging = require("messaging")
local saga = require("saga")
local saga_messaging = require("saga_messaging")
local inventory_service_local = require("inventory_service_local")

local execute_local_compensations_respond_original_requester = saga_messaging
    .execute_local_compensations_respond_original_requester
local rollback_saga_instance_respond_original_requester = saga_messaging
    .rollback_saga_instance_respond_original_requester
local complete_saga_instance_respond_original_requester = saga_messaging
    .complete_saga_instance_respond_original_requester
local execute_local_compensations = saga_messaging.execute_local_compensations

local process_inventory_surplus_or_shortage_prepare_get_inventory_item_request =
    inventory_service_local.process_inventory_surplus_or_shortage_prepare_get_inventory_item_request
local process_inventory_surplus_or_shortage_on_get_inventory_item_reply =
    inventory_service_local.process_inventory_surplus_or_shortage_on_get_inventory_item_reply
local process_inventory_surplus_or_shortage_do_something_locally =
    inventory_service_local.process_inventory_surplus_or_shortage_do_something_locally
local process_inventory_surplus_or_shortage_compensate_do_something_locally =
    inventory_service_local.process_inventory_surplus_or_shortage_compensate_do_something_locally

local inventory_service = {}


local ERRORS = {
    INVALID_MESSAGE = "INVALID_MESSAGE",
    COMPENSATION_FAILED = "COMPENSATION_FAILED",
}

inventory_service.ERRORS = ERRORS

local ACTIONS = {
    PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE =
    "InventoryService_ProcessInventorySurplusOrShortage",
    PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_GET_INVENTORY_ITEM_CALLBACK =
    "InventoryService_ProcessInventorySurplusOrShortage_GetInventoryItem_Callback",
    PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_CREATE_SINGLE_LINE_IN_OUT_CALLBACK =
    "InventoryService_ProcessInventorySurplusOrShortage_CreateSingleLineInOut_Callback",
    PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_CREATE_SINGLE_LINE_IN_OUT_COMPENSATION_CALLBACK =
    "InventoryService_ProcessInventorySurplusOrShortage_CreateSingleLineInOut_Compensation_Callback",
    PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_ADD_INVENTORY_ITEM_ENTRY_CALLBACK =
    "InventoryService_ProcessInventorySurplusOrShortage_AddInventoryItemEntry_Callback",
    PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_COMPLETE_IN_OUT_CALLBACK =
    "InventoryService_ProcessInventorySurplusOrShortage_CompleteInOut_Callback",
}

inventory_service.ACTIONS = ACTIONS

-- required components
local inventory_service_config = require("inventory_service_config")
local inventory_item_config = inventory_service_config.inventory_item;
local in_out_config = inventory_service_config.in_out;


-- process an inventory surplus or shortage
function inventory_service.process_inventory_surplus_or_shortage(msg, env, response)
    local cmd = json.decode(msg.Data)

    local context = cmd

    -- If there are invokeLocal steps at the beginning...
    --[[
    local local_steps = {
        function(_context)
            error("TEST_INVOKE_LOCAL_ERROR")
        end
    }
    local local_commits = {}
    for i = 1, #local_steps, 1 do
        local local_step = local_steps[i]
        local local_status, local_result_or_error, local_commit = pcall((function()
            return local_step(context)
        end))
        if (not local_status) then
            messaging.respond(false, local_result_or_error, msg)
            return -- error(local_result_or_error) -- Not just throw error?
        else
            local_commits[#local_commits + 1] = local_commit
        end
    end
    ]]

    local target = inventory_item_config.get_target()
    local tags = { Action = inventory_item_config.get_get_inventory_item_action() }
    local status, request_or_error, commit = pcall((function()
        local saga_instance, commit = saga.create_saga_instance(ACTIONS.PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE, target,
            tags,
            context, -- cmd as context
            {
                from = msg.From,
                response_action = msg.Tags[messaging.X_TAGS.RESPONSE_ACTION],
                no_response_required = msg.Tags[messaging.X_TAGS.NO_RESPONSE_REQUIRED],
            },
            0
        )

        local saga_id = saga_instance.saga_id
        -- local context = saga_instance.context

        local request = process_inventory_surplus_or_shortage_prepare_get_inventory_item_request(context)
        tags[messaging.X_TAGS.SAGA_ID] = tostring(saga_id)
        tags[messaging.X_TAGS.RESPONSE_ACTION] = ACTIONS
            .PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_GET_INVENTORY_ITEM_CALLBACK
        return request, commit
    end))

    -- If there are invokeLocal steps at the beginning...
    --[[
    local total_commit = function()
        for _, local_commit in ipairs(local_commits) do
            local_commit()
        end
        commit()
    end
    ]]

    messaging.commit_send_or_error(status, request_or_error, commit, target, tags) -- or total_commit
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
        -- handle error, no need to compensate
        rollback_saga_instance_respond_original_requester(saga_instance, data.error)
        return
    end

    local result = data.result

    -- On-reply
    local short_circuited, is_error, result_or_error = process_inventory_surplus_or_shortage_on_get_inventory_item_reply(
        context, result)
    if (short_circuited) then
        if (not is_error) then
            complete_saga_instance_respond_original_requester(saga_instance, result_or_error, context)
        else
            rollback_saga_instance_respond_original_requester(saga_instance, result_or_error)
        end
        return
    end

    local target = in_out_config.get_target()
    local tags = { Action = in_out_config.get_create_single_line_in_out_action() }
    local status, request_or_error, commit = pcall((function()
        local request = {
            product_id = context.product_id,
            location = context.location,
            movement_quantity = context.movement_quantity,
        }

        local commit = saga.move_saga_instance_forward(saga_id, 1, target, tags, context)
        tags[messaging.X_TAGS.SAGA_ID] = tostring(saga_id)
        tags[messaging.X_TAGS.RESPONSE_ACTION] = ACTIONS
            .PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_CREATE_SINGLE_LINE_IN_OUT_CALLBACK
        return request, commit
    end))
    messaging.commit_send_or_error(status, request_or_error, commit, target, tags)
end

-- TEMPLATE: function invoking remote participant to compensate --
--[[
local function xxx_service_compensate_xxx(
    saga_id, context, _err, pre_local_step_count, pre_local_commits
)
    -- If there are remote compensations left...
    -- Invoke remote compensation
    local target = xxx_config.get_target()
    local tags = { Action = xxx_config.get_do_xxx_something_action() }
    local request = {
        xxx_id = context.xxx_id,
        version = context.xxx_version,
    }
    local status, request_or_error, commit = pcall((function()
        local commit = saga.rollback_saga_instance(saga_id, pre_local_step_count + 1, target, tags, context, _err)
        tags[messaging.X_TAGS.SAGA_ID] = tostring(saga_id)
        tags[messaging.X_TAGS.RESPONSE_ACTION] = ACTIONS
            .XXX_SERVICE_XXX_COMPENSATION_CALLBACK
        return request, commit
    end))
    local total_commit = function()
        for _, local_commit in ipairs(pre_local_commits) do
            local_commit()
        end
        commit()
    end
    messaging.commit_send_or_error(status, request_or_error, total_commit, target, tags)
end
]]

function inventory_service.process_inventory_surplus_or_shortage_create_single_line_in_out_compensation_callback(
    msg, env, response
)
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


    -- If there are only local compensations left, execute them, then respond to the original requester.
    --[[

    execute_local_compensations_respond_original_requester(saga_instance, context, nil, {
        -- local compensations
    })
    return

    ]]


    -- Invoke remote compensation.
    --[[

    -- If there are local compensations before left remote compensations...
    local pre_local_compensations = {
    }
    local pre_local_step_count, pre_local_commits = execute_local_compensations(pre_local_compensations, context)

    -- If there are not local compensations before left remote compensations...
    local pre_local_step_count = 0
    local pre_local_commits = {}

    -- invoke remote
    xxx_service_compensate_xxx(
        saga_id, nil, _err, pre_local_step_count, pre_local_commits
    )
    -- return

    --]]

    -- No more compensations, just rollback
    rollback_saga_instance_respond_original_requester(saga_instance, nil)
end

local function process_inventory_surplus_or_shortage_compensate_create_single_line_in_out(
    saga_id, context, _err, pre_local_step_count, pre_local_commits
)
    local target = in_out_config.get_target()
    local tags = { Action = in_out_config.get_void_in_out_action() }
    local status, request_or_error, commit = pcall((function()
        local request = {
            in_out_id = context.in_out_id,
            version = context.in_out_version,
        }

        local commit = saga.rollback_saga_instance(saga_id, pre_local_step_count + 1, target, tags, context, _err)
        tags[messaging.X_TAGS.SAGA_ID] = tostring(saga_id)
        tags[messaging.X_TAGS.RESPONSE_ACTION] = ACTIONS
            .PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_CREATE_SINGLE_LINE_IN_OUT_COMPENSATION_CALLBACK
        return request, commit
    end))
    local total_commit = function()
        if (pre_local_commits) then
            for _, local_commit in ipairs(pre_local_commits) do
                local_commit()
            end
        end
        commit()
    end
    messaging.commit_send_or_error(status, request_or_error, total_commit, target, tags)
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
        -- handle error, no need to compensate
        rollback_saga_instance_respond_original_requester(saga_instance, data.error)
        return
    end
    local result = data.result

    -- invoke local steps
    local local_steps = {
        process_inventory_surplus_or_shortage_do_something_locally
    }
    local local_commits = {}
    for i = 1, #local_steps, 1 do
        local local_step = local_steps[i]
        local local_status, local_result_or_error, local_commit = pcall((function()
            return local_step(context)
        end))
        if (not local_status) then
            -- Mark saga instance as compensating, and commit immediately.
            saga.set_instance_compensating(saga_id, 1)()
            local pre_local_step_count, pre_local_commits = 0, {}
            -- Invoke remote compensation.
            process_inventory_surplus_or_shortage_compensate_create_single_line_in_out(saga_id, context,
                local_result_or_error, pre_local_step_count, pre_local_commits)
            return
        else
            local_commits[#local_commits + 1] = local_commit
        end
    end

    local target = inventory_item_config.get_target()
    local tags = { Action = inventory_item_config.get_add_inventory_item_entry_action() }

    -- Export result variables into context
    context.in_out_id = result.in_out_id
    context.in_out_version = result.version

    local status, request_or_error, commit = pcall((function()
        -- Construct request from context
        local request = {
            inventory_item_id = context.inventory_item_id,
            version = context.item_version,
            movement_quantity = context.movement_quantity,
        }

        local commit = saga.move_saga_instance_forward(saga_id, 1 + #local_steps, target, tags, context)
        tags[messaging.X_TAGS.SAGA_ID] = tostring(saga_id)
        tags[messaging.X_TAGS.RESPONSE_ACTION] = ACTIONS
            .PROCESS_INVENTORY_SURPLUS_OR_SHORTAGE_ADD_INVENTORY_ITEM_ENTRY_CALLBACK
        return request, commit
    end))

    local total_commit = function()
        for _, local_commit in ipairs(local_commits) do
            local_commit()
        end
        commit()
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
        -- handle error, need to compensate
        local pre_local_compensations = {
            process_inventory_surplus_or_shortage_compensate_do_something_locally
        }
        local pre_local_step_count, pre_local_commits = execute_local_compensations(pre_local_compensations, context)
        -- Invoke remote compensation
        process_inventory_surplus_or_shortage_compensate_create_single_line_in_out(saga_id, context, data.error,
            pre_local_step_count, pre_local_commits)
        return
    end
    local result = data.result

    local target = in_out_config.get_target()
    local tags = { Action = in_out_config.get_complete_in_out_action() }
    local status, request_or_error, commit = pcall((function()
        local request = {
            in_out_id = context.in_out_id,
            version = context.in_out_version,
        }

        local commit = saga.move_saga_instance_forward(saga_id, 1, target, tags, context)
        tags[messaging.X_TAGS.SAGA_ID] = tostring(saga_id)
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
        -- handle error, need to compensate
        local pre_local_compensations = {
            nil, -- empty step compensation
            process_inventory_surplus_or_shortage_compensate_do_something_locally
        }
        local pre_local_step_count, pre_local_commits = execute_local_compensations(pre_local_compensations, context)
        -- Invoke remote compensation
        process_inventory_surplus_or_shortage_compensate_create_single_line_in_out(saga_id, context, data.error,
            pre_local_step_count, pre_local_commits)
        return
    end
    local result = data.result -- the last step result

    --  If there are "InvokeLocal" steps after
    --[[
    -- invoke local steps
    local local_steps = {
        -- local steps
    }
    local local_commits = {}
    for i = 1, #local_steps, 1 do
        local local_step = local_steps[i]
        local local_status, local_result_or_error, local_commit = pcall((function()
            return local_step(context)
        end))
        if (not local_status) then
            -- Mark saga instance as compensating, and commit immediately.
            saga.set_instance_compensating(saga_id, 1)()
            local pre_local_compensations = {
                nil, -- empty step compensation
                process_inventory_surplus_or_shortage_compensate_do_something_locally
            }
            local pre_local_step_count, pre_local_commits = execute_local_compensations(pre_local_compensations, context)
                -- Invoke remote compensation.
            process_inventory_surplus_or_shortage_compensate_create_single_line_in_out(saga_id, context,
                local_result_or_error, pre_local_step_count, pre_local_commits)
            return
        else
            local_commits[#local_commits + 1] = local_commit
        end
    end
    ]]

    local completed_result = { in_out_id = context.in_out_id }
    -- Or "completed_result = result"?

    --  If there are "InvokeLocal" steps after
    --[[
    if (local_commits ~= nil) then
        for _, local_commit in ipairs(local_commits) do
            local_commit()
        end
    end
    ]]
    complete_saga_instance_respond_original_requester(saga_instance, completed_result, context)
end

return inventory_service
