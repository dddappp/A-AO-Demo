# AO NFT Escrow 核心设计（基于 EVM 的 6 步流程）

> **设计原则**：聚焦核心场景，直接基于 EVM Escrow 的 6 步流程进行适配  
> **目标**：最小可行产品（MVP），清晰的消息流和状态转移  
> **参考**：Perplexity-NFT-Escrow.md 的 EVM 设计
> **作者**：Haiku 4.5（AI）

---

## AO 特性对设计的关键影响

### ✅ 异步消息驱动 vs EVM 的同步调用

**EVM 模式**（同步）：
```solidity
// 调用方等待返回结果
nft.safeTransferFrom(seller, buyer, tokenId);  // 阻塞，立即知道结果
token.transfer(seller, amount);                 // 阻塞，立即知道结果
```

**AO 模式**（异步）：
```lua
-- 发送消息后立即返回，通过 Handlers 监听响应
ao.send({
    Target = nft_contract,
    Tags = { Action = "Transfer" },
    Data = json.encode({ ... })
})
-- 不等待！继续执行其他逻辑
-- NFT 合约稍后通过 Credit-Notice 或自定义消息告知结果
```

**关键影响**：
- ❌ 无法在一个事务中完成所有操作
- ✅ 必须使用 Saga 编排多步骤交互
- ✅ 每一步都需要异步回复处理

### ✅ 状态一致性：补偿 vs 回滚

**EVM 模式**（原子性）：
```lua
-- 步骤 1 成功
nft_transferred = true

-- 步骤 2 失败
payment_failed = true

-- 数据库事务自动回滚 ✅
-- nft_transferred 变回 false（如同没执行过）
```

**AO 模式**（最终一致性）：
```lua
-- 步骤 1 成功
escrow.status = "NFT_TRANSFERRED"  -- 立即持久化，无法撤销 ❌

-- 步骤 2 失败
payment_failed = true

-- 必须手动补偿 ✅
compensate_nft_transfer()  -- 业务操作逆向（转移回卖方）
```

**关键影响**：
- ❌ 无法依赖数据库回滚
- ✅ 必须在 Saga 补偿链中逆向操作
- ✅ 理解"补偿"不等于"回滚"（是业务逆操作）

### ✅ 消息标签丢失风险与缓解

**风险场景**：
```
Saga 发送消息到 NFT 代理时包含 X-SagaId:
ao.send({
    Target = nft_proxy,
    Tags = { ["X-SagaId"] = "123" }  -- 自定义标签
})
    ↓
NFT 代理转发到 NFT 合约时：
ao.send({
    Target = nft_contract,
    Tags = { ["X-SagaId"] = "123" }  -- ⚠️ 标签可能丢失！
})
    ↓
NFT 合约响应回 NFT 代理时：
Handlers.add(...)
msg.Tags["X-SagaId"]  -- ❌ 可能是 nil！
```

**我们的缓解方式**：
```lua
-- 1. 使用 AO 标准化属性名（第一道防线）
tags["X-Saga-Id"] = saga_id  -- 与自定义标签 X-SagaId 不同

-- 2. 在数据中嵌入 Saga ID（第二道防线）
Data = json.encode({
    saga_id = saga_id,
    ...
})

-- 3. 通过业务参数匹配（第三道防线 - 根本保障）
-- amount + sender 精确匹配，无需依赖标签
local key = tostring(amount) .. "|" .. sender
local escrow_id = payment_index[key]  -- O(1) 查询
```

**关键影响**：
- ❌ 不能盲目相信消息标签
- ✅ 多层防御保证可靠性
- ✅ 业务参数匹配是设计基石

### ✅ 无内置定时器 - 外部监控必需

**EVM 模式**（内置时间）：
```solidity
// 可以在合约内设置超时
require(block.timestamp < escrow.expiresAt, "Escrow expired");
```

