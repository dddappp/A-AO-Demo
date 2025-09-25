-- NFT 合约示例 - 基于 AO Legacy 网络标准
-- 此合约实现了完整的 NFT 功能，与 Wander 钱包完全兼容

-- 使用 AO 官方的 bint 大整数库
-- 来源: https://github.com/edubart/lua-bint (v0.5.1)
local bint = require('.bint')(256)
local json = require('json')

-- NFT 合约核心状态
NFTs = NFTs or {}
Owners = Owners or {}
TokenIdCounter = TokenIdCounter or 0

-- NFT 元数据结构
-- NFTs[tokenId] = {
--   name = "NFT 名称",
--   description = "NFT 描述",
--   image = "Arweave TxID",
--   attributes = {...},
--   transferable = true/false
-- }

-- 工具函数
local utils = {
  add = function(a, b) return tostring(bint(a) + bint(b)) end,
  subtract = function(a, b) return tostring(bint(a) - bint(b)) end,
  toBalanceValue = function(a) return tostring(bint(a)) end,
  toNumber = function(a) return bint.tonumber(a) end
}

-- Info handler - 让 Wander 钱包能够识别这个 NFT 合约
Handlers.add('nft_info', Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
  if msg.reply then
    msg.reply({
      Name = "AO NFT Collection Demo",
      Ticker = "NFT-DEMO",
      Logo = "NFT_LOGO_TXID_HERE",
      Denomination = 0,
      Transferable = true
    })
  else
    Send({
      Target = msg.From,
      Action = "Info",
      Name = "AO NFT Collection Demo",
      Ticker = "NFT-DEMO",
      Logo = "NFT_LOGO_TXID_HERE",
      Denomination = "0",
      Transferable = "true",
      ["Data-Protocol"] = "ao",
      Type = "NFT-Contract"
    })
  end
end)

-- 铸造 NFT
Handlers.add('mint_nft', Handlers.utils.hasMatchingTag("Action", "Mint-NFT"), function(msg)
  -- 参数验证：返回错误消息而不是崩溃
  if not msg.Name or type(msg.Name) ~= 'string' then
    local errorResponse = {
      Action = 'Mint-Error',
      Error = 'Name is required!',
      Data = 'Name parameter must be a string'
    }
    if msg.reply then
      msg.reply(errorResponse)
    else
      Send({
        Target = msg.From,
        Action = "Mint-Error",
        Error = 'Name is required!',
        ["Data-Protocol"] = "ao",
        Type = "Mint-Error",
        Data = json.encode({
          error = 'Name is required',
          message = 'Name parameter must be a string'
        })
      })
    end
    return
  end

  if not msg.Description or type(msg.Description) ~= 'string' then
    local errorResponse = {
      Action = 'Mint-Error',
      Error = 'Description is required!',
      Data = 'Description parameter must be a string'
    }
    if msg.reply then
      msg.reply(errorResponse)
    else
      Send({
        Target = msg.From,
        Action = "Mint-Error",
        Error = 'Description is required!',
        ["Data-Protocol"] = "ao",
        Type = "Mint-Error",
        Data = json.encode({
          error = 'Description is required',
          message = 'Description parameter must be a string'
        })
      })
    end
    return
  end

  if not msg.Image or type(msg.Image) ~= 'string' then
    local errorResponse = {
      Action = 'Mint-Error',
      Error = 'Image is required!',
      Data = 'Image parameter must be a string'
    }
    if msg.reply then
      msg.reply(errorResponse)
    else
      Send({
        Target = msg.From,
        Action = "Mint-Error",
        Error = 'Image is required!',
        ["Data-Protocol"] = "ao",
        Type = "Mint-Error",
        Data = json.encode({
          error = 'Image is required',
          message = 'Image parameter must be a string'
        })
      })
    end
    return
  end

  TokenIdCounter = TokenIdCounter + 1
  local tokenId = tostring(TokenIdCounter)

  -- 安全地解析属性数据
  local attributes = {}
  if msg.Data and msg.Data ~= '' then
    local success, decoded = pcall(function()
      return json.decode(msg.Data)
    end)
    if success and decoded and decoded.attributes then
      attributes = decoded.attributes
    end
  end

  -- 在 AO 中，参数通过 Tags 传递，AO 会将参数名转换为小写
  local transferable = msg.Tags.Transferable or msg.Tags.Transferable or msg.Transferable

  NFTs[tokenId] = {
    name = msg.Name,
    description = msg.Description,
    image = msg.Image,
    attributes = attributes,
    transferable = transferable == 'true',
    createdAt = msg.Timestamp or tostring(os.time()),
    creator = msg.From
  }

  Owners[tokenId] = msg.From

  -- 发送铸造确认（与 Wander 钱包兼容）
  if msg.reply then
    msg.reply({
      Action = 'Mint-Confirmation',
      TokenId = tokenId,
      Name = msg.Name,
      Data = "NFT '" .. msg.Name .. "' minted successfully with ID: " .. tokenId
    })
  else
    Send({
      Target = msg.From,
      Action = "Mint-Confirmation",
      TokenId = tokenId,
      Name = msg.Name,
      ["Data-Protocol"] = "ao",
      Type = "NFT-Mint",
      Data = json.encode({
        success = true,
        tokenId = tokenId,
        message = "NFT '" .. msg.Name .. "' minted successfully with ID: " .. tokenId,
        transferable = transferable == 'true'
      })
    })
  end
end)

