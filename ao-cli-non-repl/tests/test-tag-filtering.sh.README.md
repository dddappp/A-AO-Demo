# AO 自定义标签过滤测试

## 概述

`test-tag-filtering.sh` 脚本用于验证 AO 网络是否会过滤自定义标签（如 `X-SagaId`, `X-ResponseAction`, `X-NoResponseRequired`）。

## 关键发现

### ✅ 标签完全保留

AO 网络**不过滤**自定义标签。在 `ao-cli eval` 的返回结果中，这些标签被完整保留在 `_RawTags` 字段中。

```json
{
  "Messages": [{
    "_RawTags": [
      { "name": "X-SagaId", "value": "saga-test-123" },
      { "name": "X-ResponseAction", "value": "ForwardToProxy" },
      { "name": "X-NoResponseRequired", "value": "false" }
    ]
  }]
}
```

## 关键 JSON 解析技巧

### 1. 处理多个 JSON 对象

`ao-cli eval --wait` 返回**两个** JSON 对象：
- 第一个：等待确认
- 第二个：完整结果

**解决方案**：使用 `jq -s '.[-1]'` 获取最后一个对象

```bash
RESULT=$(ao-cli eval "$PID" --data "return 1" --wait --json 2>/dev/null)
FINAL=$(echo "$RESULT" | jq -s '.[-1]')  # 获取最后一个 JSON 对象
```

### 2. 提取数字字段

`Output.data` 返回的是 JSON **字符串**（带引号），不是原生数字。

```bash
# ❌ 错误：会得到带引号的字符串 "1"
VALUE=$(echo "$RESULT" | jq -s '.[-1] | .data.result.Output.data')
echo "$VALUE"  # 输出: "1"

# ✅ 正确：用 jq -r 去掉引号
VALUE=$(echo "$RESULT" | jq -s '.[-1] | .data.result.Output.data' | jq -r '.')
echo "$VALUE"  # 输出: 1

# 数字比较前必须验证
if [[ "$VALUE" =~ ^[0-9]+$ ]]; then
    if [ "$VALUE" -gt 10 ]; then
        echo "Value is greater than 10"
    fi
fi
```

### 3. 严格的类型检查

不要依赖默认值。如果无法获取有效的数字，应该立即报错：

```bash
# ❌ 错误：容易隐藏问题
VALUE=$(echo "$RESULT" | jq '.data // "0"')

# ✅ 正确：严格验证
VALUE=$(echo "$RESULT" | jq '.data' | jq -r '.')
if ! [[ "$VALUE" =~ ^[0-9]+$ ]]; then
    echo "❌ 错误：无效的数据"
    exit 1
fi
```

### 4. 提取数组中的特定字段

在标签数组中查找特定标签：

```bash
# 从 _RawTags 数组中查找 X-SagaId
SAGA_ID=$(echo "$TAGS_JSON" | jq -r '.[] | select(.name | contains("SagaId")) | .value')
```

## 脚本流程

### 步骤 1-2: 创建进程
创建发送者和接收者两个独立进程。

### 步骤 3: 加载 Handler
在接收者进程中加载 Lua Handler，用于：
- 接收 `CheckTags` 消息
- 检查接收到的自定义标签
- 发送 `TagCheckResult` 回复消息

### 步骤 4: 发送消息
发送者通过 `Send()` 发送包含自定义标签的消息：

```lua
Send({
    Target = receiver_id,
    Action = 'CheckTags',
    ['X-SagaId'] = 'saga-test-123',
    ['X-ResponseAction'] = 'ForwardToProxy',
    Data = 'test'
})
```

### 步骤 5: 验证发送时的标签
从 `eval` 返回的 `_RawTags` 中提取标签，验证它们没有被过滤。

### 步骤 6: 等待并验证回复
- 记录初始 Inbox 长度
- 轮询检查 Inbox 长度增加（最多 30 次，每次间隔 2 秒）
- 查找来自接收者的 `TagCheckResult` 消息
- 解析接收者报告的收到的标签

## 关键代码片段

### 获取并验证数值

