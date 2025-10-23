# AO CLI 非REPL模式

> **⚠️ 重要更新**: AO CLI 工具已迁移到独立的代码库！
>
> **新地址**: https://github.com/dddappp/ao-cli
> **npm包**: `@dddappp/ao-cli`

## 📦 迁移状态

AO CLI 工具已完全迁移到独立代码库，包含：

- ✅ **自包含测试套件**: 独立的测试应用，不依赖外部项目
- ✅ **完整命令支持**: spawn, eval, load, message, inbox 所有命令
- ✅ **npm发布就绪**: 可作为独立包发布和安装
- ✅ **文档完善**: 独立的使用文档和API说明

## 🏠 此目录内容

此目录保留了 A-AO-Demo 项目的完整测试套件，包括博客应用测试和 SAGA 跨进程测试：

### 文件结构
```
ao-cli-non-repl/
├── README.md           # 此文档 - 项目测试概览和完整使用指南
└── tests/
    ├── run-blog-tests.sh           # 博客应用自动化测试脚本
    ├── run-saga-tests.sh           # SAGA跨进程自动化测试脚本 ⭐
    ├── run-legacy-token-tests.sh   # Legacy Token蓝图功能测试脚本
    ├── ao-legacy-token-blueprint.lua    # Legacy网络兼容的Token蓝图
    ├── ao-official-token-blueprint.lua  # AO官方标准Token蓝图
    └── process_alice_1008.txt      # 测试过程数据记录
```

### 测试套件功能

#### 博客应用测试 (`run-blog-tests.sh`)
验证博客应用的核心功能：
- 文章的创建、读取、更新操作
- 评论系统功能
- 版本控制和乐观锁机制
- Inbox 消息处理机制

> **NOTE**:
> 按照当前博客应用的代码，"方法"总是向消息的发动者（`From`）回复消息，如果要想让包含执行结果的消息出现在一个进程 Inbox 里，可以在该进程内用 eval 的方式来发送消息。
> 这样收到消息的进程就会从 From 中看到发送消息的进程 ID，然后将执行结果回复给这个 ID 指向的进程。
> 如果收到消息的进程（原进程）没有 handler 可以处理消息，消息就会出现在原进程的 Inbox 中。

**测试流程**:
1. 生成 AO 进程并加载博客应用代码
2. 执行文章和评论的 CRUD 操作
3. 验证版本控制和并发安全
4. 检查 Inbox 消息处理

#### SAGA 跨进程测试 (`run-saga-tests.sh`) ⭐
验证分布式事务处理能力：
- 多进程架构下的消息协调
- SAGA 模式的事务管理
- 跨进程的状态一致性
- 错误处理和补偿机制

**🎯 技术亮点**: 该脚本验证了我们对AO平台Tag过滤问题的解决方案。通过将Saga信息嵌入Data字段而非Tags，确保了分布式事务的可靠执行。

**关键技术突破**:
- **Data嵌入策略**：将Saga信息从Tags移到Data，绕过AO Tag过滤
- **请求vs响应区分**：请求消息嵌入`saga_id`+`response_action`，响应消息只嵌入`saga_id`
- **混合使用Tag和Data**：Action用Tag（不被过滤），Saga协调信息用Data
- **验证成果**：SAGA完全成功，库存从100更新到119

**测试流程**:
1. 生成 Alice 和 Bob 两个独立进程
2. 配置进程间通信目标（Bob调用Alice的服务）
3. 执行库存调整的 SAGA 事务（Data嵌入Saga信息传递）
4. 验证事务完成和数据一致性（库存数量正确更新）


#### Legacy Token 蓝图测试 (`run-legacy-token-tests.sh`)
测试基于官方Token Blueprint的legacy网络兼容版本，包含7个核心API：
- Info, Balance, Balances, Transfer, Mint, Total-Supply
- 验证bint大整数库的精确计算功能
- 测试Debit-Notice/Credit-Notice通知系统
- 验证legacy网络兼容性和Inbox机制
- 提供详细的测试报告和功能验证

**踩坑经验总结**:
- eval + Send跨进程通信确实工作，From='Unknown'不影响消息传递
- Inbox相对变化检测比绝对长度预测更可靠
- AO网络延迟大，跨进程响应可能需要10-30秒
- ao-cli inbox会影响Inbox长度，不能用于长度查询
- 合约进程可以成功查询其他合约，无需外部客户端

## 🚀 使用说明

