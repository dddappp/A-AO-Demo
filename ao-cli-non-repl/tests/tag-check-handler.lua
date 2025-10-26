Handlers.add(
    "CheckTags",
    Handlers.utils.hasMatchingTag("Action", "CheckTags"),
    function(msg)
        local received_tags = {}
        for key, value in pairs(msg) do
            if type(key) == "string" and string.sub(key, 1, 2) == "X-" then
                received_tags[key] = value
            end
        end
        
        if msg.reply then
            msg.reply({
                result = "OK",
                tags = received_tags
            })
        else
            Send({
                Target = msg.From,
                Action = "TagCheckReply",
                Data = json.encode({
                    result = "OK",
                    tags = received_tags
                })
            })
        end
    end
)
