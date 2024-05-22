local utils = {}

local json = require("json")

local X_TAGS = {
    NO_RESPONSE_REQUIRED = "X-NoResponseRequired",
    RESPONSE_ACTION = "X-ResponseAction",
}

local MESSAGE_PASS_THROUGH_TAGS = {
    "X-SAGA_ID",
}

local string_to_boolean_mappings = {
    ["true"] = true,
    ["false"] = false,
    ["yes"] = true,
    ["no"] = false,
    ["1"] = true,
    ["0"] = false
}

function utils.convert_to_boolean(val)
    if (type(val) == "string") then
        return string_to_boolean_mappings[val:lower()] or false
    end
    if (type(val) == "number") then
        return val ~= 0
    end
    return (val and true) or false
end


function utils.extract_error_code(err)
    return tostring(err):match("([^ ]+)$") or "UNKNOWN_ERROR"
end

function utils.respond(status, result_or_error, request_msg)
    local data = status and { result = result_or_error } or { error = utils.extract_error_code(result_or_error) };
    local tags = {}
    for _, tag in ipairs(MESSAGE_PASS_THROUGH_TAGS) do
        if request_msg.Tags[tag] then
            tags[tag] = request_msg.Tags[tag]
        end
    end
    if request_msg.Tags[X_TAGS.RESPONSE_ACTION] then
        tags["Action"] = request_msg.Tags[X_TAGS.RESPONSE_ACTION]
    end
    ao.send({
        Target = request_msg.From,
        Data = json.encode(data),
        Tags = tags
    })
end

function utils.handle_response_based_on_tag(status, result_or_error, commit, request_msg)
    if status then
        commit()
    end
    if (not utils.convert_to_boolean(request_msg.Tags[X_TAGS.NO_RESPONSE_REQUIRED])) then
        utils.respond(status, result_or_error, request_msg)
    else
        if not status then
            error(result_or_error)
        end
    end
end

return utils
