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
├── README.md           # 此文档 - 项目测试概览
└── tests/
    ├── README.md       # 详细测试文档和使用指南
    ├── run-blog-tests.sh   # 博客应用自动化测试脚本
    └── run-saga-tests.sh   # SAGA跨进程自动化测试脚本 ⭐
```

### 测试套件功能

#### 博客应用测试
- 完整的博客应用端到端测试（文章、评论、版本控制）
- 精确重现 `AO-Testing-with-iTerm-MCP-Server.md` 文档流程
- Send() → sleep → Inbox[#Inbox] 完整测试模式
- Inbox机制验证和业务逻辑测试

#### SAGA 跨进程测试 ⭐
- 多进程架构下的分布式事务测试
- 库存管理和 SAGA 模式实现验证
- 跨进程消息传递和最终一致性保证
- 动态配置和运行时参数设置

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

# 带自定义参数的测试
AO_WAIT_TIME=5 AO_SAGA_WAIT_TIME=15 ./ao-cli-non-repl/tests/run-saga-tests.sh

# 模拟运行（验证脚本逻辑）
AO_DRY_RUN=true ./ao-cli-non-repl/tests/run-saga-tests.sh

# 查看详细测试文档
cat ./ao-cli-non-repl/tests/README.md
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
- ✅ **Inbox机制**: Send() → sleep → Inbox[#Inbox] 完整流程
- ✅ **业务逻辑**: 博客应用和库存管理功能
- ✅ **分布式事务**: SAGA 模式和最终一致性
- ✅ **错误处理**: 超时、重试和故障恢复

## 📋 测试用例说明

### 博客应用测试
`run-blog-tests.sh` 脚本实现完整的博客应用功能测试：

1. **生成 AO 进程** (`ao-cli spawn`)
2. **加载博客应用代码** (`ao-cli load`)
3. **获取文章序号** (`ao-cli message` + Inbox检查)
4. **创建文章** (`ao-cli message` + Inbox检查)
5. **获取文章** (`ao-cli message` + Inbox检查)
6. **更新文章** (`ao-cli message` + Inbox检查)
7. **更新正文** (`ao-cli message` + Inbox检查)
8. **添加评论** (`ao-cli message` + Inbox检查)

### SAGA 跨进程测试 ⭐
`run-saga-tests.sh` 脚本实现多进程分布式事务测试：

1. **生成聚合服务进程** (`ao-cli spawn`)
2. **加载聚合和出入库服务代码** (`ao-cli load`)
3. **生成业务服务进程** (`ao-cli spawn`)
4. **加载业务服务代码** (`ao-cli load`)
5. **动态配置进程间通信** (`ao-cli eval`)
6. **创建测试数据** (`ao-cli message`)
7. **执行 SAGA 事务** (`ao-cli eval`)
8. **验证执行结果** (库存更新和事务状态)


### 官方 Token 蓝图测试脚本 (主网)
```bash
./ao-cli-non-repl/tests/run-official-token-tests.sh
```

**注意**: 此脚本专为AO主网设计，使用现代AO API (ao.send()等)，在legacy网络上可能无法正常工作。如需测试legacy网络，请使用下方的legacy版本。

这个脚本测试AO官方标准Token蓝图的完整功能，包括Info、Balance、Transfer、Mint、Total-Supply、Burn等7个核心API。

**脚本功能**：
- 自动生成AO进程并加载官方Token蓝图
- 验证bint大整数库的精确计算功能
- 测试Debit-Notice/Credit-Notice通知系统
- 验证幂等性和状态一致性保证
- 提供详细的测试报告和功能验证

**环境变量**：

### Legacy Token 蓝图测试脚本 (遗留网络)
```bash
./ao-cli-non-repl/tests/run-legacy-token-tests.sh
```

**注意**: 此脚本专为AO legacy网络设计，使用Send()等legacy兼容API，在主网上可能无法正常工作。

这个脚本测试基于官方Token Blueprint的legacy网络兼容版本，包含相同的7个核心API。

**脚本功能**：
- 自动生成AO进程并加载legacy兼容Token蓝图
- 验证bint大整数库的精确计算功能
- 测试Debit-Notice/Credit-Notice通知系统
- 验证legacy网络兼容性
- 提供详细的测试报告和功能验证

**环境变量**：
- `AO_DRY_RUN=true` - 模拟模式，验证脚本逻辑而不连接AO网络
- `AO_PROJECT_ROOT=/path/to/project` - 指定项目根目录
- `AO_WAIT_TIME=5` - 设置普通操作等待时间
- `AO_SAGA_WAIT_TIME=30` - 设置Saga执行基础等待时间
- `AO_MAX_SAGA_WAIT_TIME=300` - 设置Saga执行最大等待时间（秒）
- `AO_CHECK_INTERVAL=30` - 设置Saga状态检查重试间隔（秒），默认为SAGA_WAIT_TIME


### 核心验证机制

#### Inbox 机制
- **Send() → sleep → Inbox[#Inbox]**: 完整的消息处理流程
- **进程内部 vs 外部调用**: 区分 Inbox 填充行为
- **Eval vs Message**: 不同的消息传递模式验证

#### 跨进程架构
- **动态配置**: 运行时设置进程间通信目标
- **消息路由**: 自动的请求-响应匹配
- **事务协调**: SAGA 模式的分布式事务处理
- **最终一致性**: 跨进程状态同步验证

**关键发现**: 通过 Eval 在进程内部执行 Send，且当回复消息没有被 Handler 处理时，才会进入进程的 Inbox。

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

### 测试覆盖
- **基础功能**: 博客应用、版本控制、乐观锁
- **高级功能**: SAGA 模式、最终一致性、补偿事务
- **系统特性**: Inbox 机制、多进程通信、错误处理

这些测试确保 A-AO-Demo 项目作为 AO 平台复杂应用的参考实现。

## 🔧 技术突破：AO Tag过滤问题解决方案

此项目的核心贡献是解决了AO平台上的Saga框架实现关键问题：

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