-- 转让 NFT
Handlers.add('transfer_nft', Handlers.utils.hasMatchingTag("Action", "Transfer-NFT"), function(msg)
  -- 在 AO 中，参数通过 Tags 传递，AO 会将参数名转换为小写
  local tokenId = msg.Tags.Tokenid or msg.Tags.TokenId or msg.TokenId
  local recipient = msg.Tags.Recipient or msg.Tags.Recipient or msg.Recipient

  -- 参数验证：返回错误消息而不是崩溃
  if not tokenId or type(tokenId) ~= 'string' then
    local errorResponse = {
      Action = 'Transfer-Error',
      Error = 'TokenId is required!',
      Data = 'TokenId parameter must be a string'
    }
    if msg.reply then
      msg.reply(errorResponse)
    else
      Send({
        Target = msg.From,
        Action = "Transfer-Error",
        Error = 'TokenId is required!',
        ["Data-Protocol"] = "ao",
        Type = "Transfer-Error",
        Data = json.encode({
          error = 'TokenId is required',
          message = 'TokenId parameter must be a string',
          debug = {
            tagsTokenId = msg.Tags.TokenId,
            msgTokenId = msg.TokenId
          }
        })
      })
    end
    return
  end

  if not recipient or type(recipient) ~= 'string' then
    local errorResponse = {
      Action = 'Transfer-Error',
      Error = 'Recipient is required!',
      Data = 'Recipient parameter must be a string'
    }
    if msg.reply then
      msg.reply(errorResponse)
    else
      Send({
        Target = msg.From,
        Action = "Transfer-Error",
        Error = 'Recipient is required!',
        ["Data-Protocol"] = "ao",
        Type = "Transfer-Error",
        Data = json.encode({
          error = 'Recipient is required',
          message = 'Recipient parameter must be a string',
          debug = {
            tagsRecipient = msg.Tags.Recipient,
            msgRecipient = msg.Recipient
          }
        })
      })
    end
    return
  end

  -- 验证所有权
  if not Owners[tokenId] then
    local errorResponse = {
      Action = 'Transfer-Error',
      TokenId = tokenId,
      Error = 'NFT not found!',
      Data = 'The requested NFT does not exist'
    }
    if msg.reply then
      msg.reply(errorResponse)
    else
      Send({
        Target = msg.From,
        Action = "Transfer-Error",
        TokenId = tokenId,
        Error = 'NFT not found!',
        ["Data-Protocol"] = "ao",
        Type = "Transfer-Error",
        Data = json.encode({
          error = 'NFT not found',
          tokenId = tokenId,
          message = 'The requested NFT does not exist'
        })
      })
    end
    return
  end

  if Owners[tokenId] ~= msg.From then
    local errorResponse = {
      Action = 'Transfer-Error',
      TokenId = tokenId,
      Error = 'You do not own this NFT!',
      Data = 'Only the owner can transfer this NFT'
    }
    if msg.reply then
      msg.reply(errorResponse)
    else
      Send({
        Target = msg.From,
        Action = "Transfer-Error",
        TokenId = tokenId,
        Error = 'You do not own this NFT!',
        ["Data-Protocol"] = "ao",
        Type = "Transfer-Error",
        Data = json.encode({
          error = 'You do not own this NFT',
          tokenId = tokenId,
          message = 'Only the owner can transfer this NFT'
        })
      })
    end
    return
  end

  -- 验证可转让性
  if not NFTs[tokenId] then
    local errorResponse = {
      Action = 'Transfer-Error',
      TokenId = tokenId,
      Error = 'NFT not found!',
      Data = 'NFT data not found'
    }
    if msg.reply then
      msg.reply(errorResponse)
    else
      Send({
        Target = msg.From,
        Action = "Transfer-Error",
        TokenId = tokenId,
        Error = 'NFT not found!',
        ["Data-Protocol"] = "ao",
        Type = "Transfer-Error",
        Data = json.encode({
          error = 'NFT not found',
          tokenId = tokenId,
          message = 'NFT data not found'
        })
      })
    end
    return
  end

  if not NFTs[tokenId].transferable then
    local errorResponse = {
      Action = 'Transfer-Error',
      TokenId = tokenId,
      Error = 'This NFT is not transferable!',
      Data = 'This NFT has been set to non-transferable'
    }
    if msg.reply then
      msg.reply(errorResponse)
    else
      Send({
        Target = msg.From,
        Action = "Transfer-Error",
        TokenId = tokenId,
        Error = 'This NFT is not transferable!',
        ["Data-Protocol"] = "ao",
        Type = "Transfer-Error",
        Data = json.encode({
          error = 'This NFT is not transferable',
          tokenId = tokenId,
          message = 'This NFT has been set to non-transferable'
        })
      })
    end
    return
  end

  local oldOwner = Owners[tokenId]
  Owners[tokenId] = recipient

  -- 发送转让通知（与 Wander 钱包兼容）
  if msg.reply then
    msg.reply({
      Action = 'NFT-Transfer-Notice',
      TokenId = tokenId,
      From = oldOwner,
      To = recipient,
      Name = NFTs[tokenId].name,
      Data = "NFT '" .. NFTs[tokenId].name .. "' transferred from " .. oldOwner .. " to " .. recipient
    })
  else
    -- 发送给接收者（Credit-Notice 格式）
    Send({
      Target = recipient,
      Action = "Credit-Notice",
      TokenId = tokenId,
      From = oldOwner,
      To = recipient,
      Name = NFTs[tokenId].name,
      ["Data-Protocol"] = "ao",
      Type = "NFT-Transfer",
      Data = json.encode({
        success = true,
        tokenId = tokenId,
        message = "You received NFT '" .. NFTs[tokenId].name .. "' from " .. oldOwner
      })
    })

    -- 发送给发送者（Debit-Notice 格式）
    Send({
      Target = oldOwner,
      Action = "Debit-Notice",
      TokenId = tokenId,
      From = oldOwner,
      To = recipient,
      Name = NFTs[tokenId].name,
      ["Data-Protocol"] = "ao",
      Type = "NFT-Transfer",
      Data = json.encode({
        success = true,
        tokenId = tokenId,
        message = "You transferred NFT '" .. NFTs[tokenId].name .. "' to " .. recipient
      })
    })
  end
end)

