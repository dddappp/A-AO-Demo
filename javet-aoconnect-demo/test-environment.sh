#!/bin/bash

# Javet + aoconnect 集成演示环境检查脚本
# 检查运行演示项目所需的所有环境和依赖

set -e

echo "🔍 开始环境检查..."

# 检查Java
echo "☕ 检查Java..."
if ! command -v java &> /dev/null; then
    echo "❌ Java 未安装，请先安装 JDK 11+"
    exit 1
fi
echo "✅ Java 版本: $(java -version 2>&1 | head -1)"

# 检查Maven
echo "🔧 检查Maven..."
if ! command -v mvn &> /dev/null; then
    echo "❌ Maven 未安装，请先安装 Maven"
    exit 1
fi
echo "✅ Maven 版本: $(mvn -v | head -1)"

# 检查Node.js
echo "🟢 检查Node.js..."
if ! command -v node &> /dev/null; then
    echo "❌ Node.js 未安装，请先安装 Node.js 18+"
    exit 1
fi
echo "✅ Node.js 版本: $(node --version)"

# 检查npm
echo "📦 检查npm..."
if ! command -v npm &> /dev/null; then
    echo "❌ npm 未安装"
    exit 1
fi
echo "✅ npm 版本: $(npm --version)"

# 检查aoconnect安装
echo "🌐 检查aoconnect..."
if [ ! -d "node_modules/@permaweb" ]; then
    echo "⚠️  aoconnect 未安装，运行预处理脚本..."
    ./scripts/prepare-aoconnect.sh
fi

# 检查aoconnect文件
echo "📋 检查aoconnect文件..."
if [ -f "src/main/resources/js/aoconnect.browser.js" ]; then
    echo "✅ 浏览器版本aoconnect: $(wc -c < src/main/resources/js/aoconnect.browser.js) bytes"
else
    echo "❌ 浏览器版本aoconnect不存在"
    exit 1
fi

if [ -f "src/main/resources/js/aoconnect.esm.js" ]; then
    echo "✅ ESM版本aoconnect: $(wc -c < src/main/resources/js/aoconnect.esm.js) bytes"
else
    echo "❌ ESM版本aoconnect不存在"
    exit 1
fi

# 检查Maven依赖
echo "🏗️ 检查Maven依赖..."
if [ ! -d "target/dependency" ]; then
    echo "📥 下载Maven依赖..."
    mvn dependency:copy-dependencies
fi

# 检查Javet原生库
echo "🔗 检查Javet原生库..."
if [ ! -d "$HOME/.m2/repository/com/caoccao/javet" ]; then
    echo "⚠️  Javet原生库未找到，尝试编译项目下载..."
    mvn compile
else
    echo "✅ Javet原生库已存在"
fi

# 运行测试
echo "🧪 运行集成测试..."
node test-aoconnect-integration.js

echo "✅ 环境检查完成！可以运行演示项目了。"

echo ""
echo "🚀 运行演示项目的命令："
echo "  ./run-demo.sh"
echo "  或"
echo "  mvn compile exec:java"
