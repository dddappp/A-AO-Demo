# AO NFT Escrow Implementation Plan (DDDML-Driven)

> **作者**：GPT-5 Codex（AI）

## 1. Background & Goals

- 参考 `dddml-saga-async-waiting-enhancement-proposal.md` 的扩展规范，假设 `waitForEvent` 以及相关运行时支持已经在 DDDML 工具链中落地。
- 结合 `external-contract-saga-integration.md` 中的“代理合约模式”与 `Perplexity-NFT-Escrow.md` 的 EVM 设计目标，在 AO 网络上实现一个 NFT 托管 (Escrow) 合约。
- 目标是通过 DDDML 模型驱动生成大部分编排代码，只在 `*_logic.lua` 和代理层补充必要的业务实现。

## 2. 成功标准

- **功能性**：支持 NFT 托管的创建、资金托管、支付确认、NFT 转移、资金提取、取消等核心流程。
- **异步等待**：Saga 编排中能够等待用户支付完成事件，并在成功/失败/超时情况下正确推进或补偿。
- **区块链友好**：所有超时与状态检查遵循 AO 消息驱动模式，依赖外部监控触发补偿。
- **安全性**：资金与 NFT 流程遵循代理合约安全校验、幂等处理、重放保护等要求。
- **可运维性**：提供监控指标、告警条件以及测试/验收方案。

## 3. AO 平台特性与约束

- **消息驱动异步模型**：所有进程之间通过 `ao.send` 传递消息，Escrow Saga 中的每一步都必须依赖消息标签（`Action`, `X-SagaId`, `X-ResponseAction` 等）来路由。设计时需为每个步骤规划唯一的 `Action` 名称，并在代理层补齐缺失的 Saga 标签。
- **状态持久化**：AO 进程通过 Lua 全局表和 `ao.storage`（如已启用）持久化状态。金额、TokenId 等需以字符串存储，实际运算时转换为 `bint`，与 AO Token 生态保持一致。
- **单线程执行语义**：同一进程内部消息串行处理，可简化并发控制，但跨进程交互必须考虑最终一致性以及潜在的消息乱序、延迟。
- **消息大小和费用控制**：遵循 AO 的消息大小限制（建议 < 64 KB 数据部分）以及最小费用策略。Escrow 事件数据设计应避免传输大型结构体，采用引用 ID 或哈希。
- **幂等性与重放防护**：由于 AO 消息可能重放，所有关键 Handler（尤其代理响应和 Saga 事件）需检查 `Message-Id`/自定义 `event_id`，并在状态中记录已处理事件。
- **前端与索引器集成**：DApp 前端通常通过 AO Explorer、GraphQL Indexer 或自建监听服务获得状态。本文档在监控章节中提出的指标应暴露为消息或日志，便于外部索引器消费。
- **安全与权限**：AO 缺少内置身份验证，需在业务逻辑中校验消息的来源地址（`msg.From`）、签名信息（如通过代理合约生成的校验 token），并结合白名单或多签方案保护高价值操作。
- **多进程部署**：推荐将 Saga 服务、代理合约、支付接收、监控等分别部署为独立 AO 进程，利用配置文件（`*_config.lua`）管理目标进程 ID，遵循项目规则中的可部署结构。
- **开发与测试工具链**：使用 `aos` 或 Docker 化 AO 环境调试，配合 `run-legacy-nft-tests.sh` 等脚本模拟消息流。DDDML 生成代码后，只能在 `_logic.lua` 等允许的扩展点修改，避免覆盖生成文件。

## 4. 系统上下文

| 角色/组件 | 职责 | 交互方式 |
| --- | --- | --- |
| 客户端 (卖家/买家) | 提交托管请求、发起资金托管、查询状态 | HTTP/API → AO 消息 |
| Saga 服务进程 | 执行 Escrow 领域服务与 Saga 编排 | DDDML 生成 + 手写逻辑 |
| NFT 代理合约进程 | 包装外部 NFT 转移、支付验证逻辑 | 本地调用 + 消息桥接 |
| AO Token 合约 | 处理 Token 转账，产生 `Credit-Notice/Transfer-Error` 消息 | AO 原生 |
| 支付接收合约 (可选) | 统一监听平台收款地址，向 Saga 发布支付完成事件 | 消息触发 |
| 超时监控服务 | 定期检查等待中的 Saga，必要时发送超时补偿消息 | 外部调度 |

## 5. 核心业务流程

