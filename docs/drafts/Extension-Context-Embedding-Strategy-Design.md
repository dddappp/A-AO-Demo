# Extension Context Embedding Strategy Design

**日期**: 2025-10-29
**状态**: 设计讨论阶段
**参与者**: AI Assistant, User

## 🎯 问题背景

在AO消息系统中，扩展上下文（Saga ID, Response Action等）需要在进程间传递。目前的实现将这些信息嵌入到消息的`Data`属性中，但这可能不是最优的传递方式。

## 📋 配置设计方案

### 方案评估

经过讨论，我们决定采用**方案C**：

**方案C: 保持原函数，新增单独的配置函数**
```lua
-- 保持原有API不变
get_target() → target_process_id

-- 新增配置函数
get_extension_context_embedding() → embedding_strategy
```

### 配置实现

**全局变量支持动态配置**：
```lua
-- 支持运行时通过Eval消息修改
INVENTORY_SERVICE_DEFAULT_EXTENSION_CONTEXT_EMBEDDING = INVENTORY_SERVICE_DEFAULT_EXTENSION_CONTEXT_EMBEDDING or "data"
INVENTORY_SERVICE_INVENTORY_ITEM_EXTENSION_CONTEXT_EMBEDDING = INVENTORY_SERVICE_INVENTORY_ITEM_EXTENSION_CONTEXT_EMBEDDING or "data"
INVENTORY_SERVICE_IN_OUT_EXTENSION_CONTEXT_EMBEDDING = INVENTORY_SERVICE_IN_OUT_EXTENSION_CONTEXT_EMBEDDING or "data"
```

**配置函数**：
```lua
local config = {
    -- 全局配置
    get_extension_context_embedding = function()
        return INVENTORY_SERVICE_DEFAULT_EXTENSION_CONTEXT_EMBEDDING
    end,
    set_extension_context_embedding = function(strategy)
        INVENTORY_SERVICE_DEFAULT_EXTENSION_CONTEXT_EMBEDDING = strategy
    end,

    inventory_item = {
        -- 服务特定配置
        get_extension_context_embedding = function()
            return INVENTORY_SERVICE_INVENTORY_ITEM_EXTENSION_CONTEXT_EMBEDDING
        end,
        set_extension_context_embedding = function(strategy)
            INVENTORY_SERVICE_INVENTORY_ITEM_EXTENSION_CONTEXT_EMBEDDING = strategy
        end,
        -- ... 其他现有配置
    },

    in_out = {
        -- 服务特定配置
        get_extension_context_embedding = function()
            return INVENTORY_SERVICE_IN_OUT_EXTENSION_CONTEXT_EMBEDDING
        end,
        set_extension_context_embedding = function(strategy)
            INVENTORY_SERVICE_IN_OUT_EXTENSION_CONTEXT_EMBEDDING = strategy
        end,
        -- ... 其他现有配置
    }
}
```

## 🔧 Messaging 模块重构

### 函数重构方案

**1. 原函数变更为内部local函数**：
```lua
-- messaging.lua 内部
local function embed_saga_info_in_data(request, saga_id, response_action)
    -- 专门处理Data嵌入逻辑
    local enhanced_data = request or {}
    enhanced_data[messaging.X_CONTEXT.SAGA_ID] = saga_id
    enhanced_data[messaging.X_CONTEXT.RESPONSE_ACTION] = response_action
    return enhanced_data
end
```

**2. 新增统一嵌入函数**：
```lua
-- Public API
function messaging.embed_saga_info(request, tags, embedding_strategy, saga_id, response_action)
    -- 参数顺序调整：request, tags, embedding_strategy, saga_id, response_action

    -- 策略验证和默认值处理
    if not embedding_strategy or embedding_strategy == "" then
        embedding_strategy = "direct_properties"  -- 默认策略
    end

    -- 初始化参数
    request = request or {}
    tags = tags or {}

    if embedding_strategy == "data" then
        -- 嵌入到Data属性
        request = embed_saga_info_in_data(request, saga_id, response_action)

    elseif embedding_strategy == "direct_properties" then
        -- 嵌入到消息直接属性
        request[X_CONTEXT_NORMALIZED_NAMES.SAGA_ID] = saga_id
        request[X_CONTEXT_NORMALIZED_NAMES.RESPONSE_ACTION] = response_action

    elseif embedding_strategy == "tags" then
        -- 添加到tags表
        tags[X_CONTEXT.SAGA_ID] = saga_id
        tags[X_CONTEXT.RESPONSE_ACTION] = response_action

    elseif embedding_strategy == "none" then
        -- 不嵌入任何信息
        -- 直接返回，不做任何修改

    else
        -- 无效策略，默认使用直接属性嵌入
        request[X_CONTEXT_NORMALIZED_NAMES.SAGA_ID] = saga_id
        request[X_CONTEXT_NORMALIZED_NAMES.RESPONSE_ACTION] = response_action
    end

    return request, tags
end
```

### 使用示例

**inventory_service.lua 中的使用**：
```lua
-- 获取配置
local embedding_strategy = inventory_item_config.get_extension_context_embedding()

-- 使用新API
local request, tags = messaging.embed_saga_info(
    request,
    tags,
    embedding_strategy,
    saga_id,
    callback_action
)

-- 发送消息
messaging.commit_send_or_error(status, request_or_error, commit, target, tags)
```

## 🎯 策略说明

### 支持的嵌入策略

| 策略 | 说明 | 使用场景 |
|------|------|----------|
| `"data"` | 嵌入到消息Data属性 | 当前默认，兼容现有代码 |
| `"direct_properties"` | 嵌入到消息直接属性 | 新推荐方式，规范化名称访问 |
| `"tags"` | 添加到tags表 | 通过commit_send_or_error处理 |
| `"none"` | 不嵌入 | 调试或特殊情况 |

### 策略选择逻辑

1. **优先级**: `direct_properties` > `data` > `tags` > `none`
2. **默认值**: 无效策略自动降级为 `direct_properties`
3. **兼容性**: 现有代码默认使用 `data` 策略

## 🔄 向后兼容性

### 保持原有API
```lua
-- 原有函数继续可用，用于兼容性
function messaging.embed_saga_info_in_data(request, saga_id, response_action)
    return embed_saga_info_in_data(request, saga_id, response_action)
end
```

### 迁移路径
1. **Phase 1**: 新增API，保持原有API不变
2. **Phase 2**: 逐步迁移调用点到新API
3. **Phase 3**: 考虑废弃旧API（如果需要）

## 💭 设计决策

### 为什么选择方案C？
- **API稳定性**: 不破坏现有调用
- **渐进式迁移**: 可以逐步采用新API
- **配置灵活性**: 支持全局和服务级配置

### 参数顺序设计
`request, tags, embedding_strategy, saga_id, response_action` 的顺序考虑：
- **输入优先**: request和tags是主要输入
- **配置其次**: embedding_strategy是控制参数
- **数据最后**: saga_id和response_action是业务数据

## 📝 待实现任务

- [ ] 在 `inventory_service_config.lua` 中添加配置函数
- [ ] 在 `messaging.lua` 中实现新API
- [ ] 在 `inventory_service.lua` 中迁移调用
- [ ] 更新相关文档
- [ ] 添加测试用例

## 🎉 总结

这个设计提供了灵活的扩展上下文嵌入策略，同时保持了向后兼容性。通过全局变量配置支持运行时动态调整，为不同的外部服务提供个性化的嵌入策略。统一的 `embed_saga_info` API 让代码更加清晰和可维护。
