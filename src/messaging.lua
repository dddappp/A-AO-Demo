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


-- 将 Saga 信息嵌入到消息的 Data 中，以避免 Tag 在转发过程中丢失。返回增强后的 Data。
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

function messaging.extract_cached_x_tags_from_message(msg)
    local x_tags = msg[messaging.X_TAGS_KEY] -- 将结果缓存到 msg["XTags"] 中，避免重复计算
    -- 只有 nil 和 false 被视为假，其它值（包括空表 {}）都为真
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
    -- 从 data 中找到所有的 X_TAGS，并且将其添加到 x_tags 中。包括：
    -- data["X-SagaId"]
    -- data["X-ResponseAction"]
    for _, v in pairs(X_TAGS) do
        if (data[v]) then
            x_tags[v] = data[v]
        end
    end
    msg[messaging.X_TAGS_KEY] = x_tags
    return x_tags
end

-- 从Data中提取Saga信息，使用 extract_cached_x_tags_from_message
-- function messaging.extract_saga_info_from_data(data)
--     if type(data) == "string" then
--         data = json.decode(data)
--     end
--     return data[messaging.X_TAGS.SAGA_ID], data[messaging.X_TAGS.RESPONSE_ACTION]
-- end


-- 🆕 DDDML改进：Saga信息访问函数
-- 基于Data嵌入机制（唯一可靠的跨进程传递方式）
function messaging.get_saga_id(msg)
    -- 仅从Data中提取Saga信息（跨进程安全）
    local x_tags = messaging.extract_cached_x_tags_from_message(msg)
    return x_tags[messaging.X_TAGS.SAGA_ID]
end

function messaging.get_response_action(msg)
    -- 仅从Data中提取响应动作（跨进程安全）
    local x_tags = messaging.extract_cached_x_tags_from_message(msg)
    return x_tags[messaging.X_TAGS.RESPONSE_ACTION]
end

function messaging.get_no_response_required(msg)
    local x_tags = messaging.extract_cached_x_tags_from_message(msg)
    return x_tags[messaging.X_TAGS.NO_RESPONSE_REQUIRED]
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

-- NOTE 旧版本的代码：
-- function messaging.respond(status, result_or_error, request_msg)
--     local data = status and { result = result_or_error } or { error = messaging.extract_error_code(result_or_error) };
--     local tags = {}
--     for _, tag in ipairs(MESSAGE_PASS_THROUGH_TAGS) do
--         if request_msg.Tags[tag] then
--             tags[tag] = request_msg.Tags[tag]
--         end
--     end
--     if request_msg.Tags[X_TAGS.RESPONSE_ACTION] then
--         tags["Action"] = request_msg.Tags[X_TAGS.RESPONSE_ACTION]
--     end
--     ao.send({
--         Target = request_msg.From,
--         Data = json.encode(data),
--         Tags = tags
--     })
-- end

function messaging.respond(status, result_or_error, request_msg)
    local data = status and { result = result_or_error } or { error = messaging.extract_error_code(result_or_error) };

    -- 🆕 DDDML改进：从Data中提取Saga信息
    -- local saga_id, response_action = messaging.extract_saga_info_from_data(request_msg.Data)
    local x_tags = messaging.extract_cached_x_tags_from_message(request_msg)
    local response_action = x_tags[messaging.X_TAGS.RESPONSE_ACTION]

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
    -- 注意：响应消息只需要嵌入saga_id，不需要嵌入response_action
    -- 因为response_action已经设置在Tags.Action中用于触发callback
    -- if saga_id then
    --     data = messaging.embed_saga_info_in_data(data, saga_id, nil)
    -- end

    for _, x_tag in ipairs(MESSAGE_PASS_THROUGH_TAGS) do
        if x_tags[x_tag] then
            data[x_tag] = x_tags[x_tag]
        end
    end

    message.Data = json.encode(data)

    ao.send(message)
end

-- NOTE 该方法之前命名为 `handle_response_based_on_tag`
-- 统一处理操作结果：
-- 1. 如果操作成功 → 执行 commit
-- 2. 根据请求消息决定 → 回复 or 抛错 or 无操作
function messaging.process_operation_result(status, result_or_error, commit, request_msg)
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

-- NOTE 旧版本的代码：
-- local function send(target, data, tags)
--     ao.send({
--         Target = target,
--         Data = json.encode(data),
--         Tags = tags
--     })
-- end
-- TODO 下面的新版本代码真的有区别吗？

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