1. **Create Escrow**：卖家提交托管请求，包含 NFT 合约地址、TokenId、价格、过期时间等。Saga 启动。
2. **Transfer NFT into Escrow (optional)**：视 AO NFT 资产模型而定，可通过代理合约在创建时锁仓或在出售后再转移。
3. **Wait for Buyer Payment**：Saga 进入 `waitForEvent` 步骤，等待支付事件 (`PaymentCompleted`)，由支付接收组件触发。
4. **Validate Payment & Update Context**：收到事件后执行 `onSuccess` 校验金额、订单号等，写入 Saga 上下文。
5. **Transfer NFT to Buyer**：通过代理合约安全转移 NFT 所有权，确认成功后记录。
6. **Record Escrow Completion & Release Funds**：更新托管状态，允许卖家提取资金。
7. **Cancellation / Timeout Handling**：在等待阶段接收到 `PaymentFailed` 或外部超时事件时走补偿路径，撤销托管并解锁资源。

## 6. DDDML 模型设计

### 6.1 聚合与实体

- `EscrowAgreement` (聚合根)
  - 属性：`EscrowId`, `Seller`, `Buyer` (可选), `NftContract`, `TokenId`, `AskingPrice`, `PaymentTimeout`, `Status`, `CreatedAt`, `ExpiresAt`, `PaymentReceipt`, `SettlementTx`
  - 状态枚举：`Pending`, `WaitingForPayment`, `PaymentVerified`, `Completed`, `Cancelled`。
- `EscrowLedgerEntry` (值对象/日志)：记录资金流、NFT 转移记录。

### 6.2 命令 (Commands)

- `CreateEscrow`：创建托管并启动 Saga。
- `CancelEscrow`：在特定状态下允许卖家取消。
- `ConfirmSettlement`：在 Saga 中由系统内部调用，更新状态。
- `MarkEscrowCompleted`：最终提交成功。
- `MarkEscrowFailed`：处理失败/补偿。

### 6.3 事件 (Events)

- `EscrowCreated`
- `EscrowPaymentPending`
- `EscrowPaymentVerified`
- `EscrowNFTTransferred`
- `EscrowCompleted`
- `EscrowCancelled`
- `EscrowFailed`

### 6.4 Saga 定义 (DDDML `waitForEvent` 支持)

示意 YAML（简化）：

```yaml
services:
  EscrowService:
    methods:
      ProcessEscrowSale:
        parameters:
          EscrowId: uuid
        steps:
          RegisterEscrow:
            invokeLocal: "register_escrow"
            exportVariables:
              EscrowContextId:
                extractionPath: ".escrow_id"
          WaitForPayment:
            waitForEvent: "PaymentCompleted"
            onSuccess:
              Lua: |
                if event.data.amount == context.AskingPrice and event.data.escrow_id == context.EscrowContextId then
                  return true
                end
                return false
            exportVariables:
              PaymentTransactionId:
                extractionPath: ".data.transaction_id"
            failureEvent: "PaymentFailed"
            onFailure:
              Lua: "context.failure_reason = event.data.reason or 'payment_failed'; return 'compensate'"
            maxWaitTime: "30m"
            withCompensation: "revert_escrow"
            compensationArguments:
              EscrowId: "EscrowContextId"
          TransferNFT:
            invokeParticipant: "EscrowProxy.TransferNFTToBuyer"
            arguments:
              EscrowId: "EscrowContextId"
              Buyer: "context.BuyerAddress"
              TokenId: "context.TokenId"
            onReply:
              Lua: "context.nft_transfer_receipt = reply.transaction_id"
          ReleaseFunds:
            invokeLocal: "release_funds"
          CompleteEscrow:
            invokeLocal: "mark_escrow_completed"
```

> 实际 YAML 将对标 DDDML 语法，命名遵循 `camelCase` 关键字与 `PascalCase` 业务对象约定。

### 6.5 代理参与者调用

- `invokeParticipant: "EscrowProxy.TransferNFTToBuyer"` 与 `EscrowProxy` 进程交互，代理处理外部 NFT 合约调用和响应验证。
- 代理负责将外部消息转换为 Saga 能理解的 `X-SagaId` 回调，并在成功时通过 `trigger_local_saga_event()` 推动 Saga 前进。

## 7. 代理合约设计 (参考 external-contract-saga-integration.md)

### 7.1 代理职责

- **请求分派**：接收 Saga 调用，记录 pending 请求（包含 `saga_id`, `escrow_id`, 业务参数）。
- **外部调用**：向 AO NFT 合约或 Token 合约发送消息（去除 Saga 相关标签）。
- **响应匹配**：根据金额、接收方、TokenId 等复合索引匹配响应，确保幂等。
- **事件发布**：通过 `trigger_local_saga_event()` 或回调消息，将结果同步到 Saga。
- **补偿执行**：在 Saga 回滚时执行退款或 NFT 回转。