**AO 模式**（无内置机制）：
```lua
-- ❌ AO 中不存在类似 block.timestamp 的自动触发机制
-- 无法在 Saga 内部设置"30 分钟后自动过期"

-- ✅ 必须依赖外部监控服务
Handlers.add(
  "check_escrow_expiry",
  Handlers.utils.hasMatchingTag("Action", "CheckExpiry"),
  function(msg)
    local escrow = get_escrow(msg.Data)
    if os.time() > escrow.expires_at then
      -- 触发过期处理
      cancel_escrow(escrow.id)
    end
  end
)
```

**关键影响**：
- ❌ 不能依赖自动超时
- ✅ 需要外部监控系统（可以是 cron job 或链下服务）
- ✅ 文档第 7.3 节已考虑过期场景

### ✅ Lua 特定性：大整数处理（bint）

**风险场景**：
```lua
-- ❌ Lua 原生数字是浮点数
local price = 1000000000000000000  -- 1e18（常见 Token 金额）
-- Lua 会丢失精度！

-- ✅ 使用 bint 库（已在项目中使用）
local bint = require('bint')(256)
local price = bint("1000000000000000000")  -- 精度保证
```

**关键影响**：
- ❌ 所有大金额必须使用 `bint`
- ✅ 在 escrows 数据模型中已使用：`price = bint(...)`
- ✅ 业务参数匹配时需要 `tostring()` 转换

### ✅ 消息队列与处理模型

**AO 消息处理的关键特性**：
```lua
-- AO 是单进程、单线程的消息处理模型
-- Handlers 按注册顺序顺序执行，一次只处理一条消息

Handlers.add(
  "handler1",
  condition1,
  function(msg)
    -- 这个消息完全处理完后，才会处理下一条消息
    -- ✅ 无竞态条件，无锁
    -- ❌ 但也意味着一条消息的处理延迟会影响整个队列
  end
)
```

**关键影响**：
- ✅ 天然的互斥锁：每条消息处理完后才处理下一条
- ✅ 无竞态条件：不用担心两个消息同时修改同一个 Escrow
- ❌ 单点性能风险：如果某个 Handler 特别慢，会阻塞整个队列

### ✅ 无持久存储 - 状态在内存中

**AO 的存储模型**：
```lua
-- ❌ 无数据库，无 SQL
-- ❌ 无预定义的持久化机制

-- ✅ 状态保存在内存中的 Lua 表
local escrows = {}  -- 这是 AO 进程的内存
local seller_balances = {}

-- ✅ 数据持久化方式：
-- 1. 存储在合约数据中（通过 Data 字段）
-- 2. 长期存储在 Arweave（链下）
-- 3. 进程重启时加载（从 Arweave 恢复）

-- 这个 NFT Escrow 设计中：
-- - 短期数据存在内存（escrows 表）
-- - 关键数据持久化到 Arweave（长期保存）
```

**关键影响**：
- ❌ 进程重启会丢失内存数据（除非有持久化）
- ✅ 设计中应考虑数据恢复机制
- ✅ 这个 MVP 设计中：Escrow 创建时持久化关键字段到 Arweave

### ✅ 幂等性要求 - 处理重复消息

**风险场景**：网络延迟导致消息重复
```
买方发送 TransferTokens 消息
    ↓ (网络延迟，买方没收到响应)
买方再发一次 TransferTokens 消息
    ↓
Token 合约处理第一条消息 → 转账
    ↓
Token 合约处理第二条消息 → 又转账一次！
    ↓
❌ 买方被扣了两次钱
```

**我们的幂等性保护**：
```lua
-- 业务参数匹配时检查是否已处理
function find_pending_escrow(amount, sender)
  local key = tostring(amount) .. "|" .. sender
  local escrow_id = payment_index[key]
  
  if escrow_id then
    local escrow = escrows[escrow_id]
    -- ✅ 检查是否已处理过相同支付
    if escrow.status == "COMPLETED" then
      return nil  -- 已处理，忽略重复消息
    end
    return escrow
  end
  return nil
end

-- 或者使用 request_id 去重
local processed_requests = {}  -- request_id -> processed_at
function mark_request_processed(request_id)
  processed_requests[request_id] = os.time()
end
```

