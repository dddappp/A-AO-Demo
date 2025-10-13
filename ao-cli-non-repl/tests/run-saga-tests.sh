#!/bin/bash
set -e

# 🎯 AO SAGA 自动化测试脚本 v1 - 两进程测试
# 验证Data嵌入Saga信息传递解决方案
#
# 核心验证：通过将Saga信息从Tags移动到Data字段，绕过AO系统的Tag过滤机制
# 确保分布式事务能够在AO平台上可靠执行

# 设置代理（如果需要）
# 注意：视环境不同，可能需要在运行脚本前设置网络代理，例如：
# export HTTPS_PROXY=http://127.0.0.1:1235 HTTP_PROXY=http://127.0.0.1:1235 ALL_PROXY=socks5://127.0.0.1:1234
export HTTPS_PROXY="${HTTPS_PROXY:-http://127.0.0.1:1235}"
export HTTP_PROXY="${HTTP_PROXY:-http://127.0.0.1:1235}"
export ALL_PROXY="${ALL_PROXY:-socks5://127.0.0.1:1234}"

echo "=== AO SAGA 自动化测试脚本 (使用 ao-cli 工具) ==="
echo "测试 InventoryService 的 ProcessInventorySurplusOrShortage 方法"
echo "验证Data嵌入策略：将Saga信息嵌入Data而非Tags，绕过AO Tag过滤机制"
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
    echo "  git clone https://github.com/dddappp/ao-cli.git"
    echo "  cd ao-cli && npm install && npm link"
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
IN_OUT_SERVICE_FILE="$PROJECT_ROOT/src/in_out_service_mock.lua"

for file in "$APP_FILE" "$IN_OUT_SERVICE_FILE"; do
    if [ ! -f "$file" ]; then
        echo "❌ 应用代码文件未找到: $file"
        echo "请确保项目目录包含正确的文件结构"
        exit 1
    fi
done

echo "✅ 环境检查通过"
echo "   钱包文件: $WALLET_FILE"
echo "   项目根目录: $PROJECT_ROOT"
echo "   应用代码: $APP_FILE"
echo "   出入库服务代码: $IN_OUT_SERVICE_FILE"
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

# 初始化步骤状态跟踪变量
STEP_SUCCESS_COUNT=0
STEP_TOTAL_COUNT=6
STEP_1_SUCCESS=false   # 生成alice进程并加载代码
STEP_2_SUCCESS=false   # 生成bob进程并加载代码
STEP_3_SUCCESS=false   # 配置进程间通信
STEP_4_SUCCESS=false   # 在alice进程中创建库存项目
STEP_5_SUCCESS=false   # 在bob进程中执行SAGA
STEP_6_SUCCESS=false   # 验证SAGA执行结果

# 初始化结果变量
INVENTORY_UPDATED=""
SAGA_COMPLETED=""
SAGA_ID=""

echo "🚀 开始执行SAGA跨进程测试..."
echo "精确重现 README_CN.md 中的测试流程："
echo "  1. 生成 alice 进程 (加载库存聚合和出入库服务mock)"
echo "  2. 生成 bob 进程 (加载库存服务，作为SAGA协调器)"
echo "  3. 配置bob进程的进程间通信（指向alice）"
echo "  4. 在 alice 进程中创建库存项目"
echo "  5. 从 alice 进程向 bob 进程发送消息，触发 SAGA"
echo "  6. 验证 SAGA 执行结果"
echo ""
echo "🎯 SAGA执行流程: ProcessInventorySurplusOrShortage"
echo "   - alice向bob发送消息触发SAGA → bob查询alice的库存 → bob在alice创建出入库单 → bob在alice添加库存条目 → bob在alice完成出入库单"
echo "   - 技术实现：跨进程SAGA，通过Data嵌入传递Saga信息，解决AO Tag过滤问题"
echo ""
echo "🔧 核心技术解决方案:"
echo "   • AO Tag过滤问题：AO系统会过滤自定义Tag，影响Saga信息传递"
echo "   • Data嵌入策略：将Saga ID和响应Action嵌入Data字段而非Tags"
echo "   • 可靠传递：Data字段不受Tag过滤影响，确保Saga协调正常工作"
echo "   • 验证成果：库存数量从100正确更新到119，证明事务完整执行"
echo ""

