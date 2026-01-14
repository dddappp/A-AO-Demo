#!/bin/bash

# 启动脚本 - 包含前端构建和后端启动
# 用于前后端一体化部署模式

set -e  # 遇到错误立即退出

echo "🚀 启动OAuth2演示应用（前后端一体化模式）..."

# 检查Java是否安装
if ! command -v java &> /dev/null; then
    echo "❌ 错误: Java 未安装。请先安装 Java 17+"
    exit 1
fi

# 检查Maven是否安装
if ! command -v mvn &> /dev/null; then
    echo "❌ 错误: Maven 未安装。请先安装 Maven"
    exit 1
fi

echo "🔨 构建前端..."
./build-frontend.sh

echo "🔧 构建后端..."
mvn clean compile -q

echo "🏃 启动Spring Boot应用..."
echo "📱 前端访问地址: http://localhost:8081"
echo "🔗 后端API地址: http://localhost:8081/api"
echo "⚠️  使用 Ctrl+C 停止应用"
echo ""

echo "⚠️  请确保设置以下环境变量："
echo "   export GOOGLE_CLIENT_ID='your-google-client-id'"
echo "   export GOOGLE_CLIENT_SECRET='your-google-client-secret'"
echo "   export GITHUB_CLIENT_ID='your-github-client-id'"
echo "   export GITHUB_CLIENT_SECRET='your-github-client-secret'"
echo "   export TWITTER_CLIENT_ID='your-twitter-client-id'"
echo "   export TWITTER_CLIENT_SECRET='your-twitter-client-secret'"
echo ""

# 检查环境变量
if [ -z "$GOOGLE_CLIENT_ID" ] || [ -z "$GOOGLE_CLIENT_SECRET" ] || \
   [ -z "$GITHUB_CLIENT_ID" ] || [ -z "$GITHUB_CLIENT_SECRET" ] || \
   [ -z "$TWITTER_CLIENT_ID" ] || [ -z "$TWITTER_CLIENT_SECRET" ]; then
    echo "❌ 错误: 环境变量未设置"
    echo "请先设置环境变量，然后重新运行此脚本"
    exit 1
fi

mvn spring-boot:run
