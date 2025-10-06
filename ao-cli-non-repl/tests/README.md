# AO CLI 博客测试用例

> **⚠️ 重要**: AO CLI 工具已迁移到独立代码库！
>
> **新地址**: https://github.com/dddappp/ao-cli
> **npm包**: `@dddappp/ao-cli`

此文档描述了专为 A-AO-Demo 项目博客应用设计的测试用例。这些测试用例用于验证博客应用的完整功能，并精确重现 `AO-Testing-with-iTerm-MCP-Server.md` 文档中的端到端测试流程。

## 📋 测试用例概览

### 保留文件

此目录保留了以下文件用于 A-AO-Demo 项目的博客应用测试：

```
tests/
├── README.md          # 此文档 - 测试用例说明
└── run-blog-tests.sh  # 博客应用自动化测试脚本
```

### 脚本功能说明

#### `run-blog-tests.sh`
专为 A-AO-Demo 项目博客应用设计的自动化测试脚本，使用 AO CLI 工具精确重现 `AO-Testing-with-iTerm-MCP-Server.md` 文档中的完整测试流程。

**核心特性**:
- 🎯 精确重现原始 MCP + iTerm 测试流程
- 🔄 完整实现 `Send(message)` → `sleep N` → `Inbox[#Inbox]` 测试模式
- 📬 每个消息发送后都通过 `ao-cli inbox --latest` 检查收件箱状态
- ✅ 验证回复消息是否正确进入 Inbox
- 🔍 智能项目根目录检测（自动查找 `src/a_ao_demo.lua`）
- 🛡️ 完整环境检查和错误处理
- 📊 详细的步骤化输出和计时

**测试流程** (完全对应原始文档):
1. **生成 AO 进程** (`ao-cli spawn default --name "blog-test-$(date +%s)"`)
2. **加载博客应用代码** (`ao-cli load $PROCESS_ID $APP_FILE --wait`)
3. **获取文章序号** (`ao-cli message $PROCESS_ID GetArticleIdSequence --wait` + Inbox检查)
4. **创建文章** (`ao-cli message $PROCESS_ID CreateArticle --data '{"title":"title_1","body":"body_1"}' --wait` + Inbox检查)
5. **获取文章** (`ao-cli message $PROCESS_ID GetArticle --data '1' --wait` + Inbox检查)
6. **更新文章** (`ao-cli message $PROCESS_ID UpdateArticle --data '{"article_id":1,"version":0,"title":"new_title_1","body":"new_body_1"}' --wait` + Inbox检查)
7. **获取文章** (`ao-cli message $PROCESS_ID GetArticle --data '1' --wait` + Inbox检查)
8. **更新正文** (`ao-cli message $PROCESS_ID UpdateArticleBody --data '{"article_id":1,"version":1,"body":"updated_body_manual"}' --wait` + Inbox检查)
9. **获取文章** (`ao-cli message $PROCESS_ID GetArticle --data '1' --wait` + Inbox检查)
10. **添加评论** (`ao-cli message $PROCESS_ID AddComment --data '{"article_id":1,"version":2,"commenter":"alice","body":"comment_body_manual"}' --wait` + Inbox检查)

**Inbox验证**: 每个消息发送后都会验证回复消息是否正确进入Inbox，包含业务处理结果。

## 🚀 运行测试

### 前提条件

1. 获取并安装独立的 AO CLI 工具：
   ```bash
   git clone https://github.com/dddappp/ao-cli.git
   cd ao-cli
   npm install
   npm link
   ao-cli --version
   ```

2. 确保 A-AO-Demo 项目结构完整：
   - 项目根目录包含 `src/a_ao_demo.lua` (博客应用代码)
   - 项目根目录包含 `README.md` (项目标识文件)

### 执行测试

```bash
# 在项目根目录运行
./ao-cli-non-repl/tests/run-blog-tests.sh

# 在任何子目录运行（会自动向上查找项目根目录）
cd any/subdirectory
../../../ao-cli-non-repl/tests/run-blog-tests.sh

# 指定特定的项目路径
AO_PROJECT_ROOT=/path/to/project ./ao-cli-non-repl/tests/run-blog-tests.sh
```