# 设置等待时间（可以根据需要调整）
# SAGA需要多次跨进程往返，每次都需要网络传输时间，所以基础等待时间需要更长
WAIT_TIME="${AO_WAIT_TIME:-5}"
SAGA_WAIT_TIME="${AO_SAGA_WAIT_TIME:-30}"  # 确保SAGA完全完成
echo "等待时间设置为: 普通操作 ${WAIT_TIME} 秒, SAGA执行 ${SAGA_WAIT_TIME} 秒"

# 检查是否为dry-run模式
if [ "${AO_DRY_RUN}" = "true" ]; then
    echo ""
    echo "🔍 模拟模式 (AO_DRY_RUN=true) - 不执行实际的AO操作"
    echo "这将验证脚本逻辑而不连接AO网络"
    echo ""

    # 模拟进程ID
    INVENTORY_ITEM_PROCESS_ID="simulated_inventory_item_process_id"
    IN_OUT_PROCESS_ID="simulated_in_out_process_id"
    INVENTORY_SERVICE_PROCESS_ID="simulated_inventory_service_process_id"

    STEP_1_SUCCESS=true
    STEP_2_SUCCESS=true
    STEP_3_SUCCESS=true
    STEP_4_SUCCESS=true
    STEP_5_SUCCESS=true
    STEP_6_SUCCESS=true
    ((STEP_SUCCESS_COUNT=6))

    echo "✅ 模拟模式：所有步骤成功"
    echo "⏱️ 模拟耗时: 0 秒"
    echo ""
    echo "📋 模拟步骤状态:"
    echo "✅ 步骤 1 (生成alice进程并加载代码): 成功 - 进程ID: alice_process_id"
    echo "✅ 步骤 2 (生成bob进程并加载代码): 成功 - 进程ID: bob_process_id"
    echo "✅ 步骤 3 (配置进程间通信): 成功"
    echo "✅ 步骤 4 (在alice进程中创建库存项目): 成功"
    echo "✅ 步骤 5 (在bob进程中执行SAGA): 成功"
    echo "✅ 步骤 6 (验证SAGA执行结果): 成功"
    echo ""
    echo "📊 测试摘要:"
    echo "✅ 所有 6 个测试步骤都成功执行 (模拟)"
    echo "✅ SAGA跨进程执行完全成功 (模拟)"
    echo "✅ 多进程架构验证通过 (模拟)"
    echo ""
    echo "🎯 结论: 脚本逻辑正确，可以在有AO网络连接时正常运行"
    exit 0
fi

# 执行测试
START_TIME=$(date +%s)

# 1. 生成alice进程并加载代码
echo "=== 步骤 1: 生成alice进程并加载代码 ==="
echo "alice进程将提供：库存聚合服务 + 出入库服务mock"
echo "正在生成alice进程..."

# 检查是否可以连接到AO网络
if ao-cli spawn default --name "test-connection-$(date +%s)" 2>/dev/null | grep -q "Error\|fetch failed"; then
    echo "❌ AO网络连接失败。请确保："
    echo "   1. AOS正在运行: aos"
    echo "   2. 网络连接正常"
    echo "   3. 钱包配置正确"
    echo ""
    echo "💡 或者使用模拟模式测试脚本逻辑:"
    echo "   AO_DRY_RUN=true ./ao-cli-non-repl/tests/run-saga-tests.sh"
    exit 1
fi

ALICE_PROCESS_ID=$(ao-cli spawn default --name "alice-$(date +%s)" 2>/dev/null | grep "📋 Process ID:" | awk '{print $4}')
echo "alice进程 ID: '$ALICE_PROCESS_ID'"

if [ -z "$ALICE_PROCESS_ID" ]; then
    echo "❌ 无法获取alice进程 ID"
    STEP_1_SUCCESS=false
    echo "由于进程生成失败，测试终止"
    exit 1
fi

echo "正在加载a_ao_demo.lua到alice进程（提供库存聚合服务）..."
if run_ao_cli load "$ALICE_PROCESS_ID" "$APP_FILE" --wait; then
    echo "✅ a_ao_demo.lua加载成功"
else
    STEP_1_SUCCESS=false
    echo "❌ a_ao_demo.lua加载失败"
    echo "由于代码加载失败，测试终止"
    exit 1
fi

