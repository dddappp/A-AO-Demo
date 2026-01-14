#!/bin/bash

# 前端构建脚本
# 用于将React前端构建并集成到Spring Boot应用中

set -e  # 遇到错误立即退出

echo "🚀 开始构建前端..."

# 检查Node.js是否安装
if ! command -v node &> /dev/null; then
    echo "❌ 错误: Node.js 未安装。请先安装 Node.js 16+"
    exit 1
fi

# 检查npm是否安装
if ! command -v npm &> /dev/null; then
    echo "❌ 错误: npm 未安装。请先安装 npm"
    exit 1
fi

# 进入前端目录
cd frontend

echo "📦 安装依赖..."
npm install

echo "🔨 构建前端..."
npm run build

echo "✅ 前端构建完成！"
echo "📁 静态文件已输出到: ../src/main/resources/static/"

# 返回项目根目录
cd ..

echo "🎉 前端集成完成！现在可以启动Spring Boot应用了。"
echo "启动命令: ./start.sh"
