# 使用低代码方法开发 AO 去中心化应用

[English](./README.md) | 中文版

> 对于部分开发者来说，本文讨论的内容以及当前代码库中的示例其实已经有相当的复杂度了，
> [这里](https://github.com/dddappp/AI-Assisted-AO-Dapp-Example)有一些更简单的示例，可供参考。

AO 正沿着正确的发展道路前进。

我们认为，Web3 的大规模采用之所以遭遇障碍，主要是由于构建大型去中心化应用的工程复杂性所致。
这使得我们无法在资源有限的情况下——在事物发展的初始阶段，通常如此，开发出更多样化的、更大规模、功能更丰富的去中心化应用。

> 不要相信那些类似“智能合约/链上程序应该就是很简单的，不需要搞得太复杂”之类倒果为因的鬼话。

与 Web2 相比，Web3 在技术基础设施、工具以及实践经验方面仍有待（**大幅**）提升。
AO 填补了其中一项重大空白。我们认为，最少，AO 作为当前 Web3 领域中的最佳去中心化*消息代理* [^MsgBrokerWpZh]，已经展现出巨大的潜力。

> 传统 Web2 应用的开发者可以拿着 Kafka 去类比理解一下：如果没有 Kafka 或者类 Kafka 的消息代理可用，你能想象现在很多大型互联网应用“程序要怎么写”吗？

例如，传统的大型复杂应用依赖于消息通信机制来实现组件之间的解耦，这对于提高系统的可维护性和可扩展性至关重要。

此外，这些应用在必要时通常会采用“最终一致性”模型，以进一步提高系统的可用性和可扩展性。

然而，即使在工程化更成熟的 Web2 环境中，基于消息通信来实现“最终一致性”也是许多开发者面临的挑战。

> 在新生的 AO 平台上开发 Dapp，这个挑战似乎还更凸显一些：）。

比如，下面的 Lua 代码（for AO dapp），你会不会觉得这么写是“理所当然”的？

```lua
Handlers.add(
    "a_multi_step_action",
    Handlers.utils.hasMatchingTag("Action", "AMultiStepAction"),
    function(msg)
        local status, result_or_error = pcall((function()
            local foo = do_a_mutate_memory_state_operation()
            local bar = do_another_mutate_memory_state_operation()
            return { foo = foo, bar = bar }
        end))
        ao.send({
            Target = msg.From,
            Data = json.encode(
                status and { result = result_or_error } 
                or { error = tostring(result_or_error) }
            )
        })
    end
)
```

如果您不熟悉 Lua，可以将 `pcall` 函数视为类似其他语言的 try-catch 结构：它尝试执行一个函数，成功时返回 true 和函数结果，失败时返回 false 和错误对象。

你发现问题了吗？假设 `do_a_mutate_memory_state_operation` 这一步执行成功，而 `do_another_mutate_memory_state_operation` 这一步执行发生错误，
消息的接收方（`Target`）会收到一个“错误”消息。按照常理，接收方可以安心地认为这个操作失败了，一切没变，岁月静好。
但是，实际上，`do_a_mutate_memory_state_operation` 这一步已经执行成功了，系统的状态已经发生了变化！也就是说，消息传递出来的信息和系统的实际状态是“不一致”的。

在传统的 Web2 开发环境中，我们通常可以采用“事务发件箱模式”[^TransactionalOutbox]来解决这一问题。
但是在 AO 平台上，我们没有发件箱模式所依赖的数据库 ACID 事务可用，事情就变得有点“微妙”了。

幸运的是，通过使用 dddappp 低代码工具，我们可以极大地简化 AO dapp 开发的复杂性。
在接下来的演示中，我们将展示如何利用 dddappp 来优雅地解决这些问题，并有力地支持我们的观点。


## 背景

我们觉得可能有必要先介绍一些背景知识，以便大家更好地理解本 demo 的内容。如果你对这些内容已经很熟悉，可以直接跳到[下一节](#前置条件)。
下面的行文我们偶尔用使用到一些 DDD（领域驱动设计）的术语，但我们相信，即使你不熟悉 DDD，应该也不会影响你的整体理解。


### 关于“最终一致性”

当我们开发传统企业软件或者互联网应用时，一个希望尽快推出的应用程序在开始时往往使用完全的“强一致性”模型
（因为使用“最终一致性”而不是“强一致性”会导致更高的应用程序开发成本）。
但是，如果应用很受欢迎，随着用户群的扩大，应用的负荷日益增加，当所有可用的纵向扩展方案（如更好也更昂贵的硬件）都已用尽，
应用最终有必要改进其软件架构——包括采用最终一致性模型。


### 没有 ACID 数据库事务，带来什么麻烦？

比如说，假设在一个 WMS 应用的领域模型中，InventoryItem（库存单元）实体（这是一个聚合根）表示“某个产品在某个货位上的库存数量”。
如果我们打算使用“最终一致性”模型来实现一个库存调拨（Inventory Movement）服务，需要考虑到执行这个调拨服务的时候可能发生这样的场景：

- 在源货位上，某产品 A 本来的库存数量是 1000 个。
- 我们开始执行一个调拨操作，打算把 100 个产品 A 转移到目标货位上。
- 一开始，我们的库存调拨服务扣减了源货位的库存数量，在这个货位上产品 A 的库存数量变成了 900——这个结果是持久的、不能通过数据库事务“回滚”，但此时目标货位的库存数量还没有增加，调拨还没有最终完成。
- 接着，其他人因为生产加工的需要，用掉（出库）了在源货位上的 100 个产品 A，库存数量变成了 800——这个结果也是持久的、不能使用数据库事务回滚。
- 然后，因为某些原因，我们没法在目标货位上增加产品 A 的库存数量，所以我们需要取消这次调拨操作。
- 这时候，我们应该把源货位上产品 A 的库存数量改为 900 个（这个动作被称为“**补偿**”操作），也就是在数量 800 个的基础上加回 100 个，而不能直接将库存数量改回调拨操作发生前的数量（1000 个）。

> 虽然在上面的场景中，我们只是改变了库存单元的两个实体的“实例”的状态，而没有涉及更多其他的“实体”（类型），但按照 DDD 社区的实践，仍然会推荐开发者考虑（最少是“考虑一下”）使用“最终一致性”模型来实现这样的业务逻辑。

更别说，在这样的模型中，可能还存在另一个 MovementOrder 实体（聚合根），它表示“库存调拨单”，这会使得整个调拨业务逻辑的“最终一致性”实现更加复杂。


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

可以认为基于协作的 Saga “非常” EDA 原生的一种程序设计模式。

一般来说，事件的发布，一般是使用*异步消息通信*机制来实现的（当然，较真来说，用同步的 RPC 也不是不可以）。

基于编制的 Saga 可以使用异步消息，也可以使用 RPC。但显然，一般来说，前者更轻量一些。
其实，在异步消息的基础上，我们也可以包装出同步“调用”的 API，或制作一些工具，支持调用方编写“类似同步调用”的代码。

具体一点说，就是一个名为 `Xxx` 的调用，可以分解为一对事件的发布过程：`XxxRequested` / `XxxResponded`。调用方发布前者，被调用方发布后者。


总的来说，在 EDA 里面，异步消息的使用范围非常广泛。
异步的基于消息的通信机制通常会使用到*消息代理* [^MsgBrokerWpZh]（Message Broker）。

你可能注意到，在很多时候，我们行文中也并不严格区分事件和消息这两个概念的区别。


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


不用着急，下面，我们将展示如何使用 dddappp 低代码工具来开发一个 AO Dapp。
在这个应用中，当然会包含上面👆所讨论的“更新库存单元的在库数量”的服务的 Saga 实现。
不过，如果你想先睹为快，可以直接先查看我们的 DDDML 模型文件 `./dddml/a-ao-demo.yaml`，
其中 `InventoryService` 服务的 `ProcessInventorySurplusOrShortage` 方法的定义。

> **提示**
> 
> 你可能没想到，我们用来编制 Saga 的 DSL，
> 还可以用来[解决 Move Dapp 开发中让大家头大的“依赖注入”问题](https://github.com/dddappp/sui-interface-demo/blob/main/README_CN.md)。
> 我们设计的 DSL 就是如此多才多艺。


## 前置条件

如果你想跟随我们走一遍演示的流程，请安装下面的工具：

* 安装 [aos](https://cookbook_ao.g8way.io/welcome/getting-started.html)
* 安装 [Docker](https://docs.docker.com/engine/install/).


然后，现在就启动一个 aos 进程：

```shell
aos process_alice
```

让我们记下它的进程 ID，比如 `DH4EI_kDShcHFf7FZotIjzW3lMoy4fLZKDA0qqTPt1Q`，
我们在下面的示例命令中使用占位符 `__PROCESS_ALICE__` 表示它。



## 编码

### 编写 DDDML 模型

已经编写好的模型文件见 `./dddml/a-ao-demo.yaml`.

对于稍有 OOP（面向对象编程）经验的开发者来说，模型所表达的内容应该不难理解。

让我们先抓主线。我们在模型中定义了聚合 `InventoryItem`，以及一个服务：`InventoryService`。
其中的 `steps` 就是我们所说的 Saga 的定义。
而服务 `InventoryService` 依赖两个组件： `InventoryItem` 聚合以及一个抽象的 `InOutService` 服务
——你可以把这里的“抽象”理解为：我们描述了这个服务“应有的样子”，但是并不打算自己实现它，而是期望“其他人”来实现它。

> **提示**
>
> 关于 DDDML，这里有个介绍文章：["Introducing DDDML: The Key to Low-Code Development for Decentralized Applications"](https://github.com/wubuku/Dapp-LCDP-Demo/blob/main/IntroducingDDDML.md).
>
> 在本代码库中，还包含了一个博客示例的模型文件 `./dddml/blog.yaml`，
> 你可以参考[这个文档](./doc/BlogExample_CN.md)来填充这个示例的业务逻辑实现代码，以及进行测试。
> 在下文的讨论中我们会忽略这个博客示例。


### 生成代码

在代码库的根目录执行：

```shell
docker run \
-v .:/myapp \
wubuku/dddappp-ao:master \
--dddmlDirectoryPath /myapp/dddml \
--boundedContextName A.AO.Demo \
--aoLuaProjectDirectoryPath /myapp/src
```

上面的命令行参数实际上还是挺直白的：

* This line `-v .:/myapp \` indicates mounting the local current directory into the `/myapp` directory inside the container.
* `dddmlDirectoryPath` is the directory where the DDDML model files are located. It should be a directory path that can be read in the container.
* Understand the value of the `boundedContextName` parameter as the name of the application you want to develop. When the name has multiple parts, separate them with dots and use the PascalCase naming convention for each part. 
    Bounded-context is a term in Domain-driven design (DDD) that refers to a specific problem domain scope that contains specific business boundaries, constraints, and language. 
    If you cannot understand this concept for the time being, it is not a big deal.
* `aoLuaProjectDirectoryPath` is the directory path where the "on-chain contract" code is placed. It should be a readable and writable directory path in the container.

执行完上面的命令后，你会在 `./src` 目录下看到 dddappp 工具为你生成的“成吨”的代码。


#### 更新 Docker 镜像

由于 dddappp 工具的镜像的 master 版本经常更新，如果你之前运行过上述命令，现在遇到了问题，
你可能需要手动删除旧的镜像，以确保你使用的是最新版本的镜像。

```shell
# If you have already run it, you may need to Clean Up Exited Docker Containers first
docker rm $(docker ps -aq --filter "ancestor=wubuku/dddappp-ao:master")
# remove the image
docker image rm wubuku/dddappp-ao:master
# pull the image
docker pull wubuku/dddappp-ao:master
```


### 填充业务逻辑

下面让我们填充以 Lua 代码编写的业务操作逻辑。

> 理想情况下，未来应该有一门平台中立的表达式语言，让开发者可以更方便的编写“多链”应用的业务逻辑。当然，我们还在朝这个方向努力。

你会发现，下面需要填充业务逻辑实现的后缀名为 `_logic.lua` 的那些文件中，函数的签名部分已经写好了，你只需要填充函数体部分。

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

如上所述，我们在模型中将 `InOutService` 声明为“抽象的”（`abstract`），表示我们并不打算自己实现它，而是期望其他人来实现它。
这里我们使用 `in_out_service_mock.lua` 中的代码来模拟 `InOutService` 的行为。

像下面这样，修改文件 `./src/in_out_service_mock.lua`：

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

修改“配置文件” `./src/inventory_service_config.lua`，填入上面记录的 `__PROCESS_ALICE__`：

```lua
return {
    inventory_item = {
        get_target = function()
            return "DH4EI_kDShcHFf7FZotIjzW3lMoy4fLZKDA0qqTPt1Q" -- <- Fill in the __PROCESS_ALICE__
        end,
        -- ...
    },
    in_out = {
        get_target = function()
            return "DH4EI_kDShcHFf7FZotIjzW3lMoy4fLZKDA0qqTPt1Q" -- <- Fill in the __PROCESS_ALICE__
        end,
        -- ...
    }
}
```

关于需要你做的编码部分，就这么多。现在一切准备就绪，让我们开始测试这个应用。


## 测试应用

启动另一个 aos 进程：

```shell
aos process_bob
```

记录下它的进程 ID，比如 `0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow`，
我们在下面的示例命令中可能会使用占位符 `__PROCESS_BOB__` 表示它。


在这个 aos (`__PROCESS_BOB__`) 进程中，装载我们的应用代码（注意将 `{PATH/TO/A-AO-Demo/src}` 替换为实际的路径）：

```lua
.load {PATH/TO/A-AO-Demo/src}/a_ao_demo.lua
```

现在，可以在第一个进程（`__PROCESS_ALICE__`）中，向这个 `__PROCESS_BOB__` 进程发送消息进行测试了。


### “库存”相关的测试

在进程 `__PROCESS_ALICE__` 中执行下面的命令，通过“添加库存项目条目”来更新库存项目（Inventory Item）：

```lua
Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "AddInventoryItemEntry" }, Data = json.encode({ inventory_item_id = { product_id = 1, location = "x" }, movement_quantity = 100}) })

Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "AddInventoryItemEntry" }, Data = json.encode({ inventory_item_id = { product_id = 1, location = "x" }, movement_quantity = 130, version = 0}) })

Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "AddInventoryItemEntry" }, Data = json.encode({ inventory_item_id = { product_id = 1, location = "x", inventory_attribute_set = { foo = "foo", bar = "bar" } }, movement_quantity = 100}) })

Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "AddInventoryItemEntry" }, Data = json.encode({ inventory_item_id = { product_id = 1, location = "x", inventory_attribute_set = { foo = "foo", bar = "bar" } }, movement_quantity = 101, version = 0}) })
```

查看库存项目的内容：

```lua
Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "GetInventoryItem" }, Data = json.encode({ product_id = 1, location = "x" }) })