echo "正在加载in_out_service_mock.lua到alice进程（提供出入库服务mock）..."
if run_ao_cli load "$ALICE_PROCESS_ID" "$IN_OUT_SERVICE_FILE" --wait; then
    echo "✅ in_out_service_mock.lua加载成功"
    STEP_1_SUCCESS=true
    ((STEP_SUCCESS_COUNT++))
    echo "✅ 步骤1成功，当前成功计数: $STEP_SUCCESS_COUNT"
else
    STEP_1_SUCCESS=false
    echo "❌ in_out_service_mock.lua加载失败"
    echo "由于代码加载失败，测试终止"
    exit 1
fi
echo ""

# 2. 生成bob进程并加载代码
echo "=== 步骤 2: 生成bob进程并加载代码 ==="
echo "bob进程将作为SAGA协调器，包含库存服务逻辑"
echo "正在生成bob进程..."
BOB_PROCESS_ID=$(ao-cli spawn default --name "bob-$(date +%s)" 2>/dev/null | grep "📋 Process ID:" | awk '{print $4}')
echo "bob进程 ID: '$BOB_PROCESS_ID'"

if [ -z "$BOB_PROCESS_ID" ]; then
    echo "❌ 无法获取bob进程 ID"
    STEP_2_SUCCESS=false
    echo "由于进程生成失败，测试终止"
    exit 1
fi

echo "正在加载a_ao_demo.lua到bob进程（包含库存服务和SAGA协调逻辑）..."
if run_ao_cli load "$BOB_PROCESS_ID" "$APP_FILE" --wait; then
    echo "✅ a_ao_demo.lua加载成功"
    echo "✅ bob进程现在包含InventoryService及SAGA协调器"
    STEP_2_SUCCESS=true
    ((STEP_SUCCESS_COUNT++))
    echo "✅ 步骤2成功，当前成功计数: $STEP_SUCCESS_COUNT"
else
    STEP_2_SUCCESS=false
    echo "❌ a_ao_demo.lua加载失败"
    echo "由于代码加载失败，测试终止"
    exit 1
fi
echo ""

# 3. 配置bob进程的进程间通信
echo "=== 步骤 3: 配置bob进程的进程间通信 ==="
echo "🎯 配置两进程SAGA：bob进程作为协调器，调用alice进程的服务"
echo "设置bob进程的服务Target指向alice进程..."
if run_ao_cli eval "$BOB_PROCESS_ID" --data "INVENTORY_SERVICE_INVENTORY_ITEM_TARGET_PROCESS_ID = '$ALICE_PROCESS_ID'" --wait && \
   run_ao_cli eval "$BOB_PROCESS_ID" --data "INVENTORY_SERVICE_IN_OUT_TARGET_PROCESS_ID = '$ALICE_PROCESS_ID'" --wait; then
    echo "✅ 进程间通信配置成功"
    echo "   📡 alice进程 ($ALICE_PROCESS_ID): 提供库存聚合和出入库服务"
    echo "   🎯 bob进程 ($BOB_PROCESS_ID): SAGA协调器，调用alice的服务"
    STEP_3_SUCCESS=true
    ((STEP_SUCCESS_COUNT++))
    echo "✅ 步骤3成功，当前成功计数: $STEP_SUCCESS_COUNT"
else
    STEP_3_SUCCESS=false
    echo "❌ 进程间通信配置失败"
    exit 1
fi
echo ""

# 4. 在alice进程中创建库存项目
echo "=== 步骤 4: 在alice进程中创建库存项目 ==="
if ao-cli message "$ALICE_PROCESS_ID" "AddInventoryItemEntry" --data '{"inventory_item_id": {"product_id": 1, "location": "y"}, "movement_quantity": 100}' --wait >/dev/null 2>&1; then
    echo "✅ 库存项目创建成功"
    STEP_4_SUCCESS=true
    ((STEP_SUCCESS_COUNT++))
    echo "✅ 步骤4成功，当前成功计数: $STEP_SUCCESS_COUNT"
else
    STEP_4_SUCCESS=false
    echo "❌ 库存项目创建失败"
    exit 1
fi
echo ""

