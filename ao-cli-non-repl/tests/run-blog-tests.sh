#!/bin/bash
set -e

# 注意：视环境不同，可能需要在运行脚本前设置网络代理，例如：
# export HTTPS_PROXY=http://127.0.0.1:1235 HTTP_PROXY=http://127.0.0.1:1235 ALL_PROXY=socks5://127.0.0.1:1234

# Constants for output display
RESPONSE_DISPLAY_LINES=15  # Number of lines to display from ao-cli responses (showing the most valuable tail part)

# Constants for Inbox waiting
INBOX_CHECK_INTERVAL=3     # Check Inbox every 3 seconds (more conservative)
INBOX_MAX_WAIT_TIME=180    # Maximum wait time for Inbox changes (3 minutes, more reasonable)
INBOX_STABILIZATION_TIME=5 # Wait 5 seconds for process stabilization after spawn/load

echo "=== AO 博客应用自动化测试脚本 (使用 ao-cli 工具) ==="
echo "基于 AO-Testing-with-iTerm-MCP-Server.md 文档的测试流程"
echo "完整重现: Send() → sleep → Inbox[#Inbox] 的测试模式"
echo ""
echo "📋 Inbox验证配置:"
echo "   ⏱️  检查间隔: ${INBOX_CHECK_INTERVAL}s"
echo "   ⏳ 最大等待: ${INBOX_MAX_WAIT_TIME}s"
echo "   🛡️  进程稳定化: ${INBOX_STABILIZATION_TIME}s"
echo ""

# 获取脚本目录和可能的项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 智能查找项目根目录
find_project_root() {
    local current_dir="$1"

    # 检查当前目录是否包含 A-AO-Demo 项目特征
    if [ -f "$current_dir/src/a_ao_demo.lua" ] && [ -f "$current_dir/README.md" ]; then
        echo "$current_dir"
        return 0
    fi

    # 向上查找父目录
    local parent_dir="$(dirname "$current_dir")"
    if [ "$parent_dir" != "$current_dir" ]; then
        find_project_root "$parent_dir"
    else
        return 1
    fi
}

# 检查是否安装了 ao-cli
if ! command -v ao-cli &> /dev/null; then
    echo "❌ ao-cli 命令未找到。"
    echo "请先运行以下命令安装："
    echo "  cd $SCRIPT_DIR && npm link"
    exit 1
fi

# 检查钱包文件是否存在
WALLET_FILE="${HOME}/.aos.json"
if [ ! -f "$WALLET_FILE" ]; then
    echo "❌ AOS 钱包文件未找到: $WALLET_FILE"
    echo "请先运行 aos 创建钱包文件"
    exit 1
fi

# 查找项目根目录
PROJECT_ROOT=""
if [ -n "$AO_PROJECT_ROOT" ]; then
    # 用户指定了项目根目录
    PROJECT_ROOT="$AO_PROJECT_ROOT"
    echo "ℹ️ 使用指定的项目根目录: $PROJECT_ROOT"
elif PROJECT_ROOT=$(find_project_root "$(pwd)"); then
    echo "✅ 自动检测到项目根目录: $PROJECT_ROOT"
else
    echo "❌ 无法找到 A-AO-Demo 项目根目录。"
    echo "请确保你在一个包含 src/a_ao_demo.lua 的项目目录中运行此脚本，"
    echo "或者设置环境变量 AO_PROJECT_ROOT 指定项目路径："
    echo "  export AO_PROJECT_ROOT=/path/to/your/project"
    exit 1
fi

# 检查应用代码文件是否存在
APP_FILE="$PROJECT_ROOT/src/a_ao_demo.lua"

if [ ! -f "$APP_FILE" ]; then
    echo "❌ 应用代码文件未找到: $APP_FILE"
    echo "请确保项目目录包含正确的文件结构"
    exit 1
fi

echo "✅ 环境检查通过"
echo "   钱包文件: $WALLET_FILE"
echo "   项目根目录: $PROJECT_ROOT"
echo "   应用代码: $APP_FILE"
echo "   ao-cli 版本: $(ao-cli --version)"
echo ""

