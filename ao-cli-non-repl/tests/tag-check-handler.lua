-- 标签检查处理器
-- 接收消息，收集其中的 X- 前缀标签，然后回复给发送者

local json = require('json')

Handlers.add(
    "CheckTags",
    Handlers.utils.hasMatchingTag("Action", "CheckTags"),
    function(msg)
        -- 收集所有接收到的 X- 开头的标签
        -- 在 AO 中，标签存储在 msg.Tags 表中
        local received_tags = {}
        if msg.Tags then
            for key, value in pairs(msg.Tags) do
                if type(key) == "string" and string.sub(key, 1, 2) == "X-" then
                    received_tags[key] = value
                end
            end
        end
        
        -- 打印接收到的信息（详细调试用）
        print("✅ Handler 接收到消息")
        print("   Action: " .. tostring(msg.Action))
        print("   From: " .. tostring(msg.From))
        print("   Data: " .. tostring(msg.Data))

        -- 调试：检查 msg 对象的直接属性
        print("   🔍 调试: 检查 msg 对象的直接属性")
        print("   msg.X-SagaId = " .. tostring(msg["X-SagaId"]))
        print("   msg.X-ResponseAction = " .. tostring(msg["X-ResponseAction"]))
        print("   msg.X-NoResponseRequired = " .. tostring(msg["X-NoResponseRequired"]))

        -- 调试：检查 msg.Tags 表
        print("   🔍 调试: 检查 msg.Tags 表")
        if msg.Tags then
            for k, v in pairs(msg.Tags) do
                print("   msg.Tags." .. k .. " = " .. tostring(v))
            end
        else
            print("   msg.Tags 表不存在")
        end

        -- 计算标签数量（修复计数问题）
        local tag_count = 0
        for _ in pairs(received_tags) do
            tag_count = tag_count + 1
        end

        print("   📊 收到的自定义 X- 标签数量: " .. tostring(tag_count))

        -- 逐个打印接收到的标签
        print("   📍 接收到的 X- 标签详情:")
        for key, value in pairs(received_tags) do
            print("     " .. key .. " = " .. tostring(value))
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
                tag_count = tag_count
            })
        })
        print("✅ 回复消息已发送")
    end
)
