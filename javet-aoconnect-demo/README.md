# Javet + aoconnect 集成演示项目

这是Javet框架与aoconnect SDK集成的完整演示项目，展示了如何在Java应用中使用AO网络功能。

## 📋 项目结构

```
javet-aoconnect-demo/
├── pom.xml                 # Maven项目配置
├── src/main/
│   ├── java/
│   │   └── com/example/javetaodemo/
│   │       └── JavetAOConnectDemo.java    # 演示主类
│   └── resources/
│       ├── logback.xml                    # 日志配置
│       └── js/
│           ├── aoconnect.browser.js       # 浏览器版本aoconnect
│           ├── aoconnect.esm.js           # ESM版本aoconnect
│           └── module-setup.js            # 模块配置脚本
├── scripts/
│   └── prepare-aoconnect.sh               # 预处理脚本
├── test-aoconnect-integration.js          # 集成测试脚本
└── README.md                              # 本文件
```

## 🚀 快速开始

### 1. 环境要求

- **Java**: JDK 11+
- **Node.js**: 18.0.0+
- **Maven**: 3.6+
- **Javet原生库**: 需要平台特定的Javet原生库文件

### 2. 运行预处理脚本

```bash
chmod +x scripts/prepare-aoconnect.sh
./scripts/prepare-aoconnect.sh
```

此脚本将：
- 安装@permaweb/aoconnect依赖
- 复制aoconnect文件到资源目录
- 创建必要的配置脚本

### 3. 运行演示

```bash
# 方法1: 使用运行脚本（推荐）
chmod +x run-demo.sh
./run-demo.sh

# 方法2: 使用Maven
mvn compile exec:java

# 方法3: 编译后运行
mvn compile
java -cp target/classes:target/dependency/* com.example.javetaodemo.JavetAOConnectDemo
```

### 4. 预期输出

```
🚀 开始Javet + aoconnect集成演示
🎯 演示1: V8模式 + 浏览器版本aoconnect
📦 加载浏览器版本aoconnect: /path/to/project/src/main/resources/js/aoconnect.browser.js
✅ aoconnect加载成功，spawn函数可用: function
🎯 演示2: Node.js模式 + ESM版本aoconnect
✅ aoconnect加载成功，版本: 可用
🎯 演示3: 引擎池管理
🏊 引擎池创建成功，池大小: 3
✅ 任务0执行完成
✅ 任务1执行完成
✅ 任务2执行完成
✅ 任务3执行完成
✅ 任务4执行完成
✅ 演示完成
```

## 🎯 演示功能

### 1. V8模式 + 浏览器版本aoconnect（推荐）
- 使用Javet的V8运行时
- 加载浏览器版本aoconnect（3.2MB，包含所有polyfill）
- 演示直接使用，无需额外配置

### 2. Node.js模式 + ESM版本aoconnect
- 使用Javet的Node.js运行时
- 加载ESM版本aoconnect（66kB）
- 演示模块路径配置和依赖加载

### 3. 引擎池管理
- 演示JavetEnginePool的使用
- 并发执行多个JavaScript任务
- 展示资源池化管理

## 🔧 故障排除

### 1. 依赖问题
```bash
# 重新安装依赖
rm -rf node_modules package-lock.json
npm install @permaweb/aoconnect@0.0.90
```

### 2. 文件权限问题
```bash
# 确保脚本可执行
chmod +x scripts/prepare-aoconnect.sh
```

### 3. Java编译问题
```bash
# 清理并重新编译
mvn clean compile
```

### 4. Javet原生库问题
如果遇到 `Javet library not found` 错误，需要：
- 确保使用正确的Javet版本（当前3.1.6）
- 检查是否下载了正确的原生库文件
- 对于macOS，可能需要安装额外的依赖

```bash
# 检查Javet原生库
ls -la ~/.m2/repository/com/caoccao/javet/
```

### 5. 内存问题
如果遇到内存不足错误，尝试：
```bash
# 增加Java堆内存
java -Xmx2g -cp target/classes:target/dependency/* com.example.javetaodemo.JavetAOConnectDemo
```

## 📚 相关文档

- [Javet官方文档](https://www.caoccao.com/Javet/)
- [aoconnect SDK文档](https://cookbook_ao.g8way.io/guides/aoconnect/)
- [AO网络文档](https://docs.ao.computer/)

## 🔍 技术细节

### 依赖分析
- **aoconnect**: AO网络的JavaScript SDK
- **Javet**: Java中嵌入V8/Node.js的框架
- **集成方式**: 通过Javet在Java中执行aoconnect的JavaScript代码

### 版本信息
- **Javet**: 3.1.6
- **aoconnect**: 0.0.90
- **Node.js**: 18.0.0+
- **Java**: 11+

---

*创建时间: 2025年1月*
*最后更新: 2025年1月*
