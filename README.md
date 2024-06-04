# An AO Dapp Development Demo with a Low-Code Approach


AO 正沿着正确的发展道路前进。

我们认为，Web3 的大规模采用之所以遭遇障碍，主要是由于构建大型去中心化应用的工程复杂性所致。与 Web2 相比，Web3 在技术基础设施、工具以及实践经验方面仍有待（**大幅**）提升。

例如，传统的大型复杂应用依赖于消息通信机制来实现组件之间的解耦，这对于提高系统的可维护性和可扩展性至关重要。我们认为，AO 作为当前 Web3 领域中的最佳*消息代理* [^MsgBrokerWpZh]，展现出了巨大的潜力。

此外，这些应用在必要时通常会采用“最终一致性”模型，以进一步提高系统的可用性和可扩展性。

然而，基于消息通信来实现“最终一致性”对许多开发者来说仍然是一个挑战，无论是在 Web2 环境中还是在 AO 平台上开发 Dapp。

幸运的是，通过使用 dddappp 低代码工具，我们可以大大简化这一任务。

通过接下来的演示，我们将有力地证明我们的立场。



## 引子

作为一个 AO 开发者，你能看出来下面这样看起来“理所应当”的 Lua 代码可能暗藏着什么“大坑”吗？

```lua
Handlers.add(
    "a_multi_step_operation",
    Handlers.utils.hasMatchingTag("Action", "AMultiStepOperation"),
    function(msg)
        local status, result_or_error = pcall((function()
            local foo = do_a_mutate_memory_state_operation()
            local bar = do_another_mutate_memory_state_operation()
            return { foo = foo, bar = bar }
        end))
        ao.send({
            Target = msg.From,
            Data = json.encode(status and { result = result_or_error } or { error = tostring(result_or_error) }
            )
        })
    end
)
```

如果你不是 Lua 开发者，你可以把上面的 `pcall` 函数调用看作是一个 try-catch 操作。它会执行作为参数传入的函数，如果执行成功，`pcall` 返回 `true` 和函数的返回值；如果函数执行失败，`pcall` 返回 `false` 和错误对象。

你发现问题了吗？假设 `do_a_mutate_memory_state_operation` 这一步执行成功，而 `do_another_mutate_memory_state_operation` 这一步执行发生错误，会发生什么？


我们觉的有必要先介绍一些背景知识，以便大家更好地理解本 demo 的内容。
下面的行文我们偶尔用使用到一些 DDD（领域驱动设计）的术语，但我们相信，即使你不熟悉 DDD，应该也不会影响你的整体理解。


### 关于最终一致性

An application that needs to be launched quickly often begins with the use of a total "strong consistency" architecture (Indeed, using "eventual consistency" instead of "strong consistency" can lead to higher application development costs). But as the user base grows and all available options for vertical scaling (e.g. better/more expensive hardware) are exhausted, it eventually becomes necessary for the application to improve its software architecture


### 没有 ACID 数据库事务，带来什么麻烦？

比如说，假设在一个 WMS 应用的领域模型中，InventoryItem（库存单元）实体（聚合根）表示“某个产品在某个货位上的库存数量”。
如果我们打算使用“最终一致性”模型来实现一个库存调拨（Inventory Movement）服务，需要考虑到执行这个调拨服务的时候可能发生这样的场景：

- 在源货位上，某产品 A 本来的库存数量是 1000 个。
- 我们执行了一个调拨操作，打算把 100 个产品 A 转移到目标货位上。
- 一开始，我们的库存调拨服务扣减了源货位的库存数量，在这个货位上产品 A 的库存数量变成了 900——这个结果是持久的、不能通过数据库事务“回滚”，但此时目标货位的库存数量还没有增加，调拨还没有最终完成。
- 接着，其他人因为生产加工的需要，用掉（出库）了在源货位上的 100 个产品 A，库存数量变成了 800——这个结果也是持久的、不能使用数据库事务回滚。
- 然后，因为某些原因，我们没法在目标货位上增加产品 A 的库存数量，所以我们需要取消这次调拨操作。
- 这时候，我们应该把源货位上产品 A 的库存数量改为 900 个（这个动作被称为“**补偿**”操作），也就是在数量 800 个的基础上加回 100 个，而不能直接将库存数量改回调拨操作发生前的数量（1000 个）。