### 获取独立的 AO CLI 工具

要使用 AO CLI 工具，请访问新的独立代码库：

```bash
# 克隆独立代码库
git clone https://github.com/dddappp/ao-cli.git
cd ao-cli

# 安装和设置
npm install
npm link

# 验证安装
ao-cli --version
```

### 在 A-AO-Demo 项目中运行测试

此目录的测试套件专门用于验证 A-AO-Demo 项目的完整功能：

```bash
# 博客应用测试 - 验证基础功能和Inbox机制
./ao-cli-non-repl/tests/run-blog-tests.sh

# SAGA跨进程测试 - 验证分布式事务 ⭐
./ao-cli-non-repl/tests/run-saga-tests.sh

# Legacy Token蓝图测试 - 验证token功能和Inbox机制
./ao-cli-non-repl/tests/run-legacy-token-tests.sh

# 带自定义参数的测试
AO_WAIT_TIME=5 AO_SAGA_WAIT_TIME=15 ./ao-cli-non-repl/tests/run-saga-tests.sh

# 模拟运行（验证脚本逻辑）
AO_DRY_RUN=true ./ao-cli-non-repl/tests/run-saga-tests.sh
```

#### 环境准备

运行测试前请确保：
- 安装了 AO CLI 工具（见上文）
- A-AO-Demo 项目代码完整
- aos 进程正在运行
- 网络代理（如需要，详见脚本注释）

#### 测试覆盖

