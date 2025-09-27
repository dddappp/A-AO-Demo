#!/bin/bash

# Javet + aoconnect 集成演示运行脚本
# 运行完整的集成演示

set -e

echo "🚀 开始运行Javet + aoconnect集成演示"

# 检查Java是否安装
if ! command -v java &> /dev/null; then
    echo "❌ Java 未安装，请先安装 JDK 11+"
    exit 1
fi

echo "✅ Java 版本: $(java -version 2>&1 | head -1)"

# 检查Maven是否安装
if ! command -v mvn &> /dev/null; then
    echo "❌ Maven 未安装，请先安装 Maven"
    exit 1
fi

echo "✅ Maven 版本: $(mvn -v | head -1)"

# 编译项目
echo "🔨 编译项目..."
mvn compile

# 运行演示
echo "🎯 运行演示..."
java -cp target/classes:target/dependency/* com.example.javetaodemo.JavetAOConnectDemo

echo "✅ 演示完成！"

# 显示日志文件位置
if [ -f "logs/javet-aoconnect-demo.log" ]; then
    echo "📄 演示日志已保存到: logs/javet-aoconnect-demo.log"
fi
