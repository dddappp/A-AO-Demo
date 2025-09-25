# AO NFT 合约示例

这是一个基于 AO Legacy 网络标准的 NFT 合约示例，与 Wander 钱包完全兼容。

## 功能特性

- ✅ **铸造 NFT**: 支持单个和批量铸造 NFT
- ✅ **转让 NFT**: 支持 NFT 转让功能
- ✅ **查询功能**: 支持查询单个 NFT 和用户所有 NFT
- ✅ **可转让控制**: 可以设置 NFT 是否可转让
- ✅ **统计信息**: 提供合约统计信息查询
- ✅ **Wander 钱包兼容**: 与主流 AO 钱包完全兼容

## 文件结构

```
src/
├── nft_contract.lua    # 主要的 NFT 合约实现
└── README.md          # 本说明文件
```

## 合约功能

启动一个 aos 进程，加载代码：

```lua
.load /PATH/TO/A-AO-Demo/docs/AO-token-research/src/nft_contract.lua
```

### 1. 获取合约信息 (Info)
让 Wander 钱包能够识别这个 NFT 合约。

**消息格式：**
```lua
Send({
  Target = "W9aPA8rp_Hbr24WnZxrP4rqjPsI-b3mzCsNWTfFN060",
  Action = "Info"
})
```

### 2. 铸造 NFT (Mint-NFT)✅
铸造单个 NFT。

先执行：
```lua
json = require("json")
```

**消息格式：**
```lua
Send({  Target = "W9aPA8rp_Hbr24WnZxrP4rqjPsI-b3mzCsNWTfFN060",  Action = "Mint-NFT",  Name = "My NFT",  Description = "A beautiful NFT",  Image = "ARWEAVE_TXID_HERE",  Transferable = "true",  Data = json.encode({    attributes = {      { trait_type = "Rarity", value = "Legendary" },      { trait_type = "Artist", value = "ArtistName" }    }  })})
```

### 3. 批量铸造 NFT (Mint-Batch-NFT)
一次性铸造多个 NFT。

**消息格式：**
```lua
Send({
  Target = "W9aPA8rp_Hbr24WnZxrP4rqjPsI-b3mzCsNWTfFN060",
  Action = "Mint-Batch-NFT",
  NFTs = json.encode({
    {
      name = "NFT 1",
      description = "First NFT",
      image = "ARWEAVE_TXID_1",
      attributes = {{ trait_type = "Type", value = "Art" }}
    },
    {
      name = "NFT 2",
      description = "Second NFT",
      image = "ARWEAVE_TXID_2",
      attributes = {{ trait_type = "Type", value = "Collectible" }}
    }
  })
})
```

### 4. 转让 NFT (Transfer-NFT)
转让 NFT 给其他用户。

**消息格式：**
```lua
Send({
  Target = "W9aPA8rp_Hbr24WnZxrP4rqjPsI-b3mzCsNWTfFN060",
  Action = "Transfer-NFT",
  TokenId = "1",
  Recipient = "RECIPIENT_ADDRESS"
})
```

### 5. 查询 NFT 信息 (Get-NFT)
查询特定 NFT 的详细信息。

**消息格式：**
```lua
Send({  Target = "W9aPA8rp_Hbr24WnZxrP4rqjPsI-b3mzCsNWTfFN060",  Action = "Get-NFT",  TokenId = "1"})
```

### 6. 查询用户 NFT (Get-User-NFTs)
查询用户拥有的所有 NFT。

**消息格式：**
```lua
Send({  Target = "W9aPA8rp_Hbr24WnZxrP4rqjPsI-b3mzCsNWTfFN060",  Action = "Get-User-NFTs",  Address = "W9aPA8rp_Hbr24WnZxrP4rqjPsI-b3mzCsNWTfFN060"  })
-- 最后一个地址参数可选，不指定则查询发送者
```

### 7. 设置可转让性 (Set-NFT-Transferable)
设置 NFT 是否可转让。

**消息格式：**
```lua
Send({
  Target = "W9aPA8rp_Hbr24WnZxrP4rqjPsI-b3mzCsNWTfFN060",
  Action = "Set-NFT-Transferable",
  TokenId = "1",
  Transferable = "false"  -- true/false
})
```

### 8. 获取统计信息 (Get-Contract-Stats)✅
获取合约的统计信息。

**消息格式：**
```lua
Send({  Target = "W9aPA8rp_Hbr24WnZxrP4rqjPsI-b3mzCsNWTfFN060",  Action = "Get-Contract-Stats"})
```

## 技术特性

### 消息格式标准
- 使用 AO Legacy 网络标准的直接属性格式
- 支持 `Debit-Notice`、`Credit-Notice`、`Mint-Confirmation` 消息类型
- 包含 `Data-Protocol = "ao"` 标签确保钱包同步
- 添加 `Type` 标签区分不同操作类型

### 数据结构
```lua
-- NFT 基本结构
{
  name = "NFT Name",
  description = "NFT Description",
  image = "Arweave TxID",
  attributes = {
    { trait_type = "Rarity", value = "Legendary" },
    { trait_type = "Artist", value = "ArtistName" }
  },
  transferable = true,
  createdAt = "timestamp",
  creator = "creator_address"
}

-- 所有者记录
Owners[tokenId] = "owner_address"
```

### 错误处理
- 完善的参数验证
- 清晰的错误消息
- 支持异步错误通知

## 与 Wander 钱包的兼容性

