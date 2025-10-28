local json = require("json")

local messaging = {}

local X_CONTEXT = {
    NO_RESPONSE_REQUIRED = "X-NoResponseRequired",
    RESPONSE_ACTION = "X-ResponseAction",
    SAGA_ID = "X-SagaId",
}

local MESSAGE_PASS_THROUGH_PROPERTIES = {
    X_CONTEXT.SAGA_ID,
}

messaging.X_CONTEXT = X_CONTEXT
messaging.MESSAGE_PASS_THROUGH_PROPERTIES = MESSAGE_PASS_THROUGH_PROPERTIES
messaging.X_CONTEXT_KEY = "XTags"

-- Embed saga information in data to avoid tag loss during forwarding
function messaging.embed_saga_info_in_data(data, saga_id, response_action)
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
    local x_context = msg[messaging.X_CONTEXT_KEY] -- Cache result in msg["XTags"] to avoid repeated computation
    -- Only nil and false are considered false, other values (including empty table {}) are true
    if (x_context) then
        return x_context
    end
    x_context = {}

    -- Safely handle msg.Data
    local data = msg.Data
    if (data) then
        if (type(data) == "string") then
            local success, decoded = pcall(json.decode, data)
            if success and type(decoded) == "table" then
                data = decoded
            else
                -- JSON parsing failed, return empty result
                msg[messaging.X_CONTEXT_KEY] = x_context
                return x_context
            end
        elseif (type(data) ~= "table") then
            -- data is neither string nor table, return empty result
            msg[messaging.X_CONTEXT_KEY] = x_context
            return x_context
        end
    else
        -- No Data field, return empty result
        msg[messaging.X_CONTEXT_KEY] = x_context
        return x_context
    end

    -- Ensure data is a table
    if (type(data) ~= "table") then
        msg[messaging.X_CONTEXT_KEY] = x_context
        return x_context
    end

    -- Safely extract X_CONTEXT
    for _, v in pairs(X_CONTEXT) do
        if type(v) == "string" and data[v] ~= nil then
            x_context[v] = data[v]
        end
    end

    msg[messaging.X_CONTEXT_KEY] = x_context
    return x_context
end

-- Extract complete reply context from message
function messaging.extract_reply_context(msg)
    return {
        reply = msg.reply,
        From = msg.From,  -- Reply target address
        Data = {},        -- Reply data (always empty object)
        [messaging.X_CONTEXT_KEY] = extract_cached_x_context_from_message(msg)  -- Pre-extracted X-Tags
    }
end

function messaging.get_saga_id(msg)
    -- Extract saga information only from data (cross-process safe)
    local x_context = extract_cached_x_context_from_message(msg)
    return x_context[messaging.X_CONTEXT.SAGA_ID]
end

function messaging.get_response_action(msg)
    -- Extract response action only from data (cross-process safe)
    local x_context = extract_cached_x_context_from_message(msg)
    return x_context[messaging.X_CONTEXT.RESPONSE_ACTION]
end

function messaging.get_no_response_required(msg)
    local x_context = extract_cached_x_context_from_message(msg)
    return x_context[messaging.X_CONTEXT.NO_RESPONSE_REQUIRED]
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
    local x_context = extract_cached_x_context_from_message(request_msg)
    local response_action = x_context[messaging.X_CONTEXT.RESPONSE_ACTION]

    -- Use request_msg.From as response target
    -- local target = request_msg.From

    if (type(data) == "table") then
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
