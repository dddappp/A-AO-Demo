# A-AO-Demo 项目记忆和规则系统

这个目录包含了 A-AO-Demo 项目的集体记忆和开发规则，使用现代的 Cursor IDE 项目结构。

## 📁 目录结构

```
.cursor/
├── README.md              # 本文档
├── config.json            # Cursor IDE 配置
├── learned_memories.mdc   # 项目记忆和上下文
└── rules/
    ├── project-rules.mdc      # 通用项目规则和规范
    └── ao-development.mdc     # AO 开发专用规则
```

## 📄 文件说明

### `config.json` - IDE 配置
**目的**: 为 Cursor IDE 提供项目特定的配置和元数据

**包含内容**:
- 项目基本信息和元数据
- 启用的规则和上下文文件
- 开发环境配置
- 技术约束和模式识别
- 文件类型定义

### `learned_memories.mdc` - 项目记忆
**格式**: Markdown Component (.mdc) 格式，包含 frontmatter 元数据

**目的**: 项目的"集体记忆"，包含完整的技术背景和历史

**适用场景**:
- 新开发者快速了解项目全貌
- 回顾重要技术决策和架构演进
- 查找常见问题解决方案
- 了解项目发展历程和技术债务

### `rules/` 目录 - 项目规则集合

#### `project-rules.mdc` - 通用项目规则
**类型**: Always rules (始终激活)
**适用**: 所有项目文件
**内容**: 项目的通用开发规范、约束条件和最佳实践

#### `ao-development.mdc` - AO 开发专用规则
**类型**: Auto-attached rules (自动附加，基于文件类型)
**适用**: `src/**/*.lua` 和其他 Lua 文件
**内容**: AO 区块链开发特定的规则和技术约束

## 🚀 如何使用

### 1. 新开发者入门路径
1. **阅读配置**: 查看 `config.json` 了解项目技术栈
2. **了解背景**: 阅读 `learned_memories.mdc` 的"项目概述"和"核心架构理解"
3. **学习规则**:
   - 阅读 `rules/project-rules.mdc` 了解通用开发规范
   - 阅读 `rules/ao-development.mdc` 了解 AO 开发专用规则
4. **设置环境**: 按照规则配置 AO 开发环境
5. **开始开发**: 参考规则进行开发工作

### 2. 日常开发工作流
- **代码修改**: 检查 `rules/project-rules.mdc` 中的"可修改文件规则"
- **测试执行**: 参考"测试规则"选择合适的测试类型
- **问题排查**: 在 `learned_memories.mdc` 中查找"常见问题解决方案"
- **架构决策**: 参考"开发原则和最佳实践"

### 3. Cursor IDE 集成特性

#### 自动规则识别
- IDE 会自动读取 `config.json` 中的规则配置
- 编辑代码时提供相关的上下文和约束提示
- 支持项目特定的代码补全和格式化

#### 智能上下文感知
- 基于配置文件识别技术栈和框架
- 提供相关的文档链接和资源
- 支持项目特定的开发模式识别

## 🔧 维护和更新

### 更新时机
- **技术演进**: 项目技术栈或架构发生变化
- **新发现**: 发现新的技术陷阱或最佳实践
- **问题解决**: 解决重要技术问题后记录解决方案
- **流程优化**: 开发流程有新的改进

### 更新流程
1. 在相应文件中添加或修改内容
2. 更新 `config.json` 中的 `lastUpdated` 字段
3. 提交到版本控制系统
4. 通知团队成员了解变更

## 📊 配置架构

### Schema 版本
当前使用 `https://cursor.sh/schema/project/v1` schema

### 主要配置块
- **rules**: 规则文件配置
- **context**: 上下文文件配置
- **metadata**: 项目元数据
- **development**: 开发环境配置
- **constraints**: 技术约束
- **patterns**: 代码模式识别
- **fileTypes**: 文件类型定义

## 🎯 快速导航表

| 场景 | 文档位置 | 具体章节 |
|------|----------|----------|
| 项目概览 | `learned_memories.mdc` | 项目概述 |
| 技术架构 | `learned_memories.mdc` | 核心架构理解 |
| 开发规范 | `rules/project-rules.mdc` | 代码生成和修改规则 |
| AO开发规则 | `rules/ao-development.mdc` | 序列化安全规则 |
| 测试指南 | `rules/project-rules.mdc` | 测试规则 |
| 部署说明 | `rules/project-rules.mdc` | 部署规则 |
| 问题排查 | `learned_memories.mdc` | 关键技术陷阱 |
| 最佳实践 | `learned_memories.mdc` | 开发原则和最佳实践 |

## 🔗 相关资源

- **项目文档**: `docs/` 目录
- **测试脚本**: `ao-cli-non-repl/tests/`
- **领域模型**: `dddml/` 目录
- **源码**: `src/` 目录

---

*此系统采用现代 Cursor IDE 项目结构设计，确保了项目的可维护性和开发体验。如有问题或建议，请及时更新相关文档。*