**关键影响**：
- ❌ 同一条消息可能被处理多次
- ✅ 必须实现幂等性检查
- ✅ 本设计中已通过业务参数匹配保证幂等

### ✅ 最终一致性模型

**EVM：强一致性**
```
操作前：consistent ✅
操作中：executing
操作后：consistent ✅
```

**AO：最终一致性**
```
操作前：consistent ✅
Step 1：consistent ✅（已持久化）
Step 2：possibly_inconsistent ⚠️（Step 1 完成但 Step 2 未完成）
Step 3：consistent ✅（所有步骤完成，或启动补偿回到一致）
```

**关键影响**：
- ❌ 短时间内系统可能不一致
- ✅ 必须接受中间不一致状态
- ✅ Saga 补偿确保最终一致性
- ✅ 客户端需要重试机制或轮询检查

---

## 核心流程映射

### EVM 版本（同步，原子性）
```
Step 1: approve()         → Escrow 获权
Step 2: createEscrow()    → 创建托管记录
Step 3: getEscrow()       → 查询托管（查询）
Step 4: fundEscrow()      → 转账 ETH
Step 5: safeTransferFrom()  → 自动转移 NFT
Step 6: withdrawFunds()   → 卖方提取资金
```

### AO 版本（异步，Saga 编排）
```
Step 1: RegisterNftApproval  → 卖方确认授权（本地操作）
Step 2: CreateEscrow         → 创建托管记录 + 启动 Saga
Step 3: QueryEscrow          → 买方查询托管（查询）
Step 4: TransferTokens       → 买方转账 Token
        └─ WaitForPaymentConfirm  → Saga 等待支付确认
        └─ TransferNft            → 自动转移 NFT
        └─ UpdateBalance          → 更新卖方可提取余额
Step 5-6: WithdrawFunds      → 卖方提取资金（本地操作）
```

---

## 1. 数据模型

### Escrow 聚合根

```lua
{
  id = "ESC_20250104_001",
  seller = "SELLER_ADDR",
  buyer = "BUYER_ADDR",
  nft_contract = "NFT_CONTRACT_ID",
  token_id = "TOKEN_001",
  price = bint("1000000"),  -- 最小单位
  status = "CREATED",       -- CREATED | PENDING_PAYMENT | COMPLETED | CANCELLED
  balance = bint("0"),      -- 托管中的余额
  created_at = 1704326400,
  expires_at = 1704412800,
  completed_at = nil
}
```

### 状态转移图

```
CREATED
  ↓
  ├─ 买方转账 Token
  └─ → PENDING_PAYMENT
       ↓
       ├─ 支付验证成功 & NFT 转移成功
       └─ → COMPLETED
            ↓
            └─ 卖方提取资金 (状态保持 COMPLETED)

失败路径：CREATED/PENDING_PAYMENT → CANCELLED
```

---

## 2. Saga 流程

### 核心 Saga：ProcessNftEscrow

```yaml
name: NftEscrowService
method: ProcessEscrow
parameters:
  escrow_id: string
  buyer_address: string
  
steps:
  # 步骤 1：查询托管记录
  GetEscrowRecord:
    invokeLocal: "get_escrow"
    arguments:
      escrow_id: "escrow_id"
    exportVariables:
      nft_contract: ".nft_contract"
      token_id: ".token_id"
      seller: ".seller"
      price: ".price"
  
  # 步骤 2：向 Token 合约验证支付
  VerifyPayment:
    invokeParticipant: "TokenContract.VerifyTransfer"
    arguments:
      from: "buyer_address"
      to: "escrow_contract"
      amount: "price"
    onReply: "verify_payment_result"
    exportVariables:
      transaction_id: ".tx_id"
      actual_amount: ".amount"
  
  # 步骤 3：转移 NFT（通过代理）
  TransferNft:
    invokeParticipant: "NftTransferProxy.Transfer"
    arguments:
      nft_contract: "nft_contract"
      token_id: "token_id"
      from: "seller"
      to: "buyer_address"
    withCompensation: "ReverseNftTransfer"
  
  # 步骤 4：更新 Escrow 状态为已完成
  CompleteEscrow:
    invokeLocal: "mark_escrow_completed"
    arguments:
      escrow_id: "escrow_id"
      buyer: "buyer_address"
      amount: "actual_amount"
      tx_id: "transaction_id"
```

