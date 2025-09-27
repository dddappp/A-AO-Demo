#!/bin/bash

# Javet + aoconnect 集成演示项目预处理脚本
# 此脚本准备演示项目所需的aoconnect文件

set -e

echo "🚀 开始准备aoconnect集成演示项目"

# 检查 Node.js 是否安装
if ! command -v node &> /dev/null; then
    echo "❌ Node.js 未安装，请先安装 Node.js 18+ 版本"
    exit 1
fi

echo "✅ Node.js 版本: $(node --version)"

# 检查 npm 是否可用
if ! command -v npm &> /dev/null; then
    echo "❌ npm 未安装"
    exit 1
fi

echo "✅ npm 版本: $(npm --version)"

# 安装aoconnect依赖
echo "📦 安装 @permaweb/aoconnect..."
if [ ! -d "node_modules/@permaweb" ]; then
    npm install @permaweb/aoconnect@0.0.90
    echo "✅ 已安装 @permaweb/aoconnect@0.0.90"
else
    echo "✅ @permaweb/aoconnect 已经安装"
fi

# 创建资源目录
echo "📁 创建资源目录..."
mkdir -p src/main/resources/js

# 复制aoconnect文件
echo "📋 复制aoconnect文件..."

# 方案1: 浏览器版本（V8模式推荐）
if [ -f "node_modules/@permaweb/aoconnect/dist/browser.js" ]; then
    cp node_modules/@permaweb/aoconnect/dist/browser.js src/main/resources/js/aoconnect.browser.js
    echo "✅ 已复制浏览器版本: src/main/resources/js/aoconnect.browser.js"
    echo "   文件大小: $(wc -c < src/main/resources/js/aoconnect.browser.js) bytes"
else
    echo "❌ 浏览器版本文件不存在"
fi

# 方案2: ESM版本（Node.js模式）
if [ -f "node_modules/@permaweb/aoconnect/dist/index.js" ]; then
    cp node_modules/@permaweb/aoconnect/dist/index.js src/main/resources/js/aoconnect.esm.js
    echo "✅ 已复制ESM版本: src/main/resources/js/aoconnect.esm.js"
    echo "   文件大小: $(wc -c < src/main/resources/js/aoconnect.esm.js) bytes"
else
    echo "❌ ESM版本文件不存在"
fi

# 创建模块路径配置脚本
cat > src/main/resources/js/module-setup.js << 'EOF'
// Javet演示项目模块路径配置
// 这个文件用于在Javet中配置Node.js模块搜索路径

console.log('🔧 配置Node.js模块搜索路径...');

// 添加项目node_modules路径
require('module').globalPaths.push(process.cwd() + '/node_modules');

// 加载aoconnect
try {
    global.aoconnect = require('@permaweb/aoconnect');
    console.log('✅ aoconnect模块加载成功');
} catch (error) {
    console.error('❌ aoconnect模块加载失败:', error.message);
    throw error;
}

console.log('📍 模块搜索路径:', require('module').globalPaths);
EOF

echo "✅ 已创建模块路径配置脚本: src/main/resources/js/module-setup.js"

# 创建测试脚本
cat > test-aoconnect-integration.js << 'EOF'
// 测试aoconnect集成是否正常工作
const assert = require('assert');

async function testAOConnectIntegration() {
    console.log('🧪 测试aoconnect集成...');

    try {
        // 测试模块是否正确加载
        assert(global.aoconnect, 'aoconnect模块未加载');
        assert(global.aoconnect.spawn, 'spawn函数不存在');
        assert(global.aoconnect.message, 'message函数不存在');
        assert(global.aoconnect.result, 'result函数不存在');

        console.log('✅ 基础模块加载测试通过');

        // 测试基本功能（不实际调用网络）
        console.log('✅ aoconnect集成测试完成');

        return true;
    } catch (error) {
        console.error('❌ 测试失败:', error.message);
        throw error;
    }
}

// 如果直接运行此脚本
if (require.main === module) {
    testAOConnectIntegration()
        .then(() => process.exit(0))
        .catch(() => process.exit(1));
}

module.exports = { testAOConnectIntegration };
EOF

echo "✅ 已创建测试脚本: test-aoconnect-integration.js"

# 创建演示说明
cat > README.md << 'EOF'
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
# 方法1: 使用Maven
mvn compile exec:java

# 方法2: 编译后运行
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

### 4. 内存问题
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
