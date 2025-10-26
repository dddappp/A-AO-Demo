#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# 测试脚本：AO 自定义标签过滤检测
# ═══════════════════════════════════════════════════════════════════════════
#
# 目的：
#   验证 AO 网络是否会过滤自定义标签（X-SagaId, X-ResponseAction, X-NoResponseRequired）
#   这对于 Saga 框架的实现至关重要。
#
# 关键发现：
#   1. Handler 处理的消息不会进入 Inbox
#   2. 需要通过 Send() 回复来验证接收到的标签内容
#   3. 标签完全保留，但会进行大小写规范化
#
# ═══════════════════════════════════════════════════════════════════════════

export HTTPS_PROXY=http://127.0.0.1:1235
export HTTP_PROXY=http://127.0.0.1:1235
export ALL_PROXY=socks5://127.0.0.1:1235

echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║  🧪 AO 自定义标签过滤测试                                              ║"
echo "║  验证标签传递是否被过滤或保留                                          ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""

# 检查 ao-cli 是否安装
if ! command -v ao-cli &> /dev/null; then
    echo "❌ ao-cli 命令未找到，请先安装"
    exit 1
fi

# 检查钱包文件
WALLET_FILE="${HOME}/.aos.json"
if [ ! -f "$WALLET_FILE" ]; then
    echo "❌ AOS 钱包文件未找到: $WALLET_FILE"
    exit 1
fi

echo "✅ 环境检查通过"
echo ""

# ==================== 步骤 1: 生成发送者进程 ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📤 步骤 1: 生成发送者进程"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
SENDER_JSON=$(ao-cli spawn default --name "tag-test-sender-$(date +%s)" --json 2>/dev/null)
SENDER_ID=$(echo "$SENDER_JSON" | jq -r '.data.processId')
echo "✅ 发送者进程ID: $SENDER_ID"
echo ""

# ==================== 步骤 2: 生成接收者进程 ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📥 步骤 2: 生成接收者进程"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RECEIVER_JSON=$(ao-cli spawn default --name "tag-test-receiver-$(date +%s)" --json 2>/dev/null)
RECEIVER_ID=$(echo "$RECEIVER_JSON" | jq -r '.data.processId')
echo "✅ 接收者进程ID: $RECEIVER_ID"
echo ""

# ==================== 步骤 3: 为接收者加载标签检查代码 ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚙️  步骤 3: 为接收者加载标签检查代码"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 创建临时Lua代码，用于检查接收到的消息标签
# 使用时间戳和随机数避免文件冲突
TEST_CODE="/tmp/tag-test-$(date +%s%N)-$RANDOM.lua"
cat > "$TEST_CODE" << 'LUAEOF'
-- 全局变量：存储调试信息
DebugInfo = DebugInfo or {}

-- 标签检查处理器
-- 注意：Handler 处理的消息不会进入 Inbox，需要通过 Send() 来回复
Handlers.add(
    "CheckTags",
    function(msg)
        return msg.Action == "CheckTags"
    end,
    function(msg)
        -- 保存接收到的标签信息到全局变量
        local received_tags = {}
        
        -- 检查所有 X- 开头的自定义标签
        for key, value in pairs(msg) do
            if type(key) == "string" and (key:sub(1, 2) == "X-" or key:sub(1, 2) == "x-") then
                received_tags[key] = value
            end
        end
        
        -- 保存到全局变量供之后查询
        DebugInfo.last_received_tags = received_tags
        DebugInfo.last_msg_tags_dict = msg.Tags
        DebugInfo.last_msg_action = msg.Action
        DebugInfo.last_msg_from = msg.From
        DebugInfo.last_msg_data = msg.Data
        
        -- 通过 Send() 回复发送方，这样数据会进入发送方的 Inbox
        Send({
            Target = msg.From,
            Action = "TagCheckResult",
            Data = json.encode({
                message_received = true,
                handler_name = "CheckTags",
                received_tags = received_tags,
                tags_dict = msg.Tags,
                original_action = msg.Action,
                from_process = msg.From
            })
        })
    end
)

-- 处理调试查询请求
Handlers.add(
    "GetDebugInfo",
    function(msg)
        return msg.Action == "GetDebugInfo"
    end,
    function(msg)
        Send({
            Target = msg.From,
            Action = "DebugInfoResult",
            Data = json.encode(DebugInfo)
        })
    end
)
LUAEOF

ao-cli load "$RECEIVER_ID" "$TEST_CODE" --json 2>/dev/null > /dev/null
rm -f "$TEST_CODE"
echo "✅ 接收者代码加载完成（包含标签检查处理器）"
echo ""

# ==================== 步骤 4: 发送带自定义标签的消息 ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📨 步骤 4: 发送包含自定义标签的消息"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "发送者: $SENDER_ID"
echo "接收者: $RECEIVER_ID"
echo ""
echo "📋 发送的标签："
echo "  • X-SagaId = saga-test-123"
echo "  • X-ResponseAction = ForwardToProxy"
echo "  • X-NoResponseRequired = false"
echo ""