### 补偿链

```
若 Step 3 (TransferNft) 失败：
  ├─ 触发 ReverseNftTransfer（补偿）
  ├─ NFT 转移回卖方
  └─ Saga 回滚

若 Step 2 (VerifyPayment) 失败：
  └─ Token 保留在买方钱包（无需补偿）
```

---

## 3. 消息流

### 消息流序列

```
买方                        AO Escrow                    NFT 合约               Token 合约
  │                            │                           │                      │
  ├─ QueryEscrow ────────────→ │                           │                      │
  │                            ├─ 返回托管详情 ──────────→ │                      │
  │                            │                           │                      │
  ├─ TransferTokens ──────────────────────────────────────────────────────────────→ │
  │                                                                                 │
  │                                                                       (Token 转账成功)
  │                                                    ← Credit-Notice ──────────────┤
  │                                                                                 │
  │                            (代理监听 Credit-Notice)
  │                            ├─ 验证支付（金额 + 接收方）
  │                            ├─ 发送 TriggerEscrow 消息（包含 X-SagaId）
  │                            │
  │                            ├─ Saga 执行 Step 2: VerifyPayment
  │                            ├─ Saga 执行 Step 3: TransferNft
  │                            ├─ (向 NFT 合约转移 NFT)
  │                            │
  │                            ├─ Saga 执行 Step 4: CompleteEscrow
  │                            ├─ 更新 Escrow 状态 → COMPLETED
  │                            ├─ 记录卖方可提取余额
  │                            │
  │                            ├─ 返回成功消息 ──────────→ │
  │                            │                           │
```

---

## 4. 关键实现要点

### 4.1 支付验证机制

在 AO 中无法"主动查询"Token 合约的转账历史，因此采用：

1. **被动监听**：支付接收代理监听 Token 合约的 `Credit-Notice` 消息
2. **业务参数匹配**：通过 (金额 + 接收方地址) 精确匹配待处理的 Escrow
3. **触发 Saga**：验证通过后，触发 Saga 的 `ProcessEscrow` 方法

```lua
-- 支付接收代理的核心逻辑
Handlers.add(
  "token_transfer",
  Handlers.utils.hasMatchingTag("Action", "Credit-Notice"),
  function(msg)
    local amount = msg.Tags.Quantity
    local sender = msg.Tags.Sender
    
    -- 通过 (amount + sender) 查找待处理的 Escrow
    local pending_escrow = find_pending_escrow(amount, sender)
    
    if pending_escrow then
      -- 触发 Saga
      trigger_escrow_saga(pending_escrow.escrow_id, sender)
    end
  end
)
```

### 4.2 代理合约（NftTransferProxy）