Inbox[#Inbox]

Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "GetInventoryItem" }, Data = json.encode({ product_id = 1, location = "x", inventory_attribute_set = { foo = "foo", bar = "bar" } }) })

Inbox[#Inbox]
```


### 手动发送消息测试 Saga

我们先通过手动发送消息来逐步测试和观察 Saga 的执行过程。

在 `__PROCESS_ALICE__` 进程中，查看另外一个进程 `__PROCESS_BOB__` 中的当前 Saga 实例的序号：

```lua
Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "GetSagaIdSequence" } })
-- New Message From u37...zs4: Data = {"result":[0]}
```

执行下面的命令，“启动” `InventoryService` 的 `ProcessInventorySurplusOrShortage` 方法：


```lua
Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage" }, Data = json.encode({ product_id = 1, location = "x", quantity = 100 }) })
```

这会创建一个新的 Saga 实例。如果之前没有执行过下面的命令，那么显然这个 Saga 实例的序号应该是 `1`。

查看序号为 `__SAGA_ID__` 的 Saga 实例的内容：

```lua
Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "GetSagaInstance" }, Data = json.encode({ saga_id = __SAGA_ID__ }) })
-- Inbox[#Inbox]
```

查询库存项目的版本号：

```lua
Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "GetInventoryItem" }, Data = json.encode({ product_id = 1, location = "x" }) })
-- Inbox[#Inbox]
```

发送消息，将 Saga 实例推进到下一步（注意替换占位符 `__ITEM_VERSION__` 为上面查询到的库存项目的版本号，以及替换占位符 `__SAGA_ID__` 为上面创建的 Saga 实例的序号）：

```lua
Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_GetInventoryItem_Callback", ["X-SagaId"] = "__SAGA_ID__" }, Data = json.encode({ result = { product_id = 1, location = "x", version = __ITEM_VERSION__, quantity = 110 } }) })
```

查看序号为 `__SAGA_ID__` 的 Saga 实例的内容是否已更新：

```lua
Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "GetSagaInstance" }, Data = json.encode({ saga_id = __SAGA_ID__ }) })
-- Inbox[#Inbox]
```

继续发送 mock 消息，以推进 Saga 实例（注意替换占位符 `__SAGA_ID__`）：

```lua
Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_CreateSingleLineInOut_Callback", ["X-SagaId"] = "__SAGA_ID__" }, Data = json.encode({ result = { in_out_id = 1, version = 0 } }) })
```

继续发送 mock 消息，以推进 Saga 实例：

```lua
Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_AddInventoryItemEntry_Callback", ["X-SagaId"] = "__SAGA_ID__" }, Data = json.encode({ result = {} }) })
```

继续发送 mock 消息，以推进 Saga 实例：

```lua
Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage_CompleteInOut_Callback", ["X-SagaId"] = "__SAGA_ID__" }, Data = json.encode({ result = {} }) })
```

查看序号为 `__SAGA_ID__` 的 Saga 实例的内容：

```lua
Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "GetSagaInstance" }, Data = json.encode({ saga_id = __SAGA_ID__ }) })