### 7.2 核心扩展点

- 在 `saga.lua`/`saga_messaging.lua` 运行时中使用提案提供的 API：
  - `trigger_local_saga_event(saga_id, event_type, event_data)`
  - 等待状态管理 & 幂等性检查。
- 代理实现需遵循“先缓存后 commit”模式，保持与现有模板一致。

### 7.3 支付验证流程

1. 支付接收合约监听 `Credit-Notice`。
2. 依据金额与订单信息匹配待处理 escrow。
3. 调用 `trigger_local_saga_event(saga_id, "PaymentCompleted", event_payload)`。
4. 如金额不符，触发 `PaymentFailed` 事件。

## 8. 业务逻辑实现点

| 模块 | 位置 | 说明 |
| --- | --- | --- |
| 注册/创建逻辑 | `escrow_service_local.lua` | 校验输入、保存上下文、生成支付意向 |
| NFT 转移代理 | `proxy-contracts/nft_escrow_proxy.lua` (新建) | 封装 NFT 转移与退款逻辑 |
| 资金释放逻辑 | `escrow_service_logic.lua` | 更新余额、允许卖家提取 |
| Saga 回调 | `escrow_service_main.lua` (生成) | 使用 DDDML waitForEvent 生成的 handler |
| 监控处理器 | `escrow_timeout_monitor.lua` | 外部进程，查询等待状态并触发补偿 |

## 9. 实施阶段划分

### 阶段 1：模型与原型 (1-2 周)

- 定义 DDDML 模型 (`dddml/escrow.yaml`)，包含聚合、命令、Saga。
- 运行 DDDML 代码生成，审查生成的服务入口、Saga 编排。
- 建立基础代理合约模板，确认消息协议。

### 阶段 2：核心功能实现 (2-3 周)

- 实现本地逻辑 (`register_escrow`, `release_funds`, `mark_escrow_completed` 等)。
- 实现支付接收合约与代理事件触发。
- 实现 NFT 转移代理及补偿逻辑。
- 完成 `waitForEvent` 步骤的上下文处理逻辑（`onSuccess`, `onFailure`）。

### 阶段 3：测试与验证 (2 周)

- 编写单元测试：聚合行为、代理逻辑、事件过滤。
- 集成测试：端到端支付流程、失败补偿、超时处理。
- 压力测试：批量并发 Escrow 请求，验证索引与幂等性。

### 阶段 4：运维与文档 (1 周)

- 配置监控指标、告警规则。
- 完成部署脚本与运行指南。
- 更新 README 与 API 文档。

## 10. 测试策略

- **功能测试**：覆盖成功路径、失败路径、重复事件、超时补偿。
- **幂等性测试**：模拟重复 `Credit-Notice` 消息，确保不会多次结算。
- **安全测试**：验证未经授权的取消/提取请求被拒绝；模拟恶意事件数据。
- **性能测试**：在 1,000+ 并行等待的 Saga 场景下评估代理索引性能。
- **回归测试**：确保加入 waitForEvent 后，现有 DDDML 生成的 Saga 行为不受影响。

## 11. 监控与运维

- **关键指标**：等待中的 Saga 数量、超时 Saga 数量、平均等待时长、事件处理耗时、补偿执行次数。
- **告警条件**：等待数超过阈值、超时率 > 10%、重复事件率异常、代理进程内存超标。
- **日志策略**：结构化记录 Saga 生命周期事件 (`saga_created`, `saga_waiting_started`, `saga_event_received`, `saga_completed`, `saga_timeout`, `saga_compensated`)。

## 12. 风险与缓解

- **支付验证不一致**：通过复合索引 (金额 + 接收方 + 订单号) 确保匹配准确，并在 `onSuccess` 中执行再校验。
- **超时误补偿**：超时监控在发送补偿前再次向支付网关确认状态。
- **代理进程负载过高**：启用批量处理模式与定期内存清理。
- **工具链不稳定**：保持与 DDDML 工具团队的同步，提前验证生成代码；如必要提供特性标志回滚方案。

## 13. 下一步行动

1. 与业务方确认 Escrow 状态机、角色权限与支付渠道细节。
2. 起草 `dddml/escrow.yaml` 初稿，提交评审。
3. 原型实现支付接收合约与 `trigger_local_saga_event()` 调用链。
4. 规划自动化测试框架与模拟数据集。
5. 与 DevOps 团队讨论监控、部署与告警集成需求。

---

**附录**

- 参考文档
  - `docs/dddml-saga-async-waiting-enhancement-proposal.md`
  - `docs/AO-token-research/external-contract-saga-integration.md`
  - `docs/drafts/Perplexity-NFT-Escrow.md`