### 使用 Saga 实现最终一致性

如果打算使用“最终一致性”模型来实现多个聚合之间的状态（数据）的一致性，我们有必要考虑使用 *Saga 模式*[^SagaPattern]。

这里说的 Saga 是什么东西？我们看看 ChatGPT 怎么说的：

> SAGA 是一种设计模式，全称为“分布式事务的 saga 模式”（Saga Pattern for Distributed Transactions）。它是一种在分布式系统中执行长时间运行的事务的解决方案，可以同时保证数据的一致性和可靠性。
> 
> 在Saga模式中，一个长时间运行的事务被分解为多个步骤，每个步骤都是一个原子操作，并且对应一个事务。每当一个步骤完成时，Saga 都会发出一个事件，触发下一个步骤的执行。如果某个步骤失败，Saga 将会执行补偿行动，来撤销已经完成的步骤，从而保证数据的一致性。
> 
> 简单来说，SAGA 模式解决了分布式系统中长时间运行事务的问题，将一个大的事务拆分成多个小的原子操作，通过在每一步操作之间传递事件和执行补偿操作，来保证数据的一致性和可靠性。

显然，Saga 实现业务事务所采用的是“最终一致性”模型。保证数据的最终一致是需要应用开发人员自己负责实现的“业务逻辑”。


### 两种风格的 Saga

有两种风格的 Saga：*基于协作的 Saga*（Choreography-based saga），以及，*基于编制的 Saga*（Orchestration-based saga）。

基于协作的 Saga 没有中心协调者，大家都通过公开地发布消息/事件来推进业务流程。比如说：

- 当客户下了一个订单后，订单服务会发布一个“OrderPlaced”事件——它其实并不在意谁对这个事件感兴趣，发布事件的意思就是相当于大喊：
    > 有人下单了！
    > 
- 也许库存服务会对这个事件感兴趣，它会“订阅”这个事件。当收到这个事件时，它可能会按照订单上的产品以及数量信息预留库存（Reserve Inventory），为接下来的发货操作做准备。同样地，当它预留好库存之后，它也发布一个“InventoryReserved”事件——相当于大喊：
    > 库存预留好了！
    > 
- 也许，拣货服务一直就在监听这类消息，因为预留好库存之后，接下来就应该拣货员干活了……

在上面描述的业务流程的执行过程中，并**没有**一个协调者负责：

- “命令”每个服务干什么；
- 记录每个服务干出来的结果如何；
- 决定这个服务干完后哪个服务接着干，或者这个服务“彻底干不下去了”应该怎么办。

而基于编制的 Saga 就**存在**这个居中指挥的协调者，我们可以把这个协调者称为 Saga Manager。
Saga Manager 与服务（组件）之间的交互可能使用异步的基于消息的通信机制（Asynchronous Messaging），也可能使用同步的 RPC 方式。


### 事件驱动的架构（EDA）与 Saga

可以认为基于协作的 Saga 很接近 EDA 的本意。

一般来说，事件的发布，一般是使用*异步消息通信*机制来实现的（当然，较真来说，用同步的 RPC 也不是不可以）。

基于编制的 Saga 可以使用异步消息，也可以使用 RPC。但显然，一般来说，前者更轻量一些。
其实，在异步消息的基础上，我们也可以包装出同步“调用”的 API，或制作一些工具，支持调用方编写“类似同步调用”的代码。

具体一点说，就是一个名为 `Xxx` 的调用，可以分解为一对事件的发布过程：`XxxRequested` / `XxxResponded`。调用方发布前者，被调用方发布后者。

由于基于编制的 Saga 对服务（组件）的“调用”可以拆分为事件，那么，说它是 EDA 的一种特殊形式也未尝不可。

---

