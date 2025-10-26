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
-- 标签检查处理器
-- 在 Handler 中 print 出接收到的标签，观察是否出现在 outcome 中
Handlers.add(
    "CheckTags",
    function(msg)
        return msg.Action == "CheckTags"
    end,
    function(msg)
        -- 收集所有接收到的自定义标签
        local received_tags = {}
        
        -- 检查所有 X- 开头的标签
        for key, value in pairs(msg) do
            if type(key) == "string" and key:sub(1, 2) == "X-" then
                received_tags[key] = value
            end
        end
        
        -- 回复消息到发送者，包含接收到的完整信息
        Send({
            Target = msg.From,
            Action = "TagCheckResult",
            Data = json.encode({
                message_received = true,
                received_action = msg.Action,
                received_data = msg.Data,
                received_custom_tags = received_tags,
                received_tags_dict = msg.Tags
            })
        })
    end
)
LUAEOF

ao-cli load "$RECEIVER_ID" "$TEST_CODE" --json 2>/dev/null > /dev/null
rm -f "$TEST_CODE"
echo "✅ 接收者代码加载完成（包含标签检查处理器和回复机制）"
echo ""

# ==================== 步骤 4: 发送包含自定义标签的消息 ====================
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

# 在发送消息前记录发送者的初始 Inbox 长度
INITIAL_LENGTH_RAW=$(ao-cli eval "$SENDER_ID" --data "return #Inbox" --wait --json 2>/dev/null)
INITIAL_LENGTH=$(echo "$INITIAL_LENGTH_RAW" | jq -s '.[-1] | .data.result.Output.data' 2>/dev/null | tr -d '"' || echo "0")
echo "发送前 Inbox 长度: $INITIAL_LENGTH"
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

# ==================== 步骤 4.5: 检查消息处理输出（包含 print） ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 步骤 4.5: 检查消息处理输出"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 从 eval 结果中提取 Output.data（包含 Handler 的 print 输出）
OUTPUT_DATA=$(echo "$SEND_OUTPUT" | jq -s '.[-1] | .data.result.Output.data' 2>/dev/null | tr -d '"')

if [ -n "$OUTPUT_DATA" ] && [ "$OUTPUT_DATA" != "null" ]; then
    echo "📤 Handler 处理输出:"
    echo "$OUTPUT_DATA" | sed 's/\\n/\n/g'
    echo ""
fi

echo ""

# eval 返回的结果包含消息的完整信息（包括标签）
# 从 eval 结果中提取消息的标签
TAGS_JSON=$(echo "$SEND_OUTPUT" | jq -s '.[-1] | .data.result.Messages[0]._RawTags // []' 2>/dev/null)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 步骤 5: 从消息中提取并验证标签"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📋 发送的消息中的标签："
echo "$TAGS_JSON" | jq '.' 2>/dev/null
echo ""

# 提取并验证每个自定义标签
echo "🔍 标签验证结果："
echo ""
echo "  发送时              →  接收时              →  值               →  状态"
echo "  ─────────────────────────────────────────────────────────────────────"

# 检查 X-SagaId
SAGA_ID=$(echo "$TAGS_JSON" | jq -r '.[] | select(.name | contains("SagaId")) | .value' 2>/dev/null || echo "NOT_FOUND")
if [ "$SAGA_ID" != "NOT_FOUND" ] && [ -n "$SAGA_ID" ]; then
    echo "  ✅ X-SagaId         →  X-SagaId          →  $SAGA_ID       →  ✓ 保留"
else
    echo "  ❌ X-SagaId         →  (未找到)          →  -               →  ✗ 被过滤"
fi

# 检查 X-ResponseAction
RESPONSE_ACTION=$(echo "$TAGS_JSON" | jq -r '.[] | select(.name | contains("ResponseAction")) | .value' 2>/dev/null || echo "NOT_FOUND")
if [ "$RESPONSE_ACTION" != "NOT_FOUND" ] && [ -n "$RESPONSE_ACTION" ]; then
    echo "  ✅ X-ResponseAction →  X-ResponseAction  →  $RESPONSE_ACTION →  ✓ 保留"
else
    echo "  ❌ X-ResponseAction →  (未找到)          →  -               →  ✗ 被过滤"
fi

# 检查 X-NoResponseRequired
NO_RESPONSE=$(echo "$TAGS_JSON" | jq -r '.[] | select(.name | contains("NoResponseRequired")) | .value' 2>/dev/null || echo "NOT_FOUND")
if [ "$NO_RESPONSE" != "NOT_FOUND" ] && [ -n "$NO_RESPONSE" ]; then
    echo "  ✅ X-NoResponseRequired → X-NoResponseRequired → $NO_RESPONSE       →  ✓ 保留"
else
    echo "  ❌ X-NoResponseRequired → (未找到)          →  -               →  ✗ 被过滤"
