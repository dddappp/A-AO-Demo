# AO CLI 测试套件

这个目录包含 AO CLI 工具的测试脚本，用于精确重现 `AO-Testing-with-iTerm-MCP-Server.md` 文档中的端到端测试流程。

## 测试文件说明

### 脚本文件

#### `run-blog-tests.sh`
自动化测试脚本，使用简单的 shell 命令精确重现 AO-Testing-with-iTerm-MCP-Server.md 中的完整测试流程。

**特性**:
- 精确重现原始 MCP + iTerm 测试流程
- 完整实现 `Send(message)` → `sleep N` → `Inbox[#Inbox]` 测试模式
- 每个消息发送后都通过 `ao-cli inbox --latest` 检查收件箱状态
- 验证回复消息是否正确进入Inbox
- 智能项目根目录检测（自动查找 `src/a_ao_demo.lua`）
- 完整环境检查和错误处理
- 详细的步骤化输出和计时

**测试流程** (完全对应原始文档):
1. **生成 AO 进程** (`ao-cli spawn default --name "blog-test-$(date +%s)"`)
2. **加载博客应用代码** (`ao-cli load $PROCESS_ID $APP_FILE --wait`)
3. **获取文章序号** (`ao-cli message $PROCESS_ID GetArticleIdSequence --wait` + `sleep N` + `ao-cli inbox $PROCESS_ID --latest`)
4. **创建文章** (`ao-cli message $PROCESS_ID CreateArticle --data '{"title":"title_1","body":"body_1"}' --wait` + `sleep N` + `ao-cli inbox $PROCESS_ID --latest`)
5. **获取文章** (`ao-cli message $PROCESS_ID GetArticle --data '1' --wait` + `sleep N` + `ao-cli inbox $PROCESS_ID --latest`)
6. **更新文章** (`ao-cli message $PROCESS_ID UpdateArticle --data '{"article_id":1,"version":0,"title":"new_title_1","body":"new_body_1"}' --wait` + `sleep N` + `ao-cli inbox $PROCESS_ID --latest`)
7. **获取文章** (`ao-cli message $PROCESS_ID GetArticle --data '1' --wait` + `sleep N` + `ao-cli inbox $PROCESS_ID --latest`)
8. **更新正文** (`ao-cli message $PROCESS_ID UpdateArticleBody --data '{"article_id":1,"version":1,"body":"updated_body_manual"}' --wait` + `sleep N` + `ao-cli inbox $PROCESS_ID --latest`)
9. **获取文章** (`ao-cli message $PROCESS_ID GetArticle --data '1' --wait` + `sleep N` + `ao-cli inbox $PROCESS_ID --latest`)
10. **添加评论** (`ao-cli message $PROCESS_ID AddComment --data '{"article_id":1,"version":2,"commenter":"alice","body":"comment_body_manual"}' --wait` + `sleep N` + `ao-cli inbox $PROCESS_ID --latest`)

**Inbox验证**: 每个消息发送后都会验证回复消息是否正确进入Inbox，包含业务处理结果。

**使用方法**:
```bash
# 在项目根目录运行
./ao-cli-non-repl/tests/run-blog-tests.sh

# 在任何子目录运行（会自动向上查找项目根目录）
cd any/subdirectory
../../../ao-cli-non-repl/tests/run-blog-tests.sh

# 指定特定的项目路径
AO_PROJECT_ROOT=/path/to/project ./ao-cli-non-repl/tests/run-blog-tests.sh
```

**输出示例**:
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
=== 步骤 4: 创建文章 ===
✅ Operation completed successfully
✅ Found messages in inbox!
...
=== 测试完成 ===
⏱️ 总耗时: 45 秒
✅ 所有测试步骤执行完毕
```

## 运行测试

### 前提条件

1. 安装 Node.js 和 npm
2. 安装 AO CLI 工具：
   ```bash
   cd ao-cli-non-repl
   npm install
   npm link
   ```

3. 确保有有效的 AO 钱包文件 (`~/.aos.json`)

4. 对于博客测试，确保项目根目录包含：
   - `src/a_ao_demo.lua` (博客应用代码)
   - `README.md` (项目标识文件)

### 运行博客完整测试

```bash
# 使用自动化脚本（推荐）
./ao-cli-non-repl/tests/run-blog-tests.sh

