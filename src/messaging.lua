local json = require("json")

local messaging = {}

local X_CONTEXT = {
    NO_RESPONSE_REQUIRED = "X-NoResponseRequired",
    RESPONSE_ACTION = "X-ResponseAction",
    SAGA_ID = "X-SagaId",
}

-- 扩展上下文的规范化属性名（Title-Kebab-Case格式）
-- 用于从消息的直接属性中提取扩展上下文
local X_CONTEXT_NORMALIZED_NAMES = {
    NO_RESPONSE_REQUIRED = "X-No-Response-Required",
    RESPONSE_ACTION = "X-Response-Action",
    SAGA_ID = "X-Saga-Id",
}


local MESSAGE_PASS_THROUGH_PROPERTIES = {
    X_CONTEXT.SAGA_ID,
    X_CONTEXT_NORMALIZED_NAMES.SAGA_ID,
}

-- 扩展上下文来源常量
local X_CONTEXT_SOURCE = {
    DIRECT_PROPERTIES = 1,  -- 来自消息的直接属性
    DATA_EMBEDDED = 2, -- 嵌入在msg.Data中的扩展上下文信息
}

local X_CONTEXT_KEY = "X-Context"
local X_CONTEXT_SOURCE_KEY = "X-Context-Source"  -- 存储扩展上下文来源的key

messaging.X_CONTEXT = X_CONTEXT
messaging.MESSAGE_PASS_THROUGH_PROPERTIES = MESSAGE_PASS_THROUGH_PROPERTIES

-- Embed saga information in data to avoid tag loss during forwarding
function messaging.embed_saga_info_in_data(data, saga_id, response_action)

    -- todo 查找所有使用 embed_saga_info_in_data 的地方，应该根据远端“参与者”的设置来决定是否在 Data 中嵌入扩展上下文信息。
    --   如果没有，那么考虑（默认）在发送的消息的直接属性中嵌入扩展上下文信息？
    --   我们可以看到，embed_saga_info_in_data 之后，紧接着就是 commit_send_or_error。
    --   此时，将要嵌入的扩展上下文信息通过 commit_send_or_error 的 tags 参数传递？

    -- CRITICAL FIX: Create a copy instead of modifying the original object to avoid polluting context references
    local enhanced_data = {}
    if data then
        for k, v in pairs(data) do
            enhanced_data[k] = v
        end
    end
    enhanced_data[messaging.X_CONTEXT.SAGA_ID] = saga_id
    enhanced_data[messaging.X_CONTEXT.RESPONSE_ACTION] = response_action
    return enhanced_data
end

local function extract_cached_x_context_from_message(msg)

    local x_context = msg[X_CONTEXT_KEY] -- Cache result to avoid repeated computation
    -- Only nil and false are considered false, other values (including empty table {}) are true
    if (x_context) then
        return x_context, msg[X_CONTEXT_SOURCE_KEY] or X_CONTEXT_SOURCE.DIRECT_PROPERTIES
    end
    x_context = {}

    local x_context_source = nil

    -- 优先遍历 X_CONTEXT_NORMALIZED_NAMES 指定的属性名称，尝试从消息的直接属性中提取扩展上下文。
    --   并且一旦在消息的直接属性中找到了扩展上下文，就不要再尝试提取“嵌入在 msg.Data 中的扩展上下文信息”
    for _, v in pairs(X_CONTEXT_NORMALIZED_NAMES) do
        if type(v) == "string" and msg[v] ~= nil then
            x_context[v] = msg[v]
            x_context_source = X_CONTEXT_SOURCE.DIRECT_PROPERTIES
        end
    end
    if (x_context_source) then
        return x_context, x_context_source
    end

    -- 默认情况下，可以认为扩展上下文来自消息的直接属性
    x_context_source = X_CONTEXT_SOURCE.DIRECT_PROPERTIES

    -- Safely handle msg.Data
    local data = msg.Data
    if (data) then
        if (type(data) == "string") then
            local success, decoded = pcall(json.decode, data)
            if success and type(decoded) == "table" then
                data = decoded
            else
                -- JSON parsing failed, return empty result
                msg[X_CONTEXT_KEY] = x_context
                msg[X_CONTEXT_SOURCE_KEY] = x_context_source
                return x_context, x_context_source
            end
        elseif (type(data) ~= "table") then
            -- data is neither string nor table, return empty result
            msg[X_CONTEXT_KEY] = x_context
            msg[X_CONTEXT_SOURCE_KEY] = x_context_source
            return x_context, x_context_source
        end
    else
        -- No Data field, return empty result
        msg[X_CONTEXT_KEY] = x_context
        msg[X_CONTEXT_SOURCE_KEY] = x_context_source
        return x_context, x_context_source
    end

    -- Ensure data is a table
    if (type(data) ~= "table") then
        msg[X_CONTEXT_KEY] = x_context
        msg[X_CONTEXT_SOURCE_KEY] = x_context_source
        return x_context, x_context_source
    end

    -- Safely extract X_CONTEXT
    for _, v in pairs(X_CONTEXT) do
        if type(v) == "string" and data[v] ~= nil then
            x_context[v] = data[v]
            x_context_source = X_CONTEXT_SOURCE.DATA_EMBEDDED
        end
    end

    msg[X_CONTEXT_KEY] = x_context
    msg[X_CONTEXT_SOURCE_KEY] = x_context_source
    return x_context, x_context_source