```bash
# 获取 Inbox 长度
LENGTH_RAW=$(ao-cli eval "$PID" --data "return #Inbox" --wait --json 2>/dev/null)
LENGTH=$(echo "$LENGTH_RAW" | jq -s '.[-1] | .data.result.Output.data' | jq -r '.')

# 验证是数字
if ! [[ "$LENGTH" =~ ^[0-9]+$ ]]; then
    echo "❌ 无效的 Inbox 长度: $LENGTH"
    exit 1
fi

echo "Inbox 长度: $LENGTH"
```

### 从发送消息中提取标签

```bash
# 发送消息并捕获完整返回
SEND_OUTPUT=$(ao-cli eval "$SENDER_ID" --data "
Send({
    Target = '$RECEIVER_ID',
    Action = 'CheckTags',
    ['X-SagaId'] = 'test-123',
    Data = 'test'
})
" --wait --json 2>/dev/null)

# 从返回的 Messages 中提取 _RawTags
TAGS_JSON=$(echo "$SEND_OUTPUT" | jq -s '.[-1] | .data.result.Messages[0]._RawTags // []' 2>/dev/null)

# 验证特定标签
SAGA_ID=$(echo "$TAGS_JSON" | jq -r '.[] | select(.name == "X-SagaId") | .value' 2>/dev/null)
```

### 解析接收者的回复

```bash
# 查询 Inbox 中的回复消息
REPLY_JSON=$(ao-cli eval "$SENDER_ID" --data "
local result = {}
for i, msg in ipairs(Inbox) do
    if msg.Action == 'TagCheckResult' and msg.From == '$RECEIVER_ID' then
        table.insert(result, { data = msg.Data })
    end
end
return json.encode(result)
" --wait --json 2>/dev/null)

# 提取并解析
REPLY_DATA=$(echo "$REPLY_JSON" | jq -s '.[-1] | .data.result.Output.data' | jq -r '.' | jq 'fromjson?' 2>/dev/null)
echo "$REPLY_DATA" | jq '.received_custom_tags'
```

## 常见错误和解决方案

### 错误 1: "Cannot index string with string"

**原因**：`Output` 被当作字符串而非对象
**解决**：确保使用 `jq -s '.[-1]'` 获取最后一个 JSON 对象

### 错误 2: "[: <value>: integer expression expected"

**原因**：变量包含引号或非数字值
**解决**：使用 `jq -r '.'` 去掉引号，并验证是否为数字

```bash
VALUE=$(echo "$RESULT" | jq -s '.[-1] | .value' | jq -r '.')
if ! [[ "$VALUE" =~ ^[0-9]+$ ]]; then
    exit 1
fi
```

### 错误 3: 消息永远无法到达接收者

**原因**：进程间通信延迟，或网络问题
**解决**：
- 使用充足的等待时间（最多 30 次，每次 2 秒 = 60 秒）
- 验证网络代理设置
- 检查网络连接

### 错误 4: Handler 的 print 输出没有显示

**原因**：print 输出只在调用 eval 时显示，不会在后续 eval 中出现
**解决**：通过 `Send()` 回复消息，在接收端查询 Inbox 来验证

## 运行脚本

```bash
# 设置网络代理（如果需要）
export HTTPS_PROXY=http://127.0.0.1:1235
export HTTP_PROXY=http://127.0.0.1:1235
export ALL_PROXY=socks5://127.0.0.1:1235

# 执行脚本
./test-tag-filtering.sh
```

## 测试结果

脚本会输出标签验证结果：

```
🔍 标签验证结果：

  发送时              →  接收时              →  值               →  状态
  ─────────────────────────────────────────────────────────────────────
  ✅ X-SagaId         →  X-SagaId          →  saga-test-123   →  ✓ 保留
  ✅ X-ResponseAction →  X-ResponseAction  →  ForwardToProxy  →  ✓ 保留
  ✅ X-NoResponseRequired → X-NoResponseRequired → false       →  ✓ 保留
```

## 总结

- ✅ AO 网络**完全保留**自定义标签
- ✅ 标签可以安全地用于 Saga 框架
- ✅ 不需要在 Data 字段中嵌入这些信息
- ⚠️ 跨进程消息传递有网络延迟，需要充足的等待时间

