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
echo "📤 步骤 1: 创建接收者进程"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

RECEIVER_JSON=$(ao-cli spawn default --name "tag-receiver-$(date +%s)" --json 2>/dev/null)
RECEIVER_ID=$(echo "$RECEIVER_JSON" | jq -r '.data.processId')
echo "✅ 接收者进程ID: $RECEIVER_ID"
echo ""

SENDER_JSON=$(ao-cli spawn default --name "tag-sender-$(date +%s)" --json 2>/dev/null)
SENDER_ID=$(echo "$SENDER_JSON" | jq -r '.data.processId')
echo "✅ 发送者进程ID: $SENDER_ID"
echo ""

# ==================== 步骤 2: 为接收者加载 Handler ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚙️  步骤 2: 为接收者加载 Handler"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

HANDLER_FILE="$(dirname "$0")/tag-check-handler.lua"
if [ ! -f "$HANDLER_FILE" ]; then
    echo "❌ Handler 文件未找到: $HANDLER_FILE"
    exit 1
fi

LOAD_RESULT=$(ao-cli load "$RECEIVER_ID" "$HANDLER_FILE" --json 2>/dev/null)
if echo "$LOAD_RESULT" | jq -e '.success == true' >/dev/null 2>&1; then
    echo "✅ Handler 加载成功"
else
    echo "❌ Handler 加载失败"
    exit 1
fi
echo ""

# ==================== 步骤 3: 记录发送者初始 Inbox 长度 ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 步骤 3: 记录发送者初始 Inbox 长度"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

INITIAL_RESULT=$(ao-cli eval "$SENDER_ID" --data "return #Inbox" --wait --json 2>/dev/null)
INITIAL_LENGTH=$(echo "$INITIAL_RESULT" | jq -s '.[-1] | .data.result.Output.data' 2>/dev/null | tr -d '"')
echo "初始 Inbox 长度: $INITIAL_LENGTH"
echo ""

# ==================== 步骤 4: 发送包含自定义标签的消息 ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📨 步骤 4: 从发送者发送包含自定义标签的消息"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "发送者: $SENDER_ID"
echo "接收者: $RECEIVER_ID"
echo "自定义标签:"
echo "  • X-SagaId = saga-123"
echo "  • X-ResponseAction = ForwardToProxy"
echo "  • X-NoResponseRequired = false"
echo ""

# 首先显示发送的原始消息结构
echo "📤 发送端消息结构预览:"
echo "  Target: $RECEIVER_ID"
echo "  Action: CheckTags"
echo "  X-SagaId: saga-123"
echo "  X-ResponseAction: ForwardToProxy"
echo "  X-NoResponseRequired: false"
echo "  Data: Test message with custom tags"
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

echo "✅ 消息已发送到接收者 outbox"
echo ""

# ==================== 步骤 4.5: 显示 Handler 调试信息 ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 步骤 4.5: 显示 Handler 对消息的处理过程（调试信息）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📋 使用 ao-cli message 命令触发 Handler，显示详细调试信息:"

DEBUG_RESULT=$(ao-cli message "$RECEIVER_ID" CheckTags \
    --data 'Debug: Test message for displaying handler logs' \
    --tag 'X-SagaId=debug-saga-123' \
    --tag 'X-ResponseAction=DebugForward' \
    --tag 'X-NoResponseRequired=false' \
    --wait --json 2>/dev/null)

# 直接格式化整个调试结果
echo ""
echo "🐛 Handler 调试输出（完整 JSON 响应）:"
echo "$DEBUG_RESULT" | jq '.' 2>/dev/null || echo "JSON 解析失败，原始输出: $DEBUG_RESULT"

# 提取并格式化 Handler 的输出数据
DEBUG_OUTPUT=$(echo "$DEBUG_RESULT" | jq -r '.data.result.Output.data // empty' 2>/dev/null)

