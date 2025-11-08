# AO NFT Escrow 简化设计与实施规划 (AO 原生所有权转移模型)

> **文档状态**：v3.2 - 预存支付安全模式
> **核心优化**：采用预存支付模式，买家先转账生成PaymentId，卖家指定使用特定支付记录。彻底消除支付匹配风险，实现精确、安全的资金控制。
> **作者**：Gemini（AI）

---

## 1. 核心业务流程 (AO 原生所有权转移模型)

> **关键优化**: 采用**预存支付模式** - 买家先将资金转入托管合约生成PaymentId，卖家启动交易时指定使用哪个PaymentId。彻底消除支付匹配的复杂性和风险，实现精确的资金控制。

纠正了关键的认知偏差：AO中没有EVM的`approve`授权模型。资产转移必须由当前所有者发起。因此，托管流程被重构为以下符合AO原生模型的步骤：

| 步骤 | 操作方 | 动作 | 目标合约 | 结果 |
| :--- | :--- | :--- | :--- | :--- |
| 1. **启动交易** | 卖家 | 发送 `ExecuteNftEscrowTransaction` 消息 | **托管合约** | Saga 创建托管记录（Aggregate），指定 NFT 信息和交易条件（币种+价格），生成 EscrowId。开始等待 NFT 存入。 |
| 2. **存入NFT** | 卖家 | 调用 `Transfer` | **NFT合约** | 将NFT的所有权直接转移给**托管合约的地址**。NFT被锁定。 |
| 3. **确认存入** | NFT合约 | 发送 `Credit-Notice` | **托管合约** | 托管合约监听到通知，触发 `NftDeposited` 事件，Saga 继续执行。 |
| 4. **买家指定支付** | 买家 | 调用 `UseEscrowPayment` | **托管合约** | 指定使用预存的 EscrowPayment 记录来支付当前 Escrow 交易。 |
| 5. **确认支付** | 托管合约 | 内部处理 | **托管合约** | 验证并锁定指定的 EscrowPayment，确认支付信息匹配 Escrow 要求，触发 `EscrowPaymentUsed` 事件，Saga 继续执行。 |
| 6. **转移NFT** | **托管合约** | 调用 `Transfer` | **NFT合约** | 将NFT从**自己**转移给买家，等待链上确认。 |
| 7. **确认NFT转移** | NFT合约 | 发送 `Debit-Notice` | **托管合约** | 托管合约监听到通知，确认 NFT 已转移给买家，Saga 继续执行。 |
| 8. **转移资金** | **托管合约** | 调用 `Transfer` | **Token合约** | 将预存资金（从EscrowPayment中获取）转移给卖家，等待链上确认。 |
| 9. **确认资金转移** | Token合约 | 发送 `Debit-Notice` | **托管合约** | 托管合约监听到通知，确认资金已转移给卖家，Saga 标记为完成。 |

### 完整的 AO Saga 流程

```
1. Saga 创建托管记录 (invoke: CreateNftEscrowRecord)
     │ 生成 EscrowId，关联已验证的支付记录
     │
     └─> 2. Saga 等待NFT存入 (waitForEvent: NftDeposited)
          │ 筛选条件: escrowId == EscrowId
          │
          └─> (卖家 Transfer NFT -> 托管合约)
               │
               └─> 3. Saga 等待买家指定支付 (waitForEvent: EscrowPaymentUsed)
                    │ 筛选条件: escrowId == EscrowId
                    │ 匹配机制: 买家指定使用预存的 EscrowPayment 记录
                    │
                    └─> (买家 UseEscrowPayment -> 托管合约)
                         │
                         └─> 4. Saga 发送转移NFT指令 (invokeLocal: transfer_nft_to_buyer_via_proxy)
                              │
                              └─> 5. Saga 等待NFT转移确认 (waitForEvent: NftTransferredToBuyer)
                                   │ 筛选条件: escrowId == EscrowId
                                   │
                                   └─> (监听NFT合约的Debit-Notice)
                                        │
                                        └─> 6. Saga 发送转移资金指令 (invokeLocal: transfer_funds_to_seller_via_proxy)
                                             │
                                             └─> 7. Saga 等待资金转移确认 (waitForEvent: FundsTransferredToSeller)
                                                  │ 筛选条件: escrowId == EscrowId
                                                  │
                                                  └─> (监听Token合约的Debit-Notice)
                                                       │
                                                       └─> Saga 标记为完成
```

