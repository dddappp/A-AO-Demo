<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# 我想写一个 NFT Escrow 合约，就是一个人能将自己的 NFT 托管给它销售

其他人支付后可以获得 NFT，出售 NFT 的人可以提取资金。请你详细讲解这个智能合约的设计。

---

完美！现在我有了所有必要的信息。让我生成最终的综合答案：

## NFT Escrow 智能合约完整设计与实现指南

NFT Escrow 合约是一个去中心化托管系统，允许卖方将 NFT 安全地托管，买方支付后自动获得所有权，卖方最后提取资金。这个设计完全消除了对第三方的信任需求，所有操作通过智能合约的不可变逻辑自动执行。

![NFT Escrow Smart Contract Architecture](https://ppl-ai-code-interpreter-files.s3.amazonaws.com/web/direct-files/f58a2cd1ddc9f074a97ac714a6099b62/3ec894f0-4da8-4dcf-a301-b82780dcb5e4/d06f5132.png)

NFT Escrow Smart Contract Architecture

***

## 核心业务流程

### 交易六大步骤

**第 1 步：NFT 批准** - 卖方调用 ERC-721 合约的 `approve()` 方法，授权 Escrow 合约可以转移其 NFT

**第 2 步：创建托管** - 卖方调用 `createEscrow()`，指定 NFT 合约地址、tokenId、价格和过期时间。合约创建托管记录，状态为 `CREATED`，并分配唯一的 escrowId

**第 3 步：买方查询** - 买方通过 `getEscrow()` 查询托管详情，验证 NFT 和价格

**第 4 步：买方支付** - 买方调用 `fundEscrow(escrowId)`，发送 ETH（金额 >= 价格）。合约接收资金，状态变为 `FUNDED`

**第 5 步：自动转移 NFT** - 合约使用 `safeTransferFrom()` 将 NFT 从卖方转给买方，状态更新为 `COMPLETED`

**第 6 步：提取资金** - 卖方调用 `withdrawFunds()` 获得收益（扣除平台费用后），买方获得 NFT 完全所有权

***

## 完整 Solidity 合约实现

完整的生产级合约已详细记录在文档中，包含以下关键特性：

**核心数据结构**：

```solidity
struct EscrowRecord {
    address seller;              // 卖方
    address buyer;               // 买方
    address nftContract;         // ERC-721 合约
    uint256 tokenId;             // NFT ID
    uint256 price;               // 售价
    uint256 balance;             // 托管中的资金
    EscrowStatus status;         // 托管状态
    uint256 createdAt;           // 创建时间
    uint256 expiresAt;           // 过期时间
    uint256 completedAt;         // 完成时间
}

enum EscrowStatus { CREATED, FUNDED, COMPLETED, CANCELLED }
```

**关键状态变量**：

- `mapping(uint256 => EscrowRecord) public escrows` - 托管记录
- `mapping(address => uint256[]) public sellerEscrows` - 卖方的托管列表
- `mapping(address => uint256[]) public buyerEscrows` - 买方的托管列表
- `mapping(address => uint256) public pendingWithdrawals` - 待提取资金
- `uint256 public feePercentage = 250` - 手续费比例（2.5%，基点表示）

***

## 手续费与资金分配

系统采用自动手续费机制。当交易完成时：


| 场景 | 买方支付 | 手续费(2.5%) | 卖方获得 |
| :-- | :-- | :-- | :-- |
| 标准交易 | 1.0 ETH | 0.025 ETH | 0.975 ETH |
| 超额支付 | 1.5 ETH | 0.0375 ETH | 1.4625 ETH |
| 大额交易 | 100 ETH | 2.5 ETH | 97.5 ETH |


***

## 安全机制详解

### 1. 重入攻击防护

采用 `nonReentrant` 修饰符（OpenZeppelin）和 checks-effects-interactions 模式。资金转移前先更新状态，防止重入：

```solidity
function withdrawFunds() external nonReentrant {
    uint256 amount = pendingWithdrawals[msg.sender];
    require(amount > 0, "No funds to withdraw");
    
    pendingWithdrawals[msg.sender] = 0;  // 先更新状态
    (bool success, ) = payable(msg.sender).call{value: amount}("");
    require(success, "Transfer failed");
}
```


### 2. 输入验证

- 验证 NFT 合约实现 ERC-721 接口
- 检查卖方是 NFT 所有者
- 验证已授予批准权限
- 检查价格 > 0，过期时间在未来


### 3. 安全的 NFT 转移

使用 `safeTransferFrom()` 而非 `transferFrom()`，确保接收方支持 ERC-721，防止 NFT 被永久锁定

### 4. 访问控制

- `onlyEscrowSeller` - 仅卖方可取消托管
- `onlyOwner` - 仅所有者可管理平台费用
- 内部检查防止卖方购买自己的 NFT

***

## 实现部署步骤

### 本地开发环境

**1. 项目初始化**

```bash
mkdir nft-escrow && cd nft-escrow
npm init -y
npm install --save-dev hardhat @openzeppelin/contracts @nomicfoundation/hardhat-toolbox
npx hardhat
```

**2. 启动本地区块链**

```bash
npx hardhat node
```

**3. 部署合约**

```bash
npx hardhat run scripts/deploy.js --network localhost
```

**4. 运行完整测试套件**

```bash
npx hardhat test
```


### 主要测试场景

完整的测试套件包含 30+ 个测试用例，覆盖：

- 正常流程（创建→支付→转移→提取）
- 边界情况（过期托管、超额支付、无效输入）
- 错误处理（非所有者操作、未批准、资金不足）
- 重入攻击防护
- 手续费计算准确性
- 状态转移有效性

***

## 关键函数说明

### createEscrow() - 创建托管

```
输入：NFT合约, tokenId, 价格, 过期时间
输出：escrowId
前置条件：调用者是NFT所有者、已批准Escrow合约
状态变化：CREATED
事件：EscrowCreated
```


### fundEscrow() - 买方支付

```
输入：escrowId, msg.value (ETH金额)
输出：无
前置条件：支付金额 >= 价格、托管未过期、调用者不是卖方
状态变化：CREATED → FUNDED → COMPLETED
事件：EscrowFunded, EscrowCompleted
```


### withdrawFunds() - 提取资金

```
输入：无
输出：无
前置条件：有待提取资金
结果：转移资金到卖方钱包
事件：FundsWithdrawn
```


### cancelEscrow() - 取消托管

```
输入：escrowId
输出：无
前置条件：仅卖方、状态为CREATED（未被购买）
状态变化：CREATED → CANCELLED
事件：EscrowCancelled
```


***

## 扩展功能建议

**1. ERC-1155 支持** - 支持半可替代代币

**2. 多种支付代币** - 接受 USDC、DAI 等稳定币而非仅限 ETH

**3. 分阶段支付** - 支持分期付款模式

**4. 荷兰式拍卖** - 价格随时间递减

**5. 纠纷解决** - 买方可在一定时间内申请退款

**6. 批量操作** - 批量创建或取消多个托管

***

## 完整资源

我为您生成了三份详细文档：

- **NFT Escrow 合约设计完全指南**：包含核心概念、业务流程、完整 Solidity 代码、安全考量和理论说明
- **实践部署与测试指南**：包含 Hardhat 项目配置、完整测试代码（30+ 测试用例）、本地部署步骤、交互脚本示例和常见问题解答
- **交易流程、状态转移和费用计算数据表**

这些资源覆盖了从理论设计到生产部署的所有方面。建议按以下顺序使用：

1. 先阅读完整指南理解架构
2. 在本地运行测试套件验证逻辑
3. 使用交互脚本进行端到端测试
4. 在测试网（Sepolia）部署验证
5. 最后在主网部署前进行安全审计
<span style="display:none">[^1][^10][^11][^12][^13][^14][^15][^16][^17][^18][^19][^2][^3][^4][^5][^6][^7][^8][^9]</span>

<div align="center">⁂</div>

[^1]: https://dev.to/fassko/understanding-escrow-in-erc-721-nft-smart-contracts-n6n

[^2]: https://www.quicknode.com/guides/ethereum-development/smart-contracts/how-to-create-a-smart-contract-with-dapp-tools-by-dapp-hub

[^3]: https://www.youtube.com/watch?v=sf0Y6snmr-I

[^4]: https://github.com/topics/escrow-contract?l=javascript\&o=desc\&s=updated

[^5]: https://aws.amazon.com/blogs/database/part-2-develop-a-full-stack-serverless-nft-application-with-amazon-managed-blockchain/

[^6]: https://blog.csdn.net/weixin_35705784/article/details/147849737

[^7]: https://github.com/ringaile/escrow

[^8]: https://www.reddit.com/r/ethdev/comments/1g57iuj/smart_contract_escrow_can_you_help/

[^9]: https://learnblockchain.cn/article/17257

[^10]: https://ethereum-magicians.org/t/erc721-with-a-validation-step/14071

[^11]: https://www.alchemy.com/overviews/nft-seller-financing

[^12]: https://www.antiersolutions.com/blogs/empowering-nft-marketplaces-with-smart-contracts/

[^13]: https://ilink.dev/blog/smart-contract-payments-automating-payouts-royalties-and-escrow-with-blockchain/

[^14]: https://castler.com/learning-hub/how-escrow-is-powering-trust-in-tokenized-assets-and-digital-securities

[^15]: https://blog.master-builders-solutions.com/en/smart_contracts

[^16]: https://metana.io/blog/nft-marketplace-development-with-solidity-essential-guide/

[^17]: https://codehawks.cyfrin.io/c/2025-04-eggstravaganza/s/107

[^18]: https://fintechlab.la/decentralized-escrow-service-what-is-it-and-how-does-it-work/

[^19]: https://www.antiersolutions.com/blogs/an-in-depth-insight-into-erc-721-and-other-nft-standards/