# 或手动执行单个步骤
ao-cli spawn default --name test-process
ao-cli eval <process-id> --file src/a_ao_demo.lua --wait
ao-cli message <process-id> GetArticleIdSequence --wait
sleep 2
ao-cli inbox <process-id> --latest
```

## 与原始 MCP 测试的对应关系

| 原始 MCP + iTerm                                            | AO CLI shell 脚本                                     | 说明       |
| ----------------------------------------------------------- | ----------------------------------------------------- | ---------- |
| `aos test-blog-xxx`                                         | `ao-cli spawn default --name "blog-test-$(date +%s)"` | 生成进程   |
| `.load ./src/a_ao_demo.lua`                                 | `ao-cli load $PID $APP_FILE --wait`                   | 加载代码   |
| `Send({ Target = ao.id, Action = "GetArticleIdSequence" })` | `ao-cli message $PID GetArticleIdSequence --wait`     | 发送消息   |
| `read_terminal_output`                                      | `sleep N`                                             | 等待处理   |
| `Inbox[#Inbox]`                                             | `ao-cli inbox $PID --latest`                          | 检查 inbox |

## 测试验证

### 成功指标

- ✅ 进程成功创建并返回有效的进程 ID
- ✅ 应用代码成功加载（load 返回成功）
- ✅ 所有消息发送成功并收到确认（message --wait）
- ✅ 每次消息发送后都能通过 `ao-cli inbox --latest` 检查收件箱状态
- ✅ 完整的 Send() → sleep → Inbox[#Inbox] 流程实现
- ✅ Inbox中包含所有业务回复消息（GetArticleIdSequence、CreateArticle等的结果）
- ✅ Inbox子命令功能完全验证

### Inbox机制说明

在AO架构中，Inbox有特定的含义和行为：

#### **Inbox 的本质**
- **Inbox 是进程内部的全局变量**，存储在进程WASM内存中
- **不是网络级别的消息队列**，而是进程级别的接收消息缓存
- **每当进程接收到消息时，都会被插入到Inbox中**

#### **Inbox 内容分类**
Inbox 包含发送给进程的所有消息：
- 系统初始化消息（Type=Process）
- 其他进程发送的业务消息
- **进程自身处理业务逻辑后的回复消息** ← 关键发现
- 定时任务消息等

#### **外部API vs 进程内部操作**

**外部API调用**（`ao-cli message`）：
- 通过aoconnect SDK发送消息到AO网络
- 消息不会作为"接收消息"进入进程Inbox
- 结果通过API直接返回

**进程内部操作**（`ao-cli eval "Send()"`）：
- 在进程WASM内部执行Lua代码
- Send函数发送消息时，进程会接收到回复副本
- 回复消息被handler处理并插入Inbox

#### **Inbox 完整性验证**
- Inbox是进程的消息队列，记录所有接收到的消息
- 包括外部消息和内部处理产生的回复消息
- 通过 `ao-cli inbox --latest` 可以查看最新消息

#### **测试验证结果**
- Inbox length 从 1 增加到 2，证明新消息进入
- 通过 `ao-cli eval --data "Send(...)"` 在进程内部发送消息
- 回复消息确实会进入进程的Inbox
- Inbox子命令功能完全正常工作
- **这证明了Inbox机制的完整性和正确性**

### 故障排除

#### 常见问题

1. **"ao-cli command not found"**
   ```bash
   cd ao-cli-non-repl && npm link
   ```

2. **"Wallet file not found"**
   ```bash
   # 确保有 ~/.aos.json 文件
   ls -la ~/.aos.json
   ```

3. **"Project root directory not found"**
   ```bash
   # 手动指定项目路径
   AO_PROJECT_ROOT=/path/to/project ./run-blog-tests.sh
   ```

4. **应用代码加载失败**
   - 检查 `src/a_ao_demo.lua` 是否存在
   - 确保应用代码语法正确

5. **消息发送失败**
   - 验证进程 ID 正确
   - 检查消息格式和参数

6. **inbox 检查无消息**
   - 增加 sleep 时间
   - 检查应用代码是否正确处理消息

## 扩展测试

### 为你的 AO dApp 创建测试

基于这个脚本模板，你可以为任何 AO dApp 创建类似的测试：

```bash
# 1. 创建进程
PROCESS_ID=$(ao-cli spawn default --name "my-dapp-test" | grep "Process ID:" | awk '{print $3}')

# 2. 加载你的应用代码
ao-cli eval "$PROCESS_ID" --file "path/to/your/app.lua" --wait

# 3. 执行你的业务操作 (记得使用正确的版本号)
# 例如，对于博客应用：
ao-cli message "$PROCESS_ID" CreateArticle --data '{"title": "Test", "body": "Content"}' --wait
ao-cli message "$PROCESS_ID" GetArticle --data '1' --wait  # 检查版本=0
ao-cli message "$PROCESS_ID" UpdateArticle --data '{"article_id": 1, "version": 0, "title": "Updated"}' --wait

# 4. 更多测试步骤...
```

### 自定义测试脚本

复制 `run-blog-tests.sh` 并修改为适应你的应用：

```bash
cp run-blog-tests.sh run-my-dapp-tests.sh
# 编辑脚本中的操作和数据
```

这样你就可以为任何 AO dApp 创建精确的端到端测试，完全对应 aos REPL 的交互模式！