### 核心流程时间轴（估算）

```
T=0s:   卖家发送 `ExecuteNftEscrowTransaction` 消息（指定交易条件），Saga 创建托管记录，生成 EscrowId，开始等待 NFT 存入。
T=10s:  卖家发送 `Transfer` 消息给NFT合约，将NFT转入托管合约。
T=11s:  NFT合约处理转移，并向托管合约发送 `Credit-Notice`。
T=12s:  托管合约监听到 `Credit-Notice`，触发 `NftDeposited` 事件，Saga 继续执行，等待买家指定支付。
T=20s:  买家发送 `UseEscrowPayment` 消息，指定使用预存的 EscrowPayment 记录支付。
T=21s:  托管合约验证并锁定指定的 EscrowPayment，确认支付信息匹配 Escrow 要求。
T=22s:  托管合约触发 `EscrowPaymentUsed` 事件，Saga 被唤醒，开始转移 NFT。
T=22.1s: Saga执行本地代理函数，向NFT合约发送 `Transfer` 消息。
T=22.2s: Saga进入 `WaitForNftTransferConfirmation` 等待状态。
T=23s:  NFT合约处理转移，并向托管合约(原Owner)发送 `Debit-Notice`。
T=24s:  托管合约监听到 `Debit-Notice`，触发 `NftTransferredToBuyer` 事件，Saga 被唤醒，开始转移资金。
T=24.1s: Saga执行本地代理函数，向Token合约发送 `Transfer` 消息。
T=24.2s: Saga进入 `WaitForFundsTransferConfirmation` 等待状态。
T=25s:  Token合约处理转移，并向托管合约(原Owner)发送 `Debit-Notice`。
T=26s:  托管合约监听到 `Debit-Notice`，触发 `FundsTransferredToSeller` 事件，Saga 标记为完成。

【总耗时估算：~26秒，包含用户操作时间】
```

## 2. AO 平台特性适配：设计决策的基石

本设计的所有关键决策都根植于对AO平台核心特性的深刻理解和适配。理解这些差异是理解本方案的关键。

| 特性 | EVM (同步模型) | AO (异步Actor模型) & 本方案的适配 |
| :--- | :--- | :--- |
| **调用模型** | `nft.transfer()` 是一个阻塞式调用，立即返回成功或失败。 | `ao.send({Target=NFT, ...})` 是一个非阻塞消息，立即返回。**适配**：必须使用 **Saga模式** 来编排需要多个异步消息交互的流程。 |
| **事务与状态** | 单次交易内所有操作要么全部成功，要么全部回滚 (ACID)。 | 每个消息处理都是一个原子操作，状态立即持久化。**适配**：无法回滚，必须通过Saga的 **补偿(Compensation)** 机制来执行业务逆操作，以实现最终一致性。 |
| **超时处理** | `block.timestamp < deadline` 可在合约内直接判断。 | 进程无法自我唤醒。**适配**：`waitForEvent`步骤的超时通过 **外部监控系统** 定期检查Saga状态并发送超时消息来触发，无需依赖AO的 `cron` 标签。 |
| **大数处理** | 原生支持 `uint256`。 | Lua原生数字是双精度浮点数，会丢失精度。**适配**：遵循AO生态标准，所有金额、余额等都使用字符串形式的 **`bint`** (大整数) 进行处理。 |
| **消息可靠性** | - | 消息可能因网络问题重发。**适配**：所有接收外部事件的处理器（如支付验证）必须实现 **幂等性**，通过检查唯一的 `Message-Id` 或业务ID (`intentId`) 来防止重复处理。 |
| **数据获取** | 前端可直接调用合约的 `view` 函数同步获取状态。 | 前端无法直接查询进程内存。**适配**：1. 通过发送只读消息异步获取状态。2. 更常见的是，依赖 **外部索引器** (如GraphQL) 监听合约日志（通过 `print` 输出）来构建可查询的数据库。 |
| **部署模型** | 所有逻辑在一个合约地址。 | 提倡多进程协作。**适配**：虽然本简化方案可置于单进程，但推荐将不同职责（如Saga服务、代理）逻辑上分离，通过配置文件管理依赖的进程ID，便于未来扩展为多进程部署。 |