- ✅ **进程管理**: 自动生成、配置、清理 AO 进程
- ✅ **代码加载**: 动态加载和验证 Lua 代码
- ✅ **消息传递**: 进程内和跨进程消息传递
- ✅ **Inbox机制**: Send() → sleep → Inbox[#Inbox] 完整流程验证
- ✅ **业务逻辑**: 博客应用、库存管理和Token功能
- ✅ **分布式事务**: SAGA 模式和最终一致性保证
- ✅ **错误处理**: 超时、重试和故障恢复机制
- ✅ **跨进程通信**: 合约间的直接查询和响应处理

## 📋 测试用例详细流程

### 博客应用测试流程
`run-blog-tests.sh` 执行完整的博客应用功能测试：

1. **生成 AO 进程** (`ao-cli spawn`)
2. **加载博客应用代码** (`ao-cli load`)
3. **获取文章序号** (`ao-cli message` + Inbox检查)
4. **创建文章** (`ao-cli message` + Inbox检查)
5. **获取文章** (`ao-cli message` + Inbox检查)
6. **更新文章** (`ao-cli message` + Inbox检查)
7. **更新正文** (`ao-cli message` + Inbox检查)
8. **添加评论** (`ao-cli message` + Inbox检查)

### SAGA 跨进程测试流程 ⭐
`run-saga-tests.sh` 实现多进程分布式事务测试：

1. **生成聚合服务进程** (`ao-cli spawn`)
2. **加载聚合和出入库服务代码** (`ao-cli load`)
3. **生成业务服务进程** (`ao-cli spawn`)
4. **加载业务服务代码** (`ao-cli load`)
5. **动态配置进程间通信** (`ao-cli eval`)
6. **创建测试数据** (`ao-cli message`)
7. **执行 SAGA 事务** (`ao-cli eval`)
8. **验证执行结果** (库存更新和事务状态)

### Legacy Token 测试环境变量
```bash
# 模拟运行（不连接网络）
AO_DRY_RUN=true ./ao-cli-non-repl/tests/run-legacy-token-tests.sh

# 自定义等待时间
AO_WAIT_TIME=5 AO_SAGA_WAIT_TIME=30 ./ao-cli-non-repl/tests/run-legacy-token-tests.sh
```

**环境变量说明**：
- `AO_DRY_RUN=true` - 模拟模式，验证脚本逻辑而不连接AO网络
- `AO_PROJECT_ROOT=/path/to/project` - 指定项目根目录
- `AO_WAIT_TIME=5` - 设置普通操作等待时间
- `AO_SAGA_WAIT_TIME=30` - 设置Saga执行基础等待时间
- `AO_MAX_SAGA_WAIT_TIME=300` - 设置Saga执行最大等待时间（秒）
- `AO_CHECK_INTERVAL=30` - 设置Saga状态检查重试间隔（秒）


### 核心验证机制

#### Inbox 消息处理
- **Send() → sleep → Inbox[#Inbox]**: 完整的消息生命周期验证
- **相对变化检测**: 比绝对长度预测更可靠的验证策略
- **跨进程响应**: 合约间直接查询的Inbox响应处理

#### 跨进程通信架构
- **进程间消息传递**: eval + Send跨进程通信机制验证
- **From='Unknown'处理**: 跨进程调用中的发送者标识处理
- **网络延迟适应**: AO网络延迟的超时和重试策略
- **事务协调**: SAGA模式的分布式状态同步

**关键技术发现**: AO平台支持完整的进程间通信，合约进程可以直接查询其他合约，无需外部客户端介入。

## 📖 相关文档

- **AO CLI 独立版本**: https://github.com/dddappp/ao-cli
- **A-AO-Demo 项目**: 当前项目根目录的 README.md
- **AO 官方文档**: https://ao.arweave.dev/

## 🔗 迁移历史和项目进展

此目录原本包含完整的 AO CLI 工具实现，现已迁移至独立代码库。保留的测试套件专注于验证 A-AO-Demo 项目的核心功能，特别是复杂的分布式事务场景。

### 最新进展
- ✅ **SAGA 跨进程测试**: 新增完整的分布式事务自动化测试
- ✅ **Inbox 机制验证**: 深度测试 AO 的消息处理机制
- ✅ **多进程架构**: 验证跨进程通信和状态同步
- ✅ **动态配置**: 运行时参数设置和环境适应性

这些测试确保 A-AO-Demo 项目作为 AO 平台复杂应用的完整参考实现，涵盖从基础CRUD到分布式事务的全功能验证。


## 🔧 背景知识：AO Tag 过滤问题解决方案

### 🎯 问题背景
AO系统会对消息Tags进行过滤，导致Saga框架依赖的自定义Tag（如`X-SagaId`、`X-ResponseAction`）在跨进程传递时丢失，破坏了分布式事务的协调机制。

### ✅ 解决方案
通过深入分析AO/AOS源码和系统测试，我们实现了**Data嵌入策略**：
- 将Saga相关信息从Tags移动到Data字段
- 使用`messaging.embed_saga_info_in_data()`函数安全嵌入
- 使用`messaging.get_saga_id()`函数可靠提取
- **关键发现**：区分请求和响应的Saga信息嵌入策略
  - 请求消息：嵌入`saga_id` + `response_action`
  - 响应消息：只嵌入`saga_id`（`response_action`仅设置在`Tags.Action`中）
- 确保信息在AO系统的Tag过滤机制下仍然完整传递

### 📊 验证成果
- ✅ SAGA事务完全成功（current_step=6, completed=true）
- ✅ 库存管理业务逻辑正确执行（数量从100更新到119）
- ✅ 跨进程通信正常（alice↔bob消息传递无误）
- ✅ Data嵌入策略有效（绕过AO Tag过滤机制）

### 🎖️ 技术意义
此解决方案为AO平台上的复杂分布式应用提供了可靠的技术基础，特别是对于需要跨进程协调的业务场景。核心经验：
1. **Action tag不会被过滤**，可用于handler匹配
2. **自定义tag会被过滤**，必须用Data嵌入
3. **请求和响应的Saga信息嵌入策略不同**，这是关键细节


## 🔄 JSON 输出解析改进 - 从脆弱的正则表达式到健壮的 JSON 解析

### 问题背景

测试脚本 `ao-cli-non-repl/tests/run-blog-tests.sh` 之前的版本使用脆弱的正则表达式（`grep`、`sed`、`awk`）来解析 ao-cli 的文本输出，存在以下问题：
- **易出错**：输出格式变化导致解析失败
- **难维护**：复杂的 sed/awk 表达式难以理解和修改
- **生成误报**：日志混入 JSON 导致解析异常
- **低可靠性**：特殊字符处理不当导致边界情况失败

### 解决方案

使用 ao-cli 的 `--json` 选项获得结构化的 JSON 输出，通过 `jq` 进行可靠的解析：

```bash
# ❌ 脆弱的方式（原来的做法）
PROCESS_ID=$(ao-cli spawn default --name "test" 2>/dev/null | grep "📋 Process ID:" | awk '{print $4}')
# 问题：依赖于输出格式，易碎

# ✅ 健壮的方式（改进后）
JSON_OUTPUT=$(ao-cli spawn default --name "test" --json 2>/dev/null)
PROCESS_ID=$(echo "$JSON_OUTPUT" | jq -r '.data.processId')
# 优点：结构化数据，可靠性高
```

### 关键改进点

#### 1. **Helper 函数统一处理** - `run_ao_cli()`

```bash
run_ao_cli() {
    local command="$1"
    local process_id="$2"
    shift 2

    if [[ "$process_id" == -* ]]; then
        ao-cli "$command" -- "$process_id" --json "$@" 2>/dev/null
    else
        ao-cli "$command" "$process_id" --json "$@" 2>/dev/null
    fi
}
```

**优点**：
- 所有 ao-cli 调用统一使用 `--json` 和 `2>/dev/null`，消除日志混入问题
- 处理进程 ID 以 `-` 开头的特殊情况（需要使用 `--` 分隔）
- 屏蔽 Node.js 警告日志，确保只得到有效 JSON

#### 2. **处理多个 JSON 对象流** - `jq -s '.[-1]'`

ao-cli 的某些命令（特别是 `eval --wait` 和 `message --wait`）可能返回多个 JSON 对象：

```bash
# 命令输出可能包含：
# { "command": "eval", "success": true, ... }  # 消息发送确认
# { "command": "eval", "success": true, ... }  # 执行结果

# 使用 jq -s 将流转为数组，.[-1] 取最后一个
FINAL_RESULT=$(echo "$RAW_OUTPUT" | jq -s '.[-1]' 2>/dev/null)
```

**注意**：必须使用 `jq -s '.[-1]'` 而不是直接用 `jq`，否则会错误地处理第二个 JSON 对象。

#### 3. **隐藏 jq 错误** - `2>/dev/null`

所有 `jq` 调用都要在末尾加 `2>/dev/null`，避免：
- 解析错误信息污染输出
- jq 错误与命令结果混淆

```bash
# ❌ 不好的做法
local current_length=$(echo "$json_output" | jq -r '.data.result.Output.data')

# ✅ 好的做法
local current_length=$(echo "$json_output" | jq -r '.data.result.Output.data // "0"' 2>/dev/null)
```

#### 4. **成功检查的统一方式** - `jq -e '.success == true'`

```bash
if echo "$JSON_OUTPUT" | jq -e '.success == true' >/dev/null 2>&1; then
    echo "✅ 操作成功"
else
    echo "❌ 操作失败"
fi
```

**优点**：
- 统一的成功判断逻辑
- 避免解析具体字段时的异常
- 清晰的语义

#### 5. **数据提取的防御性编程**

始终使用 `// "默认值"` 提供备选值：

```bash
# ❌ 容易出错
local value=$(echo "$json" | jq -r '.data.field')

# ✅ 防御性编程
local value=$(echo "$json" | jq -r '.data.field // "0"' 2>/dev/null)
```

### 具体改进对比

| 操作            | 原来（脆弱）                | 改进后（健壮）                     |
| --------------- | --------------------------- | ---------------------------------- |
| Spawn 进程      | `grep "Process ID:" \| awk` | `jq -r '.data.processId'`          |
| 验证成功        | 检查命令退出码              | `jq -e '.success == true'`         |
| 提取 Inbox 长度 | 复杂 sed 表达式             | `jq -r '.data.result.Output.data'` |
| 显示消息        | grep + sed 组合拳           | `jq -r '.data.inbox'`              |
| 错误处理        | 手动检查输出                | JSON 结构保证格式                  |

### 改进成果

改进后的脚本：
- **代码行数减少**：132 行改为 44 行（-67%）
- **可读性提高**：JSON 查询比 sed 表达式更容易理解
- **可维护性改善**：ao-cli 输出格式变化时只需更新 jq 表达式
- **可靠性增强**：结构化数据保证不会出现解析异常
- **测试通过率**：10/10 步骤全部通过，零误报

### 后续迁移指导

对其他测试脚本进行类似改进时，遵循此检查清单：

- [ ] 所有 `ao-cli` 调用添加 `--json` 和 `2>/dev/null`
- [ ] 使用 `run_ao_cli()` helper 函数统一管理
- [ ] 处理多个 JSON 对象情况：`jq -s '.[-1]'`
- [ ] 成功检查：`jq -e '.success == true'`
- [ ] 数据提取：`jq -r '.path.to.field // "default"'`
- [ ] 所有 jq 调用加 `2>/dev/null`
- [ ] 移除过时的 grep/sed/awk 解析逻辑
- [ ] 清理无必要的 debug 输出
