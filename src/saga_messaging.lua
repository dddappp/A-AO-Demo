local json = require("json")
local saga = require("saga")
local messaging = require("messaging")

local saga_messaging = {}


local function respond_original_requester(saga_instance, result_or_error, is_error)
    local original_message_from = saga_instance.original_message and saga_instance.original_message.from or nil
    if is_error and not result_or_error then
        result_or_error = saga_instance.error or "INTERNAL_ERROR"
    end

    -- Construct response data with embedded saga information
    local data = not is_error and { result = result_or_error } or { error = messaging.extract_error_code(result_or_error) }

    -- Embed saga information if available
    -- Note: Response messages only embed saga_id, not response_action
    if saga_instance.saga_id then
        data = messaging.embed_saga_info_in_data(data, tostring(saga_instance.saga_id), nil)
    end

    -- Send response directly instead of using handle_response_based_on_tag
    local tags = {}
    if saga_instance.original_message and saga_instance.original_message.response_action then
        tags["Action"] = saga_instance.original_message.response_action
    end

    ao.send({
        Target = original_message_from,
        Data = json.encode(data),
        Tags = tags
    })
end

function saga_messaging.execute_local_compensations(local_compensations, context)
    local step_count = 0
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
            step_count = step_count + 1
        end
    end
    return step_count, local_commits
end


function saga_messaging.rollback_saga_instance_respond_original_requester(saga_instance, _err)
    local saga_id = saga_instance.saga_id
    local commit = saga.rollback_saga_instance(saga_id, saga_instance.current_step - 1, nil, nil, nil, _err)
    commit()
    respond_original_requester(saga_instance, _err, true)
end

function saga_messaging.execute_local_compensations_respond_original_requester(
    saga_instance, context, _err,
    local_compensations
)
    local saga_id = saga_instance.saga_id
    local _, local_commits = saga_messaging.execute_local_compensations(local_compensations, context)
    local commit = saga.rollback_saga_instance(saga_id, saga_instance.current_step - 1, nil, nil, context,
        _err)
    local total_commit = function()
        for _, local_commit in ipairs(local_commits) do
            local_commit()
        end
        commit()
    end
    total_commit()
    respond_original_requester(saga_instance, _err, true)
end


function saga_messaging.complete_saga_instance_respond_original_requester(saga_instance, result, context, pre_local_commits)
    local saga_id = saga_instance.saga_id

    if (pre_local_commits and type(pre_local_commits) ~= "table") then
        error("pre_local_commits must be a table")
    end
    if (pre_local_commits) then
        for _, local_commit in ipairs(pre_local_commits) do
            local_commit()
        end
    end

    local commit = saga.complete_saga_instance(saga_id, result, context, pre_local_commits and #pre_local_commits or 0)
    commit()
    respond_original_requester(saga_instance, result, false)
end

return saga_messaging
