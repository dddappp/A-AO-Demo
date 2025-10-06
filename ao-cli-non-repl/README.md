# AO CLI 非REPL模式 - 博客测试用例

> **⚠️ 重要更新**: AO CLI 工具已迁移到独立的代码库！
>
> **新地址**: https://github.com/dddappp/ao-cli
> **npm包**: `@dddappp/ao-cli`

此目录现在仅保留原始的博客应用测试用例文档和脚本，用于测试 A-AO-Demo 项目中的博客应用。

## 📦 迁移状态

AO CLI 工具已完全迁移到独立代码库，包含：

- ✅ **自包含测试套件**: 独立的测试应用，不依赖外部项目
- ✅ **完整命令支持**: spawn, eval, load, message, inbox 所有命令
- ✅ **npm发布就绪**: 可作为独立包发布和安装
- ✅ **文档完善**: 独立的使用文档和API说明

## 🏠 此目录内容

此目录保留了原始的博客应用测试用例，供 A-AO-Demo 项目使用：

### 文件结构
```
ao-cli-non-repl/
├── README.md           # 此文档 - 迁移说明
└── tests/
    ├── README.md       # 博客测试用例详细文档
    └── run-blog-tests.sh # 博客应用自动化测试脚本
```

### 测试用例功能
- 完整的博客应用端到端测试
- 精确重现 `AO-Testing-with-iTerm-MCP-Server.md` 文档流程
- Send() → sleep → Inbox[#Inbox] 完整测试模式
- 智能项目根目录检测和环境检查

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

### 在 A-AO-Demo 项目中使用测试用例

此目录保留的测试用例专门用于测试当前项目的博客应用：

```bash
# 使用保留的博客测试脚本
./ao-cli-non-repl/tests/run-blog-tests.sh

# 查看测试文档
cat ./ao-cli-non-repl/tests/README.md
```

## 📋 测试用例说明

### 博客应用测试流程

保留的 `run-blog-tests.sh` 脚本实现了完整的博客应用测试：

1. **生成 AO 进程** (`ao-cli spawn`)
2. **加载博客应用代码** (`ao-cli load`)
3. **获取文章序号** (`ao-cli message` + Inbox检查)
4. **创建文章** (`ao-cli message` + Inbox检查)
5. **获取文章** (`ao-cli message` + Inbox检查)
6. **更新文章** (`ao-cli message` + Inbox检查)
7. **更新正文** (`ao-cli message` + Inbox检查)
8. **添加评论** (`ao-cli message` + Inbox检查)

### Inbox 机制验证

测试用例重点验证 AO 的 Inbox 机制：
- Send() → sleep → Inbox[#Inbox] 完整流程
- 进程内部消息发送会进入 Inbox
- 外部 API 调用不会进入 Inbox
- Inbox 子命令功能验证

## 📖 相关文档

- **AO CLI 独立版本**: https://github.com/dddappp/ao-cli
- **A-AO-Demo 项目**: 当前项目根目录的 README.md
- **AO 官方文档**: https://ao.arweave.dev/

## 🔗 迁移历史

此目录原本包含完整的 AO CLI 工具实现，现已迁移至独立代码库以便更好地维护和发布。
