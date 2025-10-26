-- 完整的标签检查处理器
-- 接收带有 X- 标签的消息，将接收到的信息回复给发送者

Handlers.add(
    "CheckTags",
    Handlers.utils.hasMatchingTag("Action", "CheckTags"),
    function(msg)
        -- 收集所有接收到的 X- 开头的标签
        local received_tags = {}
        for key, value in pairs(msg) do
            if type(key) == "string" and string.sub(key, 1, 2) == "X-" then
                received_tags[key] = value
            end
        end
        
        -- 回复给发送者（使用 Send 确保消息进入 Inbox）
        Send({
            Target = msg.From,
            Action = "TagCheckReply",
            Data = json.encode({
                handler_success = true,
                received_action = msg.Action,
                received_data = msg.Data,
                received_tags = received_tags,
                tag_count = #received_tags
            })
        })
    end
)