---

## 3. DDDML Saga 实施细节

我们将所有复杂性移除，只留下最核心的Saga定义。

### 3.1. 基于 Aggregate 的 DDDML 模型定义

> **关键优化**: 将托管记录抽象为 Aggregate，完全整合 Saga 流程。参考 `blog.yaml` 的 Aggregate 设计模式。

```yaml
aggregates:
  # 预存支付资金管理
  EscrowPayment:
    module: "EscrowPayment"
    metadata:
      Preprocessors: ["CRUD_IT"]
      CRUD_IT_NO_UPDATE: true  # 支付记录一旦创建不可修改
      CRUD_IT_NO_DELETE: true  # 支付记录不可删除，只能标记为已使用或退款
    id:
      name: PaymentId
      type: bint
      generator:
        class: sequence
        structName: PaymentIdSequence
    properties:
      PayerAddress:
        type: string
        immutable: true  # 付款人地址不可更改
      TokenContract:
        type: string
        immutable: true  # 支付代币合约地址不可更改
      Amount:
        type: bint
        immutable: true  # 支付金额不可更改
      Status:
        type: string
        # enum: ["AVAILABLE", "USED", "REFUNDED"]
        initializationLogic:
          __CONSTANT__: "AVAILABLE"
      CreatedAt:
        type: number
        initializationLogic:
          __CONTEXT_VARIABLE__: MsgTimestamp
      UsedByEscrowId:
        type: bint  # 关联的Escrow交易ID（使用时填充）
    methods:
      Create:
        isInternal: true
        # 仅限支付接收代理调用
      MarkAsUsed:
        isInternal: true
        parameters:
          EscrowId: bint
        # 标记支付已被特定Escrow交易使用
      Refund:
        isInternal: true
        # 退款给付款人

  # NFT托管交易记录
  NftEscrow:
    module: "NftEscrow"
    metadata:
      Preprocessors: ["CRUD_IT"]
      CRUD_IT_NO_UPDATE: true  # 托管记录一旦创建，业务规则不允许修改
      CRUD_IT_NO_DELETE: true  # 托管记录不可删除，只能标记为完成或取消
      # 业务约束：在预存支付模式下，EscrowPayment的金额/币种必须与NftEscrow的交易条件匹配
    id:
      name: EscrowId
      type: bint
      # 可以使用 SagaId 作为 EscrowId
      # generator:
      #   class: sequence
      #   structName: EscrowIdSequence
    properties:
      SellerAddress:
        type: string
        immutable: true  # 卖家地址一旦设置不可更改
      BuyerAddress:
        type: string
        optional: true  # 创建时可选，在UseEscrowPayment时填充
      NftContract:
        type: string
        immutable: true  # NFT 合约地址不可更改
      TokenId:
        type: bint
        immutable: true  # Token ID 不可更改
      TokenContract:
        type: string
        immutable: true  # 交易期望的支付代币合约地址（如 ETH、USDC、SOL 等）
      Price:
        type: bint
        immutable: true  # 交易价格，UseEscrowPayment时需要与EscrowPayment匹配
      PaymentId:
        type: bint
        # 使用时填充，关联实际使用的预存支付记录
      EscrowTerms:
        type: string
        immutable: true  # 托管条款不可更改
      # Saga 本身有状态管理，所以不需要再定义状态字段
      # Status:
      #   type: string
      #   # 注意下面这样定义“枚举”其实是错误的，不符合 DDDML 规范
      #   enum: ["CREATED", "NFT_DEPOSITED", "PAYMENT_COMPLETED", "NFT_TRANSFERRED", "FUNDS_TRANSFERRED", "COMPLETED", "CANCELLED"]
      #   initializationLogic:
      #     __CONSTANT__: "CREATED"
      CreatedAt:
        type: number
        initializationLogic:
          __CONTEXT_VARIABLE__: MsgTimestamp
      # UpdatedAt:
      #   type: number
      #   initializationLogic:
      #     __CONTEXT_VARIABLE__: MsgTimestamp
    methods:
      Create:
        isInternal: true
        # 仅限 Saga 内部调用
      # UpdateStatus:
      #   isInternal: true
      #   parameters:
      #     Status: string
      #   event:
      #     name: "EscrowStatusUpdated"

services:
  # 统一的 NFT 托管服务 - 基于 Aggregate 构建
  NftEscrowService:
    requiredComponents:
      NftEscrow:
        type: NftEscrow
        # 依赖托管聚合根，用于状态管理和业务规则验证

    methods:
      # # 查询托管记录（同步本地操作）
      # GetEscrow:
      #   parameters:
      #     EscrowId: bint
      #   # 本地操作，查询托管状态

      # 买家指定使用预存的 EscrowPayment 支付
      UseEscrowPayment:
        parameters:
          EscrowId: bint
          PaymentId: bint
        description: "买家指定使用预存的 EscrowPayment 记录来支付指定的 Escrow 交易。系统会验证支付记录的有效性，检查EscrowPayment的金额/币种是否与Escrow交易条件匹配，将买家地址和PaymentId关联到Escrow记录，并锁定支付记录防止重复使用。最后触发EscrowPaymentUsed事件推动Saga继续"

      # 完整的 NFT 托管交易 Saga（在一个方法内完成所有步骤编排）
      # Saga 第一步创建托管记录，然后控制整个交易生命周期
      ExecuteNftEscrowTransaction:
        parameters:
          SellerAddress: string
          NftContract: string
          TokenId: bint
          TokenContract: string  # 期望的支付币种
          Price: bint  # 期望的交易价格
          EscrowTerms: string
        description: "完整的 NFT 托管交易流程编排，从创建托管记录开始，所有步骤在一个方法内定义"
        steps:
          # 步骤1: 创建托管记录（本地操作，生成 EscrowId）
          CreateNftEscrowRecord:
            invokeParticipant: "NftEscrow.CreateNftEscrow"
            description: "创建托管记录，初始化所有必要字段，生成唯一的 EscrowId"
            arguments:
              SellerAddress: "SellerAddress"
              NftContract: "NftContract"
              TokenId: "TokenId"
              TokenContract: "TokenContract"  # 期望的支付币种
              Price: "Price"  # 期望的交易价格
              EscrowTerms: "EscrowTerms"
            exportVariables:
              EscrowId:
                extractionPath: ".EscrowId"
                # 从创建响应中提取生成的 EscrowId，用于后续步骤
            # 这一步本身没有什么可补偿的
            # withCompensation: "cancel_created_escrow_record"

          # 步骤2: 等待卖家将NFT转移至本合约（外部用户操作）
          WaitForNftDeposit:
            waitForEvent: "NftDeposited"
            description: "等待卖家将NFT的所有权转移给本托管合约"
            eventFilter:
              escrowId: "EscrowId"  # 只监听对应 EscrowId 的 NFT 存入事件
            maxWaitTime: "24h"  # 24小时超时
            # 如果这一步成功、此后的步骤失败，那么需要执行补偿操作，这一步对应的补偿操作是 "将 NFT 返还给卖家"
            withCompensation: "return_nft_to_seller"

          # # 已移除的步骤: 更新托管状态为 NFT 已存入（本地操作）
          # UpdateEscrowNftDeposited:
          #   invokeParticipant: "NftEscrow.UpdateStatus"
          #   description: "NFT 已存入托管合约，更新托管记录状态"
          #   arguments:
          #     EscrowId: "EscrowId"
          #     Status: "NFT_DEPOSITED"

          # 步骤3: 等待买家指定使用预存的 EscrowPayment 支付（外部用户操作）
          WaitForPayment:
            waitForEvent: "EscrowPaymentUsed"
            description: "NFT已入库，等待买家指定使用预存的 EscrowPayment 记录完成支付"
            eventFilter:
              escrowId: "EscrowId"  # 只监听对应 EscrowId 的 EscrowPayment 使用事件
            maxWaitTime: "1h"  # 1小时支付超时
            # 如果这一步成功、此后的步骤失败，那么需要执行补偿操作，这一步对应的补偿操作是 "解锁 EscrowPayment"
            withCompensation: "unlock_escrow_payment"

          # # 已移除的步骤: 更新托管状态为支付已完成（本地操作）
          # UpdateEscrowPaymentCompleted:
          #   invokeParticipant: "NftEscrow.UpdateStatus"
          #   description: "买家已完成支付，更新托管记录状态"
          #   arguments:
          #     EscrowId: "EscrowId"
          #     Status: "PAYMENT_COMPLETED"

          # --- 与外部合约交互的标准模式: invoke + waitForEvent ---

          # 步骤4.1: 发送"转移NFT给买家"指令（通过本地代理）
          SendTransferNftToBuyer:
            invokeLocal: "transfer_nft_to_buyer_via_proxy"
            description: "调用本地 NFT 转移代理，向外部 NFT 合约发送转移指令"
            # 这个步骤只是发送一条异步消息，结果未知，所以这一步本身没有什么可补偿的

          # 步骤4.2: 等待NFT转移的链上确认
          WaitForNftTransferConfirmation:
            waitForEvent: "NftTransferredToBuyer"
            description: "等待本地代理监听到 NFT 合约的 Debit-Notice 后，发出的链上确认事件"
            eventFilter:
              escrowId: "EscrowId"
            maxWaitTime: "5m"
            # 如果这一步成功、此后的步骤失败，那么需要执行补偿操作，但是补偿操作的逻辑是定义在之前的步骤中的
            # withCompensation: "return_nft_to_seller_and_refund_buyer"

          # # 已移除的步骤: 更新托管状态为 NFT 已转移（本地操作）
          # UpdateEscrowNftTransferred:
          #   invokeParticipant: "NftEscrow.UpdateStatus"
          #   description: "NFT 已成功转移给买家，更新托管记录状态"
          #   arguments:
          #     EscrowId: "EscrowId"
          #     Status: "NFT_TRANSFERRED"

          # 步骤5.1: 发送"转移资金给卖家"指令（通过本地代理）
          SendTransferFundsToSeller:
            invokeLocal: "transfer_funds_to_seller_via_proxy"
            description: "调用本地 Token 转移代理，向外部 Token 合约发送转移指令"
            # 这个步骤只是发送一条异步消息，结果未知，所以这一步本身没有什么可补偿的

          # 步骤5.2: 等待资金转移的链上确认
          WaitForFundsTransferConfirmation:
            waitForEvent: "FundsTransferredToSeller"
            description: "等待本地代理监听到 Token 合约的 Debit-Notice 后，发出的链上确认事件"
            eventFilter:
              escrowId: "EscrowId"
            # maxWaitTime: "5m" # 不要处理超时，可以等待人工介入
            # 这是最后一步，成功了就结束了，没有什么可以补偿的
            # withCompensation: "notify_admin_of_reversal_needed" # NFT已到买家手，但资金步骤失败

          # # 已移除的步骤: 更新托管状态为资金已转移（本地操作）
          # UpdateEscrowFundsTransferred:
          #   invokeParticipant: "NftEscrow.UpdateStatus"
          #   description: "资金已成功转移给卖家，更新托管记录状态"
          #   arguments:
          #     EscrowId: "EscrowId"
          #     Status: "FUNDS_TRANSFERRED"

          # # 已移除的步骤: 完成托管交易（内部操作）
          # CompleteEscrowTransaction:
          #   invokeParticipant: "NftEscrow.UpdateStatus"
          #   description: "所有步骤均已确认，将托管记录标记为完成"
          #   arguments:
          #     EscrowId: "EscrowId"
          #     Status: "COMPLETED"
```

