#!/bin/bash

# AO Demo 启动脚本
# 此脚本用于启动 AO Demo 应用程序

echo "Starting AO Demo Application..."

# 检查 Java 是否安装
if ! command -v java &> /dev/null; then
    echo "Error: Java is not installed or not in PATH"
    exit 1
fi

# 检查 Maven 是否安装
if ! command -v mvn &> /dev/null; then
    echo "Error: Maven is not installed or not in PATH"
    exit 1
fi

# 设置代理环境变量（如果需要）
echo "Setting proxy environment variables..."
export HTTPS_PROXY=http://127.0.0.1:1235
export HTTP_PROXY=http://127.0.0.1:1235
export ALL_PROXY=socks5://127.0.0.1:1234

echo "Proxy configuration:"
echo "  HTTPS_PROXY: $HTTPS_PROXY"
echo "  HTTP_PROXY: $HTTP_PROXY"
echo "  ALL_PROXY: $ALL_PROXY"

# 创建日志目录
mkdir -p logs

# 编译并运行项目
echo "Compiling and running AO Demo..."
mvn clean compile exec:java

echo "AO Demo completed."
