# Javet AOConnect Integration Demo

## 项目概述

这是一个演示项目，展示如何在 Java 应用程序中集成 **Javet** 框架和 **aoconnect** SDK，实现与 AO（Actor-Oriented Computer）网络的无缝交互。

**⚠️ 重要说明**: 本项目已成功实现 Javet + aoconnect 集成，并可以连接到 AO Legacy 网络。原生库依赖已正确配置，支持 macOS arm64 架构。

### 核心特性

- ✅ **Javet 集成**: 使用 Node.js 运行时在 Java 中执行 JavaScript 代码
- ✅ **AO 网络连接**: 通过 aoconnect SDK 与 AO Legacy 网络交互
- ✅ **引擎池管理**: 高效的 Node.js 运行时实例池化
- ✅ **自动资源管理**: try-with-resources 模式的资源清理
- ✅ **完整日志记录**: 详细的操作日志和错误处理
- ✅ **代理支持**: 支持 HTTP/SOCKS 代理访问网络
- ✅ **单元测试**: 完整的测试覆盖

### 技术架构

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Java 应用层    │───▶│ Javet 桥接层     │───▶│ AO 网络层       │
│                 │    │                  │    │                 │
│ - 业务逻辑      │    │ - V8 引擎运行时  │    │ - 进程管理      │
│ - 状态管理      │    │ - 引擎池管理     │    │ - 消息传递      │
│ - 错误处理      │    │ - 资源管理       │    │ - 状态查询      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 技术栈

- **Java 11+** - 主要编程语言
- **Javet 3.1.6** - Java与V8/Node.js引擎桥接
- **Node.js 18+** - JavaScript运行时环境
- **aoconnect 0.0.90** - AO网络官方SDK
- **Maven 3.8+** - Java项目构建工具
- **SLF4J + Logback** - 日志框架

## 环境要求

- **操作系统**: Windows 11/10, Linux (glibc 2.29+), macOS 12.0+ (包括 Apple Silicon)
- **架构**: 支持 x86_64 和 arm64
- **内存**: 最小 512MB RAM，推荐 2GB RAM
- **磁盘**: 2GB 可用空间（包括依赖下载）
- **Java**: JDK 11+ (推荐 JDK 17+)
- **Node.js**: 18.0.0+ (推荐 20.x LTS)
- **npm**: 8.0.0+ (推荐最新版本)
- **Maven**: 3.8.0+ (推荐 3.9.x)

## 快速开始

### 1. 环境准备

```bash
# 验证环境
java -version
node --version
npm --version
mvn --version

# 配置代理（如果需要）
export HTTPS_PROXY=http://127.0.0.1:1235
export HTTP_PROXY=http://127.0.0.1:1235
export ALL_PROXY=socks5://127.0.0.1:1234
```

### 2. 构建项目

```bash
git clone <repository-url>
cd javet-aoconnect-demo

# 安装依赖
npm install
mvn clean compile
```

### 3. 运行应用

```bash
# 方式一：Maven 插件（推荐）
mvn exec:java

# 方式二：启动脚本
./start.sh

# 方式三：JAR 包
mvn clean package
java -jar target/javet-aoconnect-demo.jar
```

### 4. 运行测试

```bash
mvn test
```

### 5. 预期输出

```
✅ AO Java Bridge initialized with Node.js runtime pool
✅ Loading aoconnect SDK...
✅ aoconnect SDK loaded successfully
✅ AO Java Bridge initialized successfully!
✅ Bridge info: V8Runtime pool initialized
✅ Bridge initialized: true
```

## 项目结构

```
javet-aoconnect-demo/
├── src/
│   ├── main/
│   │   ├── java/com/example/aodemo/
│   │   │   ├── AOJavaBridge.java          # 核心桥接类 - AO 网络桥接实现
│   │   │   └── AODemoApplication.java     # 演示应用 - 主程序入口
│   │   └── resources/
│   │       ├── js/
│   │       │   └── aoconnect.browser.js   # aoconnect 浏览器版本 (备用)
│   │       ├── application.properties     # 应用配置 - AO 网络和代理设置
│   │       └── logback.xml               # 日志配置 - 详细日志记录
│   └── test/
│       └── java/com/example/aodemo/
│           └── AOJavaBridgeTest.java      # 单元测试 - 桥接功能测试
├── node_modules/                          # npm 依赖 - @permaweb/aoconnect
├── package.json                           # npm 配置 - 依赖管理
├── package-lock.json                      # npm 锁定文件 - 版本锁定
├── pom.xml                               # Maven 配置 - Java 依赖和构建
├── start.sh                              # 启动脚本 - 一键启动应用
├── .gitignore                            # Git 忽略文件 - 排除可下载内容
└── README.md                             # 项目文档 - 完整使用指南
```