### 3.2. 本地代理实现模式

> **重要架构决策**: Saga 不直接调用外部合约，而是通过本地代理模块进行间接调用。

**为什么需要本地代理？**
- **技术集成层**: 本地代理负责与外部 AO 合约的通信细节
- **不在 DDDML 中建模**: 代理不是业务服务，不需要领域建模
- **运行时组件**: 代理作为 Lua 模块存在于 AO 进程中

**代理实现位置**:
```lua
-- 在生成的 nft_escrow_service_local.lua 中实现
function transfer_nft_to_buyer_via_proxy(context)
    -- 从关联的NftEscrow记录中获取买家地址
    local escrow_record = get_nft_escrow(context.EscrowId)

    -- 调用本地 NFT 转移代理模块
    local nft_proxy = require("nft_transfer_proxy")
    return nft_proxy.transfer({
        from = ao.id,
        to = escrow_record.BuyerAddress,
        nft_contract = context.NftContract,
        token_id = context.TokenId
    })
end

function transfer_funds_to_seller_via_proxy(context)
    -- 从关联的EscrowPayment中获取支付信息
    local escrow_payment = get_escrow_payment(context.EscrowId)

    -- 调用本地 Token 转移代理模块
    local token_proxy = require("token_transfer_proxy")
    return token_proxy.transfer({
        token_contract = escrow_payment.TokenContract,  -- 从EscrowPayment获取币种
        recipient = context.SellerAddress,
        amount = escrow_payment.Amount  -- 转出全部预存金额
    })
end
```

