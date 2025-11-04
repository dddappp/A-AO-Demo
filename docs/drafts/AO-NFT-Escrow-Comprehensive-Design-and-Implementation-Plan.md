# AO NFT Escrow 简化设计与实施规划 (EVM 适配版)

> **文档状态**：v2.0 - 简化版  
> **核心目标**：将经典的6步EVM NFT Escrow流程，以最直接、最简单的方式适配到AO的异步消息模型中，并使用DDDML Saga进行核心事务的编排。
> **作者**：Gemini（AI）

---

## 1. 核心业务流程 (EVM 6步法 AO 适配)

我们严格遵循用户指定的6步流程，并将其转换为AO原生的异步Saga模型。

| EVM 步骤 | 描述 | AO 适配实现 |
| :--- | :--- | :--- |
| **1. NFT 批准** | 卖家授权Escrow合约转移其NFT。 | **(前提条件)** 卖家向NFT合约发送消息，`approve`托管合约地址作为操作员。这是一个独立于托管流程的**手动前置操作**。 |
| **2. 创建托管** | 卖家调用`createEscrow`创建托管记录。 | **(Saga前置)** 卖家向托管合约发送`CreateEscrow`消息，合约创建状态为`CREATED`的记录。 |
| **3. 查询托管** | 买家查询托管详情。 | **(Saga前置)** 买家向托管合约发送只读消息`GetEscrow`以获取状态。 |
| **4. 买方支付** | 买家调用`fundEscrow`发送Token。 | **(Saga步骤1: 等待事件)** 买家向托管合约地址转账。Saga使用`waitForEvent`等待由代理合约转发的`PaymentCompleted`事件。 |
| **5. 转移NFT** | 合约自动将NFT从卖家转移给买家。 | **(Saga步骤2: 调用参与者)** Saga在收到支付事件后，调用`NftTransferProxy`将NFT从卖家地址转移到买家地址。 |
| **6. 提取资金** | 卖家调用`withdrawFunds`提取收益。 | **(Saga步骤3 & 独立操作)** Saga调用`TokenTransferProxy`将资金转给卖家。**注意**：为简化流程，我们设计为Saga自动转账，而非卖家手动提取。 |

### 简化的 AO Saga 流程

核心的原子事务（支付、转移NFT、转移资金）被封装在一个Saga中，确保最终一致性。

```
(前提: 卖家已Approve, 已CreateEscrow)

1. 买家向托管合约转账 (用户操作)
     │
     └─> 2. Saga 等待支付事件 (waitForEvent)
          │
          └─> 3. Saga 命令转移 NFT (Seller -> Buyer)
               │
               └─> 4. Saga 命令转移资金 (Escrow -> Seller)
                    │
                    └─> 5. Saga 完成
```

## 2. AO 平台特性适配

本设计的所有关键决策都根植于对AO平台核心特性的深刻理解和适配。

- **异步消息驱动**: AO中没有同步函数调用，所有跨进程交互都是异步消息。这决定了我们必须采用 **Saga模式** 来编排多步事务，而不能像EVM那样在单次调用中完成所有操作。

- **最终一致性**: 由于异步和多进程的特性，我们无法实现强一致性。Saga的 **补偿（Compensation）机制** 是实现最终一致性的唯一途径。这意味着每一步操作都必须有一个对应的“逆操作”。

- **原生超时机制 (`cron`)**: AO支持通过为消息添加 `cron` 标签来调度未来的消息。我们利用此特性来处理 `maxWaitTime`，替代了对外部监控服务的依赖，使设计更内聚、更健壮。

- **状态持久化与 `bint`**: AO进程的状态（Lua全局变量）会自动持久化。为处理大额token数量并避免Lua原生数字的精度问题，所有金额都将使用字符串形式的`bint`（大整数）进行处理，这已成为AO生态的事实标准。

- **单线程与幂等性**: AO进程内的消息是串行处理的，天然避免了竞态条件。但网络可能导致消息重发，因此所有关键的入口消息处理器（特别是接收支付事件的）都必须实现 **幂等性**，通过 `event_id` 或 `Message-Id` 防止重复处理。

---

## 3. DDDML Saga 实施细节

我们将所有复杂性移除，只留下最核心的Saga定义。

### 3.1. 简化的 DDDML 服务定义