### 完全兼容的功能
- ✅ **Info 查询**: 钱包能正确识别 NFT 合约
- ✅ **NFT 分类**: 支持 Transferable 属性和 collectible 类型识别
- ✅ **消息通知**: 使用标准的 Debit-Notice/Credit-Notice/Mint-Confirmation
- ✅ **数据格式**: 标准的 JSON 数据格式
- ✅ **标签协议**: 正确的 Data-Protocol 和 Type 标签

### 支持的 NFT 特性
- ✅ **唯一标识**: 每个 NFT 都有唯一的 TokenId
- ✅ **元数据存储**: 支持名称、描述、图片和自定义属性
- ✅ **所有权追踪**: 完整的拥有者记录
- ✅ **可转让控制**: 可设置 NFT 是否可转让
- ✅ **批量查询**: 支持查询用户的所有 NFT
- ✅ **批量操作**: 支持批量铸造多个 NFT

## 部署说明

1. **准备环境**: 确保使用 AO Legacy 网络环境
2. **部署合约**: 将 `nft_contract.lua` 部署到 AO 网络
3. **记录合约地址**: 保存生成的合约 Process ID
4. **测试功能**: 使用上述消息格式测试各项功能
5. **与钱包集成**: 在 Wander 钱包中添加合约地址

## 安全注意事项

- **权限验证**: 所有操作都需要验证所有权
- **可转让控制**: 可以通过设置 transferable 字段限制转让
- **错误处理**: 完善的错误处理机制
- **消息验证**: 验证所有必需参数的存在性

## 故障排除与经验教训

### 消息格式最佳实践（初步判断）

在开发过程中，我们观察到以下模式对消息传递的可靠性有重要影响：

#### ✅ 推荐的消息格式（已验证有效）
```lua
-- 方式1：使用简单字符串 Data（与 Mint-NFT 一致）
msg.reply({
  Action = 'NFT-Info',
  TokenId = tokenId,
  Name = nft.name,
  Data = "NFT information retrieved successfully"
})

-- 方式2：使用简洁 JSON 结构（与 messaging.lua 一致）
msg.reply({
  Action = 'NFT-Info',
  Data = json.encode({
    tokenId = tokenId,
    name = nft.name,
    description = nft.description,
    image = nft.image,
    attributes = nft.attributes,
    owner = ownerAddress,
    creator = creatorAddress,
    createdAt = createdAt,
    transferable = transferable
  })
})
```

#### ❌ 避免的消息格式（可能导致问题）
```lua
-- 过多根级别字段 + 复杂嵌套 JSON（已观察到问题）
msg.reply({
  Action = 'NFT-Info',
  TokenId = tokenId,                    // 根级别字段1
  Name = nft.name,                     // 根级别字段2
  Description = nft.description,       // 根级别字段3
  Image = nft.image,                   // 根级别字段4
  Owner = ownerAddress,                // 根级别字段5
  Creator = creatorAddress,            // 根级别字段6
  CreatedAt = createdAt,               // 根级别字段7
  Transferable = transferable,         // 根级别字段8
  Data = json.encode({                 // 根级别字段9 - 复杂嵌套
    tokenId = tokenId,                 // 字段重复！
    name = nft.name,                   // 字段重复！
    description = nft.description,     // 字段重复！
    image = nft.image,                 // 字段重复！
    attributes = nft.attributes,       // 字段重复！
    owner = ownerAddress,              // 字段重复！
    creator = creatorAddress,          // 字段重复！
    createdAt = createdAt,             // 字段重复！
    transferable = transferable        // 字段重复！
  })
})
```

#### 📝 经验观察（需要进一步验证）

1. **根级别字段数量**：
   - 2-4个字段：通常工作正常 ✅
   - 9+个字段：可能导致问题 ❌

2. **字段重复传递**：
   - 避免在根级别和 Data 中传递相同信息
   - 选择一种传递方式：要么根级别，要么 Data 中

3. **JSON 复杂度**：
   - 扁平 JSON 结构：更可靠 ✅
   - 深度嵌套结构：可能有兼容性问题 ❌

4. **与成功示例一致性**：
   - 参考 messaging.lua 和 BlogExample 的格式 ✅
   - 避免自定义复杂格式 ❌

### 调试建议

当遇到消息传递问题时，建议按以下顺序排查：

1. **检查参数获取**：
   ```lua
   print("msg.Tags.TokenId: " .. tostring(msg.Tags.TokenId))
   print("msg.Tags.Tokenid: " .. tostring(msg.Tags.Tokenid))
   print("Final tokenId: " .. tostring(tokenId))
   ```

2. **简化消息格式**：
   - 先用简单字符串测试
   - 再逐步添加 JSON 结构
3. **参考成功示例**：
   - 对比 messaging.lua 的格式
   - 参考 BlogExample 的实现

4. **确保执行确定性**：
   - 验证所有节点执行结果一致
   - 检查是否为正确的 AO Legacy 网络环境
   - 确认合约代码的确定性实现

## 扩展建议

1. **版税功能**: 可以添加版税分配机制
2. **拍卖功能**: 实现 NFT 拍卖功能
3. **租赁功能**: 支持 NFT 租赁功能
4. **碎片化**: 支持 NFT 碎片化功能
5. **多媒体**: 支持更多类型的多媒体内容

## 许可证

本示例代码仅供学习和参考使用。在生产环境中使用前，请进行充分的测试和安全审计。
