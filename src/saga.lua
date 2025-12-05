local entity_coll = require("entity_coll")
local bint = require('.bint')(256)

local saga = {}

local ERRORS = {
    NIL_SAGA_ID_SEQUENCE = "NIL_SAGA_ID_SEQUENCE",
    INVALID_STEP = "INVALID_STEP",
}

local saga_instances
local saga_id_sequence


function saga.init(_saga_instances, _saga_id_sequence)
    saga_instances = _saga_instances
    saga_id_sequence = _saga_id_sequence
end

local function next_saga_id()
    if (saga_id_sequence == nil) then
        error(ERRORS.NIL_SAGA_ID_SEQUENCE)
    end
    local current_bint = bint(saga_id_sequence.current)
    local next_bint = current_bint + 1
    saga_id_sequence.current = tostring(next_bint)
    return saga_id_sequence.current
end

function saga.get_saga_instance(saga_id)
    return entity_coll.get(saga_instances, saga_id)
end

function saga.get_saga_instance_copy(saga_id)
    return entity_coll.get_copy(saga_instances, saga_id)
end

function saga.contains_saga_instance(saga_id)
    return entity_coll.contains(saga_instances, saga_id)
end

function saga.create_saga_instance(saga_type, target, tags, context, original_message, local_steps)
    local saga_id = next_saga_id()
    local saga_instance = {
        saga_id = saga_id,
        saga_type = saga_type,
        current_step = 1,
        compensating = false,
        completed = false,
        participants = {},
        compensations = {},
        context = context,
        original_message = original_message,
        waiting_state = {
            is_waiting = false,
            success_event_type = nil,
            failure_event_type = nil,
            step_name = nil,
            started_at = nil,
            max_wait_time_seconds = nil,
            -- TODO 不应该在 saga 实例中使用这两个字段。应该直接在 continuation_handler 函数中调用成功或者失败的本地回调函数
            -- on_success_handler = nil,
            -- on_failure_handler = nil,
            data_mapping_rules = nil,
            compensation_config = nil,
            continuation_handler = nil
        },
    }
    if (local_steps) then
        for i = 1, local_steps, 1 do
            saga_instance.current_step = saga_instance.current_step + 1
            saga_instance.participants[#saga_instance.participants + 1] = {} -- invoke local
        end
    end
    saga_instance.participants[#saga_instance.participants + 1] = {
        {
            target = target,
            tags = tags,
        },
    }

    local commit = function()
        entity_coll.add(saga_instances, saga_id, saga_instance)
    end
    return saga_instance, commit
end

function saga.set_instance_compensating(saga_id, steps_upward)
    local saga_instance = saga.get_saga_instance_copy(saga_id)
    saga_instance.current_step = saga_instance.current_step + steps_upward
    saga_instance.compensating = true
    local commit = function()
        entity_coll.update(saga_instances, saga_id, saga_instance)
    end
    return commit
end

--- Move saga instance's current_step forward and record participant information
function saga.move_saga_instance_forward(saga_id, steps, target, tags, context)
    if (type(steps) ~= "number" or steps < 1) then
        error(ERRORS.INVALID_STEP)
    end
    local saga_instance = saga.get_saga_instance_copy(saga_id)
    for _ = 1, steps - 1, 1 do
        saga_instance.current_step = saga_instance.current_step + 1
        saga_instance.participants[saga_instance.current_step] = {} -- invoke local
    end
    saga_instance.current_step = saga_instance.current_step + 1
    saga_instance.participants[saga_instance.current_step] = {
        target = target,
        tags = tags,
    }
    saga_instance.context = context
    local commit = function()
        entity_coll.update(saga_instances, saga_id, saga_instance)
    end
    return commit
end

function saga.rollback_saga_instance(saga_id, steps, compensation_target, compensation_tags, context, _err)
    if (type(steps) ~= "number" or steps < 0) then
        error(ERRORS.INVALID_STEP)
    end
    local saga_instance = saga.get_saga_instance_copy(saga_id)
    saga_instance.compensating = true
    for _ = 1, steps - 1, 1 do
        saga_instance.current_step = saga_instance.current_step - 1
        saga_instance.compensations[#saga_instance.compensations + 1] = {} -- "invokeLocal" or empty compensation
    end
    if (saga_instance.current_step <= 1) then
        -- Let current_step stop at 1
        saga_instance.completed = true
    elseif (saga_instance.current_step > 1) then
        saga_instance.current_step = saga_instance.current_step - 1
        if (saga_instance.current_step <= 1) then
            saga_instance.completed = true
        end
        if (compensation_target) then
            saga_instance.compensations[#saga_instance.compensations + 1] = {
                target = compensation_target,
                tags = compensation_tags or {},
            }
        else
            saga_instance.compensations[#saga_instance.compensations + 1] = {}
        end
    else -- if (saga_instance.current_step == 1) then
        -- do nothing
    end
    if context then
        saga_instance.context = context
    end
    if _err then
        saga_instance.error = tostring(_err)
    end
    local commit = function()
        entity_coll.update(saga_instances, saga_id, saga_instance)
    end
    return commit
end

--- Complete saga instance
function saga.complete_saga_instance(saga_id, result, context, steps_upward)
    local saga_instance = saga.get_saga_instance_copy(saga_id)
    saga_instance.completed = true
    if (steps_upward) then
        saga_instance.current_step = saga_instance.current_step + steps_upward
    end
    if (result) then
        saga_instance.result = result
    end
    if (context) then
        saga_instance.context = context
    end
    local commit = function()
        entity_coll.update(saga_instances, saga_id, saga_instance)
    end
    return commit
end

function saga.trigger_local_event(saga_id, event_type, event_data)
    local saga_instance = saga.get_saga_instance_copy(saga_id)
    if not saga_instance or not saga_instance.waiting_state or not saga_instance.waiting_state.is_waiting then
        print("Saga " .. saga_id .. " is not waiting for an event. Ignoring event: " .. event_type)
        return
    end

    local waiting_state = saga_instance.waiting_state
    local context = saga_instance.context

    -- TODO 不应该在这里处理成功或者失败的情况！直接在 continuation_handler 指向的那个函数内部处理成功或者失败的情况
    if event_type == waiting_state.success_event_type then
        print("Handling success event '" .. event_type .. "' for Saga " .. saga_id)
        local short_circuited, is_error, result_or_error

        -- TODO 不要使用 on_success_handler 字段！直接在 continuation_handler 指向的那个函数内部处理成功的情况
        if waiting_state.on_success_handler then
            short_circuited, is_error, result_or_error = waiting_state.on_success_handler(event_data, context)
        else
            -- No handler means default success: continue execution
            short_circuited, is_error, result_or_error = false, false, nil
        end

        if is_error then
            local commit = saga.rollback_saga_instance(saga_id, saga_instance.current_step - 1, nil, nil, context, result_or_error)
            commit()
            return
        end

        if short_circuited then
            local commit = saga.complete_saga_instance(saga_id, result_or_error, context)
            commit()
            return
        end

        -- Continue execution: update context, clear waiting state, and call continuation handler.
        saga_instance.context = result_or_error or context
        saga_instance.waiting_state = { is_waiting = false }
        -- TODO 不要让 continuation_handler 的值是一个字符串！直接保存函数引用！
        local continuation_handler_name = waiting_state.continuation_handler

        local commit = function() entity_coll.update(saga_instances, saga_id, saga_instance) end
        commit()

        if continuation_handler_name then
            -- Parse modularized function name (e.g., "service.method_callback")
            local func = _G
            for part in string.gmatch(continuation_handler_name, "[^%.]+") do
                func = func[part]
                if not func then break end
            end

            if func and type(func) == "function" then
                -- Call the continuation handler to proceed to the next step of the saga.
                func(saga_id, saga_instance.context, result_or_error)
            else
                print("WARN: continuation_handler not found: " .. continuation_handler_name)
                -- If handler not found, complete the saga
                local complete_commit = saga.complete_saga_instance(saga_id, result_or_error, saga_instance.context)
                complete_commit()
            end
        else
            -- If there is no continuation handler, it means the saga is completed after this event.
            local complete_commit = saga.complete_saga_instance(saga_id, result_or_error, saga_instance.context)
            complete_commit()
        end

    elseif event_type == waiting_state.failure_event_type then
        print("Handling failure event '" .. event_type .. "' for Saga " .. saga_id)
        -- TODO 不要使用 on_failure_handler 字段！直接在 continuation_handler 指向的那个函数内部处理失败的情况
        if waiting_state.on_failure_handler then
            waiting_state.on_failure_handler(event_data, context)
        end

        -- Prepare total commits array for atomic execution
        local total_commits = {}

        -- Execute local compensation if compensation_config is defined
        if waiting_state.compensation_config and waiting_state.compensation_config.action then
            local _, local_commits = saga_messaging.execute_local_compensations(
                {waiting_state.compensation_config.action}, context
            )
            for _, lc in ipairs(local_commits) do
                table.insert(total_commits, lc)
            end
        end

        -- Rollback Saga instance
        local err_msg = "Failure event received: " .. event_type
        if event_data and event_data.reason then err_msg = err_msg .. " - Reason: " .. event_data.reason end
        local rollback_commit = saga.rollback_saga_instance(saga_id, saga_instance.current_step - 1, nil, nil, context, err_msg)
        table.insert(total_commits, rollback_commit)

        -- Execute all commits atomically
        for _, commit in ipairs(total_commits) do
            commit()
        end

    else
        print("Saga " .. saga_id .. " is waiting for '" .. waiting_state.success_event_type .. "' or '" .. (waiting_state.failure_event_type or "") .. "', but received '" .. event_type .. "'. Ignoring.")
    end
end

return saga