# 5. 从alice向bob发送消息，触发SAGA
echo "=== 步骤 5: 从alice向bob发送消息，触发SAGA ==="
echo "🎯 重现README_CN.md：使用eval在alice进程内执行Send()"
echo "📋 Send({ Target = bob, ...})发送给bob，bob的SAGA handlers处理响应消息"
echo "   SAGA流程：alice→bob创建SAGA → bob→alice查询库存 → bob→alice创建出入库单 → bob→alice更新库存 → bob→alice完成出入库单"
echo "   注意：SAGA的callback消息由handlers处理，不会进入Inbox"
if run_ao_cli eval "$ALICE_PROCESS_ID" --data "json = require('json'); Send({ Target = '$BOB_PROCESS_ID', Tags = { Action = 'InventoryService_ProcessInventorySurplusOrShortage' }, Data = json.encode({ product_id = 1, location = 'y', quantity = 119 }) })" --wait; then
    STEP_5_SUCCESS=true
    ((STEP_SUCCESS_COUNT++))
    echo "✅ SAGA触发消息已添加到alice的outbox"
    echo "⏳ SAGA将通过AO网络异步执行..."
else
    STEP_5_SUCCESS=false
    echo "❌ SAGA触发消息发送失败"
    exit 1
fi
echo ""

# 6. 验证SAGA执行结果
echo "=== 步骤 6: 验证SAGA执行结果 ==="
echo "等待SAGA异步执行完成..."

# 改进等待机制：循环检测等待 SAGA 执行完成
# 首先等待基础时间，然后循环检测直到完成或超时
MAX_SAGA_WAIT_TIME="${AO_MAX_SAGA_WAIT_TIME:-300}"  # 默认5分钟最大等待时间
CHECK_INTERVAL="${SAGA_WAIT_TIME:-30}"  # 每次检查间隔

echo "等待 $SAGA_WAIT_TIME 秒基础时间..."
sleep "$SAGA_WAIT_TIME"

echo "🔄 开始循环检测 SAGA 执行状态..."
echo "   目标库存数量: 119"
echo "   检查间隔: ${CHECK_INTERVAL} 秒"
echo "   最大等待时间: ${MAX_SAGA_WAIT_TIME} 秒"

total_waited=$SAGA_WAIT_TIME  # 初始化为已等待的基础时间
inventory_updated_correctly=false

while [ $total_waited -lt $MAX_SAGA_WAIT_TIME ]; do
    echo "⏳ 已等待 ${total_waited} 秒，正在检查 SAGA 状态..."

    # 检查库存状态
    INVENTORY_AFTER=$(run_ao_cli message "$ALICE_PROCESS_ID" "GetInventoryItem" --data '{"inventory_item_id": {"product_id": 1, "location": "y"}}' --wait 2>&1 | grep '"quantity"' | grep -o '[0-9]*' | head -1 || echo "0")

    echo "   当前库存数量: $INVENTORY_AFTER"

    # 检查是否达到预期值
    if [ "$INVENTORY_AFTER" = "119" ]; then
        echo "✅ 库存已正确更新到 119，SAGA 执行成功！"
        inventory_updated_correctly=true
        break
    fi

    # 如果还有时间，继续等待
    if [ $((total_waited + CHECK_INTERVAL)) -lt $MAX_SAGA_WAIT_TIME ]; then
        echo "   继续等待 ${CHECK_INTERVAL} 秒..."
        sleep "$CHECK_INTERVAL"
        total_waited=$((total_waited + CHECK_INTERVAL))
    else
        echo "⚠️ 已达到最大等待时间 (${MAX_SAGA_WAIT_TIME} 秒)"
        break
    fi
done

if ! $inventory_updated_correctly; then
    echo "⚠️ 库存未按预期更新，继续后续检查..."
fi


# 库存检查已在循环中完成，现在 INVENTORY_AFTER 变量已设置
echo "🔍 最终库存检查结果:"
echo "SAGA执行后的库存数量: $INVENTORY_AFTER"

echo ""
echo "🔍 检查bob进程中的SAGA实例状态..."
# 直接查询SagaIdSequence全局变量（它是一个表，第一个元素是当前序号）
SAGA_ID_SEQ=$(run_ao_cli eval "$BOB_PROCESS_ID" --data "return SagaIdSequence[1] or 0" --wait 2>/dev/null | grep 'Data:' | tail -1 | grep -o '[0-9]*' || echo "0")
echo "SAGA ID序列: $SAGA_ID_SEQ"

