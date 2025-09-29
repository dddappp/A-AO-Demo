# AO 应用测试指南：使用 iTerm MCP Server

本文档指导 AI 助手如何使用 iTerm MCP Server 自动化测试 AO 应用，避免手动重复操作。

## 环境准备

### 1. 设置网络代理（必需）
```bash
export HTTPS_PROXY=http://127.0.0.1:1235
export HTTP_PROXY=http://127.0.0.1:1235
export ALL_PROXY=socks5://127.0.0.1:1234
export AOS_NO_COLOR=1
```

### 2. 进入项目目录
```bash
cd /path/to/your/dddappp/A-AO-Demo
```

## 测试流程

### 步骤 1: 启动全新 AO 进程
```bash
mcp_iterm-mcp_write_to_terminal command="cd /path/to/your/dddappp/A-AO-Demo"
mcp_iterm-mcp_write_to_terminal command="export HTTPS_PROXY=http://127.0.0.1:1235 HTTP_PROXY=http://127.0.0.1:1235 ALL_PROXY=socks5://127.0.0.1:1234 AOS_NO_COLOR=1"
mcp_iterm-mcp_write_to_terminal command="aos test-blog-$(date +%s)"
```

### 步骤 2: 加载应用代码
```bash
mcp_iterm-mcp_read_terminal_output linesOfOutput=40
mcp_iterm-mcp_write_to_terminal command=".load /path/to/your/dddappp/A-AO-Demo/src/a_ao_demo.lua"
```

### 步骤 3: 初始化环境
```bash
mcp_iterm-mcp_read_terminal_output linesOfOutput=35
mcp_iterm-mcp_write_to_terminal command="json = require(\"json\")"
```

### 步骤 4: 执行测试用例

#### 4.1 获取文章序号
```bash
mcp_iterm-mcp_read_terminal_output linesOfOutput=10
mcp_iterm-mcp_write_to_terminal command="Send({ Target = ao.id, Tags = { Action = \"GetArticleIdSequence\" } })"
mcp_iterm-mcp_read_terminal_output linesOfOutput=20
mcp_iterm-mcp_write_to_terminal command="Inbox[#Inbox]"
mcp_iterm-mcp_read_terminal_output linesOfOutput=80
```

#### 4.2 创建文章
```bash
mcp_iterm-mcp_write_to_terminal command="Send({ Target = ao.id, Tags = { Action = \"CreateArticle\" }, Data = json.encode({ title = \"title_1\", body = \"body_1\" }) })"
mcp_iterm-mcp_read_terminal_output linesOfOutput=20
mcp_iterm-mcp_write_to_terminal command="Inbox[#Inbox]"
mcp_iterm-mcp_read_terminal_output linesOfOutput=80
```

#### 4.3 获取文章
```bash
mcp_iterm-mcp_write_to_terminal command="Send({ Target = ao.id, Tags = { Action = \"GetArticle\" }, Data = json.encode(1) })"
mcp_iterm-mcp_read_terminal_output linesOfOutput=20
mcp_iterm-mcp_write_to_terminal command="Inbox[#Inbox]"
mcp_iterm-mcp_read_terminal_output linesOfOutput=80
```

#### 4.4 更新文章
```bash
mcp_iterm-mcp_write_to_terminal command="Send({ Target = ao.id, Tags = { Action = \"UpdateArticle\" }, Data = json.encode({ article_id = 1, version = 0, title = \"new_title_1\", body = \"new_body_1\" }) })"
mcp_iterm-mcp_read_terminal_output linesOfOutput=15
mcp_iterm-mcp_write_to_terminal command="Inbox[#Inbox]"
mcp_iterm-mcp_read_terminal_output linesOfOutput=80
```

#### 4.5 单独更新正文
```bash
mcp_iterm-mcp_write_to_terminal command="Send({ Target = ao.id, Tags = { Action = \"UpdateArticleBody\" }, Data = json.encode({ article_id = 1, version = 1, body = \"updated_body_manual\" }) })"
mcp_iterm-mcp_read_terminal_output linesOfOutput=20
mcp_iterm-mcp_write_to_terminal command="Inbox[#Inbox]"
mcp_iterm-mcp_read_terminal_output linesOfOutput=80
```

#### 4.6 添加评论
```bash
# 注意：需要先获取当前文章版本
mcp_iterm-mcp_write_to_terminal command="Send({ Target = ao.id, Tags = { Action = \"GetArticle\" }, Data = json.encode(1) })"
mcp_iterm-mcp_read_terminal_output linesOfOutput=20
mcp_iterm-mcp_write_to_terminal command="Inbox[#Inbox]"
mcp_iterm-mcp_read_terminal_output linesOfOutput=80
# 使用返回的 version 值
mcp_iterm-mcp_write_to_terminal command="Send({ Target = ao.id, Tags = { Action = \"AddComment\" }, Data = json.encode({ article_id = 1, version = 2, commenter = \"alice\", body = \"comment_body_manual\" }) })"
mcp_iterm-mcp_read_terminal_output linesOfOutput=20
mcp_iterm-mcp_write_to_terminal command="Inbox[#Inbox]"
mcp_iterm-mcp_read_terminal_output linesOfOutput=80
```

