# An AO Dapp Development Demo with a Low-Code Approach


## 前置条件

安装：

* 安装 [aos](https://cookbook_ao.g8way.io/welcome/getting-started.html)
* Install [Docker](https://docs.docker.com/engine/install/).


启动一个 aos 进程：

```shell
aos process_alice
```

让我们记下它的进程 ID，比如 `DH4EI_kDShcHFf7FZotIjzW3lMoy4fLZKDA0qqTPt1Q`，我们在下面的示例命令中使用占位符 `__PROGRESS_ALICE__` 表示它。



## 编码

### 编写 DDDML 模型

见 `./dddml/a-ao-demo.yaml`.

> **Tip**
>
> About DDDML, here is an introductory article: ["Introducing DDDML: The Key to Low-Code Development for Decentralized Applications"](https://github.com/wubuku/Dapp-LCDP-Demo/blob/main/IntroducingDDDML.md).


### 生成代码

执行：

```shell
docker run \
-v .:/myapp \
wubuku/dddappp-ao:0.0.1 \
--dddmlDirectoryPath /myapp/dddml \
--boundedContextName A.AO.Demo \
--aoLuaProjectDirectoryPath /myapp/src
```

### 填充业务逻辑

修改文件 `./src/article_update_body_logic.lua`，在函数体中填充业务逻辑：

```lua
function article_update_body_logic.verify(_state, body, cmd, msg, env)
    return article.new_article_body_updated(_state, body)
end

function article_update_body_logic.mutate(state, event, msg, env)
    state.body = event.body
    return state
end
```

修改文件 `./src/inventory_service_local.lua`，在函数体中填充业务逻辑：

```lua
function inventory_item_add_inventory_item_entry_logic.verify(_state, inventory_item_id, movement_quantity, cmd, msg, env)
    return inventory_item.new_inventory_item_entry_added(inventory_item_id, _state, movement_quantity)
end

function inventory_item_add_inventory_item_entry_logic.mutate(state, event, msg, env)
    if (not state) then
        state = inventory_item.new(event.inventory_item_id, event.movement_quantity)
    else
        state.quantity = (state.quantity or 0) + event.movement_quantity
    end
    if (not state.entries) then
        state.entries = {}
    end
    local entry = {
        movement_quantity = event.movement_quantity,
    }
    state.entries[#state.entries + 1] = entry
    return state
end
```

修改文件 `./src/inventory_service_local.lua`，在函数体中填充业务逻辑：

```lua
function inventory_service_local.process_inventory_surplus_or_shortage_prepare_get_inventory_item_request(context)
    local _inventory_item_id = {
        product_id = context.product_id,
        location = context.location,
    }
    context.inventory_item_id = _inventory_item_id
    return _inventory_item_id
end

function inventory_service_local.process_inventory_surplus_or_shortage_on_get_inventory_item_reply(context, result)
    context.item_version = result.version -- NOTE: The name of the field IS "version"!
    local on_hand_quantity = result.quantity
    local adjusted_quantity = context.quantity

if (adjusted_quantity == on_hand_quantity) then -- NOTE: short-circuit if no changed
        local short_circuited = true
        local is_error = false
        -- If the original request requires a result, provide one here if a short circuit occurs.
        local result_or_error = "adjusted_quantity == on_hand_quantity"
        return short_circuited, is_error, result_or_error
    end

    local movement_quantity = adjusted_quantity > on_hand_quantity and
        adjusted_quantity - on_hand_quantity or
        on_hand_quantity - adjusted_quantity
    context.movement_quantity = movement_quantity
end
```

修改文件 `./src/inventory_service_local.lua`：

```lua
Handlers.add(
    "create_single_line_in_out",
    Handlers.utils.hasMatchingTag("Action", "CreateSingleLineInOut"),
    function(msg, env, response)
        messaging.respond(true, {
            in_out_id = 1,
            version = 0,
        }, msg)
        -- messaging.respond(false, "TEST_CREATE_SINGLE_LINE_IN_OUT_ERROR", msg) -- error
    end
)
```

修改文件 `./src/inventory_service_config.lua`：

```lua
return {
    inventory_item = {
        get_target = function()
            return "DH4EI_kDShcHFf7FZotIjzW3lMoy4fLZKDA0qqTPt1Q" -- <- Fill in the __PROGRESS_ALICE__
        end,
        -- ...
    },
    in_out = {
        get_target = function()
            return "DH4EI_kDShcHFf7FZotIjzW3lMoy4fLZKDA0qqTPt1Q" -- <- Fill in the __PROGRESS_ALICE__
        end,
        -- ...
    }
}
```

## 测试应用

启动另一个 aos 进程：

```shell
aos process_bob
```

记录下它的进程 ID，比如 `u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4`，我们在下面的示例命令中可能会使用占位符 `__PROGRESS_BOB__` 表示它。

在这个 aos (`__PROGRESS_BOB__`) 进程中，装载我们的应用（注意将 `{PATH/TO/A-AO-Demo/src}` 替换为实际的路径）：

```lua
.load {PATH/TO/A-AO-Demo/src}/a_ao_demo.lua
```

现在，可以在第一个进程（`__PROGRESS_ALICE__`）中，向 `__PROGRESS_BOB__` 发送消息进行测试。


### “文章”相关的测试

在第一个进程（`__PROGRESS_ALICE__`）中，查看另外一个进程中的当前“文章的序号”：

```lua
json = require("json")
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetArticleIdSequence" } })
```

你会收到类似这样的回复：

```text
New Message From u37...zs4: Data = {"result":[0]}
```

创建一篇新文章：

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "CreateArticle" }, Data = json.encode({ title = "title_1", body = "body_1" }) })
```

在收到回复后，查看最后一条收件箱消息的内容：

```lua
Inbox[#Inbox]
```

查看当前“文章的序号”：

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetArticleIdSequence" } })
```

查看序号为 `1` 的文章的内容（在输出消息的 `Data` 属性中）：

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetArticle" }, Data = json.encode(1) })
Inbox[#Inbox]
```

更新序号为 `1` 的文章的内容（注意 `version` 的值应该与上面看到的当前文章的版本号一致）：


```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "UpdateArticleBody" }, Data = json.encode({ article_id = 1, version = 0, body = "new_body_1" }) })
```

再次查看序号为 `1` 的文章的内容：

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetArticle" }, Data = json.encode(1) })
Inbox[#Inbox]
```