**代理职责**:
1. **消息构造**: 构建正确的 AO 消息格式
2. **错误处理**: 处理外部合约调用失败
3. **事件监听**: 监听外部合约的 Credit/Debit Notice
4. **状态转换**: 将外部事件转换为 Saga 可识别的内部事件

### 3.4. 其他复杂场景

如价格协商、批量托管、拍卖等更复杂的场景，可以在此核心Saga模型的基础上，通过增加更多的`waitForEvent`步骤或引入新的Saga来进行扩展。当前设计将不再对它们进行详细阐述。

### 3.5. 超时处理器

`waitForEvent` 步骤的 `maxWaitTime` 机制依赖于**外部监控系统**。外部监控系统会定期检查Saga实例的等待状态，并在检测到超时时，向托管合约发送一个特定的消息来触发超时事件。

```lua
-- 在托管合约的主文件中，处理来自外部监控系统的超时触发消息
Handlers.add(
    "HandleSagaTimeoutTrigger",
    Handlers.utils.hasMatchingTag("Action", "SagaTimeoutTriggered"),
    function (msg)
        local saga_id = msg.Tags["X-SagaId"]
        local event_type = msg.Tags["X-EventType"] -- 例如: "PaymentTimeout"
        local reason = msg.Tags["Reason"] or "Timeout detected by external monitor."

        -- 触发Saga内部的失败/超时事件，这将启动补偿流程
        -- DDDML工具生成的 trigger_local_saga_event 会处理幂等性和状态检查
        trigger_local_saga_event(saga_id, event_type, {
            event_id = "timeout_" .. saga_id .. "_" .. event_type .. "_" .. os.time(),
            reason = reason,
            triggered_by = "external_monitor"
        })
    end
)
```