end

-- Extract complete reply context from message
function messaging.extract_reply_context(msg)
    local x_context, x_context_source = extract_cached_x_context_from_message(msg)
    return {
        reply = msg.reply,
        From = msg.From,  -- Reply target address
        Data = {},        -- Reply data (always empty object)
        [X_CONTEXT_KEY] = x_context,  -- Pre-extracted X-context
        [X_CONTEXT_SOURCE_KEY] = x_context_source  -- Source of X-context
    }, x_context_source
end

function messaging.get_saga_id(msg)
    -- Extract saga information only from data (cross-process safe)
    local x_context = extract_cached_x_context_from_message(msg)
    -- 优先使用规范化后的属性名称来提取扩展上下文中的 saga id
    return x_context[X_CONTEXT_NORMALIZED_NAMES.SAGA_ID] or x_context[messaging.X_CONTEXT.SAGA_ID]
end

function messaging.get_response_action(msg)
    -- Extract response action only from data (cross-process safe)
    local x_context = extract_cached_x_context_from_message(msg)
    return x_context[X_CONTEXT_NORMALIZED_NAMES.RESPONSE_ACTION] or x_context[messaging.X_CONTEXT.RESPONSE_ACTION]
end

function messaging.get_no_response_required(msg)
    local x_context = extract_cached_x_context_from_message(msg)
    return x_context[X_CONTEXT_NORMALIZED_NAMES.NO_RESPONSE_REQUIRED] or x_context[messaging.X_CONTEXT.NO_RESPONSE_REQUIRED]
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
    local x_context, x_context_source = extract_cached_x_context_from_message(request_msg)
    local response_action = x_context[X_CONTEXT_NORMALIZED_NAMES.RESPONSE_ACTION] or x_context[X_CONTEXT.RESPONSE_ACTION]

    -- Use request_msg.From as response target
    -- local target = request_msg.From

    -- 如果 “扩展上下文” 来自请求消息的直接属性，则**不要**在回复的 data 中嵌入扩展上下文信息
    if (x_context_source ~= X_CONTEXT_SOURCE.DIRECT_PROPERTIES and type(data) == "table") then
        for _, x_tag in ipairs(MESSAGE_PASS_THROUGH_PROPERTIES) do
            if x_context[x_tag] then
                data[x_tag] = x_context[x_tag]
            end
        end
    end

    local message = {
        -- Target = target,
        Data = json.encode(data)
    }

    -- 如果 “扩展上下文” 来自请求消息的直接属性，则在回复消息的“直接属性”中直接嵌入扩展上下文信息！
    if x_context_source == X_CONTEXT_SOURCE.DIRECT_PROPERTIES then
        for _, x_tag in ipairs(MESSAGE_PASS_THROUGH_PROPERTIES) do
            if x_context[x_tag] then
                message[x_tag] = x_context[x_tag]
            end
        end
    end

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

-- commit_send_or_error: specifically for sending messages to external parties (saga mode)
-- commit_respond_or_error: specifically for responding to messages (when request message exists)
function messaging.commit_send_or_error(status, request_or_error, commit, target, tags)
    -- 在 tags 参数中如果包含特定的属性名，则从 tags 中移除它们，直接在 message 的“直接属性”中设置它们。
    --   比如 `Action`，直接在 message 的“直接属性”中设置它似乎更合适。
    --   还有，我们的扩展上下文属性，比如 `X-Saga-Id`，`X-Response-Action`，`X-No-Response-Required`，
    --   如果通过 tags 参数传入，也应该从 tags 中移除，然后在 message 的“直接属性”中设置它们。
    if (status) then
        commit()

        local message = {
            Target = target,
            Data = json.encode(request_or_error)
        }

        -- 如果tags存在，处理其中的特殊属性
        if tags then
            local filtered_tags = {}
            for k, v in pairs(tags) do
                if k == "Action" then
                    -- Action 直接设置为消息的直接属性
                    message.Action = v
                elseif k == X_CONTEXT_NORMALIZED_NAMES.SAGA_ID or k == X_CONTEXT_NORMALIZED_NAMES.RESPONSE_ACTION or k == X_CONTEXT_NORMALIZED_NAMES.NO_RESPONSE_REQUIRED then
                    message[k] = v
                else
                    -- 其他属性保留在tags中
                    filtered_tags[k] = v
                end
            end

            message.Tags = filtered_tags
        end

        Send(message)
    else
        error(request_or_error)
    end
end

-- commit_respond_or_error: commit then respond to message, or throw error
-- Parameters: status (success or not), result_or_error (result or error), commit (commit function), request_msg (request message)
function messaging.commit_respond_or_error(status, result_or_error, commit, request_msg)
    if (status) then
        commit()
        messaging.respond(status, result_or_error, request_msg)
    else
        error(result_or_error)
    end
end

return messaging