### 预期输出示例

```
=== AO 博客应用自动化测试脚本 (使用 ao-cli 工具) ===
基于 AO-Testing-with-iTerm-MCP-Server.md 文档的测试流程

✅ 自动检测到项目根目录: /path/to/project
✅ 环境检查通过

🚀 开始执行测试...
=== 步骤 1: 生成 AO 进程 ===
进程 ID: abc123def456...
=== 步骤 2: 加载博客应用代码 ===
✅ Operation completed successfully
=== 步骤 3: 获取文章序号 ===
✅ Operation completed successfully
✅ Found messages in inbox!
...
=== 测试完成 ===
⏱️ 总耗时: 45 秒
✅ 所有测试步骤执行完毕
```

## 📚 相关文档和资源

### AO CLI 独立工具
- **GitHub 仓库**: https://github.com/dddappp/ao-cli
- **npm 包**: `@dddappp/ao-cli`
- **完整文档**: 请访问独立仓库的 README.md

### A-AO-Demo 项目
- **博客应用源码**: `src/a_ao_demo.lua`
- **测试文档**: `docs/AO-Testing-with-iTerm-MCP-Server.md`
- **项目主页**: 项目根目录的 README.md

### AO 生态系统
- **官方文档**: https://ao.arweave.dev/
- **社区资源**: https://github.com/permaweb/ao

## 🔍 测试验证要点

### 核心验证目标
这些测试用例主要验证以下关键机制：

- ✅ **Inbox 机制完整性**: Send() → sleep → Inbox[#Inbox] 完整流程
- ✅ **进程内部消息处理**: 验证进程内部 Send 操作会进入 Inbox
- ✅ **外部 API 行为**: 确认外部 message 调用不会污染 Inbox
- ✅ **业务逻辑正确性**: 博客应用的核心 CRUD 操作
- ✅ **版本控制机制**: 乐观锁和并发控制验证

### 技术验证细节

#### Inbox 行为模式
- **Inbox 是进程级状态**: 存储在 WASM 内存中的全局变量
- **进程内部 Send**: `ao-cli eval "Send()"` 会让回复进入 Inbox
- **外部 API 调用**: `ao-cli message` 结果直接返回，不进入 Inbox
- **混合测试验证**: 结合两种方式验证 Inbox 机制的完整性

#### 博客应用业务流程
1. 文章序号生成和获取
2. 文章创建、读取、更新
3. 版本控制和并发安全
4. 评论系统集成
5. 完整的状态管理和数据持久化

## 🛠️ 故障排除

### 常见问题解决

1. **找不到 ao-cli 命令**
   ```bash
   # 确保已安装独立版本
   git clone https://github.com/dddappp/ao-cli.git
   cd ao-cli && npm install && npm link
   ```

2. **钱包文件问题**
   ```bash
   # 检查钱包文件是否存在
   ls -la ~/.aos.json
   # 如不存在，请先运行 aos 创建钱包
   ```

3. **项目根目录检测失败**
   ```bash
   # 手动指定项目路径
   AO_PROJECT_ROOT=/path/to/project ./ao-cli-non-repl/tests/run-blog-tests.sh
   ```

4. **测试执行缓慢**
   - 调整等待时间：`AO_WAIT_TIME=3 ./run-blog-tests.sh`
   - 检查网络连接到 AO 测试网

## 📋 维护说明

这些测试用例专为 A-AO-Demo 项目的博客应用设计。如需：

- **修改业务逻辑**: 请同时更新 `src/a_ao_demo.lua` 和测试脚本
- **添加新功能**: 在测试脚本中添加相应的验证步骤
- **版本控制**: 确保测试中的版本号与应用逻辑保持同步

## 🔗 历史说明

此测试用例最初基于 AO CLI 工具的完整实现，现已分离为独立的工具包。这些保留的测试用例确保 A-AO-Demo 项目的博客应用功能能够持续得到验证和维护。