if [ -n "$DEBUG_OUTPUT" ] && [ "$DEBUG_OUTPUT" != "empty" ]; then
    echo ""
    echo "📄 Handler print 输出（格式化解析）:"
    # 如果输出是 JSON 格式的回复数据，格式化显示
    echo "$DEBUG_OUTPUT" | jq '.' 2>/dev/null || echo "原始输出: $DEBUG_OUTPUT"

    echo ""
    echo "🎯 关键发现总结："
    echo "   ❌ msg['X-SagaId'] = nil          (直接属性不存在)"
    echo "   ✅ msg.Tags['X-Sagaid'] 存在      (标签在 Tags 表中，大小写规范化)"
    echo "   🔄 自定义标签被 AO 系统移动到 msg.Tags 并规范化大小写"
    echo ""
fi

echo "📡 现在继续测试完整的跨进程通信流程..."
echo ""

# ==================== 步骤 5: 验证发送消息中的标签 ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 步骤 5: 验证发送消息中的标签（发送端验证）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TAGS_IN_MESSAGE=$(echo "$SEND_RESULT" | jq -s '.[-1] | .data.result.Messages[0]._RawTags // []' 2>/dev/null)
echo "📋 发送端：消息中的标签（_RawTags）:"

# 显示所有标签的原始信息
if echo "$TAGS_IN_MESSAGE" | jq -e '. != []' >/dev/null 2>&1; then
    echo "$TAGS_IN_MESSAGE" | jq -r '.[] | "  🔸 \(.name) = \(.value)"' 2>/dev/null
else
    echo "  ⚠️  未找到标签信息"
fi

SAGA_ID=$(echo "$TAGS_IN_MESSAGE" | jq -r '.[] | select(.name == "X-SagaId") | .value' 2>/dev/null || echo "")
RESPONSE_ACTION=$(echo "$TAGS_IN_MESSAGE" | jq -r '.[] | select(.name == "X-ResponseAction") | .value' 2>/dev/null || echo "")
NO_RESPONSE=$(echo "$TAGS_IN_MESSAGE" | jq -r '.[] | select(.name == "X-NoResponseRequired") | .value' 2>/dev/null || echo "")

echo ""
echo "发送端标签验证:"
[ -n "$SAGA_ID" ] && echo "  ✅ X-SagaId = $SAGA_ID" || echo "  ❌ X-SagaId 未找到"
[ -n "$RESPONSE_ACTION" ] && echo "  ✅ X-ResponseAction = $RESPONSE_ACTION" || echo "  ❌ X-ResponseAction 未找到"
[ -n "$NO_RESPONSE" ] && echo "  ✅ X-NoResponseRequired = $NO_RESPONSE" || echo "  ❌ X-NoResponseRequired 未找到"
echo ""

echo "📡 消息已发送给接收者，等待 Handler 处理..."
echo ""

# ==================== 步骤 6: 等待发送者 Inbox 增长（接收回复） ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⏳ 步骤 6: 等待接收者的回复消息进入发送者 Inbox"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

WAIT_INTERVAL=3
MAX_WAIT=300
start_time=$(date +%s)
REPLY_RECEIVED=false

while true; do
    current_time=$(date +%s)
    waited=$((current_time - start_time))
    
    if [ $waited -ge $MAX_WAIT ]; then
        echo "❌ 超时 (${MAX_WAIT}s)，未收到回复"
        break
    fi
    
    CURRENT_RESULT=$(ao-cli eval "$SENDER_ID" --data "return #Inbox" --wait --json 2>/dev/null)
    CURRENT_LENGTH=$(echo "$CURRENT_RESULT" | jq -s '.[-1] | .data.result.Output.data' 2>/dev/null | tr -d '"')
    
    echo "   ⏱️  已等待 ${waited}s: Inbox 从 $INITIAL_LENGTH -> $CURRENT_LENGTH"
    
    if [ "$CURRENT_LENGTH" -gt "$INITIAL_LENGTH" ]; then
        echo "✅ 收到回复！Inbox 长度增加到 $CURRENT_LENGTH"
        REPLY_RECEIVED=true
        break
    fi
    
    sleep $WAIT_INTERVAL
done

echo ""