### 步骤 5: 退出测试
```bash
mcp_iterm-mcp_write_to_terminal command=".exit"
```

## 自动化测试脚本示例

```bash
#!/bin/bash
set -e

echo "=== AO 应用自动化测试脚本 ==="

# 注意：此脚本需要 AI 助手在 Cursor 中执行以下 MCP 调用序列

# 1. 切换到项目目录并设置环境
echo "1. 准备环境..."
# mcp_iterm-mcp_write_to_terminal command="cd /path/to/your/dddappp/A-AO-Demo"
# mcp_iterm-mcp_write_to_terminal command="export HTTPS_PROXY=http://127.0.0.1:1235 HTTP_PROXY=http://127.0.0.1:1235 ALL_PROXY=socks5://127.0.0.1:1234 AOS_NO_COLOR=1"

# 2. 启动 AO 进程
echo "2. 启动 AO 进程..."
# mcp_iterm-mcp_write_to_terminal command="aos test-blog-$(date +%s)"

# 3. 等待进程启动
echo "3. 等待进程启动..."
# mcp_iterm-mcp_read_terminal_output linesOfOutput=40

# 4. 加载应用代码
echo "4. 加载应用代码..."
# mcp_iterm-mcp_write_to_terminal command=".load /path/to/your/dddappp/A-AO-Demo/src/a_ao_demo.lua"
# mcp_iterm-mcp_read_terminal_output linesOfOutput=35

# 5. 初始化 JSON 库
echo "5. 初始化环境..."
# mcp_iterm-mcp_write_to_terminal command="json = require(\"json\")"
# mcp_iterm-mcp_read_terminal_output linesOfOutput=10

# 6. 执行测试用例
echo "6. 执行测试用例..."

# 获取文章序号
echo "  - 获取文章序号"
# mcp_iterm-mcp_write_to_terminal command="Send({ Target = ao.id, Tags = { Action = \"GetArticleIdSequence\" } })"
# mcp_iterm-mcp_read_terminal_output linesOfOutput=20
# mcp_iterm-mcp_write_to_terminal command="Inbox[#Inbox]"
# mcp_iterm-mcp_read_terminal_output linesOfOutput=80

# 创建文章
echo "  - 创建文章"
# mcp_iterm-mcp_write_to_terminal command="Send({ Target = ao.id, Tags = { Action = \"CreateArticle\" }, Data = json.encode({ title = \"title_1\", body = \"body_1\" }) })"
# mcp_iterm-mcp_read_terminal_output linesOfOutput=20
# mcp_iterm-mcp_write_to_terminal command="Inbox[#Inbox]"
# mcp_iterm-mcp_read_terminal_output linesOfOutput=80

# 后续测试步骤类似...
echo "  - 更多测试步骤请参考文档详细说明"

# 7. 退出测试
echo "7. 退出测试..."
# mcp_iterm-mcp_write_to_terminal command=".exit"

echo "=== 测试完成 ==="
```

## 注意事项

1. **MCP 工具**: 必须使用 `mcp_iterm-mcp_write_to_terminal` 和 `mcp_iterm-mcp_read_terminal_output` 工具
2. **进程隔离**: 每次测试使用唯一的进程名（建议用时间戳），避免状态污染
3. **版本同步**: 更新操作前必须先获取当前版本号，否则会遇到 `CONCURRENCY_CONFLICT`
4. **顺序执行**: 严格按照步骤顺序执行，每发送命令后都要读取输出确认执行结果
5. **网络代理**: 必须设置正确的代理才能连接 AO 网络
6. **读取输出**: 每次发送命令后都要调用 `mcp_iterm-mcp_read_terminal_output` 检查执行结果

## 成功指标

- 所有操作返回的事件类型正确：
  - `ArticleCreated` - 文章创建成功
  - `ArticleUpdated` - 文章更新成功
  - `ArticleBodyUpdated` - 文章正文更新成功
  - `CommentAdded` - 评论添加成功
- 版本号按预期递增
- 无 `CONCURRENCY_CONFLICT` 或其他错误

## 故障排除

- **网络连接失败**: 检查代理设置是否正确
- **版本冲突**: 先获取当前文章版本，再进行更新操作
- **进程启动失败**: 使用新的进程名重新启动
- **命令无响应**: 增加 `linesOfOutput` 值或检查网络连接
- **JSON 库未加载**: 确保在发送 JSON 相关命令前先执行 `json = require("json")`
