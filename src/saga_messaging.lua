local saga = require("saga")
local messaging = require("messaging")

local saga_messaging = {}

-- 从消息中提取完整的回复上下文
function saga_messaging.extract_reply_context(msg)
    return {
        reply = msg.reply,
        From = msg.From,  -- 回复目标地址
        Data = {},        -- 回复数据（总是空对象）
        [messaging.X_TAGS_KEY] = messaging.extract_cached_x_tags_from_message(msg)  -- 预提取的X-Tags
    }
end

local function respond_original_requester(saga_instance, result_or_error, is_error)
    local reply_context = saga_instance.original_message

    if is_error and not result_or_error then
        result_or_error = saga_instance.error or "INTERNAL_ERROR"
    end

    -- 直接使用预构造的回复消息对象
    messaging.process_operation_result(not is_error, result_or_error, function() end, reply_context)
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
