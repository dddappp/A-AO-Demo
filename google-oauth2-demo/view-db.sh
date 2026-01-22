#!/bin/bash

# 查看SQLite数据库内容脚本
# 用法: ./view-db.sh [table_name]
# 如果不指定表名，则显示所有表和统计信息

DB_FILE="./dev-database.db"

if [ ! -f "$DB_FILE" ]; then
    echo "❌ 数据库文件 $DB_FILE 不存在"
    echo "请先启动应用以创建数据库"
    exit 1
fi

echo "📊 SQLite数据库: $DB_FILE"
echo "========================================"

# 检查sqlite3是否安装
if ! command -v sqlite3 &> /dev/null; then
    echo "❌ sqlite3 未安装，请安装后再试"
    echo "macOS: brew install sqlite"
    echo "Ubuntu: sudo apt install sqlite3"
    exit 1
fi

if [ $# -eq 0 ]; then
    # 显示所有表
    echo "📋 数据库中的表:"
    sqlite3 "$DB_FILE" ".tables"
    echo ""

    # 显示每张表的记录数
    echo "📈 表统计信息:"
    for table in $(sqlite3 "$DB_FILE" ".tables"); do
        count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM $table;")
        echo "  $table: $count 条记录"
    done
    echo ""

    # 显示users表内容
    echo "👥 Users表内容:"
    sqlite3 "$DB_FILE" "SELECT id, username, email, auth_provider FROM users;"
    echo ""

    # 显示user_authorities表内容
    echo "🔐 User Authorities表内容:"
    sqlite3 "$DB_FILE" "SELECT * FROM user_authorities;"
else
    TABLE_NAME="$1"
    echo "📋 表: $TABLE_NAME"
    echo "----------------------------------------"

    # 显示表结构
    echo "结构:"
    sqlite3 "$DB_FILE" ".schema $TABLE_NAME"
    echo ""

    # 显示表数据
    echo "数据:"
    sqlite3 "$DB_FILE" "SELECT * FROM $TABLE_NAME;" | head -20

    # 统计行数
    COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM $TABLE_NAME;")
    echo ""
    echo "总行数: $COUNT"
fi