### “库存”相关的测试

在进程 `__PROGRESS_ALICE__` 中执行下面的命令，通过“添加库存项目条目”来更新库存项目：

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "AddInventoryItemEntry" }, Data = json.encode({ inventory_item_id = { product_id = 1, location = "x" }, movement_quantity = 100}) })

Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "AddInventoryItemEntry" }, Data = json.encode({ inventory_item_id = { product_id = 1, location = "x" }, movement_quantity = 130, version = 0}) })

Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "AddInventoryItemEntry" }, Data = json.encode({ inventory_item_id = { product_id = 1, location = "x", inventory_attribute_set = { foo = "foo", bar = "bar" } }, movement_quantity = 100}) })

Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "AddInventoryItemEntry" }, Data = json.encode({ inventory_item_id = { product_id = 1, location = "x", inventory_attribute_set = { foo = "foo", bar = "bar" } }, movement_quantity = 101, version = 0}) })
```

查看库存项目的内容：

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetInventoryItem" }, Data = json.encode({ product_id = 1, location = "x" }) })
-- Inbox[#Inbox]

Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetInventoryItem" }, Data = json.encode({ product_id = 1, location = "x", inventory_attribute_set = { foo = "foo", bar = "bar" } }) })
-- Inbox[#Inbox]
```

### 手动发送消息测试 Saga

我们先通过手动发送消息来逐步测试和观察 Saga 的执行过程。

在 `__PROGRESS_ALICE__` 进程中，查看另外一个进程 `__PROGRESS_BOB__` 中的当前 Saga 实例的序号：

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetSagaIdSequence" } })
-- New Message From u37...zs4: Data = {"result":[0]}
```

执行下面的命令，“启动” `InventoryService` 的 `ProcessInventorySurplusOrShortage` 方法：


```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage" }, Data = json.encode({ product_id = 1, location = "x", quantity = 100 }) })
```

这会创建一个新的 Saga 实例。如果之前没有执行过下面的命令，那么显然这个 Saga 实例的序号为 `1`。

查看序号为 `__SAGA_ID__` 的 Saga 实例的内容：

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetSagaInstance" }, Data = json.encode({ saga_id = __SAGA_ID__ }) })
-- Inbox[#Inbox]
```

查询库存项目的版本号：

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetInventoryItem" }, Data = json.encode({ product_id = 1, location = "x" }) })
-- Inbox[#Inbox]
```lua

发送消息，将 Saga 实例推进到下一步（注意替换占位符 `__ITEM_VERSION__` 为上面查询到的库存项目的版本号，以及替换占位符 `__SAGA_ID__` 为上面创建的 Saga 实例的序号）：

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_GetInventoryItem_Callback", ["X-SagaId"] = "__SAGA_ID__" }, Data = json.encode({ result = { product_id = 1, location = "x", version = __ITEM_VERSION__, quantity = 110 } }) })
```

查看序号为 `__SAGA_ID__` 的 Saga 实例的内容是否已更新：

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetSagaInstance" }, Data = json.encode({ saga_id = __SAGA_ID__ }) })
-- Inbox[#Inbox]
```

继续发送 mock 消息，以推进 Saga 实例（注意替换占位符 `__SAGA_ID__`）：

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_CreateSingleLineInOut_Callback", ["X-SagaId"] = "__SAGA_ID__" }, Data = json.encode({ result = { in_out_id = 1, version = 0 } }) })
```

继续发送 mock 消息，以推进 Saga 实例：

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_AddInventoryItemEntry_Callback", ["X-SagaId"] = "__SAGA_ID__" }, Data = json.encode({ result = {} }) })
```

继续发送 mock 消息，以推进 Saga 实例：

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_CompleteInOut_Callback", ["X-SagaId"] = "__SAGA_ID__" }, Data = json.encode({ result = {} }) })
```

查看序号为 `__SAGA_ID__` 的 Saga 实例的内容：

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetSagaInstance" }, Data = json.encode({ saga_id = __SAGA_ID__ }) })

Inbox[#Inbox]
```

你应该看到输出内容中的 `Data` 属性值包含 `"completed":true` 这样代码片段， 表示这个 Saga 实例的执行状态为“已完成”。


