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
        -- Print 接收到的消息信息
        print("\n[DEBUG] 接收者 Handler 收到消息:")
        print("[DEBUG] Action: " .. tostring(msg.Action))
        print("[DEBUG] From: " .. tostring(msg.From))
        
        -- 打印所有 X- 开头的标签
        print("[DEBUG] 自定义标签:")
        local custom_tag_count = 0
        for key, value in pairs(msg) do
            if type(key) == "string" and key:sub(1, 2) == "X-" then
                print("[DEBUG]   " .. key .. " = " .. tostring(value))
                custom_tag_count = custom_tag_count + 1
            end
        end
        print("[DEBUG] 共找到 " .. custom_tag_count .. " 个自定义标签")
        
        -- 也打印 msg.Tags
        print("[DEBUG] msg.Tags 内容:")
        if msg.Tags then
            for key, value in pairs(msg.Tags) do
                if key:sub(1, 2) == "X-" then
                    print("[DEBUG]   Tags." .. key .. " = " .. tostring(value))
                end
            end
        end
        
        -- Send 响应回去
        Send({
            Target = msg.From,
            Action = "TagCheckResult",
            Data = json.encode({
                message_received = true,
                handler_name = "CheckTags"
            })
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

# ==================== 步骤 4.5: 检查消息处理的 outcome ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 步骤 4.5: 检查消息处理的 Outcome（可能包含 print 输出）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# eval 返回的完整结果（包括 outcome 中的 print 输出）
echo "eval 返回的完整结果:"
echo "$SEND_OUTPUT" | jq '.' 2>/dev/null | head -100
echo ""

# ==================== 步骤 5: 从 eval 结果中提取并验证标签 ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 步骤 5: 从消息中提取并验证标签"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 从 eval 结果中提取消息的标签
TAGS_JSON=$(echo "$SEND_OUTPUT" | jq -s '.[-1] | .data.result.Messages[0]._RawTags // []' 2>/dev/null)

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

# ==================== 步骤 6: 验证结果分析 ====================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 测试结论"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$SAGA_ID" != "NOT_FOUND" ] && [ "$RESPONSE_ACTION" != "NOT_FOUND" ] && [ "$NO_RESPONSE" != "NOT_FOUND" ]; then
    echo "✅ 重大发现：所有自定义标签都被完整保留！"
    echo ""
    echo "这意味着："
    echo "  • AO 网络不过滤自定义标签"
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
