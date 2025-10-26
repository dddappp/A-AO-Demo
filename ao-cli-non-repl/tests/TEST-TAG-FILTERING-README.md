# AO 自定义标签过滤测试

## 概述

这个测试脚本用于验证 AO 网络是否会过滤自定义标签（X-SagaId, X-ResponseAction, X-NoResponseRequired）。这对于 Saga 框架的实现和分布式事务处理至关重要。

## 文件

- `test-tag-filtering.sh` - 自动化测试脚本

## 使用方法

### 前置条件

1. AO CLI 工具已安装：
   ```bash
   npm link  # 在 ao-cli 代码库目录下
   ```

2. 钱包文件存在：`~/.aos.json`

3. 网络连接（如果需要代理）：
   ```bash
   export HTTPS_PROXY=http://127.0.0.1:1235
   export HTTP_PROXY=http://127.0.0.1:1235
   export ALL_PROXY=socks5://127.0.0.1:1235
   ```

### 运行测试

```bash
cd /Users/yangjiefeng/Documents/dddappp/A-AO-Demo/ao-cli-non-repl/tests
./test-tag-filtering.sh
```

## 测试流程

### 步骤 1-2：创建进程
- 创建**发送者进程**（Sender）
- 创建**接收者进程**（Receiver）

### 步骤 3：加载接收者代码
接收者进程加载一个 Lua handler，用于检查接收到的消息标签：

```lua
Handlers.add("DebugTags", ..., function(msg)
    local result = {
        checked_fields = {
            ["X-SagaId"] = msg["X-SagaId"],
            ["X-ResponseAction"] = msg["X-ResponseAction"],
            ["X-NoResponseRequired"] = msg["X-NoResponseRequired"],
            ...
        }
    }
    msg.reply({ Data = json.encode(result) })
end)
```

### 步骤 4：发送测试消息
从发送者进程向接收者进程发送包含自定义标签的消息：

```lua
Send({
    Target = receiver_id,
    Action = 'DebugTags',
    Tags = {
        ['X-SagaId'] = 'saga-123',
        ['X-ResponseAction'] = 'TestResponse',
        ['X-NoResponseRequired'] = 'true'
    }
})
```

### 步骤 5-7：检查结果
查询接收者的 Inbox，查看消息中是否包含这些自定义标签。

## 预期结果

### 情景 A：标签被过滤（当前已知情况）

接收到的消息中：
```json
{
    "X-SagaId": null,
    "X-ResponseAction": null,
    "X-NoResponseRequired": null,
    "Action": "DebugTags",  // 标准标签保留
    "From": "..."            // 标准标签保留
}
```

**结论**：AO 网络过滤了自定义标签！

**解决方案**：在 `Data` 字段中嵌入 Saga 信息，而不是在 Tags 中。
参考：`src/messaging.lua` 中的 `embed_saga_info_in_data()` 函数

### 情景 B：标签保留（理想情况）

接收到的消息中：
```json
{
    "X-SagaId": "saga-123",
    "X-ResponseAction": "TestResponse",
    "X-NoResponseRequired": "true",
    "Action": "DebugTags",
    "From": "..."
}
```

## 技术细节

### 消息处理流程

1. **发送方**：使用 `Send()` 在 Tags 中设置自定义标签
2. **AO 网络**：处理消息时可能过滤自定义标签
3. **接收方**：通过 `msg["X-SagaId"]` 尝试访问标签

### 相关代码

**messaging.lua - 推荐方法**：
```lua
-- 在 Data 字段中嵌入 Saga 信息
function embed_saga_info_in_data(msg, saga_info)
    local data = json.decode(msg.Data or "{}")
    data._saga = saga_info
    msg.Data = json.encode(data)
    return msg
end
```

## 诊断步骤

如果测试失败或输出不清晰，可以：

1. **检查Inbox内容**（手动）：
   ```bash
   ao-cli eval RECEIVER_ID --data "return Inbox" --wait --json
   ```

2. **查看最后消息**：
   ```bash
   ao-cli inbox RECEIVER_ID --latest --json
   ```

3. **调试消息发送**：
   查看发送过程的 `eval` 输出，确认消息格式正确

## 参考资源

- AO CLI 文档：`/Users/yangjiefeng/Documents/dddappp/ao-cli/README.md`
- Saga 实现：`src/saga.lua`
- 消息处理：`src/messaging.lua`
- 技术分析：`ao-cli-non-repl/tests/SAGA-TECHNICAL-ANALYSIS.md`

## 已知问题

✅ **已确认**：AO 网络过滤自定义标签

📝 **解决方案**：使用 Data 字段嵌入 Saga 信息

🔍 **相关分析**：见 `SAGA-TECHNICAL-ANALYSIS.md`

## 贡献

如果发现此脚本的问题或有改进建议，请提交 PR。

