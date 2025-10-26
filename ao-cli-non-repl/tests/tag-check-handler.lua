-- 标签检查处理器
-- 接收消息，收集其中的 X- 前缀标签，然后回复给发送者

local json = require('json')

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
        
        -- 打印接收到的信息（调试用）
        print("✅ Handler 接收到消息")
        print("   Action: " .. tostring(msg.Action))
        print("   From: " .. tostring(msg.From))
        print("   Data: " .. tostring(msg.Data))
        print("   收到的自定义标签数量: " .. tostring(#received_tags))
        
        -- 逐个打印接收到的标签
        for key, value in pairs(received_tags) do
            print("   📍 " .. key .. " = " .. tostring(value))
        end
        
        -- 回复给发送者（使用 Send 确保消息进入 Inbox）
        print("📤 发送回复消息给: " .. tostring(msg.From))
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
        print("✅ 回复消息已发送")
    end
)
