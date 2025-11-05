# AO NFT Escrow 简化设计与实施规划 (AO 原生所有权转移模型)

> **文档状态**：v2.0 - 简化版  
> **核心目标**：核心目标：基于对AO异步消息模型和原生所有权转移机制的深刻理解，设计并实现一个健壮、高效的NFT托管Saga。
> **作者**：Gemini（AI）

---

## 1. 核心业务流程 (AO 原生所有权转移模型)

纠正了关键的认知偏差：AO中没有EVM的`approve`授权模型。资产转移必须由当前所有者发起。因此，托管流程被重构为以下符合AO原生模型的步骤：

| 步骤 | 操作方 | 动作 | 目标合约 | 结果 |
| :--- | :--- | :--- | :--- | :--- |
| 1. **创建托管** | 卖家 | 发送 `CreateEscrow` 消息 | **托管合约** | 托管记录被创建，状态为 `AWAITING_DEPOSIT`。Saga启动，等待NFT存入。 |
| 2. **存入NFT** | 卖家 | 调用 `Transfer` | **NFT合约** | 将NFT的所有权直接转移给**托管合约的地址**。NFT被锁定。 |
| 3. **确认存入** | NFT合约 | 发送 `Credit-Notice` | **托管合约** | 托管合约监听到通知，触发 `NftDeposited` 事件，Saga状态推进到 `AWAITING_PAYMENT`。 |
| 4. **买家支付** | 买家 | 调用 `Transfer` | **Token合约** | 将约定金额的Token所有权转移给**托管合约的地址**。 |
| 5. **确认支付** | Token合约 | 发送 `Credit-Notice` | **托管合约** | 托管合约监听到通知，触发 `PaymentCompleted` 事件，Saga被唤醒。 |
| 6. **转移NFT** | **托管合约** | 调用 `Transfer` | **NFT合约** | 将NFT从**自己**转移给买家。 |
| 7. **转移资金** | **托管合约** | 调用 `Transfer` | **Token合约** | 将资金从**自己**转移给卖家。 |

### 正确的 AO Saga 流程

```
(前提: 卖家CreateEscrow)

1. Saga 等待NFT存入 (waitForEvent: NftDeposited)
     │
     └─> (卖家 Transfer NFT -> 托管合约)
          │
          └─> 2. Saga 等待买家支付 (waitForEvent: PaymentCompleted)
               │
               └─> (买家 Transfer Token -> 托管合约)
                    │
                    └─> 3. Saga 发送转移NFT指令 (invoke: TransferNftToBuyer)
                         │
                         └─> 4. Saga 等待NFT转移确认 (waitForEvent: NftTransferredToBuyer)
                              │
                              └─> (监听NFT合约的Debit-Notice)
                                   │
                                   └─> 5. Saga 发送转移资金指令 (invoke: TransferFundsToSeller)
                                        │
                                        └─> 6. Saga 等待资金转移确认 (waitForEvent: FundsTransferredToSeller)
                                             │
                                             └─> (监听Token合约的Debit-Notice)
                                                  │
                                                  └─> 7. Saga 完成 (invoke: CompleteEscrow)
```

### 核心流程时间轴（估算）

