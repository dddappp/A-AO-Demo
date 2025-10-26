#!/usr/bin/env markdown
# AO 自定义标签过滤测试

## 快速说明

验证 AO 网络是否过滤自定义标签（`X-SagaId`, `X-ResponseAction`, `X-NoResponseRequired`）。

**结论**：✅ 标签**完全保留**，不被过滤。标签名会进行大小写规范化（`X-SagaId` → `X-Sagaid`）。

## 运行方式

```bash
export HTTPS_PROXY=http://127.0.0.1:1235 HTTP_PROXY=http://127.0.0.1:1235 ALL_PROXY=socks5://127.0.0.1:1235
./test-tag-filtering.sh
```

## 关键 JSON 解析要点

### 问题 1：多个 JSON 对象
`ao-cli eval --wait` 返回两个 JSON 对象（等待确认 + 完整结果）
```bash
# ✅ 正确：取最后一个
RESULT=$(echo "$OUTPUT" | jq -s '.[-1]')
```

### 问题 2：提取数字
`Output.data` 是 JSON 字符串（带引号），需要 `jq -r` 去掉
```bash
# ❌ 错误
VALUE=$(echo "$RESULT" | jq '.data.result.Output.data')  # 得到 "1"

# ✅ 正确
VALUE=$(echo "$RESULT" | jq '.data.result.Output.data' | jq -r '.')  # 得到 1
```

### 问题 3：类型验证
必须验证是否为有效数字，否则立即报错
```bash
if ! [[ "$VALUE" =~ ^[0-9]+$ ]]; then
    echo "❌ 无效值: $VALUE"
    exit 1
fi
```

## 脚本流程

| 步骤 | 说明 |
|-----|------|
| 1-2 | 创建发送者和接收者进程 |
| 3 | 接收者加载 Handler，检查接收到的标签 |
| 4 | 发送者发送包含自定义标签的消息 |
| 5 | 验证消息中的标签（来自 `_RawTags`） |
| 6 | 等待接收者回复（最多 30 次，每次 2 秒） |
| 7 | 验证接收者收到的标签内容 |

## 代码示例

### 发送消息
```bash
SEND_OUTPUT=$(ao-cli eval "$SENDER_ID" --data "
Send({
    Target = '$RECEIVER_ID',
    Action = 'CheckTags',
    ['X-SagaId'] = 'saga-test-123',
    ['X-ResponseAction'] = 'ForwardToProxy',
    Data = 'test'
})
" --wait --json 2>/dev/null)
```

### 提取标签
```bash
# 从 eval 返回的 _RawTags 中提取
TAGS=$(echo "$SEND_OUTPUT" | jq -s '.[-1] | .data.result.Messages[0]._RawTags // []')

# 检查特定标签
SAGA_ID=$(echo "$TAGS" | jq -r '.[] | select(.name == "X-SagaId") | .value')
```

### 等待并查询 Inbox
```bash
# 获取初始长度
INITIAL=$(echo "$RAW" | jq -s '.[-1] | .data.result.Output.data' | jq -r '.')

# 轮询等待
for i in {1..30}; do
    CURRENT=$(ao-cli eval "$PID" --data "return #Inbox" --wait --json 2>/dev/null \
        | jq -s '.[-1] | .data.result.Output.data' | jq -r '.')
    if [ "$CURRENT" -gt "$INITIAL" ]; then
        echo "✅ 收到新消息"
        break
    fi
    sleep 2
done
```

## 常见错误

| 错误 | 原因 | 解决 |
|-----|------|------|
| `Cannot index string with string` | 没有用 `jq -s '.[-1]'` | 使用 `jq -s '.[-1]'` 获取最后 JSON |
| `[: value: integer expression expected` | 变量含引号或非数字 | 使用 `jq -r '.'` 去掉引号后验证 |
| 消息无法到达 | 网络延迟 | 增加等待时间（30×2秒 = 60秒） |
| Handler 输出没显示 | print 只在调用时显示 | 通过 Send() 回复并查询 Inbox |

## 测试结果示例

```
🔍 标签验证结果：
  发送时              →  接收时              →  值               →  状态
  ─────────────────────────────────────────────────────────────────────
  ✅ X-SagaId         →  X-SagaId          →  saga-test-123   →  ✓ 保留
  ✅ X-ResponseAction →  X-ResponseAction  →  ForwardToProxy  →  ✓ 保留
  ✅ X-NoResponseRequired → X-NoResponseRequired → false       →  ✓ 保留
```

## 关键发现

✅ AO 网络完全保留自定义标签  
✅ 标签在 `_RawTags` 字段中显示  
✅ 标签可安全用于 Saga 框架  
⚠️ 跨进程通信需要充足等待时间（60 秒）

