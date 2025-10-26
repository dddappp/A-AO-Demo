#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# 测试脚本：AO 自定义标签过滤检测
# ═══════════════════════════════════════════════════════════════════════════
#
# 目的：
#   验证 AO 网络是否会过滤自定义标签（X-SagaId, X-ResponseAction, X-NoResponseRequired）
#   这对于 Saga 框架的实现至关重要。
#
# 背景：
#   AO 平台对消息标签有过滤机制：
#   - 标准标签（如 Action, From, Type 等）：通常保留
#   - 自定义标签（如 X-* 开头的标签）：可能被过滤
#
# 测试流程：
#   1. 创建发送者进程（Sender）
#   2. 创建接收者进程（Receiver），加载消息调试代码
#   3. 发送包含自定义标签的消息
#   4. 接收者检查收到的消息中是否存在这些标签
#   5. 通过 Inbox 查看结果
#
# 预期行为：
#   - 如果标签被过滤：msg["X-SagaId"] 将为 nil
#   - 如果标签保留：msg["X-SagaId"] 将包含发送时的值
#
# 关键发现（已知问题）：
#   AO 网络会过滤自定义标签！解决方案是使用 Data 字段嵌入 Saga 信息。
#   参考：src/messaging.lua 中的 embed_saga_info_in_data() 函数
#
# ═══════════════════════════════════════════════════════════════════════════

export HTTPS_PROXY=http://127.0.0.1:1235
export HTTP_PROXY=http://127.0.0.1:1235
export ALL_PROXY=socks5://127.0.0.1:1235

# 不使用 set -e，而是逐个检查错误
# set -e

# 帮助函数：检查命令是否成功
check_error() {
    if [ $? -ne 0 ]; then
        echo "❌ 错误: $1"
        exit 1
    fi
}

echo "=== AO 标签过滤测试脚本 ==="
echo "测试自定义标签 (X-SagaId, X-ResponseAction, X-NoResponseRequired) 是否被过滤"
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
echo "=== 步骤 1: 生成发送者进程 ==="
SENDER_JSON=$(ao-cli spawn default --name "tag-test-sender-$(date +%s)" --json 2>/dev/null)
SENDER_ID=$(echo "$SENDER_JSON" | jq -r '.data.processId')
echo "发送者进程ID: $SENDER_ID"
echo ""

# ==================== 步骤 2: 生成接收者进程 ====================
echo "=== 步骤 2: 生成接收者进程 ==="
RECEIVER_JSON=$(ao-cli spawn default --name "tag-test-receiver-$(date +%s)" --json 2>/dev/null)
RECEIVER_ID=$(echo "$RECEIVER_JSON" | jq -r '.data.processId')
echo "接收者进程ID: $RECEIVER_ID"
echo ""

# ==================== 步骤 3: 为接收者加载测试代码 ====================
echo "=== 步骤 3: 为接收者加载消息检查代码 ==="

# 创建临时Lua代码，用于检查接收到的消息标签
TEST_CODE=$(mktemp /tmp/tag-test-XXXX.lua)
cat > "$TEST_CODE" << 'LUAEOF'
-- 处理消息，检查标签属性
Handlers.add(
    "DebugTags",
    Handlers.utils.byType("Message"),
    function(msg)
        -- 输出消息的所有顶级属性
        local result = {}
        result.received_tags = {}
        result.checked_fields = {
            ["X-SagaId"] = msg["X-SagaId"],
            ["X-ResponseAction"] = msg["X-ResponseAction"],
            ["X-NoResponseRequired"] = msg["X-NoResponseRequired"],
            ["Action"] = msg["Action"],
            ["From"] = msg["From"],
        }
        
        -- 遍历所有顶级属性
        for key, value in pairs(msg) do
            if type(key) == "string" and key:sub(1, 2) == "X-" then
                table.insert(result.received_tags, key)
            end
        end
        
        result.all_custom_tags = result.received_tags
        
        msg.reply({
            Data = json.encode(result)
        })
    end
)

-- 支持eval查询消息历史
Handlers.add(
    "QueryMessages",
    Handlers.utils.byType("Message"),
    function(msg)
        if msg.Action == "GetMessages" then
            msg.reply({
                Data = json.encode({
                    inbox_size = #Inbox,
                    message = "Check Inbox for details"
                })
            })
        end
    end
)
LUAEOF