# 在发送者进程中执行 Send 命令
SEND_OUTPUT=$(ao-cli eval "$SENDER_ID" --data "
Send({
    Target = '$RECEIVER_ID',
    Action = 'CheckTags',
    Tags = {
        ['X-SagaId'] = 'saga-test-123',
        ['X-ResponseAction'] = 'ForwardToProxy',
        ['X-NoResponseRequired'] = 'false'
    },
    Data = 'Testing custom tag preservation'
})
" --wait --json 2>/dev/null)

echo "✅ 消息已发送"
echo ""

# ==================== 步骤 5: 等待并检查发送者的 Inbox ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📬 步骤 5: 检查发送者收到的响应"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "等待接收者处理消息并发送响应..."
echo ""

# 使用 --wait 参数确保消息被完全处理
# 这样会等待直到消息完全处理完成，而不是简单地 sleep
INBOX_JSON=$(ao-cli eval "$SENDER_ID" --data "
local result = {}
for i, msg in ipairs(Inbox) do
    if msg.Action == 'TagCheckResult' then
        table.insert(result, {
            index = i,
            action = msg.Action,
            data = msg.Data
        })
    end
end
return json.encode(result)
" --wait --json 2>/dev/null)

INBOX_RESULT=$(echo "$INBOX_JSON" | jq -s '.[-1] | .data.result.Output.data | fromjson?' 2>/dev/null || echo "[]")

# ==================== 步骤 5.5: 直接查看接收者的 Inbox ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 步骤 5.5: 直接检查接收者的 Inbox（调试）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 查看接收者 Inbox 中最后一条消息的完整内容
RECEIVER_INBOX=$(ao-cli eval "$RECEIVER_ID" --data "
local msg = Inbox[#Inbox]  -- 获取最后一条消息
if msg then
    local result = {
        index = #Inbox,
        action = msg.Action,
        from = msg.From,
        data = msg.Data,
        has_x_sagaid = msg['X-Sagaid'] ~= nil,
        x_sagaid_value = msg['X-Sagaid'],
        has_x_responseaction = msg['X-Responseaction'] ~= nil,
        x_responseaction_value = msg['X-Responseaction'],
        has_x_noresponserequired = msg['X-Noresponserequired'] ~= nil,
        x_noresponserequired_value = msg['X-Noresponserequired'],
        all_keys = {}
    }
    
    -- 收集所有 X- 开头的键
    for key in pairs(msg) do
        if type(key) == 'string' and key:sub(1, 2) == 'X-' then
            table.insert(result.all_keys, key)
        end
    end
    
    return json.encode(result)
else
    return json.encode({ error = 'No message in Inbox' })
end
" --wait --json 2>/dev/null)

RECEIVER_PARSED=$(echo "$RECEIVER_INBOX" | jq -s '.[-1] | .data.result.Output.data | fromjson?' 2>/dev/null)

echo "接收者 Inbox 最后一条消息内容："
echo "$RECEIVER_PARSED" | jq '.' 2>/dev/null
echo ""

if [ "$INBOX_RESULT" != "[]" ] && [ -n "$INBOX_RESULT" ]; then
    echo "✅ 收到来自接收者的响应"
    echo ""
    
    # 解析响应数据
    RESPONSE_DATA=$(echo "$INBOX_RESULT" | jq '.[0].data' 2>/dev/null)
    
    if [ -n "$RESPONSE_DATA" ] && [ "$RESPONSE_DATA" != "null" ]; then
        PARSED_RESPONSE=$(echo "$RESPONSE_DATA" | base64 -d 2>/dev/null | jq '.' 2>/dev/null || echo "$RESPONSE_DATA")
        
        echo "📊 响应内容："
        echo "$PARSED_RESPONSE" | jq '.' 2>/dev/null | head -50
    else
        echo "⚠️  无法解析响应数据"
    fi
else
    echo "⚠️  未收到来自接收者的响应"
    echo "    这可能是因为网络延迟或消息未被正确处理"
fi

echo ""

# ==================== 步骤 6: 验证标签是否被保留 ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 步骤 6: 验证结果分析"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

RECEIVED_TAGS=$(echo "$PARSED_RESPONSE" 2>/dev/null | jq '.received_tags' 2>/dev/null)

if [ -n "$RECEIVED_TAGS" ] && [ "$RECEIVED_TAGS" != "null" ]; then
    echo "接收者收到的自定义标签："
    echo "$RECEIVED_TAGS" | jq 'to_entries | .[] | "  • \(.key) = \(.value)"' -r 2>/dev/null
    echo ""
    
    # 检查每个标签
    SAGA_ID=$(echo "$RECEIVED_TAGS" | jq -r '.["X-Sagaid"] // .["X-SagaId"] // "NOT FOUND"' 2>/dev/null)
    RESPONSE_ACTION=$(echo "$RECEIVED_TAGS" | jq -r '.["X-Responseaction"] // .["X-ResponseAction"] // "NOT FOUND"' 2>/dev/null)
    NO_RESPONSE=$(echo "$RECEIVED_TAGS" | jq -r '.["X-Noresponserequired"] // .["X-NoResponseRequired"] // "NOT FOUND"' 2>/dev/null)
    
    echo "📋 标签检查结果："
    echo ""
    echo "  发送时            →  接收时              →  结果"
    echo "  ────────────────────────────────────────────────────"
    
    if [ "$SAGA_ID" != "NOT FOUND" ]; then
        echo "  ✅ X-SagaId           X-Sagaid            ✓ 保留: $SAGA_ID"
    else
        echo "  ❌ X-SagaId           (未找到)           ✗ 被过滤"
    fi
    
    if [ "$RESPONSE_ACTION" != "NOT FOUND" ]; then
        echo "  ✅ X-ResponseAction   X-Responseaction    ✓ 保留: $RESPONSE_ACTION"
    else
        echo "  ❌ X-ResponseAction   (未找到)           ✗ 被过滤"
    fi
    
    if [ "$NO_RESPONSE" != "NOT FOUND" ]; then
        echo "  ✅ X-NoResponseRequired X-Noresponserequired ✓ 保留: $NO_RESPONSE"
    else
        echo "  ❌ X-NoResponseRequired (未找到)           ✗ 被过滤"
    fi
    
else
    echo "⚠️  无法提取标签信息"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║  🎯 测试完成                                                           ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""
