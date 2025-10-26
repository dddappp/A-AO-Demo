# 🧪 AO 自定义标签过滤测试 - 最终结果

## ✅ 测试完成

脚本执行成功，得到了决定性的结果。

## 📊 关键发现

### 结论：**AO 不过滤自定义标签**

✅ **发送的自定义标签完全保留在接收端**

#### 标签映射（大小写规范化）

| 发送时标签名 | 接收时标签名 | 值 | 状态 |
|-----------|------------|-----|------|
| X-SagaId | X-Sagaid | "saga-123" | ✅ 保留 |
| X-ResponseAction | X-Responseaction | "TestResponse" | ✅ 保留 |
| X-NoResponseRequired | X-Noresponserequired | "true" | ✅ 保留 |

### 重要发现：大小写规范化

AO 网络对标签名进行了标准化处理：
- **首字母大写**：`X-` 保持，后续首字母大写
- **其他字母小写**：中间的字母全部小写
- **破折号保留**：`-` 符号保持不变

```lua
-- 发送时
Tags = {
    ['X-SagaId'] = 'saga-123',           -- 发送端看法
    ['X-ResponseAction'] = 'TestResponse',
    ['X-NoResponseRequired'] = 'true'
}

-- 接收时（同一条消息）
X-Sagaid = "saga-123",                  -- 接收端看法（标准化后）
X-Responseaction = "TestResponse",
X-Noresponserequired = "true",

-- 在 msg.Tags 中
Tags = {
    X-Sagaid = "saga-123",              -- Tags 字典中的键名也被规范化
    X-Responseaction = "TestResponse",
    X-Noresponserequired = "true"
}
```

## 📝 Lua 中的访问方式

### 在接收进程中访问标签

```lua
Handlers.add(
    "DebugTags",
    Handlers.utils.byType("Message"),
    function(msg)
        -- 方式1：直接访问消息顶级属性（推荐）
        local saga_id = msg["X-Sagaid"]           -- 使用规范化后的名称
        local response_action = msg["X-Responseaction"]
        local no_response = msg["X-Noresponserequired"]
        
        -- 方式2：通过 msg.Tags 访问
        local saga_id_v2 = msg.Tags["X-Sagaid"]
        
        -- 方式3：遍历所有标签
        for key, value in pairs(msg.Tags) do
            if key:lower():find("x-saga") then
                print("Found saga tag: " .. value)
            end
        end
        
        msg.reply({
            Data = json.encode({
                saga_id = saga_id,
                response_action = response_action,
                no_response = no_response
            })
        })
    end
)
```

## 💡 对项目的影响

### 现状
之前认为 AO 会过滤自定义标签，所以在 `src/messaging.lua` 中使用了 Data 字段嵌入 Saga 信息。

### 新认知
❌ **AO 不过滤自定义标签！**

这意味着可以安全地使用标签传递 Saga 相关信息，而不需要额外的 Data 嵌入。

### 建议方案

1. **保持现状**（稳妥）
   - 继续使用 Data 字段嵌入 Saga 信息
   - 已经验证过的方案，风险最低

2. **重构为标签方案**（优化）
   - 直接使用标签传递 Saga ID、响应动作等
   - 更加简洁和高效
   - 需要注意标签名称的大小写规范化

## 🔬 测试详情

### 测试代码
```bash
# 发送过程
Send({
    Target = 'receiver_process_id',
    Action = 'TestAction',
    Tags = {
        Action = 'DebugTags',
        ['X-SagaId'] = 'saga-123',
        ['X-ResponseAction'] = 'TestResponse',
        ['X-NoResponseRequired'] = 'true'
    },
    Data = 'Test message with custom tags'
})
```

### 接收过程（Inbox 中的完整消息）

```lua
{
    X-Sagaid = "saga-123",
    X-Noresponserequired = "true",
    X-Responseaction = "TestResponse",
    Action = "DebugTags",
    Data = "Test message with custom tags",
    Tags = {
        X-Sagaid = "saga-123",
        X-Responseaction = "TestResponse",
        X-Noresponserequired = "true",
        Action = "DebugTags"
    },
    -- ... 其他系统标签
}
```

## 📋 验证清单

- ✅ 脚本无错误运行完成
- ✅ 消息成功发送
- ✅ 接收端收到消息
- ✅ 自定义标签完整保留
- ✅ 标签大小写规范化验证
- ✅ msg.Tags 字典访问正常
- ✅ 消息顶级属性访问正常

## 🎯 下一步建议

1. **更新 messaging.lua 文档**
   - 记录新发现：标签不被过滤
   - 说明大小写规范化规则

2. **考虑优化方案**
   - 可选：重构为更直接的标签方案
   - 或：保持现有 Data 嵌入方案

3. **单元测试**
   - 添加标签过滤行为测试
   - 验证大小写规范化

## 📚 参考文件

- **测试脚本**：`test-tag-filtering.sh`
- **被测试代码**：`src/messaging.lua`
- **测试输出日志**：`/tmp/tag-test-output.log`

---

**测试时间**：2025-10-26  
**测试环境**：AO Network (ao-cli 1.1.0)  
**代理**：http://127.0.0.1:1235  
**结论**：✅ 所有自定义标签保留，只有大小写规范化

