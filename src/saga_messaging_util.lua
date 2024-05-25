local saga = require("saga")
local messaging = require("messaging")

local saga_messaging_util = {}


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

function saga_messaging_util.execute_local_compensations(local_compensations, context)
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


function saga_messaging_util.rollback_saga_instance_respond_original_requester(saga_instance, _err)
    local saga_id = saga_instance.saga_id
    local commit = saga.rollback_saga_instance(saga_id, saga_instance.current_step - 1, nil, nil, nil, _err)
    commit()
    respond_original_requester(saga_instance, _err, true)
end

function saga_messaging_util.execute_local_compensations_respond_original_requester(
    saga_instance, context, _err,
    local_compensations
)
    local saga_id = saga_instance.saga_id
    local _, local_commits = saga_messaging_util.execute_local_compensations(local_compensations, context)
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


function saga_messaging_util.complete_saga_instance_respond_original_requester(saga_instance, result, context)
    local saga_id = saga_instance.saga_id
    local commit = saga.complete_saga_instance(saga_id, context)
    commit()
    respond_original_requester(saga_instance, result, false)
end

return saga_messaging_util