```yaml
services:
  # 用户交互服务，用于创建和查询
  EscrowService:
    methods:
      CreateEscrow:
        # ... 创建托管记录的本地步骤
      GetEscrow:
        # ... 查询托管记录的本地步骤
      StartPurchaseSaga: # 买家表达购买意图，启动等待支付的Saga
        parameters:
          EscrowId: string
          BuyerAddress: string
        steps:
          InitiateSaga:
            invokeParticipant: "NftEscrowSagaService.ProcessStandardSale"
            # ... 传递必要的上下文

  # 核心交易编排Saga
  NftEscrowSagaService:
    methods:
      ProcessStandardSale:
        parameters:
          EscrowId: string
          # ... (其他参数)
        steps:
          # 步骤0: 验证卖家是否已授权
          ValidateNftApproval:
            invokeParticipant: "NftTransferProxy.IsApproved"
            description: "验证托管合约是否已被卖家授权转移此NFT"
            arguments:
              Owner: "context.SellerAddress"
              Operator: "context.EscrowContractAddress"
              NftContract: "context.NftContract"
              TokenId: "context.TokenId"
            onReply:
              Lua: "if not reply.is_approved then error('NFT_NOT_APPROVED') end" 

          # 步骤1: 等待买家支付
          WaitForPayment:
            waitForEvent: "PaymentCompleted"
            description: "等待买家完成支付"
            onSuccess:
              Lua: "if event.data.amount == context.PriceAmount then return true end" # 采用严格相等匹配，不处理超额支付
            exportVariables:
              ActualAmount: { extractionPath: ".data.amount" }
              PaymentTxId: { extractionPath: ".data.transaction_id" }
            failureEvent: "PaymentFailedOrTimeout" # 支付失败或超时事件
            maxWaitTime: "30m"
            withCompensation: "TokenProxy.RefundToBuyer" # 关键补偿：一旦支付被确认，任何后续失败都必须首先保证退款给买家

          # 步骤1.1: 调度一个超时检查消息 (AO Cron)
          ScheduleTimeoutCheck:
            invokeLocal: "schedule_timeout_check"
            description: "使用AO的cron功能，在30分钟后发送一个消息给自己，用于检查支付是否超时"
            arguments:
              SagaId: "context.SagaId"
              Timeout: "30m"

          TransferNftToBuyer:
            invokeParticipant: "NftTransferProxy.Transfer"
            description: "将NFT从卖家转移给买家"
            arguments:
              From: "context.SellerAddress"
              To: "context.BuyerAddress"
              NftContract: "context.NftContract"
              TokenId: "context.TokenId"
            withCompensation: "notify_admin_of_reversal_needed" # 补偿：NFT已到买家手中，但交易失败，通知管理员人工处理

          # 步骤3: 转移资金（从托管合约到卖家）
          TransferFundsToSeller:
            invokeParticipant: "TokenTransferProxy.Transfer"
            description: "将资金转给卖家（减去手续费）"
            arguments:
              Recipient: "context.SellerAddress"
              Amount: "calculate_seller_payout(context.ActualAmount)"
            withCompensation: "TokenProxy.RefundToBuyer" # 关键补偿：若资金转账失败，必须退款给买家

          # 步骤4: 完成托管
          CompleteEscrow:
            invokeLocal: "mark_escrow_as_completed"
            description: "将托管记录标记为完成"
```

### 3.2. 其他复杂场景

如价格协商、批量托管、拍卖等更复杂的场景，可以在此核心Saga模型的基础上，通过增加更多的`waitForEvent`步骤或引入新的Saga来进行扩展。当前设计将不再对它们进行详细阐述。

### 3.3. 超时处理器

`schedule_timeout_check` 步骤会发送一个带有 `cron` 标签的延迟消息。托管合约需要一个对应的处理器来处理这个消息。

```lua
-- 在托管合约的主文件中
Handlers.add(
    "HandlePaymentTimeout",
    Handlers.utils.hasMatchingTag("Action", "PaymentTimeoutCheck"),
    function (msg)
        local saga_id = msg.Tags["X-SagaId"]
        local saga = saga.get_saga_instance(saga_id)

        -- 检查Saga是否仍在等待支付
        if saga and saga.waiting_state and saga.waiting_state.event_type == "PaymentCompleted" then
            -- 触发失败/超时事件，这将启动补偿流程
            trigger_local_saga_event(saga_id, "PaymentFailedOrTimeout", { 
                reason = "Payment timed out after 30 minutes."
            })
        end
        -- 如果Saga已不在等待状态（说明已成功支付），则此超时消息被安全地忽略。
    end
)
```

---

## 4. 关键技术实现

所有技术实现（如代理合约、`trigger_local_saga_event`的调用、安全措施等）将仅围绕上述简化的Saga流程进行。

- **支付验证**: `PaymentVerificationProxy` 将使用 `intentId` (在`StartPurchaseSaga`时生成) 来精确匹配收到的 `Credit-Notice`。
- **NFT转移**: `NftTransferProxy` 依赖于卖家已预先完成的 `approve` 操作。
- **资金转移**: `TokenTransferProxy` 将托管合约收到的资金转移给卖家。

---

## 5. 测试、监控与部署

所有测试、监控和部署计划将同样简化，仅聚焦于验证这一个核心交易流程的正确性、安全性和性能。

- **测试**: 重点测试“支付-转移NFT-转移资金”的Saga流程，及其在`TransferFundsToSeller`和`TransferNftToBuyer`失败时的补偿路径。
- **监控**: 核心监控此Saga的执行时长、成功率和失败率。

---

## 6. 附录

（附录部分保持不变，提供对核心提案的参考。）

### 6.1. 快速启动检查清单

- [ ] 理解简化的**6步EVM流程**如何映射到AO的异步Saga。
- [ ] 研究`ProcessStandardSale` Saga中 **`waitForEvent`** 的用法。
- [ ] 理解**代理合约**在支付验证和资产转移中的作用。
- [ ] 审查**补偿路径**，特别是`TransferFundsToSeller`失败后如何退款给买家。

### 6.2. 相关文档导航

| 文档 | 路径 | 用途 |
| :--- | :--- | :--- |
| 📘 Saga 扩展提案 | `docs/dddml-saga-async-waiting-enhancement-proposal.md` | `waitForEvent` 扩展的详细规范。 |
| 📙 代理合约模式 | `docs/AO-token-research/external-contract-saga-integration.md` | 代理合约集成的核心思想与模式。 |
| 📗 EVM 设计参考 | `docs/drafts/Perplexity-NFT-Escrow.md` | 原始的 EVM Escrow 业务逻辑参考。 |