```
T=0s:   卖家发送 `CreateEscrow` 消息，Saga启动并等待NFT存入。
T=10s:  卖家发送 `Transfer` 消息给NFT合约，将NFT转入托管合约。
T=11s:  NFT合约处理转移，并向托管合约发送 `Credit-Notice`。
T=12s:  托管合约监听到 `Credit-Notice`，触发 `NftDeposited` 事件，Saga推进到等待支付状态。
T=20s:  买家向Token合约发送 `Transfer` 消息支付费用。
T=21s:  Token合约处理转账，并向托管合约发送 `Credit-Notice`。
T=22s:  托管合约监听到支付 `Credit-Notice`，触发 `PaymentCompleted` 事件，Saga被唤醒。
T=22.1s: Saga执行 `TransferNftToBuyer` 指令，向NFT合约发送 `Transfer` 消息。
T=22.2s: Saga进入 `WaitForNftTransferConfirmation` 等待状态。
T=23s:  NFT合约处理转移，并向托管合约(原Owner)发送 `Debit-Notice`。
T=24s:  托管合约监听到 `Debit-Notice`，触发 `NftTransferredToBuyer` 事件，Saga被唤醒。
T=24.1s: Saga执行 `TransferFundsToSeller` 指令，向Token合约发送 `Transfer` 消息。
T=24.2s: Saga进入 `WaitForFundsTransferConfirmation` 等待状态。
T=25s:  Token合约处理转移，并向托管合约(原Owner)发送 `Debit-Notice`。
T=26s:  托管合约监听到 `Debit-Notice`，触发 `FundsTransferredToSeller` 事件，Saga被唤醒。
T=26.1s: Saga执行 `CompleteEscrow`，交易完成。

【总耗时估算：~27秒，包含用户操作时间】
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
          # 步骤1: 等待卖家将NFT转移至本合约 (外部用户操作)
          WaitForNftDeposit:
            waitForEvent: "NftDeposited"
            description: "等待卖家将NFT的所有权转移给本托管合约"
            # ... (onSuccess, failureEvent, etc.)
            withCompensation: "cancel_escrow_record"

          # 步骤2: 等待买家支付 (外部用户操作)
          WaitForPayment:
            waitForEvent: "PaymentCompleted"
            description: "NFT已入库，等待买家完成支付"
            # ... (onSuccess, failureEvent, etc.)
            withCompensation: "ReturnNftToSeller"

          # --- 与外部合约交互的标准模式: invoke + waitForEvent ---

          # 步骤3.1: 发送“转移NFT给买家”指令
          SendTransferNftToBuyer:
            invokeParticipant: "NftTransferProxy.Transfer"
            description: "通过代理，向外部NFT合约发送转移指令"
            arguments:
              From: "ao.id"
              To: "context.BuyerAddress"
              NftContract: "context.NftContract"
              TokenId: "context.TokenId"
            # 此步骤的补偿将在下一步骤的补偿中处理

          # 步骤3.2: 等待NFT转移的链上确认
          WaitForNftTransferConfirmation:
            waitForEvent: "NftTransferredToBuyer"
            description: "等待代理监听到NFT合约的Debit-Notice后，发出的链上确认事件"
            maxWaitTime: "5m"
            withCompensation: "ReturnNftToSellerAndRefundBuyer"

          # 步骤4.1: 发送“转移资金给卖家”指令
          SendTransferFundsToSeller:
            invokeParticipant: "TokenTransferProxy.Transfer"
            description: "通过代理，向外部Token合约发送转移指令"
            arguments:
              Recipient: "context.SellerAddress"
              Amount: "calculate_seller_payout(context.ActualAmount)"
            # 此步骤的补偿将在下一步骤的补偿中处理

          # 步骤4.2: 等待资金转移的链上确认
          WaitForFundsTransferConfirmation:
            waitForEvent: "FundsTransferredToSeller"
            description: "等待代理监听到Token合约的Debit-Notice后，发出的链上确认事件"
            maxWaitTime: "5m"
            withCompensation: "notify_admin_of_reversal_needed" # NFT已到买家手，但资金步骤失败

          # 步骤5: 完成托管 (内部操作)
          CompleteEscrow:
            invokeLocal: "mark_escrow_as_completed"
            description: "所有步骤均已确认，将托管记录标记为完成"

```

### 3.2. 其他复杂场景

如价格协商、批量托管、拍卖等更复杂的场景，可以在此核心Saga模型的基础上，通过增加更多的`waitForEvent`步骤或引入新的Saga来进行扩展。当前设计将不再对它们进行详细阐述。

### 3.3. 超时处理器

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

**支付确认**

`PaymentVerificationProxy` 依赖于监听Token合约的 `Credit-Notice`。其核心职责是从 `Credit-Notice` 的 `Tags` 中提取 `Sender` 和 `Quantity`，并与 `intentId` 绑定的预期支付进行匹配。

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
|  | Saga Service (DDDML-generated)  | |
|  |-------------------------------| |
|  | - ProcessStandardSale Saga    | |
|  | - Saga Runtime & State        | |
|  +-------------------------------+ |
|                                    |
|  +-------------------------------+ |
|  | Local Proxies (Lua Modules)   | |
|  |-------------------------------| |
|  | - NftDepositProxy             | |
|  | - PaymentVerificationProxy    | |
|  | - NftTransferProxy            | |
|  | - TokenTransferProxy          | |
|  +-------------------------------+ |
|                                    |
|  +-------------------------------+ |
|  | Handlers (Lua Module)         | |
|  |-------------------------------| |
|  | - Listens for Credit/Debit    | |
|  |   Notices from external       | |
|  |   contracts and forwards to   | |
|  |   the appropriate proxy.      | |
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

- [ ] 理解AO原生所有权转移模型下的7步Saga流程。
- [ ] 研究`ProcessStandardSale` Saga中 **`waitForEvent`** 的用法。
- [ ] 理解**代理合约**在支付验证和资产转移中的作用。
- [ ] 审查**补偿路径**，特别是`TransferFundsToSeller`失败后如何退款给买家。

### 6.2. 相关文档导航

| 文档 | 路径 | 用途 |
| :--- | :--- | :--- |
| 📘 Saga 扩展提案 | `docs/dddml-saga-async-waiting-enhancement-proposal.md` | `waitForEvent` 扩展的详细规范。 |
| 📙 代理合约模式 | `docs/AO-token-research/external-contract-saga-integration.md` | 代理合约集成的核心思想与模式。 |
| 📗 EVM 设计参考 | `docs/drafts/Perplexity-NFT-Escrow.md` | 原始的 EVM Escrow 业务逻辑参考。 |