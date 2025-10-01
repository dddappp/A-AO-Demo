# AO 应用自动化测试指南

本文档指导开发者如何使用 MCP 工具自动化测试 AO 应用，避免手动重复操作。

## 环境准备

### 1. 网络配置（根据需要）
如果您的网络环境需要代理才能访问 AO 网络，请根据您的实际情况配置相应的环境变量。例如：

```bash
# 根据您的网络环境配置以下变量（如果需要）
export HTTPS_PROXY=http://your-proxy-host:port
export HTTP_PROXY=http://your-proxy-host:port
export ALL_PROXY=socks5://your-proxy-host:port

# 禁用 AOS 命令的彩色输出（可选）
export AOS_NO_COLOR=1
```

### 2. 进入项目目录
```bash
cd /path/to/your/project
```

## 测试流程

### 步骤 1: 启动全新 AO 进程
```bash
# 进入项目目录
mcp_iterm-mcp_write_to_terminal command="cd /path/to/your/project"

# 配置网络（如果需要）
mcp_iterm-mcp_write_to_terminal command="export HTTPS_PROXY=http://your-proxy-host:port HTTP_PROXY=http://your-proxy-host:port ALL_PROXY=socks5://your-proxy-host:port"

# 启动 AO 进程（使用时间戳确保进程名唯一）
mcp_iterm-mcp_write_to_terminal command="aos test-blog-$(date +%s)"
```

### 步骤 2: 加载应用代码
```bash
mcp_iterm-mcp_read_terminal_output linesOfOutput=40
mcp_iterm-mcp_write_to_terminal command=".load ./src/a_ao_demo.lua"
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

# 以下是使用 MCP 工具执行自动化测试的命令序列
# 注意：这些命令需要通过支持 MCP 的开发环境执行

# 1. 切换到项目目录并设置环境
echo "1. 准备环境..."
# mcp_iterm-mcp_write_to_terminal command="cd /path/to/your/project"
# 如果需要，在此处配置网络代理

# 2. 启动 AO 进程
echo "2. 启动 AO 进程..."
# mcp_iterm-mcp_write_to_terminal command="aos test-blog-$(date +%s)"

# 3. 等待进程启动
echo "3. 等待进程启动..."
# mcp_iterm-mcp_read_terminal_output linesOfOutput=40

# 4. 加载应用代码
echo "4. 加载应用代码..."
# mcp_iterm-mcp_write_to_terminal command=".load ./src/a_ao_demo.lua"
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

## 关于 MCP 工具

本文档中使用的 MCP（Machine Control Protocol）工具是一套用于自动化终端操作的工具集。主要包括：

- `mcp_iterm-mcp_write_to_terminal`: 向终端写入命令
- `mcp_iterm-mcp_read_terminal_output`: 读取终端输出
- `mcp_iterm-mcp_send_control_character`: 发送控制字符

这些工具可以在支持 MCP 的各种开发环境中使用，不限于特定的 IDE。

## 注意事项

1. **网络配置**: 根据您的网络环境，可能需要配置适当的代理设置才能连接 AO 网络
2. **MCP 工具**: 确保您的开发环境支持并正确配置了 MCP 工具
3. **进程隔离**: 每次测试使用唯一的进程名（建议用时间戳），避免状态污染
4. **版本同步**: 更新操作前必须先获取当前版本号，否则会遇到 `CONCURRENCY_CONFLICT`
5. **顺序执行**: 严格按照步骤顺序执行，每发送命令后都要读取输出确认执行结果
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

- **网络连接失败**: 检查网络连接和代理设置（如果使用）
- **版本冲突**: 先获取当前文章版本，再进行更新操作
- **进程启动失败**: 使用新的进程名重新启动
- **命令无响应**: 增加 `linesOfOutput` 值或检查网络连接
- **JSON 库未加载**: 确保在发送 JSON 相关命令前先执行 `json = require("json")`
- **MCP 工具问题**: 确认开发环境中 MCP 工具的配置是否正确