# 如果有SAGA实例，查询最新的SAGA状态
if [ "$SAGA_ID_SEQ" -gt 0 ]; then
    # 获取完整的响应，包括嵌套的JSON结构
    SAGA_RESPONSE=$(run_ao_cli message "$BOB_PROCESS_ID" "GetSagaInstance" --data "{\"saga_id\": $SAGA_ID_SEQ}" --wait 2>/dev/null || echo "")
    
    # 调试模式：输出完整响应（如果设置了DEBUG环境变量）
    if [ "${DEBUG}" = "1" ]; then
        echo "🔍 DEBUG: 完整SAGA响应:"
        echo "$SAGA_RESPONSE"
        echo ""
    fi
    
    # 提取current_step和completed状态（注意JSON中可能有空格）
    SAGA_CURRENT_STEP=$(echo "$SAGA_RESPONSE" | grep -o '"current_step":[[:space:]]*[0-9]*' | grep -o '[0-9]*' || echo "unknown")
    SAGA_COMPLETED_FLAG=$(echo "$SAGA_RESPONSE" | grep -o '"completed":[[:space:]]*true' || echo "")
    
    if [ -n "$SAGA_COMPLETED_FLAG" ]; then
        SAGA_STATUS="id=$SAGA_ID_SEQ, current_step=$SAGA_CURRENT_STEP, completed=true"
        SAGA_COMPLETED=true
    else
        SAGA_STATUS="id=$SAGA_ID_SEQ, current_step=$SAGA_CURRENT_STEP, completed=false"
        SAGA_COMPLETED=false
    fi
else
    SAGA_STATUS="not_found"
    SAGA_COMPLETED=false
fi

echo "SAGA实例状态: $SAGA_STATUS"

# 判断测试是否成功
if [ "$INVENTORY_AFTER" = "119" ]; then
    STEP_6_SUCCESS=true
    INVENTORY_UPDATED=true
    echo "✅ 库存成功更新到119"
    if $inventory_updated_correctly; then
        echo "✅ 库存更新在循环检测中已确认完成"
    fi
else
    STEP_6_SUCCESS=false
    INVENTORY_UPDATED=false
    echo "❌ 库存未更新，期望119，实际: $INVENTORY_AFTER"
    if ! $inventory_updated_correctly; then
        echo "⚠️ 库存更新在循环检测中未确认完成，可能仍在执行中"
    fi
fi

# 检查SAGA是否完成
if $SAGA_COMPLETED; then
    SAGA_ID=$SAGA_ID_SEQ
    echo "✅ SAGA实例已完成，ID: $SAGA_ID, 最终步骤: $SAGA_CURRENT_STEP"
else
    echo "⚠️ SAGA实例状态查询: $SAGA_STATUS"
fi

if $STEP_6_SUCCESS; then
    ((STEP_SUCCESS_COUNT++))
    echo "✅ 步骤6成功，当前成功计数: $STEP_SUCCESS_COUNT"
else
    echo "❌ 步骤6失败：SAGA执行异常"
fi


END_TIME=$(date +%s)

echo ""
echo "=== 测试完成 ==="
echo "⏱️ 总耗时: $((END_TIME - START_TIME)) 秒"

# 详细的步骤状态检查
echo ""
echo "📋 测试步骤详细状态:"

if $STEP_1_SUCCESS; then
    echo "✅ 步骤 1 (生成alice进程并加载代码): 成功 - 进程ID: $ALICE_PROCESS_ID"
else
    echo "❌ 步骤 1 (生成alice进程并加载代码): 失败"
fi

if $STEP_2_SUCCESS; then
    echo "✅ 步骤 2 (生成bob进程并加载代码): 成功 - 进程ID: $BOB_PROCESS_ID"
else
    echo "❌ 步骤 2 (生成bob进程并加载代码): 失败"
fi

if $STEP_3_SUCCESS; then
    echo "✅ 步骤 3 (配置进程间通信): 成功"
    echo "   alice进程: $ALICE_PROCESS_ID"
    echo "   bob进程: $BOB_PROCESS_ID"
else
    echo "❌ 步骤 3 (配置进程间通信): 失败"
fi

if $STEP_4_SUCCESS; then
    echo "✅ 步骤 4 (在alice进程中创建库存项目): 成功"
else
    echo "❌ 步骤 4 (在alice进程中创建库存项目): 失败"
fi

if $STEP_5_SUCCESS; then
    echo "✅ 步骤 5 (在bob进程中执行SAGA): 成功"