**外部监控系统职责**：
1.  定期查询托管合约，获取所有处于 `waiting_state` 的Saga实例及其 `maxWaitTime`。
2.  计算当前时间是否已超过 `maxWaitTime`。
3.  如果超时，向托管合约发送一个 `Action = "SagaTimeoutTriggered"` 的消息，其中包含 `X-SagaId` 和 `X-EventType`（对应Saga定义中的 `failureEvent` 或一个通用的超时事件）。

---

### 代理合约交互规约

**架构核心**：本方案中的“代理合约”并非独立的AO进程，而是作为**进程内的本地Lua模块**与Saga服务共同部署。这种“本地包装”模式是`external-contract-saga-integration.md`文档推荐的最佳实践，旨在简化状态管理、提升性能并确保Saga事务的一致性。以下规约均基于此“本地代理”的前提。

为确保与AO生态系统的兼容性并降低实施风险，所有Saga与代理合约之间的交互遵循以下规约：

**参数传递**
当Saga通过代理调用外部合约（如NFT、Token）时，代理实现**必须**将业务参数（如`TokenId`, `Recipient`, `Quantity`）放入消息的 `Tags` 中。这是AO生态（特别是与钱包兼容的合约）的通用实践。

*示例: `NftTransferProxy.Transfer` 的实现*
```lua
-- Saga Arguments: { NftContract="abc", TokenId="123", To="xyz" }
-- 代理发送的消息:
ao.send({
    Target = "abc",
    Tags = {
        Action = "Transfer",
        TokenId = "123",
        Recipient = "xyz"
        -- 其他必要的Tags
    }
})
```

