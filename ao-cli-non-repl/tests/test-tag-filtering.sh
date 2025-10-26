#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# 测试脚本：AO 自定义标签过滤检测
# ═══════════════════════════════════════════════════════════════════════════
#
# 测试流程：
#   1. 创建接收者进程，加载 Handler
#   2. 从发送者通过 eval Send() 发送包含自定义标签的消息
#   3. 接收者 Handler 接收消息并验证标签是否被保留
#   4. 接收者回复给发送者
#   5. 验证发送者 Inbox 中收到回复
#
# ═══════════════════════════════════════════════════════════════════════════

set -e

echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║  🧪 AO 自定义标签过滤测试                                              ║"
echo "║  验证跨进程通信中标签的保留情况                                        ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""

# 检查 ao-cli 是否安装
if ! command -v ao-cli &> /dev/null; then
    echo "❌ ao-cli 命令未找到，请先安装"
    exit 1
fi

# ==================== 步骤 1: 创建两个进程 ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📤 步骤 1: 创建发送者和接收者进程"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SENDER_JSON=$(ao-cli spawn default --name "tag-sender-$(date +%s)" --json 2>/dev/null)
SENDER_ID=$(echo "$SENDER_JSON" | jq -r '.data.processId')
echo "✅ 发送者进程ID: $SENDER_ID"

RECEIVER_JSON=$(ao-cli spawn default --name "tag-receiver-$(date +%s)" --json 2>/dev/null)
RECEIVER_ID=$(echo "$RECEIVER_JSON" | jq -r '.data.processId')
echo "✅ 接收者进程ID: $RECEIVER_ID"
echo ""

# ==================== 步骤 2: 为接收者加载处理 Handler ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚙️  步骤 2: 为接收者加载 Handler"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

HANDLER_FILE="/tmp/tag-handler-$RANDOM.lua"
cat > "$HANDLER_FILE" << 'LUAEOF'
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
LUAEOF

LOAD_RESULT=$(ao-cli load "$RECEIVER_ID" "$HANDLER_FILE" --json 2>/dev/null)
if echo "$LOAD_RESULT" | jq -e '.success == true' >/dev/null 2>&1; then
    echo "✅ Handler 加载成功"
else
    echo "❌ Handler 加载失败"
    rm -f "$HANDLER_FILE"
    exit 1
fi
rm -f "$HANDLER_FILE"
echo ""

# ==================== 步骤 3: 发送者记录初始 Inbox 长度 ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 步骤 3: 记录发送者初始 Inbox 长度"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

INITIAL_RESULT=$(ao-cli eval "$SENDER_ID" --data "return #Inbox" --wait --json 2>/dev/null)
INITIAL_LENGTH=$(echo "$INITIAL_RESULT" | jq -s '.[-1] | .data.result.Output.data | tonumber' 2>/dev/null || echo "0")
echo "初始 Inbox 长度: $INITIAL_LENGTH"
echo ""

# ==================== 步骤 4: 发送包含自定义标签的消息 ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📨 步骤 4: 发送包含自定义标签的消息"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "发送者: $SENDER_ID"
echo "接收者: $RECEIVER_ID"
echo "自定义标签:"
echo "  • X-SagaId = saga-123"
echo "  • X-ResponseAction = ForwardToProxy"
echo "  • X-NoResponseRequired = false"
echo ""

SEND_RESULT=$(ao-cli eval "$SENDER_ID" --data "
Send({
    Target = '$RECEIVER_ID',
    Action = 'CheckTags',
    ['X-SagaId'] = 'saga-123',
    ['X-ResponseAction'] = 'ForwardToProxy', 
    ['X-NoResponseRequired'] = 'false',
    Data = 'Test message with custom tags'
})
" --wait --json 2>/dev/null)

echo "✅ 消息已发送"
echo ""

# ==================== 步骤 5: 从发送消息结果中验证标签 ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 步骤 5: 验证发送的消息中的标签"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TAGS_IN_MESSAGE=$(echo "$SEND_RESULT" | jq -s '.[-1] | .data.result.Messages[0]._RawTags // []' 2>/dev/null)
echo "消息中的标签:"
echo "$TAGS_IN_MESSAGE" | jq '.' 2>/dev/null

SAGA_ID=$(echo "$TAGS_IN_MESSAGE" | jq -r '.[] | select(.name == "X-SagaId") | .value' 2>/dev/null || echo "")
RESPONSE_ACTION=$(echo "$TAGS_IN_MESSAGE" | jq -r '.[] | select(.name == "X-ResponseAction") | .value' 2>/dev/null || echo "")
NO_RESPONSE=$(echo "$TAGS_IN_MESSAGE" | jq -r '.[] | select(.name == "X-NoResponseRequired") | .value' 2>/dev/null || echo "")

echo ""
echo "标签验证:"
[ -n "$SAGA_ID" ] && echo "  ✅ X-SagaId = $SAGA_ID" || echo "  ❌ X-SagaId 未找到"
[ -n "$RESPONSE_ACTION" ] && echo "  ✅ X-ResponseAction = $RESPONSE_ACTION" || echo "  ❌ X-ResponseAction 未找到"
[ -n "$NO_RESPONSE" ] && echo "  ✅ X-NoResponseRequired = $NO_RESPONSE" || echo "  ❌ X-NoResponseRequired 未找到"
echo ""

# ==================== 步骤 6: 等待发送者 Inbox 增长 ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⏳ 步骤 6: 等待接收者回复（监控发送者 Inbox）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

WAIT_INTERVAL=3
MAX_WAIT=300
start_time=$(date +%s)

while true; do
    current_time=$(date +%s)
    waited=$((current_time - start_time))
    
    if [ $waited -ge $MAX_WAIT ]; then
        echo "❌ 超时 ($MAX_WAIT秒)，未收到回复"
        break
    fi
    
    CURRENT_RESULT=$(ao-cli eval "$SENDER_ID" --data "return #Inbox" --wait --json 2>/dev/null)
    CURRENT_LENGTH=$(echo "$CURRENT_RESULT" | jq -s '.[-1] | .data.result.Output.data | tonumber' 2>/dev/null || echo "0")
    
    echo "   ⏱️  已等待 ${waited}s: Inbox 从 $INITIAL_LENGTH -> $CURRENT_LENGTH"
    
    if [ "$CURRENT_LENGTH" -gt "$INITIAL_LENGTH" ]; then
        echo "✅ 收到回复！Inbox 长度增加到 $CURRENT_LENGTH"
        break
    fi
    
    sleep $WAIT_INTERVAL
done

echo ""

# ==================== 步骤 7: 查看回复消息内容 ====================
if [ "$CURRENT_LENGTH" -gt "$INITIAL_LENGTH" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📬 步骤 7: 显示回复消息内容"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    INBOX_RESULT=$(ao-cli inbox "$SENDER_ID" --latest --json 2>/dev/null)
    if echo "$INBOX_RESULT" | jq -e '.success == true' >/dev/null 2>&1; then
        LATEST_MSG=$(echo "$INBOX_RESULT" | jq -s '.[-1] | .data.inbox' 2>/dev/null)
        echo "最新消息:"
        echo "$LATEST_MSG" | jq '.' 2>/dev/null | head -30
    else
        echo "⚠️  无法查询 Inbox"
    fi
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║  🎯 测试完成                                                           ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"