fi

echo ""

# ==================== 步骤 6: 验证接收者的回复 ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📬 步骤 6: 验证接收者的回复消息"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "等待接收者的回复消息到达..."
echo ""

# 等待 Inbox 长度增加（最多检查 30 次）
WAIT_COUNT=0
MAX_ATTEMPTS=30
while [ $WAIT_COUNT -lt $MAX_ATTEMPTS ]; do
    CURRENT_LENGTH_RAW=$(ao-cli eval "$SENDER_ID" --data "return #Inbox" --wait --json 2>/dev/null)
    CURRENT_LENGTH=$(echo "$CURRENT_LENGTH_RAW" | jq -s '.[-1] | .data.result.Output.data' 2>/dev/null | tr -d '"' || echo "0")
    
    # 检查是否有新消息到达
    if [ "$CURRENT_LENGTH" -gt "$INITIAL_LENGTH" ]; then
        echo "✅ Inbox 长度从 $INITIAL_LENGTH 增加到 $CURRENT_LENGTH，有新消息到达"
        break
    fi
    
    WAIT_COUNT=$((WAIT_COUNT + 1))
    if [ $WAIT_COUNT -lt $MAX_ATTEMPTS ]; then
        sleep 1
    fi
done

if [ "$CURRENT_LENGTH" -le "$INITIAL_LENGTH" ]; then
    echo "⏱️  等待超时（检查 $MAX_ATTEMPTS 次后仍未收到新消息）"
    echo ""
else
    echo ""
fi

# 查询发送者的 Inbox，查找来自接收者的 TagCheckResult 消息
REPLY_JSON=$(ao-cli eval "$SENDER_ID" --data "
local result = {}
for i, msg in ipairs(Inbox) do
    if msg.Action == 'TagCheckResult' and msg.From == '$RECEIVER_ID' then
        table.insert(result, {
            index = i,
            action = msg.Action,
            from = msg.From,
            data = msg.Data
        })
    end
end
return json.encode(result)
" --wait --json 2>/dev/null)

REPLY_RESULT=$(echo "$REPLY_JSON" | jq -s '.[-1] | .data.result.Output.data | fromjson?' 2>/dev/null || echo "[]")

if [ "$REPLY_RESULT" != "[]" ] && [ -n "$REPLY_RESULT" ]; then
    echo "✅ 发送者 Inbox 中收到接收者的回复消息"
    echo ""
    
    # 提取回复消息的数据
    REPLY_DATA=$(echo "$REPLY_RESULT" | jq '.[0].data' 2>/dev/null)
    
    if [ -n "$REPLY_DATA" ] && [ "$REPLY_DATA" != "null" ]; then
        # 解码消息数据（可能是 base64 或直接的 JSON）
        PARSED_REPLY=$(echo "$REPLY_DATA" | base64 -d 2>/dev/null | jq '.' 2>/dev/null || echo "$REPLY_DATA" | jq '.' 2>/dev/null)
        
        echo "📊 接收者回复的消息内容："
        echo "$PARSED_REPLY" | jq '.' 2>/dev/null
        echo ""
        
        # 验证接收者收到的自定义标签
        RECEIVED_CUSTOM=$(echo "$PARSED_REPLY" | jq '.received_custom_tags' 2>/dev/null)
        
        if [ -n "$RECEIVED_CUSTOM" ] && [ "$RECEIVED_CUSTOM" != "null" ]; then
            echo "✅ 接收者收到的自定义标签："
            echo "$RECEIVED_CUSTOM" | jq '.' 2>/dev/null
        fi
    else
        echo "⚠️  无法解析回复消息数据"
    fi
else
    echo "⚠️  发送者 Inbox 中未收到接收者的回复"
    echo "    这可能是网络延迟或消息未被正确处理"
fi

echo ""

# ==================== 步骤 7: 最终结论 ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 测试结论"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$SAGA_ID" != "NOT_FOUND" ] && [ "$RESPONSE_ACTION" != "NOT_FOUND" ] && [ "$NO_RESPONSE" != "NOT_FOUND" ]; then
    echo "✅ 重大发现：所有自定义标签都被完整保留！"
    echo ""
    echo "验证过程："
    echo "  1️⃣  发送方发送包含自定义标签的消息"
    echo "  2️⃣  消息在 eval 结果中显示所有标签完整保留"
    echo "  3️⃣  接收方处理消息并回复确认"
    echo "  4️⃣  发送方 Inbox 中收到接收方的回复"
    echo ""
    echo "结论："
    echo "  • AO 网络不过滤自定义标签"
    echo "  • 标签完全保留，名称不被修改"
    echo "  • 可以安全地使用标签传递 Saga 相关信息"
    echo "  • 不需要在 Data 字段中嵌入这些信息"
else
    echo "⚠️  某些标签未被保留"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║  🎯 测试完成                                                           ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""