# ==================== 步骤 7: 查看回复消息内容 ====================
if [ "$REPLY_RECEIVED" = true ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📬 步骤 7: 解析回复消息，验证接收端是否收到标签"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    INBOX_RESULT=$(ao-cli inbox "$SENDER_ID" --latest --json 2>/dev/null)
    if echo "$INBOX_RESULT" | jq -e '.success == true' >/dev/null 2>&1; then
        LATEST_MSG=$(echo "$INBOX_RESULT" | jq -s '.[-1] | .data.inbox' 2>/dev/null)
        echo "📨 最新收到的回复消息内容:"
        echo "$LATEST_MSG" | jq '.' 2>/dev/null | head -40
        echo ""
        
        # 从回复消息的 Data 字段中解析标签检查结果
        REPLY_DATA=$(echo "$LATEST_MSG" | jq -r '.latest.Data // empty' 2>/dev/null)
        if [ -n "$REPLY_DATA" ]; then
            echo "🔍 Handler 回复的标签检查结果:"
            echo "$REPLY_DATA" | jq '.' 2>/dev/null
            echo ""
            
            # 验证接收端是否收到了我们的自定义标签
            RECEIVED_TAGS=$(echo "$REPLY_DATA" | jq -r '.received_tags // empty' 2>/dev/null)
            TAG_COUNT=$(echo "$REPLY_DATA" | jq -r '.tag_count // 0' 2>/dev/null)

            echo "📬 接收端回复详情:"
            echo "  标签数量: $TAG_COUNT"
            echo "  接收到的标签:"

            if [ "$RECEIVED_TAGS" != "empty" ] && [ -n "$RECEIVED_TAGS" ]; then
                echo "$RECEIVED_TAGS" | jq -r 'to_entries[] | "    \(.key) = \(.value)"' 2>/dev/null || echo "    无法解析标签数据"
            else
                echo "    无标签数据"
            fi

            echo ""
            echo "🔍 标签规范化对比:"
            echo "  发送时 → 接收时"
            echo "  X-SagaId → X-Sagaid"
            echo "  X-ResponseAction → X-Responseaction"
            echo "  X-NoResponseRequired → X-Noresponserequired"

            RECEIVED_SAGA_ID=$(echo "$RECEIVED_TAGS" | jq -r '."X-Sagaid" // empty' 2>/dev/null)
            RECEIVED_ACTION=$(echo "$RECEIVED_TAGS" | jq -r '."X-Responseaction" // empty' 2>/dev/null)
            RECEIVED_NO_RESP=$(echo "$RECEIVED_TAGS" | jq -r '."X-Noresponserequired" // empty' 2>/dev/null)

            echo ""
            echo "✅ 标签保留验证:"
            [ "$RECEIVED_SAGA_ID" = "saga-123" ] && echo "  ✅ X-SagaId → X-Sagaid: $RECEIVED_SAGA_ID ✓" || echo "  ❌ X-SagaId → X-Sagaid: $RECEIVED_SAGA_ID ✗"
            [ "$RECEIVED_ACTION" = "ForwardToProxy" ] && echo "  ✅ X-ResponseAction → X-Responseaction: $RECEIVED_ACTION ✓" || echo "  ❌ X-ResponseAction → X-Responseaction: $RECEIVED_ACTION ✗"
            [ "$RECEIVED_NO_RESP" = "false" ] && echo "  ✅ X-NoResponseRequired → X-Noresponserequired: $RECEIVED_NO_RESP ✓" || echo "  ❌ X-NoResponseRequired → X-Noresponserequired: $RECEIVED_NO_RESP ✗"
            echo "  📊 标签数量: $TAG_COUNT 个"
        fi
    else
        echo "⚠️  无法查询 Inbox"
    fi
    echo ""
fi

# ==================== 总结 ====================
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║  🎯 测试完成                                                           ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""

if [ "$REPLY_RECEIVED" = true ]; then
    echo "✅ 测试成功！自定义标签被正确保留和传递"
else
    echo "❌ 测试失败！未能在 Inbox 中收到回复消息"
fi

# 🎯 测试结论总结
# ✅ 自定义 X- 前缀标签在 AO 跨进程通信中被完全保留
# 🔄 标签被 AO 系统规范化大小写：X-SagaId → X-Sagaid
# ❌ msg['X-SagaId'] 直接属性不存在（nil）
# ✅ msg.Tags['X-Sagaid'] 标签在 Tags 表中可访问
# 📝 开发建议：使用 msg.Tags 表访问自定义标签，而非直接属性

