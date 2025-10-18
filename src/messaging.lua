local json = require("json")

local messaging = {}

local X_TAGS = {
    NO_RESPONSE_REQUIRED = "X-NoResponseRequired",
    RESPONSE_ACTION = "X-ResponseAction",
    SAGA_ID = "X-SagaId",
}

local MESSAGE_PASS_THROUGH_TAGS = {
    X_TAGS.SAGA_ID,
}

messaging.X_TAGS = X_TAGS
messaging.MESSAGE_PASS_THROUGH_TAGS = MESSAGE_PASS_THROUGH_TAGS
messaging.X_TAGS_KEY = "XTags"

-- Embed saga information in data to avoid tag loss during forwarding
function messaging.embed_saga_info_in_data(data, saga_id, response_action)
    -- CRITICAL FIX: Create a copy instead of modifying the original object to avoid polluting context references
    local enhanced_data = {}
    if data then
        for k, v in pairs(data) do
            enhanced_data[k] = v
        end
    end
    enhanced_data[messaging.X_TAGS.SAGA_ID] = saga_id
    enhanced_data[messaging.X_TAGS.RESPONSE_ACTION] = response_action
    return enhanced_data
end

function messaging.extract_cached_x_tags_from_message(msg)
    local x_tags = msg[messaging.X_TAGS_KEY] -- Cache result in msg["XTags"] to avoid repeated computation
    -- Only nil and false are considered false, other values (including empty table {}) are true
    if (x_tags) then
        return x_tags
    end
    x_tags = {}

    -- 安全地处理msg.Data
    local data = msg.Data
    if (data) then
        if (type(data) == "string") then
            -- 使用pcall保护json.decode，避免解析错误导致崩溃
            local success, decoded = pcall(json.decode, data)
            if success and type(decoded) == "table" then
                data = decoded
            else
                -- JSON解析失败，返回空结果
                msg[messaging.X_TAGS_KEY] = x_tags
                return x_tags
            end
        elseif (type(data) ~= "table") then
            -- data不是字符串也不是table，返回空结果
            msg[messaging.X_TAGS_KEY] = x_tags
            return x_tags
        end
    else
        -- 没有Data字段，返回空结果
        msg[messaging.X_TAGS_KEY] = x_tags
        return x_tags
    end

    -- 确保data是table
    if (type(data) ~= "table") then
        msg[messaging.X_TAGS_KEY] = x_tags
        return x_tags
    end

    -- 安全地提取X_TAGS
    for _, v in pairs(X_TAGS) do
        if type(v) == "string" and data[v] ~= nil then
            x_tags[v] = data[v]
        end
    end

    msg[messaging.X_TAGS_KEY] = x_tags
    return x_tags
end

function messaging.get_saga_id(msg)
    -- Extract saga information only from data (cross-process safe)
    local x_tags = messaging.extract_cached_x_tags_from_message(msg)
    return x_tags[messaging.X_TAGS.SAGA_ID]
end

function messaging.get_response_action(msg)
    -- Extract response action only from data (cross-process safe)
    local x_tags = messaging.extract_cached_x_tags_from_message(msg)
    return x_tags[messaging.X_TAGS.RESPONSE_ACTION]
end

function messaging.get_no_response_required(msg)
    local x_tags = messaging.extract_cached_x_tags_from_message(msg)
    return x_tags[messaging.X_TAGS.NO_RESPONSE_REQUIRED]
end

local string_to_boolean_mappings = {
    ["true"] = true,
    ["false"] = false,
    ["yes"] = true,
    ["no"] = false,
    ["1"] = true,
    ["0"] = false
}

function messaging.convert_to_boolean(val)
    if (type(val) == "string") then
        return string_to_boolean_mappings[val:lower()] or false
    end
    if (type(val) == "number") then
        return val ~= 0
    end
    return (val and true) or false
end

function messaging.extract_error_code(err)
    if (err == nil or err == '') then
        return "INTERNAL_ERROR"
    end
    local err_msg = tostring(err)
    return err_msg:match("%s+([%u_]+)[^%s]*$") or err_msg
end

function messaging.respond(status, result_or_error, request_msg)
    local data = status and { result = result_or_error } or { error = messaging.extract_error_code(result_or_error) };

    -- Extract saga information from data
    local x_tags = messaging.extract_cached_x_tags_from_message(request_msg)
    local response_action = x_tags[messaging.X_TAGS.RESPONSE_ACTION]
    -- Use request_msg.From as response target
    -- local target = request_msg.From

    if (type(data) == "table") then
        -- todo 如果 data 是类似 `{1, 2, 3}` 的数组，如果再设置 data["KEY"] = value，按照经验 json.encode 会报错。
        -- 这里需要增加一些防御性编码
        for _, x_tag in ipairs(MESSAGE_PASS_THROUGH_TAGS) do
            if x_tags[x_tag] then
                data[x_tag] = x_tags[x_tag]
            end
        end
    end
    -- -- TODO 如果 data 不是 table，那么报错？忽略？还是将结果包装到一个 table 中？

    local message = {
        -- Target = target,
        Data = json.encode(data)
    }

    -- If there is response_action, set it to the Action field
    if response_action then
        -- message.Tags = { Action = response_action }
        message.Action = response_action
    end

    if request_msg.reply then 
        request_msg.reply(message)
    else
        message.Target = request_msg.From
        Send(message)
    end
end

function messaging.process_operation_result(status, result_or_error, commit, request_msg)
    if status then
        commit()
    end
    if (not messaging.convert_to_boolean(messaging.get_no_response_required(request_msg))) then
        messaging.respond(status, result_or_error, request_msg)
    else
        if not status then
            error(result_or_error)
        end
    end
end

-- NOTE 这个 local 函数只有一个地方使用，是否直接内联到使用它的地方就好？
-- local function send(target, data, tags)
--     ao.send({
--         Target = target,
--         Data = json.encode(data),
--         Tags = tags
--     })
-- end

-- todo 这个函数是否接受一个“请求消息”参数更好？可以搜索使用使用 commit_send_or_error 的地方，看看是否可以传入“请求消息”参数。
--   或者，让这个函数保留原样（目前看这个更好），专门用于主动对外发送消息的场景。
--   然后增加一个 commit_respond_or_error 函数，专门用于发送响应消息（存在对应的请求消息）的场景。
function messaging.commit_send_or_error(status, request_or_error, commit, target, tags)
    if (status) then
        commit()
        Send({
            Target = target,
            Data = json.encode(request_or_error),
            Tags = tags
        })
    else
        error(request_or_error)
    end
end

return messaging
