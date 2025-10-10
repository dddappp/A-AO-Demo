local json = require("json")

local messaging = {}

local X_TAGS = {
    NO_RESPONSE_REQUIRED = "X-NoResponseRequired",
    RESPONSE_ACTION = "X-ResponseAction",
    SAGA_ID = "X-SagaId",
}

-- 将Saga信息嵌入Data中，以避免Tag在转发过程中丢失
function messaging.embed_saga_info_in_data(data, saga_id, response_action)
    -- 🔧 CRITICAL FIX: 创建副本而不是修改原对象，避免污染context中的引用
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

-- 从Data中提取Saga信息
function messaging.extract_saga_info_from_data(data)
    if type(data) == "string" then
        data = json.decode(data)
    end
    return data[messaging.X_TAGS.SAGA_ID], data[messaging.X_TAGS.RESPONSE_ACTION]
end


-- 🆕 DDDML改进：Saga信息访问函数
-- 基于Data嵌入机制（唯一可靠的跨进程传递方式）
function messaging.get_saga_id(msg)
    -- 仅从Data中提取Saga信息（跨进程安全）
    return messaging.extract_saga_info_from_data(msg.Data)
end

function messaging.get_response_action(msg)
    -- 仅从Data中提取响应动作（跨进程安全）
    local _, response_action = messaging.extract_saga_info_from_data(msg.Data)
    return response_action
end

function messaging.get_no_response_required(msg)
    -- 🆕 DDDML改进：从Data嵌入中提取（目前未使用，保留兼容性）
    return nil  -- 目前没有在Data中嵌入no_response_required信息
end


messaging.X_TAGS = X_TAGS

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

    -- 🆕 DDDML改进：从Data中提取Saga信息
    local saga_id, response_action = messaging.extract_saga_info_from_data(request_msg.Data)

    -- 使用request_msg.From作为响应目标
    local target = request_msg.From

    -- 🆕 CRITICAL FIX: Action必须在Tags中，而不是作为消息的直接属性
    -- 否则跨进程消息会因为Action被过滤而无法触发handler
    local message = {
        Target = target,
        Data = json.encode(data)
    }

    -- 如果有response_action，将其设置到Tags中的Action字段
    if response_action then
        message.Tags = { Action = response_action }
    end

    -- 如果有Saga信息，将其嵌入响应Data中
    if saga_id then
        data = messaging.embed_saga_info_in_data(data, saga_id, response_action)
        message.Data = json.encode(data)
    end

    ao.send(message)
end

function messaging.handle_response_based_on_tag(status, result_or_error, commit, request_msg)
    if status then
        commit()
    end
    -- 🆕 DDDML改进：使用多层次Tag访问函数
    if (not messaging.convert_to_boolean(messaging.get_no_response_required(request_msg))) then
        messaging.respond(status, result_or_error, request_msg)
    else
        if not status then
            error(result_or_error)
        end
    end
end

local function send(target, data, tags)
    -- 🆕 CRITICAL FIX: 在AO中，Action必须在Tags中，不能作为消息的直接属性
    -- 否则跨进程消息会因为Action被过滤而无法触发handler
    local message = {
        Target = target,
        Data = json.encode(data)
    }

    -- 设置Tags字段（包含Action）
    if tags and next(tags) then
        message.Tags = tags
    end

    ao.send(message)
end

function messaging.commit_send_or_error(status, request_or_error, commit, target, tags)
    if (status) then
        commit()
        send(target, request_or_error, tags)
    else
        error(request_or_error)
    end
end

return messaging
