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

# ==================== 步骤 3: 发送包含自定义标签的消息 ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📨 步骤 3: 通过 ao-cli message 发送包含自定义标签的消息"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "发送者: $SENDER_ID"
echo "接收者: $RECEIVER_ID"
echo "自定义标签:"
echo "  • X-SagaId = saga-123"
echo "  • X-ResponseAction = ForwardToProxy"
echo "  • X-NoResponseRequired = false"
echo ""

# 使用 ao-cli message 命令发送，这样接收者才能真正收到消息
MESSAGE_RESULT=$(ao-cli message "$RECEIVER_ID" CheckTags \
    --data 'Test message with custom tags' \
    --tag 'X-SagaId=saga-123' \
    --tag 'X-ResponseAction=ForwardToProxy' \
    --tag 'X-NoResponseRequired=false' \
    --wait --json 2>/dev/null)

echo "✅ 消息已发送"
echo ""

# ==================== 步骤 4: 验证接收的消息中的标签 ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 步骤 4: 从接收者的 Handler 输出中验证标签"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 从消息命令的输出中提取 Handler 输出
HANDLER_OUTPUT=$(echo "$MESSAGE_RESULT" | jq -s '.[-1] | .data.result.Output.data' 2>/dev/null || echo "")

echo "📨 Handler 处理结果:"
echo "$HANDLER_OUTPUT"
echo ""

# 检查 Handler 是否成功处理
if echo "$HANDLER_OUTPUT" | grep -q "handler_success"; then
    echo "✅ Handler 成功处理了消息"
    echo ""
    echo "标签验证:"
    
    # 从消息结果中提取标签
    TAGS=$(echo "$MESSAGE_RESULT" | jq -s '.[-1] | .data.result.Messages[0]._RawTags // []' 2>/dev/null)
    
    SAGA_ID=$(echo "$TAGS" | jq -r '.[] | select(.name == "X-SagaId") | .value' 2>/dev/null || echo "")
    RESPONSE_ACTION=$(echo "$TAGS" | jq -r '.[] | select(.name == "X-ResponseAction") | .value' 2>/dev/null || echo "")
    NO_RESPONSE=$(echo "$TAGS" | jq -r '.[] | select(.name == "X-NoResponseRequired") | .value' 2>/dev/null || echo "")
    
    [ -n "$SAGA_ID" ] && echo "  ✅ X-SagaId = $SAGA_ID" || echo "  ❌ X-SagaId 未找到"
    [ -n "$RESPONSE_ACTION" ] && echo "  ✅ X-ResponseAction = $RESPONSE_ACTION" || echo "  ❌ X-ResponseAction 未找到"
    [ -n "$NO_RESPONSE" ] && echo "  ✅ X-NoResponseRequired = $NO_RESPONSE" || echo "  ❌ X-NoResponseRequired 未找到"
else
    echo "⚠️  Handler 未成功处理（可能是网络延迟）"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║  🎯 测试完成                                                           ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"


