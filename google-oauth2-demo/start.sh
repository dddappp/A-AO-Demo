#!/bin/bash

# Google OAuth2 Demo 启动脚本
echo "=== Google OAuth2 Demo 启动脚本 ==="

# 项目根目录
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_SECRET_FILE="$PROJECT_DIR/../docs/client_secret_864964610919-fe6l31cv6ervqflfjpd9ov9sun9olqa7.apps.googleusercontent.com.json"

echo "项目目录: $PROJECT_DIR"
echo "客户端密钥文件: $CLIENT_SECRET_FILE"

# 检查客户端密钥文件是否存在
if [ ! -f "$CLIENT_SECRET_FILE" ]; then
    echo "错误: 客户端密钥文件不存在: $CLIENT_SECRET_FILE"
    exit 1
fi

# 读取客户端配置
echo "读取 Google OAuth2 客户端配置..."
CLIENT_ID=$(cat "$CLIENT_SECRET_FILE" | grep -o '"client_id":"[^"]*"' | cut -d'"' -f4)
CLIENT_SECRET=$(cat "$CLIENT_SECRET_FILE" | grep -o '"client_secret":"[^"]*"' | cut -d'"' -f4)

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
    echo "错误: 无法从配置文件中读取客户端 ID 或密钥"
    exit 1
fi

echo "客户端 ID: $CLIENT_ID"
echo "客户端密钥: ${CLIENT_SECRET:0:10}..."

# 设置环境变量并启动应用
echo "设置环境变量并启动 Spring Boot 应用..."
export GOOGLE_CLIENT_ID="$CLIENT_ID"
export GOOGLE_CLIENT_SECRET="$CLIENT_SECRET"

echo "环境变量设置完成:"
echo "  GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID"
echo "  GOOGLE_CLIENT_SECRET=***"

# 编译并启动应用
echo "编译项目..."
cd "$PROJECT_DIR"
mvn clean compile

if [ $? -ne 0 ]; then
    echo "错误: Maven 编译失败"
    exit 1
fi

echo "启动 Spring Boot 应用..."
echo "应用将在 http://localhost:8081 上运行"
echo "按 Ctrl+C 停止应用"
echo ""

mvn spring-boot:run