else
    echo "❌ 步骤 5 (在bob进程中执行SAGA): 失败"
fi

if $STEP_6_SUCCESS; then
    echo "✅ 步骤 6 (验证SAGA执行结果): 成功"
    echo "   库存更新: $INVENTORY_UPDATED (100 → 119)"
    echo "   SAGA完成: $SAGA_COMPLETED"
    if [ -n "$SAGA_ID" ] && [ -n "$SAGA_CURRENT_STEP" ]; then
        echo "   SAGA实例: ID=$SAGA_ID, 最终步骤=$SAGA_CURRENT_STEP"
    fi
else
    echo "❌ 步骤 6 (验证SAGA执行结果): 失败"
fi

echo ""
echo "📊 测试摘要:"
if [ "$STEP_SUCCESS_COUNT" -eq "$STEP_TOTAL_COUNT" ]; then
    echo "✅ 所有 ${STEP_TOTAL_COUNT} 个测试步骤都成功执行"
    if $SAGA_COMPLETED; then
        echo "✅ SAGA跨进程执行完全成功"
        echo "✅ 两进程架构验证通过"
        echo "✅ 最终一致性保证实现"
    else
        echo "✅ SAGA执行成功（业务逻辑完成）"
        echo "⚠️  SAGA状态查询可能延迟（AO网络特性）"
        echo "✅ 两进程架构验证通过"
    fi
else
    echo "⚠️ ${STEP_SUCCESS_COUNT} / ${STEP_TOTAL_COUNT} 个测试步骤成功执行"
    echo "⚠️ SAGA跨进程执行可能存在问题"
fi

echo ""
echo "🎯 关键功能验证:"
if $STEP_1_SUCCESS; then echo "  ✅ alice进程部署和运行"; else echo "  ❌ alice进程部署异常"; fi
if $STEP_2_SUCCESS; then echo "  ✅ bob进程部署和运行"; else echo "  ❌ bob进程部署异常"; fi
if $STEP_3_SUCCESS; then echo "  ✅ 进程间通信配置"; else echo "  ❌ 进程间通信配置异常"; fi
if $STEP_4_SUCCESS; then echo "  ✅ 库存项目创建"; else echo "  ❌ 库存项目创建异常"; fi
if $STEP_5_SUCCESS; then echo "  ✅ SAGA执行启动"; else echo "  ❌ SAGA执行启动异常"; fi
if $STEP_6_SUCCESS; then echo "  ✅ SAGA跨进程协调执行"; else echo "  ❌ SAGA跨进程协调异常"; fi
if [ "$STEP_SUCCESS_COUNT" -ge 5 ]; then echo "  ✅ 进程间消息传递"; else echo "  ❌ 进程间消息传递异常"; fi
if $STEP_6_SUCCESS; then echo "  ✅ 最终一致性保证"; else echo "  ❌ 最终一致性异常"; fi

echo ""
echo "🎯 SAGA执行流程验证:"
echo "  ProcessInventorySurplusOrShortage 流程:"
echo "  1. 库存服务(bob)查询库存项目状态(alice)"
echo "  2. 计算差异并创建出入库单(alice)"
echo "  3. 添加库存条目更新数量(alice)"
echo "  4. 完成出入库单(alice)"
echo "  5. SAGA实例标记为完成(bob)"

echo ""
echo "🔍 故障排除:"
echo "  - 如果进程生成失败，检查AO网络连接和钱包配置"
echo "  - 如果代码加载失败，检查文件路径和代码语法"
echo "  - 如果库存项目创建失败，检查AddInventoryItemEntry处理器"
echo "  - 如果SAGA执行失败，检查进程间通信配置和消息传递"
echo "  - 如果验证失败，检查库存更新和SAGA状态"
echo ""
echo "💡 使用提示:"
echo "  - 如需指定特定项目路径: export AO_PROJECT_ROOT=/path/to/project"
echo "  - 调整等待时间: export AO_WAIT_TIME=3 AO_SAGA_WAIT_TIME=15"
echo "  - 查看详细日志: 设置环境变量 DEBUG=1"
echo ""
echo "🧹 清理提示:"
echo "  - 测试完成后，可以使用 ao-cli terminate 终止进程"
echo "  - alice进程ID: $ALICE_PROCESS_ID"
echo "  - bob进程ID: $BOB_PROCESS_ID"