**文件说明**:
- `AOJavaBridge.java`: 核心桥接类，实现 Javet + aoconnect 集成
- `AODemoApplication.java`: 主程序，演示 AO 网络交互功能
- `application.properties`: 配置 AO 网络端点和代理设置
- `aoconnect.browser.js`: aoconnect SDK 浏览器版本 (项目中未使用)

## 技术要点

### 依赖管理
- **Javet 3.1.6**: 自动下载平台原生库，支持 macOS arm64
- **aoconnect 0.0.90**: 通过 npm 安装，Node.js 模式运行

### 核心机制
- **引擎池管理**: Node.js 运行时复用
- **模块路径配置**: 自动设置 npm 模块搜索路径
- **资源管理**: try-with-resources 自动清理
- **错误处理**: 统一异常处理和日志记录

### AO 网络交互
支持进程创建、消息发送和结果查询等核心操作。

## 配置说明

### 应用配置
- **AO 网络端点**: 配置 gateway、mu、cu 等服务地址
- **调度器 ID**: 指定使用的 AO 调度器进程
- **代理设置**: 支持 HTTP/SOCKS 代理访问
- **日志级别**: 可调整 DEBUG/INFO 等日志级别

## 测试和验证

### 单元测试
- **桥接初始化测试**: 验证 Javet 引擎池和 aoconnect 加载
- **网络连接测试**: 验证 AO 网络可达性
- **功能测试**: 验证进程创建、消息发送等核心功能

运行测试：`mvn test`

## 故障排除

### 常见问题

#### 1. Javet 原生库加载失败
**解决方案**:
- 确保添加了 `javet-macos` 依赖用于 macOS arm64 支持
- 验证原生库已正确下载：`find ~/.m2/repository/com/caoccao/javet/ -name "*.dylib"`
- 清理 Maven 本地仓库后重新构建

#### 2. 依赖安装问题
**解决方案**:
- 确保 npm 依赖已正确安装：`npm install`
- 验证 aoconnect 模块存在且版本正确
- 检查 node_modules 目录权限

#### 3. 网络连接失败
**解决方案**:
- 验证网络连通性：`curl -I https://arweave.net`
- 检查代理配置是否正确
- 确认 AO 网络端点配置

#### 4. 调试模式
启用详细日志：
```properties
logging.level.com.example.aodemo=TRACE
logging.level.com.caoccao.javet=DEBUG
```

## 性能优化

- **引擎池调优**: 根据负载调整池大小和超时时间
- **内存管理**: 自动清理和引擎复用
- **并发处理**: 支持异步操作和连接复用

## 部署指南

### 开发环境
```bash
npm install
mvn clean compile
mvn exec:java
```

### 生产环境
- 构建：`mvn clean package`
- 配置生产环境网络端点和日志
- 设置 JVM 优化参数

### 监控要点
- 定期检查日志文件
- 监控引擎池使用情况
- 设置健康检查端点

## 扩展开发

### 自定义功能
- 扩展 `AOJavaBridge` 类添加新方法
- 在 `application.properties` 中添加配置
- 实现自定义 AO 网络操作

### 框架集成
- **Spring Boot**: 配置为 Bean 自动注入
- **监控**: 集成 Micrometer 等监控框架
- **异步**: 使用 CompletableFuture 处理并发

## 贡献指南

### 开发流程

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

### 代码规范

- 遵循 Java 编码规范
- 添加适当的注释和文档
- 编写单元测试
- 更新相关文档

## 版本历史

### v1.0.0
- 初始版本发布
- 实现基本的 Javet + aoconnect 集成
- 包含完整的演示应用和测试
- 提供详细的文档和故障排除指南

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 支持

如有问题或建议，请：

1. 查看 [故障排除](#故障排除) 部分
2. 查阅日志文件
3. 提交 Issue 描述问题

## 📚 贡献指南

### 开发流程
1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

### 代码规范
- 遵循 Java 编码规范
- 添加适当的注释和文档
- 编写单元测试
- 更新相关文档

## 📄 许可证

本项目采用 **MIT 许可证**。

---

**注意**: 本项目基于 AO 网络测试网，生产使用前请确保网络配置正确，并进行充分的测试。