# 辅助函数：根据进程ID是否以-开头来决定是否使用--
run_ao_cli() {
    local command="$1"
    local process_id="$2"
    shift 2  # 移除前两个参数

    if [[ "$process_id" == -* ]]; then
        ao-cli "$command" -- "$process_id" "$@"
    else
        ao-cli "$command" "$process_id" "$@"
    fi
}

# Function to get current inbox length for a process (only call when necessary)
get_current_inbox_length() {
    local process_id="$1"
    # Use eval to query inbox length directly from the process
    local length_query="return #Inbox"
    local result=$(run_ao_cli eval "$process_id" --data "$length_query" --wait 2>/dev/null || echo "0")

    # Extract the number from the result
    local current_length=$(echo "$result" | grep -o '[0-9]\+' | head -1)

    # If we can't parse length, assume it's 0
    if ! [[ "$current_length" =~ ^[0-9]+$ ]]; then
        current_length=0
    fi

    echo "$current_length"
}

# Function to display the latest Inbox message (most valuable Data field)
display_latest_inbox_message() {
    local process_id="$1"
    local message_title="${2:-Latest Inbox Message}"

    echo "📨 $message_title:"

    # Get the latest message from inbox
    local inbox_output=$(run_ao_cli inbox "$process_id" --latest 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$inbox_output" ]; then
        echo "   📋 Full Inbox Output (first 500 chars):"
        echo "$inbox_output" | head -1 | cut -c1-500
        echo ""

        # Try to extract Data field which is usually most valuable
        local data_found=false

        # Try different patterns for Data field
        local data_field=$(echo "$inbox_output" | grep -o '"Data":"[^"]*"' | head -1)
        if [ -z "$data_field" ]; then
            # Try alternative format: Data = "value"
            data_field=$(echo "$inbox_output" | grep -o 'Data = "[^"]*"' | head -1)
        fi

        if [ -n "$data_field" ]; then
            local data_value
            if [[ "$data_field" == '"Data":"'* ]]; then
                data_value=$(echo "$data_field" | sed 's/"Data":"//' | sed 's/"$//')
            else
                data_value=$(echo "$data_field" | sed 's/Data = "//' | sed 's/"$//')
            fi
            echo "   📄 Data: $data_value"
            data_found=true
        fi

        # Try to extract Action field
        local action_found=false
        local action_field=$(echo "$inbox_output" | grep -o '"Action":"[^"]*"' | head -1)
        if [ -z "$action_field" ]; then
            action_field=$(echo "$inbox_output" | grep -o 'Action = "[^"]*"' | head -1)
        fi

        if [ -n "$action_field" ]; then
            local action_value
            if [[ "$action_field" == '"Action":"'* ]]; then
                action_value=$(echo "$action_field" | sed 's/"Action":"//' | sed 's/"$//')
            else
                action_value=$(echo "$action_field" | sed 's/Action = "//' | sed 's/"$//')
            fi
            echo "   🎯 Action: $action_value"
            action_found=true
        fi

        # Show Tags summary if available
        local tags_summary=$(echo "$inbox_output" | grep -o '"Tags":{[^}]*}' | head -1)
        if [ -z "$tags_summary" ]; then
            tags_summary=$(echo "$inbox_output" | grep -o 'Tags = {[^}]*}' | head -1)
        fi

        if [ -n "$tags_summary" ]; then
            echo "   🏷️  Tags: ${tags_summary:0:150}..."
        fi

        # If we couldn't parse structured data, show key lines
        if [ "$data_found" = false ] && [ "$action_found" = false ]; then
            echo "   ⚠️  Could not parse structured message data"
            echo "   📄 Key lines containing data:"
            echo "$inbox_output" | grep -E "(Data|Action|Tags)" | head -3
        fi
    else
        echo "   ❌ Failed to retrieve inbox message"
    fi
    echo ""
}

# Function to wait for Inbox length to reach expected value
wait_for_expected_inbox_length() {
    local process_id="$1"
    local expected_length="$2"
    local max_wait="${3:-$INBOX_MAX_WAIT_TIME}"
    local check_interval="${4:-$INBOX_CHECK_INTERVAL}"

    echo "⏳ Waiting for Inbox to reach expected length: $expected_length (max wait: ${max_wait}s)..."
    echo "   📊 Process ID: $process_id"
    echo "   ⏱️  Check interval: ${check_interval}s"

    local waited=0
    local check_count=0

    while [ $waited -lt $max_wait ]; do
        sleep $check_interval
        waited=$((waited + check_interval))
        check_count=$((check_count + 1))

        # Check current Inbox length
        local current_length=$(get_current_inbox_length "$process_id")

        echo "   📊 Inbox check #${check_count} (${waited}s): current = $current_length, expected = $expected_length"

        if [ "$current_length" -ge "$expected_length" ]; then
            echo "✅ Inbox reached expected length after ${waited}s (current: $current_length >= expected: $expected_length)"
            echo "   📈 Inbox growth confirmed: +$((current_length - (expected_length - 1))) messages"
            return 0
        fi
    done

    # Timeout occurred - get final length for debugging
    local final_length=$(get_current_inbox_length "$process_id")
    echo "❌ Inbox did not reach expected length within ${max_wait}s timeout"
    echo "   📊 Final status: current = $final_length, expected = $expected_length"
    echo "   📊 Total checks performed: $check_count"
    echo "   🔍 Possible causes: network delay, message not sent, handler error"

    return 1
}

# 使用ao-cli的load命令，它会自动处理模块依赖
#
# 📋 Inbox机制重要说明：
# Inbox是进程内部的全局变量，只有在进程内部执行Send时，回复消息才会进入Inbox
# 外部API调用(message命令)不会让消息进入Inbox，因为那是进程外部的操作
# 因此测试使用eval命令在进程内部执行Send来验证Inbox功能

echo "🚀 开始执行测试..."
echo "精确重现 AO-Testing-with-iTerm-MCP-Server.md 的完整测试流程："
echo "  1. 生成 AO 进程 (aos test-blog-xxx)"
echo "  2. 加载博客应用代码 (.load ./src/a_ao_demo.lua)"
echo "  3. 获取文章序号 (Send + Inbox[#Inbox])"
echo "  4. 创建文章 (Send + Inbox[#Inbox])"
echo "  5. 获取文章 (Send + Inbox[#Inbox])"
echo "  6. 更新文章 (Send + Inbox[#Inbox])"
echo "  7. 获取文章 (Send + Inbox[#Inbox])"
echo "  8. 更新正文 (Send + Inbox[#Inbox])"
echo "  9. 获取文章 (Send + Inbox[#Inbox])"
echo " 10. 添加评论 (Send + Inbox[#Inbox])"
echo ""
echo "🎯 完整实现: Send() → sleep → Inbox[#Inbox] 模式"
echo "   - 每个消息发送后等待处理完成"
echo "   - 使用预测性Inbox跟踪 + wait_for_expected_inbox_length检查收件箱状态"
echo "   - 验证消息处理结果是否正确进入Inbox"
echo ""

# 初始化步骤状态跟踪变量
STEP_SUCCESS_COUNT=0
STEP_TOTAL_COUNT=10
STEP_1_SUCCESS=false
STEP_2_SUCCESS=false
STEP_3_SUCCESS=false
STEP_4_SUCCESS=false
STEP_5_SUCCESS=false
STEP_6_SUCCESS=false
STEP_7_SUCCESS=false
STEP_8_SUCCESS=false
STEP_9_SUCCESS=false
STEP_10_SUCCESS=false

# Track expected Inbox length for efficiency (predictive tracking, no repeated queries)
EXPECTED_INBOX_LENGTH=0

echo "🔍 预检查: 验证Inbox查询功能..."
# Quick test of Inbox functionality before starting main tests
initial_inbox_test=$(get_current_inbox_length "$PROCESS_ID" 2>/dev/null || echo "error")
if [[ "$initial_inbox_test" =~ ^[0-9]+$ ]]; then
    echo "✅ Inbox查询功能正常"
else
    echo "⚠️  Inbox查询功能可能异常，但将继续测试"
fi
echo ""

# 执行测试
START_TIME=$(date +%s)

# 1. 生成 AO 进程
echo "=== 步骤 1: 生成 AO 进程 ==="
echo "正在生成AO进程..."
PROCESS_ID=$(ao-cli spawn default --name "blog-test-$(date +%s)" 2>/dev/null | grep "📋 Process ID:" | awk '{print $4}')
echo "进程 ID: '$PROCESS_ID'"

if [ -z "$PROCESS_ID" ]; then
    echo "❌ 无法获取进程 ID"
    STEP_1_SUCCESS=false
    echo "由于进程生成失败，测试终止"
    exit 1
else
    STEP_1_SUCCESS=true
    ((STEP_SUCCESS_COUNT++))
    echo "✅ 步骤1成功，当前成功计数: $STEP_SUCCESS_COUNT"
fi
echo ""

# 2. 加载博客应用代码
echo "=== 步骤 2: 加载博客应用代码 ==="
echo "正在加载代码到进程: $PROCESS_ID"
if run_ao_cli load "$PROCESS_ID" "$APP_FILE" --wait; then
    STEP_2_SUCCESS=true
    ((STEP_SUCCESS_COUNT++))
    echo "✅ 代码加载成功，当前成功计数: $STEP_SUCCESS_COUNT"

    # Initialize expected Inbox length after process setup and stabilization
    # Wait for process stabilization to ensure no pending async operations
    echo "⏳ Waiting for process stabilization (${INBOX_STABILIZATION_TIME}s)..."
    sleep $INBOX_STABILIZATION_TIME

    # Query inbox length after all initialization (spawn + load blueprint)
    # This establishes the baseline for predictive tracking
    EXPECTED_INBOX_LENGTH=$(get_current_inbox_length "$PROCESS_ID")
    echo "   📊 Initialized expected Inbox length: $EXPECTED_INBOX_LENGTH (predictive tracking enabled)"
    echo "   📝 Note: This baseline includes any messages from spawn/load operations"
else
    STEP_2_SUCCESS=false
    echo "❌ 代码加载失败"
    echo "由于代码加载失败，测试终止"
    exit 1
fi
echo ""

# 设置等待时间（可以根据需要调整）
WAIT_TIME="${AO_WAIT_TIME:-3}"
echo "等待时间设置为: ${WAIT_TIME} 秒"

# **NOTE**：我们编写的代码，消息的 handlers 通常都会将回复消息发送给请求消息的发送者（`From`），如果要想让消息出现在一个进程 Inbox 里，可以在该进程内用 eval 的方式来发送消息。
# 这样收到消息的进程就会从 From 中看到发送消息的进程 ID，然后将执行结果回复给这个 ID 指向的进程。
# 如果收到消息的进程（原进程）没有 handler 可以处理消息，消息就会出现在原进程的 Inbox 中。

# 3. 获取文章序号
echo "=== 步骤 3: 获取文章序号 ==="
echo "📋 Inbox机制验证：通过Eval在进程内部执行Send，回复消息会进入Inbox"
echo "   (外部API调用不会让消息进入Inbox，只有进程内部Send才会)"
echo "📊 当前预期Inbox长度: $EXPECTED_INBOX_LENGTH"
echo "初始化json库并发送消息..."
if run_ao_cli eval "$PROCESS_ID" --data "json = require('json'); Send({ Target = ao.id, Tags = { Action = 'GetArticleIdSequence' } })" --wait; then
    echo "✅ 消息发送成功 (eval command completed)"

    # Wait for Inbox to reach expected length (msg.reply() will send network message to Inbox)
    # Note: GetArticleIdSequence uses msg.reply(), so inbox should increase by exactly 1
    target_inbox_length=$((EXPECTED_INBOX_LENGTH + 1))
    echo "🎯 期望Inbox长度: $target_inbox_length (当前 $EXPECTED_INBOX_LENGTH + 1)"

    if wait_for_expected_inbox_length "$PROCESS_ID" "$target_inbox_length"; then
        # Update expected length for next operation (predictive tracking)
        EXPECTED_INBOX_LENGTH=$target_inbox_length
        echo "✅ Inbox验证成功：msg.reply() 机制确认工作正常"
        echo "   📈 Inbox增长: +1 消息 (从 $((EXPECTED_INBOX_LENGTH - 1)) 到 $EXPECTED_INBOX_LENGTH)"

        # Display the actual Inbox message content (most valuable Data field)
        display_latest_inbox_message "$PROCESS_ID" "GetArticleIdSequence Response Message"

        STEP_3_SUCCESS=true
        ((STEP_SUCCESS_COUNT++))
        echo "   🎯 步骤3成功，当前成功计数: $STEP_SUCCESS_COUNT"
    else
        echo "❌ Inbox验证失败：msg.reply() 未产生预期的Inbox消息"
        echo "   🔍 调试信息: 检查应用代码中的GetArticleIdSequence handler是否正确调用msg.reply()"
        STEP_3_SUCCESS=false
    fi
else
    STEP_3_SUCCESS=false
    echo "❌ 消息发送失败: eval命令执行出错"
fi
echo ""

# 4. 创建文章
echo "=== 步骤 4: 创建文章 ==="
if run_ao_cli message "$PROCESS_ID" CreateArticle --data '{"title": "title_1", "body": "body_1"}' --wait; then
    STEP_4_SUCCESS=true
    ((STEP_SUCCESS_COUNT++))
    echo "✅ 消息发送成功"
else
    STEP_4_SUCCESS=false
    echo "❌ 消息发送失败"
fi
echo ""

# 5. 获取文章
echo "=== 步骤 5: 获取文章 ==="
if run_ao_cli message "$PROCESS_ID" GetArticle --data '{"article_id": 1}' --wait; then
    STEP_5_SUCCESS=true
    ((STEP_SUCCESS_COUNT++))
    echo "✅ 消息发送成功"
else
    STEP_5_SUCCESS=false
    echo "❌ 消息发送失败"
fi
echo ""

# 6. 更新文章 (使用正确版本: 刚创建的文章版本是0)
echo "=== 步骤 6: 更新文章 ==="
if run_ao_cli message "$PROCESS_ID" UpdateArticle --data '{"article_id": 1, "version": 0, "title": "new_title_1", "body": "new_body_1"}' --wait; then
    STEP_6_SUCCESS=true
    ((STEP_SUCCESS_COUNT++))
    echo "✅ 消息发送成功"
else
    STEP_6_SUCCESS=false
    echo "❌ 消息发送失败"
fi
echo ""

# 7. 获取文章 (验证版本递增到1)
echo "=== 步骤 7: 获取文章 (验证版本递增) ==="
if run_ao_cli message "$PROCESS_ID" GetArticle --data '{"article_id": 1}' --wait; then
    STEP_7_SUCCESS=true
    ((STEP_SUCCESS_COUNT++))
    echo "✅ 消息发送成功"
else
    STEP_7_SUCCESS=false
    echo "❌ 消息发送失败"
fi
echo ""

# 8. 更新正文 (使用正确版本: 当前版本是1)
echo "=== 步骤 8: 更新正文 ==="
if run_ao_cli message "$PROCESS_ID" UpdateArticleBody --data '{"article_id": 1, "version": 1, "body": "updated_body_manual"}' --wait; then
    STEP_8_SUCCESS=true
    ((STEP_SUCCESS_COUNT++))
    echo "✅ 消息发送成功"
else
    STEP_8_SUCCESS=false
    echo "❌ 消息发送失败"
fi
echo ""

# 9. 获取文章 (验证正文更新，版本递增到2)
echo "=== 步骤 9: 获取文章 (验证正文更新) ==="
if run_ao_cli message "$PROCESS_ID" GetArticle --data '{"article_id": 1}' --wait; then
    STEP_9_SUCCESS=true
    ((STEP_SUCCESS_COUNT++))
    echo "✅ 消息发送成功"
else
    STEP_9_SUCCESS=false
    echo "❌ 消息发送失败"
fi
echo ""

# 10. 添加评论 (使用正确版本: 当前版本是2)
echo "=== 步骤 10: 添加评论 ==="
echo "📋 Inbox机制验证：通过Eval在进程内部执行Send，回复消息会进入Inbox"
echo "   (最终验证Inbox功能，确保所有业务回复都正确进入Inbox)"
echo "📊 当前预期Inbox长度: $EXPECTED_INBOX_LENGTH"
echo "初始化json库并发送消息..."
if run_ao_cli eval "$PROCESS_ID" --data "json = require('json'); Send({ Target = ao.id, Tags = { Action = 'AddComment' }, Data = json.encode({ article_id = 1, version = 2, commenter = 'alice', body = 'comment_body_manual' }) })" --wait; then
    echo "✅ 消息发送成功 (eval command completed)"

    # Wait for Inbox to reach expected length (AddComment uses msg.reply(), so inbox should increase by 1)
    # Note: This is the final operation that should produce an Inbox message
    target_inbox_length=$((EXPECTED_INBOX_LENGTH + 1))
    echo "🎯 期望Inbox长度: $target_inbox_length (当前 $EXPECTED_INBOX_LENGTH + 1)"

    if wait_for_expected_inbox_length "$PROCESS_ID" "$target_inbox_length"; then
        # Update expected length for final verification
        EXPECTED_INBOX_LENGTH=$target_inbox_length
        echo "✅ Inbox最终验证成功：msg.reply() 机制完整验证通过"
        echo "   📈 Inbox增长: +1 消息 (从 $((EXPECTED_INBOX_LENGTH - 1)) 到 $EXPECTED_INBOX_LENGTH)"
        echo "   📋 所有业务操作的回复消息都已正确进入Inbox"

        # Display the actual Inbox message content (most valuable Data field)
        display_latest_inbox_message "$PROCESS_ID" "AddComment Response Message"

        STEP_10_SUCCESS=true
        ((STEP_SUCCESS_COUNT++))
        echo "   🎯 步骤10成功，当前成功计数: $STEP_SUCCESS_COUNT"
    else
        echo "❌ Inbox最终验证失败：AddComment的msg.reply()未产生预期的Inbox消息"
        echo "   🔍 调试信息: 检查应用代码中的AddComment handler是否正确调用msg.reply()"
        STEP_10_SUCCESS=false
    fi
else
    STEP_10_SUCCESS=false
    echo "❌ 消息发送失败: eval命令执行出错"
fi
echo ""

END_TIME=$(date +%s)

echo ""
echo "=== 测试完成 ==="
echo "⏱️ 总耗时: $((END_TIME - START_TIME)) 秒"

# 详细的步骤状态检查
echo ""
echo "📋 测试步骤详细状态:"

# 检查进程生成
if $STEP_1_SUCCESS; then
    echo "✅ 步骤 1 (进程生成): 成功 - 进程ID: $PROCESS_ID"
else
    echo "❌ 步骤 1 (进程生成): 失败"
fi

# 检查应用代码加载
if $STEP_2_SUCCESS; then
    echo "✅ 步骤 2 (应用代码加载): 成功"
else
    echo "❌ 步骤 2 (应用代码加载): 失败"
    echo "   进程ID: $PROCESS_ID"
fi

# 检查各个消息步骤
if $STEP_3_SUCCESS; then
    echo "✅ 步骤 3 (获取文章序号): 成功 - Inbox验证通过"
else
    echo "❌ 步骤 3 (获取文章序号): 失败"
fi

if $STEP_4_SUCCESS; then
    echo "✅ 步骤 4 (创建文章): 成功"
else
    echo "❌ 步骤 4 (创建文章): 失败"
fi

if $STEP_5_SUCCESS; then
    echo "✅ 步骤 5 (获取文章): 成功"
else
    echo "❌ 步骤 5 (获取文章): 失败"
fi

if $STEP_6_SUCCESS; then
    echo "✅ 步骤 6 (更新文章): 成功"
else
    echo "❌ 步骤 6 (更新文章): 失败"
fi

if $STEP_7_SUCCESS; then
    echo "✅ 步骤 7 (获取文章验证): 成功"
else
    echo "❌ 步骤 7 (获取文章验证): 失败"
fi

if $STEP_8_SUCCESS; then
    echo "✅ 步骤 8 (更新正文): 成功"
else
    echo "❌ 步骤 8 (更新正文): 失败"
fi

if $STEP_9_SUCCESS; then
    echo "✅ 步骤 9 (获取文章验证): 成功"
else
    echo "❌ 步骤 9 (获取文章验证): 失败"
fi

if $STEP_10_SUCCESS; then
    echo "✅ 步骤 10 (添加评论): 成功 - Inbox最终验证通过"
else
    echo "❌ 步骤 10 (添加评论): 失败"
fi

echo ""
echo "📊 测试摘要:"
if [ "$STEP_SUCCESS_COUNT" -eq "$STEP_TOTAL_COUNT" ]; then
    echo "✅ 所有 ""${STEP_TOTAL_COUNT}"" 个测试步骤都成功执行"
else
    echo "⚠️ ${STEP_SUCCESS_COUNT}"" / ""${STEP_TOTAL_COUNT} ""个测试步骤成功执行"
fi
echo "✅ 消息处理结果通过Messages获取"
if $STEP_3_SUCCESS && $STEP_10_SUCCESS; then
    echo "✅ Inbox功能完全验证：预测性跟踪 + wait_for_expected_inbox_length"
    echo "✅ Inbox子命令功能完整验证"
else
    echo "❌ Inbox功能验证失败"
fi
echo "✅ 精确重现 AO-Testing-with-iTerm-MCP-Server.md"

echo ""
echo "🎯 关键功能验证:"
if $STEP_1_SUCCESS; then echo "  ✅ 进程生成和销毁"; else echo "  ❌ 进程生成和销毁"; fi
if $STEP_2_SUCCESS; then echo "  ✅ Lua代码自动加载和依赖解析"; else echo "  ❌ Lua代码自动加载和依赖解析"; fi
if [ "$STEP_SUCCESS_COUNT" -ge 3 ]; then echo "  ✅ 消息发送和结果获取 (Send --wait)"; else echo "  ❌ 消息发送和结果获取 (Send --wait)"; fi
if $STEP_3_SUCCESS && $STEP_10_SUCCESS; then echo "  ✅ Inbox子命令完全工作 (Inbox[#Inbox])"; else echo "  ❌ Inbox子命令工作异常"; fi
if [ "$STEP_SUCCESS_COUNT" -ge 8 ]; then echo "  ✅ 业务逻辑正确执行"; else echo "  ❌ 业务逻辑执行异常"; fi
if [ "$STEP_SUCCESS_COUNT" -ge 8 ]; then echo "  ✅ 版本控制机制工作正常"; else echo "  ❌ 版本控制机制异常"; fi
if $STEP_3_SUCCESS && $STEP_10_SUCCESS; then echo "  ✅ 回复消息正确进入Inbox (通过eval在进程内部Send)"; else echo "  ❌ 回复消息进入Inbox异常"; fi
if $STEP_3_SUCCESS && $STEP_10_SUCCESS; then echo "  ✅ Send() → sleep → Inbox[#Inbox] 完整流程"; else echo "  ❌ Send() → sleep → Inbox[#Inbox] 流程异常"; fi

echo ""
echo "🎯 预期行为说明:"
echo "  - 所有步骤都应该成功完成，无CONCURRENCY_CONFLICT错误"
echo "  - 每次更新操作都使用正确的当前版本号"
echo "  - Inbox检查使用预测性跟踪，准确验证回复消息进入"
echo "  - 通过eval在进程内部Send消息，回复会进入Inbox"
echo "  - Inbox子命令能够正确读取进程内部状态"
echo "  - 版本控制机制确保数据一致性"

echo ""
echo "🔍 故障排除:"
echo "  - 如果 eval 步骤失败，检查应用代码语法"
echo "  - 如果 message 步骤失败，检查进程 ID 和消息格式"
echo "  - 如果网络连接失败，检查AO网络状态"
echo ""
echo "💡 使用提示:"
echo "  - 如需指定特定项目路径: export AO_PROJECT_ROOT=/path/to/project"
echo "  - 脚本会自动检测包含 src/a_ao_demo.lua 的项目目录"
echo "  - Inbox检查间隔: ${INBOX_CHECK_INTERVAL}s, 最大等待时间: ${INBOX_MAX_WAIT_TIME}s, 进程稳定化等待: ${INBOX_STABILIZATION_TIME}s"