**复杂返回值**
当一个代理方法需要返回复杂数据（多个字段）或布尔值时，它**必须**将返回数据 `json.encode` 为一个字符串，并将其放入回复消息的 `Data` 字段中。Saga的 `onReply` 逻辑则负责从 `Data` 字段中解码JSON。

*示例: `NftTransferProxy.IsApproved` 的回复消息*
```lua
-- 正确的回复消息格式
Send({
    Target = saga_process_id,
    Data = json.encode({ is_approved = true, operator = "..." })
    -- 其他必要的Saga路由Tags
})
```

**触发Saga事件**
当代理监听到外部合约的响应或确认后，它**必须**通过调用DDDML工具生成的 `trigger_local_saga_event(saga_id, event_type, event_data)` API来触发相应的Saga事件，以推动Saga流程继续。`event_type` 必须与Saga定义中 `waitForEvent` 声明的事件类型匹配。

**代理内部状态管理**
代理在处理外部响应并触发Saga事件时，其内部状态（如 `pending_requests`）的更新**必须**遵循“先缓存后commit”的模式，以确保与Saga的整体事务一致性。这意味着在所有验证和准备工作完成后，才进行状态的实际修改和事件的触发。

**健壮性与错误处理**
代理实现**必须**考虑以下健壮性机制：
*   **幂等性**：通过检查唯一的 `Message-Id` 或业务ID来防止重复处理外部响应。
*   **重复消息处理**：能够识别并安全地忽略重复的外部消息。
*   **内存泄漏防护**：实现机制来清理过时或超时的 `pending_requests` 记录，防止内存无限增长。

**支付确认机制**
由于采用预存支付方案，支付确认通过 `UseEscrowPayment` 方法直接指定，无需复杂的转账匹配逻辑。系统直接验证并锁定指定的 EscrowPayment 记录。

### 🔄 **过时的转账匹配机制（现已简化）**

在早期设计中，我们曾尝试通过复杂匹配机制将用户转账与Escrow交易关联起来，但发现AO生态的限制：

- **X-RequestId直接匹配**：理想但不可行，AO不支持可靠的请求ID传递
- **AO Token Blueprint限制**：不支持Memo字段，只转发X-前缀标签
- **Wander钱包限制**：UI不支持自定义标签传递

还考虑过采用**金额+时间窗口+唯一性约束匹配**的复杂方案，要求同一币种+金额组合在等待支付状态下必须唯一，以确保安全。

**但现在这些都已过时**：我们采用**预存支付+明确指定**的新方案，买家先预存资金到EscrowPayment，然后通过`UseEscrowPayment`方法明确指定使用哪个预存记录，完全避免了复杂的匹配逻辑。

**NFT存入确认**
需要一个 `NftDepositProxy` (逻辑上)来监听NFT合约的 `Credit-Notice`。当托管合约收到发给自己的NFT时，该代理负责验证收到的NFT是否与 `WaitForNftDeposit` 步骤中等待的NFT匹配，并触发 `NftDeposited` 事件。

**链上效果确认**
代理层现在还必须监听来自NFT和Token合约的 `Debit-Notice`。当托管合约成功转出NFT或Token后，它会收到相应的 `Debit-Notice`。代理监听到这些通知后，负责触发 `NftTransferredToBuyer` 和 `FundsTransferredToSeller` 事件，以推动Saga进入下一个状态。

---

## 5. 测试、监控与部署

### 5.1. 测试策略

所有测试、监控和部署计划将同样简化，仅聚焦于验证这一个核心交易流程的正确性、安全性和性能。