```lua
-- 核心职责：
-- 1. 接收来自 Saga 的 TransferNft 请求
-- 2. 向 NFT 合约发送转移请求
-- 3. 监听 NFT 合约的响应（Transfer-Success / Transfer-Error）
-- 4. 根据结果决定 Saga 是否继续或补偿

function nft_proxy.transfer(msg)
  local request = json.decode(msg.Data)
  
  -- 记录待处理请求（用于补偿）
  local request_id = generate_request_id()
  pending_requests[request_id] = {
    saga_id = msg.Tags["X-SagaId"],
    nft_contract = request.nft_contract,
    token_id = request.token_id,
    from = request.from,
    to = request.to,
    request_id = request_id
  }
  
  -- 向 NFT 合约发送转移请求
  ao.send({
    Target = request.nft_contract,
    Tags = { 
      Action = "Transfer",
      ["X-RequestId"] = request_id
    },
    Data = json.encode({
      tokenId = request.token_id,
      recipient = request.to
    })
  })
end

-- 监听 NFT 转移响应
Handlers.add(
  "nft_transfer_response",
  Handlers.utils.hasMatchingTag("Action", "Transfer-Success"),
  function(msg)
    local request_id = msg.Tags["X-RequestId"]
    local request_info = pending_requests[request_id]
    
    if request_info then
      -- 转移成功，通知 Saga 继续
      ao.send({
        Target = ao.id,  -- 发送给自己所在的 Saga 服务
        Tags = {
          Action = "EscrowStep_TransferNft_Success",
          ["X-SagaId"] = request_info.saga_id
        }
      })
      
      pending_requests[request_id] = nil
    end
  end
)
```

---

## 5. 简化的 DDDML 配置

```yaml
services:
  NftEscrowService:
    requiredComponents:
      EscrowAggregate: EscrowAggregate
      NftTransferProxy: NftTransferProxy
    
    methods:
      # 创建托管（同步）
      CreateEscrow:
        parameters:
          seller: string
          nft_contract: string
          token_id: string
          price: bint
        invokeLocal: "create_escrow_record"
      
      # 查询托管（同步查询）
      GetEscrow:
        parameters:
          escrow_id: string
        invokeLocal: "get_escrow"
      
      # 处理托管（Saga）
      ProcessEscrow:
        parameters:
          escrow_id: string
          buyer: string
        saga: true
        steps:
          GetEscrow:
            invokeLocal: "get_escrow"
          
          VerifyPayment:
            invokeParticipant: "TokenContract.Query"
          
          TransferNft:
            invokeParticipant: "NftTransferProxy.Transfer"
            withCompensation: "ReverseNftTransfer"
          
          CompleteEscrow:
            invokeLocal: "mark_completed"
      
      # 提取资金（同步）
      WithdrawFunds:
        parameters:
          seller: string
        invokeLocal: "withdraw_seller_funds"
```

---

## 6. 状态管理

### 核心数据结构

```lua
-- 托管记录表
local escrows = {}  
-- escrow_id → Escrow 记录

-- 待处理支付表（用于匹配 Token 转账）
local pending_payments = {}  
-- "amount|sender" → escrow_id

-- 待处理 NFT 转移表（用于补偿）
local pending_nft_transfers = {}  
-- request_id → { saga_id, nft_contract, token_id, ... }

-- 卖方可提取余额
local seller_balances = {}  
-- seller_address → balance
```

### 业务参数匹配的 O(1) 查询

```lua
-- 索引结构
local payment_index = {}  -- "amount|sender" → escrow_id

-- 当收到 Token Credit-Notice 时
function find_pending_escrow(amount, sender)
  local key = tostring(amount) .. "|" .. sender
  local escrow_id = payment_index[key]
  if escrow_id then
    return escrows[escrow_id]
  end
  return nil
end
```

---

## 7. 错误处理与补偿

### 失败场景

```
场景 1：支付验证失败
  → Saga 不启动，Escrow 保持 CREATED
  → 买方可重新尝试转账

场景 2：NFT 转移失败
  → 触发 ReverseNftTransfer 补偿
  → 退还 Token（需要代理合约实现）
  → Escrow 状态回退到 PENDING_PAYMENT
  → Saga 中止

场景 3：Escrow 过期
  → 外部监控服务定期检查
  → 触发 CancelEscrow 动作
  → 释放托管资金
```

### 补偿逻辑