总的来说，在 EDA 里面，异步消息的使用范围非常广泛。
异步的基于消息的通信机制通常会使用到*消息代理* [^MsgBrokerWpZh]（Message Broker）。
（你可能注意到，在很多时候，我们行文中也并不严格区分事件和消息这两个概念的区别。）


### 如何设计基于编制的 Saga

实现 Saga 其实还是比较麻烦的。要实现复杂功能，基于协作的 Saga 比基于编制的 Saga 更麻烦。所以有必要考虑使用 DSL 来帮助实现基于编制的 Saga。

怎么“编制”一个 Saga？下面举例。

假设，我们在开发一个 WMS 应用，我们在领域模型中创建了两个聚合 InventoryItem 与 InOut。

现在，我们想要一个“硬生生地”直接修改库存单元的“在库数量”的领域服务。这个服务可能是一个叫做 `CreateOrUpdateInventoryItem` 的方法。
我们可能在对库存实物进行盘点后，做“盘盈/盘亏”处理时，使用这个服务方法。
虽然此时我们是“直接”修改库存单元的在库数量，但是我们仍然希望使用 `InOut`（入库/出库单）来保存库存数量的修改记录，所以这个方法会涉及两个聚合。

假设我们把这两个聚合部署为两个微服务，我们需要使用“最终一致”的策略来实现这个修改在库数量的“业务事务”。

首先，我们设计这个业务事务的各个实现步骤，大致如下：

1. 查询库存单元（InventoryItem）信息。
   我们根据查询的结果，判断到底是需要新建一条库存单元记录还是更新已有的库存单元记录，以及，入库/出库单的行项的 `MovementQuantity`（移动数量）的应该是多少。
2. 创建一个入库/出库单（InOut）。这个单据只有一行（InOutLine），行项的 `MovementQuantity` 是更新后的在库数量与当前在库数量（我们在上一个步骤看到的在库数量）的差值。
3. 添加一个库存单元条目（InventoryItemEntry）。我们的库存单元聚合按理说应该使用了账务模式，所以我们需要通过这个方式去间接地更新库存单元的在库数量。
4. 如果更新库存单元成功，那么将入库/出库单的状态更新为“已完成”。
5. 如果更新库存单元失败，那么将入库/出库单更新为“已取消”——这个操作是第 2 个步骤的“补偿”操作。

我们可以注意到，相对于简单地使用数据库本地事务来保证强一致性的做法来说，这里我们明显多了第 4 项及第 5 项编码任务。

思路想好了，接下来我们需要为以上**步骤**定义相应的“操作聚合的**方法**”。

我们需要编写操作库存单元（Inventory Item）聚合的几个方法：

- `GetInventoryItem`，这个方法是通过聚合根 ID（库存单元的 ID）来获取库存单元状态的查询方法。
- `AddInventoryItemEntry`，这个方法添加一个库存单元条目，这是（间接地）修改库存单元的那些数量属性（账目）的唯一方式。

还需要编写操作入库/出库单（`InOut`）聚合的三个方法：

- `CreateSingleLineInOut`，这个方法创建一个入库/出库单（`InOut`），这个单据只有一行（`InOutLine`）。
- `Complete`，这个方法将入库/出库单的状态更新为“已完成”。
- `Void`，这个方法将入库/出库单更新为“已取消”。

这些方法是用于实现基于编制的 Saga 的“构造块”。

有了上面这些基础组件，我们终于可以在这些基础上编写 Saga 的“编排”逻辑，去实现 `CreateOrUpdateInventoryItem` 了……

可见，如果完全没有 DSL，要实现编制式 Saga 的过程还是挺繁琐的——毋庸置疑，如果要用协作式 Saga 来实现同样的业务逻辑，那只会更繁琐。😂

那么，如果要为此设计一个 DSL，大致会是什么样子的呢？

如果你想先睹为快，可以直接先查看我们的 DDDML 模型文件 `./dddml/a-ao-demo.yaml`，
其中 `InventoryService` 服务的 `ProcessInventorySurplusOrShortage` 方法的定义。


---

下面，我们将展示如何使用 dddappp 低代码工具来开发一个 AO Dapp。
在这个应用中，当然会包含上面👆所讨论的“更新库存单元的在库数量”的服务的 Saga 实现。