ao-cli load "$RECEIVER_ID" "$TEST_CODE" --json 2>/dev/null > /dev/null
rm "$TEST_CODE"
echo "✅ 接收者代码加载完成"
echo ""

# ==================== 步骤 4: 发送带自定义标签的消息 ====================
echo "=== 步骤 4: 发送带自定义标签的消息 ==="
echo "从 $SENDER_ID 向 $RECEIVER_ID 发送包含自定义标签的消息..."
echo ""

# 使用 eval 在发送者进程内发送消息，包含自定义标签
SEND_OUTPUT=$(ao-cli eval "$SENDER_ID" --data "
Send({
    Target = '$RECEIVER_ID',
    Action = 'TestAction',
    Tags = {
        Action = 'DebugTags',
        ['X-SagaId'] = 'saga-123',
        ['X-ResponseAction'] = 'TestResponse',
        ['X-NoResponseRequired'] = 'true'
    },
    Data = 'Test message with custom tags'
})
" --wait --json 2>/dev/null)

echo "✅ 消息已发送"
echo ""

# ==================== 步骤 5: 等待并查询接收者的Inbox ====================
echo "=== 步骤 5: 检查接收者收到的消息 ==="
echo "等待3秒让消息处理完成..."
sleep 3

# 查询接收者的Inbox
INBOX_OUTPUT=$(ao-cli eval "$RECEIVER_ID" --data "return Inbox" --wait --json 2>/dev/null)
echo ""
echo "接收者的Inbox内容："
echo "$INBOX_OUTPUT" | jq -s '.[-1] | .data.result.Output.data' 2>/dev/null | head -100
echo ""

# ==================== 步骤 6: 发送并接收DebugTags响应 ====================
echo "=== 步骤 6: 通过消息检查自定义标签 ==="
echo "发送DebugTags消息来检查标签是否存在..."

# 先获取初始Inbox长度（不使用 set -e，所以不会因为 jq 错误而退出）
INITIAL_LENGTH_RAW=$(ao-cli eval "$RECEIVER_ID" --data "return #Inbox" --wait --json 2>/dev/null)
INITIAL_LENGTH=$(echo "$INITIAL_LENGTH_RAW" | jq -s '.[-1] | .data.result.Output.data' 2>/dev/null || echo "unknown")
echo "初始Inbox长度: $INITIAL_LENGTH"
echo ""

# 发送消息给接收者，会触发DebugTags handler
echo "正在发送消息..."
MESSAGE_RESULT=$(ao-cli message "$RECEIVER_ID" "DebugTags" \
  --data "test" \
  --tags "X-SagaId=saga-456" \
  --tags "X-ResponseAction=MyResponse" \
  --tags "X-NoResponseRequired=yes" \
  --wait --json 2>/dev/null)

echo "消息发送结果:"
if [ -n "$MESSAGE_RESULT" ]; then
    echo "$MESSAGE_RESULT" | jq '.' 2>/dev/null | head -100
else
    echo "（无JSON输出）"
fi
echo ""

# ==================== 步骤 7: 查看最后的Inbox消息 ====================
echo "=== 步骤 7: 查看最后接收的消息 ==="
FINAL_INBOX=$(ao-cli inbox "$RECEIVER_ID" --latest --json 2>/dev/null)

echo "最后的Inbox消息 (完整JSON):"
echo "$FINAL_INBOX" | jq -s '.[-1]' 2>/dev/null | head -150
echo ""

# 尝试提取data字段
echo "尝试从Messages中提取标签检查结果:"
MESSAGES=$(echo "$FINAL_INBOX" | jq -s '.[-1] | .data.inbox | fromjson? | .latest?.Data' 2>/dev/null)
if [ -n "$MESSAGES" ] && [ "$MESSAGES" != "null" ]; then
    echo "接收到的标签检查结果:"
    echo "$MESSAGES"
else
    echo "无法解析消息数据"
fi

echo ""
echo "=== 测试完成 ==="
echo ""
echo "📋 总结:"
echo "  - 发送者ID: $SENDER_ID"
echo "  - 接收者ID: $RECEIVER_ID"
echo "  - 测试内容: X-SagaId, X-ResponseAction, X-NoResponseRequired"
echo "  - 观察Inbox中的消息是否包含这些自定义标签"
echo ""
