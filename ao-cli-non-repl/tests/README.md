# A-AO-Demo 项目自动化测试用例

此文档描述了专为 A-AO-Demo 项目设计的自动化测试脚本，用于验证项目的核心功能。

## 📋 文件说明

```
tests/
├── README.md           # 此文档 - 测试用例说明
├── run-blog-tests.sh   # 博客应用自动化测试脚本
└── run-saga-tests.sh   # SAGA跨进程自动化测试脚本 ⭐
```

## 🔧 测试脚本功能

### 博客应用测试 (`run-blog-tests.sh`)

验证博客应用的核心功能：
- 文章的创建、读取、更新操作
- 评论系统功能
- 版本控制和乐观锁机制
- Inbox 消息处理机制

**测试流程**:
1. 生成 AO 进程并加载博客应用代码
2. 执行文章和评论的 CRUD 操作
3. 验证版本控制和并发安全
4. 检查 Inbox 消息处理

### SAGA 跨进程测试 (`run-saga-tests.sh`) ⭐

验证分布式事务处理能力：
- 多进程架构下的消息协调
- SAGA 模式的事务管理
- 跨进程的状态一致性
- 错误处理和补偿机制

**🎯 技术亮点**: 该脚本验证了我们对AO平台Tag过滤问题的解决方案。通过将Saga信息嵌入Data字段而非Tags，确保了分布式事务的可靠执行。

**测试流程**:
1. 生成 Alice 和 Bob 两个独立进程
2. 配置进程间通信目标（单进程内完成以确保可靠性）
3. 执行库存调整的 SAGA 事务（Data嵌入Saga信息传递）
4. 验证事务完成和数据一致性（库存数量正确更新）

## 🚀 运行测试

### 前提条件

- 安装 AO CLI 工具：`npm install -g @dddappp/ao-cli`
- 确保 A-AO-Demo 项目结构完整
- aos 进程正在运行
- 网络代理（如需要）

### 执行测试

```bash
# 博客应用测试
./ao-cli-non-repl/tests/run-blog-tests.sh

# SAGA 跨进程测试
./ao-cli-non-repl/tests/run-saga-tests.sh

# 自定义参数
AO_WAIT_TIME=5 AO_SAGA_WAIT_TIME=15 ./ao-cli-non-repl/tests/run-saga-tests.sh

# 模拟运行（验证脚本逻辑）
AO_DRY_RUN=true ./ao-cli-non-repl/tests/run-saga-tests.sh
```

### 测试验证要点

#### 博客应用测试
- Inbox 消息处理机制验证
- 文章和评论的 CRUD 操作
- 版本控制和并发安全

#### SAGA 跨进程测试 ⭐
- 多进程架构下的消息协调
- SAGA 事务的完整执行流程
- 跨进程状态一致性验证

## 📋 维护说明

### 脚本更新
- 业务逻辑变更时同步更新测试脚本
- 根据网络条件调整等待时间参数
- 确保测试用例与实际实现保持一致

### 故障排除
- 检查 AO 网络连接和钱包配置
- 验证进程ID和消息格式
- 确认 Eval 消息用于 Inbox 验证