## 前置条件

安装：

* 安装 [aos](https://cookbook_ao.g8way.io/welcome/getting-started.html)
* 安装 [Docker](https://docs.docker.com/engine/install/).


启动一个 aos 进程：

```shell
aos process_alice
```

让我们记下它的进程 ID，比如 `DH4EI_kDShcHFf7FZotIjzW3lMoy4fLZKDA0qqTPt1Q`，
我们在下面的示例命令中使用占位符 `__PROGRESS_ALICE__` 表示它。



## 编码

### 编写 DDDML 模型

已经编写好的模型文件见 `./dddml/a-ao-demo.yaml`.

> **Tip**
>
> About DDDML, here is an introductory article: ["Introducing DDDML: The Key to Low-Code Development for Decentralized Applications"](https://github.com/wubuku/Dapp-LCDP-Demo/blob/main/IntroducingDDDML.md).


### 生成代码

In repository root directory, run:

```shell
docker run \
-v .:/myapp \
wubuku/dddappp-ao:0.0.1 \
--dddmlDirectoryPath /myapp/dddml \
--boundedContextName A.AO.Demo \
--aoLuaProjectDirectoryPath /myapp/src
```

The command parameters above are straightforward:

* This line `-v .:/myapp \` indicates mounting the local current directory into the `/myapp` directory inside the container.
* `dddmlDirectoryPath` is the directory where the DDDML model files are located. It should be a directory path that can be read in the container.
* Understand the value of the `boundedContextName` parameter as the name of the application you want to develop. When the name has multiple parts, separate them with dots and use the PascalCase naming convention for each part. 
    Bounded-context is a term in Domain-driven design (DDD) that refers to a specific problem domain scope that contains specific business boundaries, constraints, and language. 
    If you cannot understand this concept for the time being, it is not a big deal.
* `aoLuaProjectDirectoryPath` is the directory path where the "on-chain contract" code is placed. It should be a readable and writable directory path in the container.


#### Update dddappp Docker Image

Since the dddappp v0.0.1 image is updated frequently, 
if you've run the above command before and run into problems, 
you may be required to manually delete the image and pull it again before `docker run`.

```shell
# If you have already run it, you may need to Clean Up Exited Docker Containers first
docker rm $(docker ps -aq --filter "ancestor=wubuku/dddappp-ao:0.0.1")
# remove the image
docker image rm wubuku/dddappp-ao:0.0.1
# pull the image
docker pull wubuku/dddappp-ao:0.0.1
```


### 填充业务逻辑

#### 修改 `article_update_body_logic`

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

#### 修改 `inventory_item_add_inventory_item_entry_logic`

修改文件 `./src/inventory_item_add_inventory_item_entry_logic.lua`，在函数体中填充业务逻辑：

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

#### 修改 `inventory_service_local`

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

#### 修改 `in_out_service_mock`

你可能已经注意到，我们在模型中将 `InOutService` 生命为“抽象的”（`abstract`），表示我们并不打算自己实现它，而是期望其他组件来实现它。
所以这里我们使用 `in_out_service_mock.lua` 来模拟 `InOutService` 的行为。

修改文件 `./src/in_out_service_mock.lua`：

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

#### 修改 `inventory_service_config`

修改“配置文件” `./src/inventory_service_config.lua`，填入上面记录的 `__PROGRESS_ALICE__`：

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

记录下它的进程 ID，比如 `u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4`，
我们在下面的示例命令中可能会使用占位符 `__PROGRESS_BOB__` 表示它。


在这个 aos (`__PROGRESS_BOB__`) 进程中，装载我们的应用代码（注意将 `{PATH/TO/A-AO-Demo/src}` 替换为实际的路径）：

```lua
.load {PATH/TO/A-AO-Demo/src}/a_ao_demo.lua
```

现在，可以在第一个进程（`__PROGRESS_ALICE__`）中，向这个 `__PROGRESS_BOB__` 进程发送消息进行测试了。


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

在进程 `__PROGRESS_ALICE__` 中执行下面的命令，通过“添加库存项目条目”来更新库存项目（Inventory Item）：

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

这会创建一个新的 Saga 实例。如果之前没有执行过下面的命令，那么显然这个 Saga 实例的序号应该是 `1`。

查看序号为 `__SAGA_ID__` 的 Saga 实例的内容：

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetSagaInstance" }, Data = json.encode({ saga_id = __SAGA_ID__ }) })
-- Inbox[#Inbox]
```

查询库存项目的版本号：

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetInventoryItem" }, Data = json.encode({ product_id = 1, location = "x" }) })
-- Inbox[#Inbox]
```

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


### 测试 Saga 的跨进程执行

在上面修改 `./src/inventory_service_config.lua` 时，
我们已经将“库存服务”所依赖的两个组件 `inventory_item` 和 `in_out` 的 `target` 指向了 `__PROGRESS_ALICE__` 进程。


让我们在 `__PROGRESS_ALICE__` 进程中，先这样装载 `inventory_item` 组件
（注意，虽然我们装载了和 `__PROGRESS_BOB__` 进程同样的代码，但其实接下来的测试只使用了其中和 `InventoryItem` 聚合相关的部分）：

```lua
.load {PATH/TO/A-AO-Demo/src}/a_ao_demo.lua
```

然后，同样在 `__PROGRESS_ALICE__` 进程中，再装载 `in_out` mock 组件：

```lua
.load {PATH/TO/A-AO-Demo/src}/in_out_service_mock.lua
```

在 `__PROGRESS_ALICE__` 进程中，查看另外一个进程 `__PROGRESS_BOB__` 中的当前 Saga 实例的序号：

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetSagaIdSequence" } })
```

在 `__PROGRESS_ALICE__` 进程中，给自己“新建一个库存项目”
（注意替换占位符 `__PROGRESS_ALICE__` 为实际的进程 ID，比如 `DH4EI_kDShcHFf7FZotIjzW3lMoy4fLZKDA0qqTPt1Q`）：

```lua
Send({ Target = "__PROGRESS_ALICE__", Tags = { Action = "AddInventoryItemEntry" }, Data = json.encode({ inventory_item_id = { product_id = 1, location = "y" }, movement_quantity = 100}) })
```

执行下面的命令，“启动”进程 `__PROGRESS_BOB__` 中的 `InventoryService` 的 `ProcessInventorySurplusOrShortage` 方法：

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage" }, Data = json.encode({ product_id = 1, location = "y", quantity = 119 }) })
-- New Message From u37...zs4: Data = {"result":{"in_out_i...
```

查看进程 `__PROGRESS_ALICE__` 中的库存项目：

```lua
Send({ Target = "__PROGRESS_ALICE__", Tags = { Action = "GetInventoryItem" }, Data = json.encode({ product_id = 1, location = "y" }) })

Inbox[#Inbox]
```

你应该看到该库存项目的 `quantity` 已经更新（`Data = "{"result":{"quantity":119,"version":1...`）。


再次查看进程 `__PROGRESS_BOB__` 中的当前 Saga 实例的序号：

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetSagaIdSequence" } })
```

你应该看到该序号应该已经增加。

将下面命令的占位符号 `__SAGA_ID__` 替换为最新的 Saga 实例的序号，查看 Saga 实例的执行过程：

```lua
Send({ Target = "u37NjsXT8pVTm0CzOuEW1gogVFKtYy0UWIwxihoTzs4", Tags = { Action = "GetSagaInstance" }, Data = json.encode({ saga_id = __SAGA_ID__ }) })

Inbox[#Inbox]
```

---

[^SagaPattern]: [Microservices.io](http://microservices.io/). Pattern: Saga. [https://microservices.io/patterns/data/saga.html](https://microservices.io/patterns/data/saga.html)

[^MsgBrokerWpZh]: [Wikipedia.org](http://wikipedia.org/). 消息代理. [https://zh.wikipedia.org/zh-hans/消息代理](https://zh.wikipedia.org/zh-hans/%E6%B6%88%E6%81%AF%E4%BB%A3%E7%90%86)