Inbox[#Inbox]
```

你应该看到输出内容中的 `Data` 属性值包含 `"completed":true` 这样代码片段， 表示这个 Saga 实例的执行状态为"已完成"。



### 测试 Saga 的跨进程执行

在上面修改 `./src/inventory_service_config.lua` 时，
我们已经将“库存服务”所依赖的两个组件 `inventory_item` 和 `in_out` 的 `target` 指向了 `__PROCESS_ALICE__` 进程。


让我们在 `__PROCESS_ALICE__` 进程中，先这样装载 `inventory_item` 组件
（注意，虽然我们装载了和 `__PROCESS_BOB__` 进程同样的代码，但其实接下来的测试只使用了其中和 `InventoryItem` 聚合相关的部分）：

```lua
.load {PATH/TO/A-AO-Demo/src}/a_ao_demo.lua
```

然后，同样在 `__PROCESS_ALICE__` 进程中，再装载 `in_out_service` 的 mock 代码：

```lua
.load {PATH/TO/A-AO-Demo/src}/in_out_service_mock.lua
```

在 `__PROCESS_ALICE__` 进程中，查看另外一个进程 `__PROCESS_BOB__` 中的当前 Saga 实例的序号：

```lua
Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "GetSagaIdSequence" } })
```

在 `__PROCESS_ALICE__` 进程中，给自己“新建一个库存项目”
（注意替换占位符 `__PROCESS_ALICE__` 为实际的进程 ID，比如 `DH4EI_kDShcHFf7FZotIjzW3lMoy4fLZKDA0qqTPt1Q`）：

```lua
Send({ Target = "__PROCESS_ALICE__", Tags = { Action = "AddInventoryItemEntry" }, Data = json.encode({ inventory_item_id = { product_id = 1, location = "y" }, movement_quantity = 100}) })
```

执行下面的命令，“启动”进程 `__PROCESS_BOB__` 中的 `InventoryService` 的 `ProcessInventorySurplusOrShortage` 方法：

```lua
Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "InventoryService_ProcessInventorySurplusOrShortage" }, Data = json.encode({ product_id = 1, location = "y", quantity = 119 }) })
-- New Message From u37...zs4: Data = {"result":{"in_out_i...
```

查看进程 `__PROCESS_ALICE__` 中的库存项目：

```lua
Send({ Target = "__PROCESS_ALICE__", Tags = { Action = "GetInventoryItem" }, Data = json.encode({ product_id = 1, location = "y" }) })

Inbox[#Inbox]
```

你应该看到该库存项目的 `quantity` 已经更新（`Data = "{"result":{"quantity":119,"version":1...`）。


再次查看进程 `__PROCESS_BOB__` 中的当前 Saga 实例的序号：

```lua
Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "GetSagaIdSequence" } })
```

你应该看到该序号应该已经增加。

将下面命令的占位符号 `__SAGA_ID__` 替换为最新的 Saga 实例的序号，查看 Saga 实例的执行过程：

```lua
Send({ Target = "0RsO4RGoYdu_SJP_EUyjniiiF4wEMANF2bKMqWTWzow", Tags = { Action = "GetSagaInstance" }, Data = json.encode({ saga_id = __SAGA_ID__ }) })

Inbox[#Inbox]
```

如果没有什么意外，这个 Saga 实例的执行状态应该是“已完成”。


##  延伸阅读

### 将 dddappp 作为全链游戏引擎使用

#### 使用 dddappp 开发 Sui 全链游戏

这个一个生产级的实际案例：https://github.com/wubuku/infinite-sea

#### 用于开发 Aptos 全链游戏的示例

原版的 [constantinople](https://github.com/0xobelisk/constantinople) 是一个基于全链游戏引擎 [obelisk](https://obelisk.build) 开发的运行在 Sui 上的游戏。（注：obelisk 不是我们的项目。）

我们这里尝试了使用 dddappp 低代码开发方式，实现这个游戏的 Aptos Move 版本：https://github.com/wubuku/aptos-constantinople/blob/main/README_CN.md

开发者可以按照 README 的介绍，复现整个游戏的合约和 indexer 的开发和测试过程。模型文件写一下，生成代码，在三个文件里面填了下业务逻辑，开发就完成了。

有个地方可能值得一提。Aptos 对发布的 Move 合约包的大小有限制（不能超过60k）。这个问题在 Aptos 上开发稍微大点的应用都会碰到。我们现在可以在模型文件里面声明一些模块信息，然后就可以自动拆分（生成）多个 Move 合约项目。（注：这里说的模块是指领域模型意义上的模块，不是 Move 语言的那个模块。）


### Sui 博客示例

代码库：https://github.com/dddappp/sui-blog-example

只需要写 30 行左右的代码（全部是领域模型的描述）——除此以外不需要开发者写一行其他代码——就可以一键生成一个博客；
类似 [RoR 入门指南](https://guides.rubyonrails.org/getting_started.html) 的开发体验，

特别是，一行代码都不用写，100% 自动生成的链下查询服务（有时候我们称之为 indexer）即具备很多开箱即用的功能。


### Aptos 博客示例

上面的博客示例的 [Aptos 版本](https://github.com/dddappp/aptos-blog-example)。

### Sui 众筹 Dapp

一个以教学演示为目的“众筹” Dapp：

https://github.com/dddappp/sui-crowdfunding-example


### 复杂的 Sui 演示

如果你有进一步了解的兴趣，可以在这里找到一个更复杂的 Sui 演示：["A Sui Demo"](https://github.com/dddappp/A-Sui-Demo)。
我们使用了各种“生造”的场景，来展示 dddappp 的各种能力。

[^SagaPattern]: [Microservices.io](http://microservices.io/). Pattern: Saga. [https://microservices.io/patterns/data/saga.html](https://microservices.io/patterns/data/saga.html)

[^TransactionalOutbox]: [Microservices.io](http://microservices.io/). Pattern: Transactional Outbox. [https://microservices.io/patterns/data/transactional-outbox.html](https://microservices.io/patterns/data/transactional-outbox.html)

[^MsgBrokerWpZh]: [Wikipedia.org](http://wikipedia.org/). 消息代理. [https://zh.wikipedia.org/zh-hans/消息代理](https://zh.wikipedia.org/zh-hans/%E6%B6%88%E6%81%AF%E4%BB%A3%E7%90%86)

