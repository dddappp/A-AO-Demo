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
    local data = msg.Data
    if (data) then
        if (type(msg.Data) == "string") then
            data = json.decode(data)
        end
    end
    for _, v in pairs(X_TAGS) do
        if (data[v]) then
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
    -- Extract saga information from data
    local x_tags = messaging.extract_cached_x_tags_from_message(request_msg)
    local response_action = x_tags[messaging.X_TAGS.RESPONSE_ACTION]

    -- Use msg.reply if available (for eval context), otherwise use Send
    if request_msg.reply then
        -- Use AO's built-in reply mechanism - keep same data structure as Send
        local data = status and { result = result_or_error } or { error = messaging.extract_error_code(result_or_error) };

        -- Add saga information to data
        for _, x_tag in ipairs(MESSAGE_PASS_THROUGH_TAGS) do
            if x_tags[x_tag] then
                data[x_tag] = x_tags[x_tag]
            end
        end

        -- Use msg.reply with same data structure as Send
        if response_action then
            request_msg.reply({
                Action = response_action,
                Data = json.encode(data)
            })
        else
            request_msg.reply({
                Data = json.encode(data)
            })
        end
    else
        -- Fallback to Send for non-eval contexts
        local data = status and { result = result_or_error } or { error = messaging.extract_error_code(result_or_error) };

        -- Use request_msg.From as response target
        local target = request_msg.From

        local message = {
            Target = target,
            Data = json.encode(data)
        }

        -- If there is response_action, set it to the Action field in Tags
        if response_action then
            message.Tags = { Action = response_action }
        end

        for _, x_tag in ipairs(MESSAGE_PASS_THROUGH_TAGS) do
            if x_tags[x_tag] then
                data[x_tag] = x_tags[x_tag]
            end
        end

        message.Data = json.encode(data)

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

-- todo 这个 local 函数只有一个地方使用，是否直接内联到使用它的地方就好？
local function send(target, data, tags)
    ao.send({
        Target = target,
        Data = json.encode(data),
        Tags = tags
    })
end

-- todo 这个函数是否接受一个“请求消息”参数更好？可以搜索使用使用 commit_send_or_error 的地方，看看是否可以传入“请求消息”参数。
--   或者，让这个函数保留原样（目前看这个更好），专门用于主动对外发送消息的场景。
--   然后增加一个 commit_respond_or_error 函数，专门用于发送响应消息（存在对应的请求消息）的场景。
function messaging.commit_send_or_error(status, request_or_error, commit, target, tags)
    if (status) then
        commit()
        send(target, request_or_error, tags)
    else
        error(request_or_error)
    end
end

return messaging