```lua
-- 步骤 3 (TransferNft) 的补偿
function compensate_transfer_nft(request_info)
  -- 向 Token 代理发送退款请求
  ao.send({
    Target = token_proxy_address,
    Tags = { Action = "Refund" },
    Data = json.encode({
      recipient = request_info.buyer,
      amount = request_info.price,
      reason = "NFT transfer failed"
    })
  })
end
```

---

## 8. 与现有 DDDML 框架的集成

### 需要在 saga.lua 中扩展的函数

```lua
-- 支持本地事件触发 waitForEvent
function saga.trigger_local_event(saga_id, event_type, event_data)
  -- 查找正在等待此事件的 Saga 实例
  local saga_instance = saga.get_saga_instance(saga_id)
  
  if saga_instance.waiting_state and 
     saga_instance.waiting_state.event_type == event_type then
    -- 事件过滤（可选）
    if apply_event_filter(saga_instance, event_data) then
      -- 数据映射
      apply_event_data_mapping(saga_instance.context, event_data)
      -- 前进到下一步骤
      saga_instance.current_step = saga_instance.current_step + 1
      saga_instance.waiting_state = nil
      return true
    end
  end
  return false
end
```

### 需要在 messaging.lua 中扩展的函数

```lua
-- 本地事件 API
function messaging.trigger_saga_event(saga_id, event_type, event_data)
  -- 供代理合约和其他组件调用
  return saga.trigger_local_event(saga_id, event_type, event_data)
end
```

---

## 9. 关键设计决策

| 决策项 | 选择 | 理由 |
|--------|------|------|
| **支付验证方式** | 被动监听 Credit-Notice | AO 无法主动查询 Token 历史 |
| **业务参数匹配** | amount + sender | 消息标签丢失时的可靠性保障 |
| **Saga 风格** | 基于编制（Orchestration） | 业务流程清晰，易于补偿 |
| **代理部署** | 本地包装（同进程） | 状态管理简化，补偿逻辑集中 |
| **过期处理** | 外部监控 | AO 无内置定时器 |

---

## 10. 核心流程时间轴

### 完整交易流程（成功路径）

```
T=0s:   买方执行 QueryEscrow
T=1s:   买方执行 TransferTokens → Token 合约
T=5s:   Token 合约发送 Credit-Notice → 支付接收代理
T=6s:   代理验证支付，触发 ProcessEscrow Saga
T=7s:   Saga Step 1: GetEscrowRecord
T=8s:   Saga Step 2: VerifyPayment
T=10s:  Saga Step 3: TransferNft → NFT 代理
T=12s:  NFT 代理向 NFT 合约转移 NFT
T=15s:  Saga Step 4: CompleteEscrow（更新状态）
T=16s:  交易完成，买方获得 NFT，卖方可提取资金

总耗时：~16 秒
```

---

## 11. 最小化的部署结构

```
AO Escrow Process:
├─ NftEscrowService (主服务)
│  ├─ Saga 管理
│  ├─ Escrow 聚合根
│  └─ 业务逻辑
├─ NftTransferProxy (代理)
│  ├─ NFT 转移协调
│  └─ 补偿处理
└─ PaymentReceiverProxy (代理)
   ├─ Token 监听
   └─ 支付验证

外部依赖：
├─ NFT 合约 (标准 AO NFT)
├─ Token 合约 (标准 AO Token)
└─ 外部监控 (超时处理)
```

---

## 总结

这个设计将 EVM 的 6 步 Escrow 流程直接映射到 AO 的异步消息驱动模型：

✅ **Step 1-2**：本地操作（创建、记录）  
✅ **Step 3**：同步查询  
✅ **Step 4**：异步转账 + Saga 协调  
✅ **Step 5**：Saga 自动化（转移 NFT）  
✅ **Step 6**：本地操作（提取资金）

核心创新：
- 通过**业务参数匹配**解决消息标签丢失
- 通过**Saga 编排**实现跨合约的最终一致性
- 通过**代理合约**安全集成外部合约