- **测试**: 重点测试“支付-转移NFT-转移资金”的Saga流程，及其在`TransferFundsToSeller`和`TransferNftToBuyer`失败时的补偿路径。
- **监控**: 核心监控此Saga的执行时长、成功率和失败率。

### 5.2. 部署与运维

#### 部署架构

**推荐采用“进程内本地代理”模式**。即将所有核心服务（Saga、聚合根）与所有代理（用于与外部合约交互）部署在**同一个AO进程**中。这极大地简化了状态管理、保证了事务一致性并优化了性能。

```
+------------------------------------+
| Escrow AO Process                  |
|                                    |
|  +-------------------------------+ |
|  | NftEscrowService (DDDML-gen)  | |
|  |-------------------------------| |
|  | - ExecuteNftEscrowTransaction| |
|  |   Saga (all steps in one     | |
|  |   method per DDDML limits)   | |
|  | - UseEscrowPayment           | |
|  |   (specify payment for escrow)| |
|  | - NftEscrow Aggregate         | |
|  | - Saga Runtime & State        | |
|  +-------------------------------+ |
|                                    |
|  +-------------------------------+ |
|  | Local Proxy Functions         | |
|  | (in nft_escrow_service_local.lua)|
|  |-------------------------------| |
|  | - transfer_nft_to_buyer_via_proxy |
|  | - transfer_funds_to_seller_via_proxy |
|  +-------------------------------+ |
|                                    |
|  +-------------------------------+ |
|  | External Contract Listeners   | |
|  | (in main handlers)            | |
|  |-------------------------------| |
|  | - Credit/Debit Notice handlers |
|  |   for NFT & Token contracts   | |
|  +-------------------------------+ |
|                                    |
+------------------------------------+
```

#### 配置管理

通过一个中心化的 `config.lua` 文件管理所有可调参数，方便在不同环境中部署。

```lua
-- config.lua

local function get_env(key, default)
    local value = os.getenv(key)
    if value == nil then return default end
    return value
end

return {
    service = {
        name = "AO-NFT-Escrow-v1.0"
    },
    contracts = {
        -- 在测试或部署时通过环境变量注入
        token_contract_id = get_env("TOKEN_ID", "wARJz1KwxRWzi2r9daH4o0MKdlp0W_QgLqhah5zu4E")
    },
    business = {
        platform_fee_basis_points = 250,  -- 2.5%
        min_price = 1000, -- 最小价格，单位 aotest
    },
    security = {
        event_ttl_seconds = 86400, -- 24小时
    }
}
```

---

## 6. 附录

（附录部分保持不变，提供对核心提案的参考。）

### 6.1. 快速启动检查清单

- [ ] 理解AO原生所有权转移模型下的7步Saga流程（在一个方法内完成，从创建托管记录开始）。
- [ ] 研究`ExecuteNftEscrowTransaction` Saga中 **`waitForEvent`** 的用法和事件过滤。
- [ ] 理解**本地代理函数**（在 `nft_escrow_service_local.lua` 中）如何与外部合约交互。
- [ ] 理解**NftEscrow和EscrowPayment Aggregate** 的数据持久化和业务规则（预存支付模式，Saga 自身管理执行状态）。掌握**交易条件匹配验证**机制，确保EscrowPayment与NftEscrow的金额/币种完全匹配。
- [ ] 掌握**预存支付机制**：买家预存资金到 EscrowPayment，支付时明确指定使用哪个预存记录，确保支付精确匹配。理解 EscrowPayment 锁定和验证逻辑。
- [ ] 审查**补偿路径**，特别是资金转移失败后如何退款给买家。

### 6.2. 相关文档导航

| 文档 | 路径 | 用途 |
| :--- | :--- | :--- |
| 📘 Saga 扩展提案 | `docs/dddml-saga-async-waiting-enhancement-proposal.md` | `waitForEvent` 扩展的详细规范。 |
| 📙 代理合约模式 | `docs/AO-token-research/external-contract-saga-integration.md` | 代理合约集成的核心思想与模式。 |
| 📗 EVM 设计参考 | `docs/drafts/Perplexity-NFT-Escrow.md` | 原始的 EVM Escrow 业务逻辑参考。 |