-- 查询 NFT 信息
Handlers.add('get_nft', Handlers.utils.hasMatchingTag("Action", "Get-NFT"), function(msg)
  -- 在 AO 中，参数通过 Tags 传递，AO 会将参数名转换为小写
  local tokenId = msg.Tags.Tokenid or msg.Tags.TokenId or msg.TokenId

  -- 调试信息：打印所有可用字段
  print("=== GET-NFT DEBUG ===")
  print("msg.TokenId: " .. tostring(msg.TokenId))
  print("msg.Tags.TokenId: " .. tostring(msg.Tags.TokenId))
  print("msg.Tags.Tokenid: " .. tostring(msg.Tags.Tokenid))
  print("msg.Tags: " .. json.encode(msg.Tags or {}))
  print("Final tokenId: " .. tostring(tokenId))

  -- 修复：不要用 assert 崩溃，而是返回错误消息
  if not tokenId or type(tokenId) ~= 'string' then
    local errorResponse = {
      Action = 'NFT-Error',
      Error = 'TokenId is required!',
      Data = 'TokenId parameter must be a string'
    }

    if msg.reply then
      msg.reply(errorResponse)
    else
      Send({
        Target = msg.From,
        Action = "NFT-Error",
        Error = 'TokenId is required!',
        ["Data-Protocol"] = "ao",
        Type = "NFT-Error",
        Data = json.encode({
          error = 'TokenId is required',
          message = 'TokenId parameter must be a string',
          debug = {
            msgTokenId = msg.TokenId,
            tagsTokenId = msg.Tags.TokenId,
            allTags = msg.Tags
          }
        })
      })
    end
    return
  end

  local nft = NFTs[tokenId]

  -- 调试信息：打印当前状态
  print("=== GET-NFT DEBUG ===")
  print("TokenId: " .. tostring(tokenId))
  print("Available NFT IDs:")
  for id, _ in pairs(NFTs) do
    print("  - " .. id)
  end
  print("Available Owner IDs:")
  for id, owner in pairs(Owners) do
    print("  - TokenId " .. id .. " -> " .. tostring(owner))
  end

  -- 检查 TokenId "1" 是否存在
  if tokenId == "1" then
    print("TokenId '1' exists in NFTs table: " .. tostring(NFTs["1"] ~= nil))
    print("TokenId '1' exists in Owners table: " .. tostring(Owners["1"] ~= nil))
    if NFTs["1"] then
      print("NFT '1' data: " .. json.encode(NFTs["1"]))
    end
  end

  -- 如果找不到 NFT，返回错误消息而不是崩溃
  if not nft then
    local errorResponse = {
      Action = 'NFT-Error',
      TokenId = tokenId,
      Error = 'NFT not found!',
      Data = 'The requested NFT with TokenId ' .. tokenId .. ' does not exist'
    }

    if msg.reply then
      msg.reply(errorResponse)
    else
      Send({
        Target = msg.From,
        Action = "NFT-Error",
        TokenId = tokenId,
        Error = 'NFT not found!',
        ["Data-Protocol"] = "ao",
        Type = "NFT-Error",
        Data = json.encode({
          error = 'NFT not found',
          tokenId = tokenId,
          message = 'The requested NFT with TokenId ' .. tokenId .. ' does not exist'
        })
      })
    end
    return
  end

  local response = {
    Action = 'NFT-Info',
    TokenId = tokenId,
    Name = nft.name,
    Description = nft.description,
    Image = nft.image,
    Attributes = json.encode(nft.attributes),
    Owner = Owners[tokenId],
    Creator = nft.creator,
    CreatedAt = nft.createdAt,
    Transferable = nft.transferable
  }

  -- 优先使用 msg.reply，如果没有则使用 Send
  -- 同时打印调试信息
  print("=== SENDING NFT-INFO RESPONSE ===")
  print("msg.reply available: " .. tostring(msg.reply ~= nil))
  print("Response target (msg.From): " .. tostring(msg.From))
  print("Pushed-For field: " .. tostring(msg.Tags["Pushed-For"] or "not available"))
  print("NFT data: " .. json.encode(response))

  local targetCount = 1  -- 至少发送给 msg.From

  -- 尝试多种回复方式，确保消息能被接收
  local responseData = {
    tokenId = tokenId,
    name = nft.name,
    description = nft.description,
    image = nft.image,
    attributes = nft.attributes,
    owner = Owners[tokenId],
    creator = nft.creator,
    createdAt = nft.createdAt,
    transferable = nft.transferable
  }

  if msg.reply then
    print("Trying msg.reply() with JSON")
    local replySuccess = pcall(function()
      msg.reply({
        Action = 'NFT-Info',
        Data = json.encode(responseData)
      })
    end)

    if replySuccess then
      print("msg.reply() succeeded")
      return
    else
      print("msg.reply() failed, using Send() fallback")
    end
  end

  -- Send() 备选方案
  print("Using Send() fallback")
  local targets = {msg.From}
  if msg.Tags["Pushed-For"] then
    table.insert(targets, msg.Tags["Pushed-For"])
  end

  for _, target in ipairs(targets) do
    Send({
      Target = target,
      Action = "NFT-Info",
      Data = json.encode(responseData),
      ["Data-Protocol"] = "ao",
      Type = "NFT-Info"
    })
  end

  print("Response sent to " .. #targets .. " target(s)")
end)

-- 查询用户拥有的 NFTs
Handlers.add('get_user_nfts', Handlers.utils.hasMatchingTag("Action", "Get-User-NFTs"), function(msg)
  local userAddress = msg.Tags.Address or msg.Address or msg.From
  local userNFTs = {}

  for tokenId, owner in pairs(Owners) do
    if owner == userAddress then
      userNFTs[tokenId] = {
        name = NFTs[tokenId].name,
        description = NFTs[tokenId].description,
        image = NFTs[tokenId].image,
        transferable = NFTs[tokenId].transferable
      }
    end
  end

  local response = {
    Action = 'User-NFTs',
    Address = userAddress,
    NFTs = json.encode(userNFTs),
    Count = #userNFTs
  }

  if msg.reply then
    msg.reply({
      Action = 'User-NFTs',
      Data = json.encode({
        address = userAddress,
        nfts = userNFTs,
        count = #userNFTs
      })
    })
  else
    Send({
      Target = msg.From,
      Action = "User-NFTs",
      Address = userAddress,
      Count = tostring(#userNFTs),
      ["Data-Protocol"] = "ao",
      Type = "User-NFTs",
      Data = json.encode({
        address = userAddress,
        nfts = userNFTs,
        count = #userNFTs
      })
    })
  end
end)

-- 设置 NFT 可转让性
Handlers.add('set_nft_transferable', Handlers.utils.hasMatchingTag("Action", "Set-NFT-Transferable"), function(msg)
  -- 在 AO 中，参数通过 Tags 传递，AO 会将参数名转换为小写
  local tokenId = msg.Tags.Tokenid or msg.Tags.TokenId or msg.TokenId
  local transferable = msg.Tags.Transferable or msg.Tags.Transferable or msg.Transferable

  -- 参数验证：返回错误消息而不是崩溃
  if not tokenId or type(tokenId) ~= 'string' then
    local errorResponse = {
      Action = 'NFT-Transferable-Error',
      Error = 'TokenId is required!',
      Data = 'TokenId parameter must be a string'
    }
    if msg.reply then
      msg.reply(errorResponse)
    else
      Send({
        Target = msg.From,
        Action = "NFT-Transferable-Error",
        Error = 'TokenId is required!',
        ["Data-Protocol"] = "ao",
        Type = "NFT-Transferable-Error",
        Data = json.encode({
          error = 'TokenId is required',
          message = 'TokenId parameter must be a string'
        })
      })
    end
    return
  end

  if not transferable or type(transferable) ~= 'string' then
    local errorResponse = {
      Action = 'NFT-Transferable-Error',
      Error = 'Transferable is required!',
      Data = 'Transferable parameter must be a string'
    }
    if msg.reply then
      msg.reply(errorResponse)
    else
      Send({
        Target = msg.From,
        Action = "NFT-Transferable-Error",
        Error = 'Transferable is required!',
        ["Data-Protocol"] = "ao",
        Type = "NFT-Transferable-Error",
        Data = json.encode({
          error = 'Transferable is required',
          message = 'Transferable parameter must be a string'
        })
      })
    end
    return
  end

  local transferableValue = transferable == 'true'

  -- 验证 NFT 存在
  if not Owners[tokenId] then
    local errorResponse = {
      Action = 'NFT-Transferable-Error',
      TokenId = tokenId,
      Error = 'NFT not found!',
      Data = 'The requested NFT does not exist'
    }
    if msg.reply then
      msg.reply(errorResponse)
    else
      Send({
        Target = msg.From,
        Action = "NFT-Transferable-Error",
        TokenId = tokenId,
        Error = 'NFT not found!',
        ["Data-Protocol"] = "ao",
        Type = "NFT-Transferable-Error",
        Data = json.encode({
          error = 'NFT not found',
          tokenId = tokenId,
          message = 'The requested NFT does not exist'
        })
      })
    end
    return
  end

  if not NFTs[tokenId] then
    local errorResponse = {
      Action = 'NFT-Transferable-Error',
      TokenId = tokenId,
      Error = 'NFT not found!',
      Data = 'NFT data not found'
    }
    if msg.reply then
      msg.reply(errorResponse)
    else
      Send({
        Target = msg.From,
        Action = "NFT-Transferable-Error",
        TokenId = tokenId,
        Error = 'NFT not found!',
        ["Data-Protocol"] = "ao",
        Type = "NFT-Transferable-Error",
        Data = json.encode({
          error = 'NFT not found',
          tokenId = tokenId,
          message = 'NFT data not found'
        })
      })
    end
    return
  end

  -- 验证所有权
  if Owners[tokenId] ~= msg.From then
    local errorResponse = {
      Action = 'NFT-Transferable-Error',
      TokenId = tokenId,
      Error = 'You do not own this NFT!',
      Data = 'Only the owner can change transferable status'
    }
    if msg.reply then
      msg.reply(errorResponse)
    else
      Send({
        Target = msg.From,
        Action = "NFT-Transferable-Error",
        TokenId = tokenId,
        Error = 'You do not own this NFT!',
        ["Data-Protocol"] = "ao",
        Type = "NFT-Transferable-Error",
        Data = json.encode({
          error = 'You do not own this NFT',
          tokenId = tokenId,
          message = 'Only the owner can change transferable status'
        })
      })
    end
    return
  end

  NFTs[tokenId].transferable = transferableValue

  local response = {
    Action = 'NFT-Transferable-Updated',
    TokenId = tokenId,
    Transferable = transferableValue,
    Data = "NFT '" .. NFTs[tokenId].name .. "' transferable status updated to: " .. tostring(transferable)
  }

  if msg.reply then
    msg.reply({
      Action = 'NFT-Transferable-Updated',
      TokenId = tokenId,
      Transferable = tostring(transferable),
      Data = "NFT '" .. NFTs[tokenId].name .. "' transferable status updated to: " .. tostring(transferable)
    })
  else
    Send({
      Target = msg.From,
      Action = "NFT-Transferable-Updated",
      TokenId = tokenId,
      Transferable = tostring(transferable),
      ["Data-Protocol"] = "ao",
      Type = "NFT-Update",
      Data = "NFT '" .. NFTs[tokenId].name .. "' transferable status updated to: " .. tostring(transferable)
    })
  end
end)

-- 批量铸造 NFT
Handlers.add('mint_batch_nft', Handlers.utils.hasMatchingTag("Action", "Mint-Batch-NFT"), function(msg)
  -- 在 AO 中，参数通过 Tags 传递，AO 会将参数名转换为小写
  local nftsData = msg.Tags.NFTs or msg.Tags.NFTs or msg.NFTs

  -- 参数验证：返回错误消息而不是崩溃
  if not nftsData or type(nftsData) ~= 'string' then
    local errorResponse = {
      Action = 'Batch-Mint-Error',
      Error = 'NFTs is required!',
      Data = 'NFTs parameter must be a JSON string'
    }
    if msg.reply then
      msg.reply(errorResponse)
    else
      Send({
        Target = msg.From,
        Action = "Batch-Mint-Error",
        Error = 'NFTs is required!',
        ["Data-Protocol"] = "ao",
        Type = "Batch-Mint-Error",
        Data = json.encode({
          error = 'NFTs is required',
          message = 'NFTs parameter must be a JSON string',
          debug = {
            tagsNFTs = msg.Tags.NFTs,
            msgNFTs = msg.NFTs
          }
        })
      })
    end
    return
  end

  local nfts = json.decode(nftsData)
  if not nfts or type(nfts) ~= 'table' then
    local errorResponse = {
      Action = 'Batch-Mint-Error',
      Error = 'NFTs must be an array!',
      Data = 'NFTs parameter must be a valid JSON array'
    }
    if msg.reply then
      msg.reply(errorResponse)
    else
      Send({
        Target = msg.From,
        Action = "Batch-Mint-Error",
        Error = 'NFTs must be an array!',
        ["Data-Protocol"] = "ao",
        Type = "Batch-Mint-Error",
        Data = json.encode({
          error = 'NFTs must be an array',
          message = 'NFTs parameter must be a valid JSON array'
        })
      })
    end
    return
  end

  local mintedTokens = {}
  local mintErrors = {}

  for i, nftData in ipairs(nfts) do
    if type(nftData.name) == 'string' and type(nftData.description) == 'string' and type(nftData.image) == 'string' then
      TokenIdCounter = TokenIdCounter + 1
      local tokenId = tostring(TokenIdCounter)

      NFTs[tokenId] = {
        name = nftData.name,
        description = nftData.description,
        image = nftData.image,
        attributes = nftData.attributes or {},
        transferable = nftData.transferable ~= false, -- 默认可转让
        createdAt = msg.Timestamp or tostring(os.time()),
        creator = msg.From
      }

      Owners[tokenId] = msg.From
      table.insert(mintedTokens, {
        tokenId = tokenId,
        name = nftData.name
      })
    else
      table.insert(mintErrors, {
        index = i,
        error = 'Invalid NFT data: missing required fields'
      })
    end
  end

  -- 发送批量铸造结果
  if msg.reply then
    msg.reply({
      Action = 'Batch-Mint-Result',
      MintedTokens = json.encode(mintedTokens),
      Errors = json.encode(mintErrors),
      TotalMinted = #mintedTokens,
      TotalErrors = #mintErrors
    })
  else
    Send({
      Target = msg.From,
      Action = "Batch-Mint-Result",
      MintedTokens = json.encode(mintedTokens),
      Errors = json.encode(mintErrors),
      TotalMinted = tostring(#mintedTokens),
      TotalErrors = tostring(#mintErrors),
      ["Data-Protocol"] = "ao",
      Type = "Batch-NFT-Mint",
      Data = json.encode({
        success = true,
        mintedTokens = mintedTokens,
        errors = mintErrors,
        totalMinted = #mintedTokens,
        totalErrors = #mintErrors,
        message = "Batch mint completed"
      })
    })
  end
end)

-- 获取合约统计信息
Handlers.add('get_contract_stats', Handlers.utils.hasMatchingTag("Action", "Get-Contract-Stats"), function(msg)
  local totalNFTs = 0
  local uniqueOwners = {}
  local transferableCount = 0

  for tokenId, nft in pairs(NFTs) do
    totalNFTs = totalNFTs + 1
    uniqueOwners[Owners[tokenId]] = true
    if nft.transferable then
      transferableCount = transferableCount + 1
    end
  end

  local uniqueOwnerCount = 0
  for _ in pairs(uniqueOwners) do
    uniqueOwnerCount = uniqueOwnerCount + 1
  end

  local stats = {
    totalNFTs = totalNFTs,
    uniqueOwners = uniqueOwnerCount,
    transferableNFTs = transferableCount,
    nonTransferableNFTs = totalNFTs - transferableCount
  }

  if msg.reply then
    msg.reply({
      Action = 'Contract-Stats',
      Data = json.encode({
        stats = stats,
        message = "Contract statistics retrieved successfully"
      })
    })
  else
    Send({
      Target = msg.From,
      Action = "Contract-Stats",
      Stats = json.encode(stats),
      ["Data-Protocol"] = "ao",
      Type = "Contract-Stats",
      Data = json.encode({
        success = true,
        stats = stats,
        message = "Contract statistics retrieved successfully"
      })
    })
  end
end)

-- 调试处理器：显示所有消息处理详情
Handlers.add('debug_message', Handlers.utils.hasMatchingTag("Action", "Debug-Message"), function(msg)
  print("=== DEBUG MESSAGE RECEIVED ===")
  print("Action: " .. (msg.Action or "nil"))
  print("From: " .. (msg.From or "nil"))
  print("Target: " .. (msg.Target or "nil"))
  print("Timestamp: " .. (msg.Timestamp or "nil"))

  print("All Tags:")
  for key, value in pairs(msg.Tags or {}) do
    print("  " .. key .. " = " .. tostring(value))
  end

  print("Message Data: " .. (msg.Data or "nil"))

  local debugResponse = {
    Action = 'Debug-Response',
    Message = 'Debug information logged',
    Data = 'Check console output for detailed debug information'
  }

  if msg.reply then
    msg.reply({
      Action = 'Debug-Response',
      Message = 'Debug information logged',
      Data = json.encode({
        message = 'Debug information logged',
        checkConsole = true
      })
    })
  else
    Send({
      Target = msg.From,
      Action = "Debug-Response",
      Message = 'Debug information logged',
      ["Data-Protocol"] = "ao",
      Type = "Debug-Response",
      Data = json.encode({
        message = 'Debug information logged',
        checkConsole = true
      })
    })
  end
end)

-- 调试处理器：查看合约完整状态
Handlers.add('debug_state', Handlers.utils.hasMatchingTag("Action", "Debug-State"), function(msg)
  local stateSummary = {
    tokenIdCounter = TokenIdCounter,
    totalNFTs = 0,
    totalOwners = 0,
    nfts = {},
    owners = {},
    transferableCount = 0,
    nonTransferableCount = 0
  }

  local uniqueOwners = {}
  for tokenId, owner in pairs(Owners) do
    stateSummary.totalNFTs = stateSummary.totalNFTs + 1
    stateSummary.owners[tokenId] = owner
    stateSummary.nfts[tokenId] = {
      name = NFTs[tokenId].name,
      description = NFTs[tokenId].description,
      transferable = NFTs[tokenId].transferable
    }

    if not uniqueOwners[owner] then
      uniqueOwners[owner] = true
      stateSummary.totalOwners = stateSummary.totalOwners + 1
    end

    if NFTs[tokenId].transferable then
      stateSummary.transferableCount = stateSummary.transferableCount + 1
    else
      stateSummary.nonTransferableCount = stateSummary.nonTransferableCount + 1
    end
  end

  print("=== CONTRACT STATE DEBUG ===")
  print("TokenIdCounter: " .. TokenIdCounter)
  print("Total NFTs: " .. stateSummary.totalNFTs)
  print("Total Owners: " .. stateSummary.totalOwners)
  print("Transferable NFTs: " .. stateSummary.transferableCount)
  print("Non-Transferable NFTs: " .. stateSummary.nonTransferableCount)
  print("Owners table:")
  for tokenId, owner in pairs(Owners) do
    print("  TokenId " .. tokenId .. " -> " .. owner)
  end

  if msg.reply then
    msg.reply({
      Action = 'Debug-State-Response',
      StateSummary = json.encode(stateSummary),
      Data = json.encode({
        stateSummary = stateSummary,
        message = 'Contract state debug information'
      })
    })
  else
    Send({
      Target = msg.From,
      Action = "Debug-State-Response",
      StateSummary = json.encode(stateSummary),
      ["Data-Protocol"] = "ao",
      Type = "Debug-Response",
      Data = json.encode({
        success = true,
        stateSummary = stateSummary,
        message = 'Contract state debug information'
      })
    })
  end
end)

print("NFT Contract loaded successfully!")
print("Available actions:")
print("- Info: Get contract information")
print("- Mint-NFT: Mint a new NFT")
print("- Transfer-NFT: Transfer an NFT")
print("- Get-NFT: Get NFT information")
print("- Get-User-NFTs: Get user's NFTs")
print("- Set-NFT-Transferable: Set NFT transferable status")
print("- Mint-Batch-NFT: Mint multiple NFTs at once")
print("- Get-Contract-Stats: Get contract statistics")
print("- Debug-Message: Debug incoming messages (NEW)")
print("- Debug-State: View contract complete state (NEW)")
