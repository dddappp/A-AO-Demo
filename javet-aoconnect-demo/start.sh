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

# 创建日志目录
mkdir -p logs

# 编译并运行项目
echo "Compiling and running AO Demo..."
mvn clean compile exec:java

echo "AO Demo completed."
