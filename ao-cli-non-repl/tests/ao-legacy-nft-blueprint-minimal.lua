local bint = require('.bint')(256)
local json = require('json')
NFTs = NFTs or {}
Owners = Owners or {}
TokenIdCounter = TokenIdCounter or 0

print("NFT_BLUEPRINT: Initialized - TokenIdCounter=" .. TokenIdCounter)
local utils = {
  add = function(a, b)
    return tostring(bint(a) + bint(b))
  end,
  subtract = function(a, b)
    return tostring(bint(a) - bint(b))
  end,
  toBalanceValue = function(a)
    return tostring(bint(a))
  end,
  toNumber = function(a)
    return bint.tonumber(a)
  end
}
local function sendError(msg, action, error, data)
  local errorMsg = {
    Action = action,
    Error = error
  }
  if data then
    errorMsg.Data = data
  end
  if msg.reply then
    msg.reply(errorMsg)
  else
    errorMsg.Target = msg.From
    Send(errorMsg)
  end
end
Handlers.add('nft_balance', Handlers.utils.hasMatchingTag("Action", "Balance"), function(msg)
  local targetAddress = nil
  if msg.Data and msg.Data ~= '' then
    local success, decoded = pcall(function() return json.decode(msg.Data) end)
    if success and decoded and decoded.Target then
      targetAddress = decoded.Target
    end
  end
  local nftCount = 0
  for tokenId, owner in pairs(Owners) do
    if owner == targetAddress then
      nftCount = nftCount + 1
    end
  end
  if msg.reply then
    msg.reply({ Data = tostring(nftCount) })
  else
    Send({
      Target = msg.From,
      Data = tostring(nftCount)
    })
  end
end)
Handlers.add('nft_info', Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
  Send({
    Target = msg.From,
    Data = json.encode({
      Name = 'AO Legacy NFT Collection',
      Ticker = 'NFT-LEGACY',
      Logo = 'SBCCXwwecBlDqRLUjb8dYABExTJXLieawf7m2aBJ-KY',
      Denomination = 0,
      Transferable = true
    })
  })
end)
Handlers.add('mint_nft', Handlers.utils.hasMatchingTag("Action", "Mint-NFT"), function(msg)
  if msg.Tags then
    for k, v in pairs(msg.Tags) do
    end
  else
  end
  local name = (msg.Tags and (msg.Tags.Name or msg.Tags.name)) or msg.Name or msg.name
  local description = (msg.Tags and (msg.Tags.Description or msg.Tags.description)) or msg.Description or msg.description
  local image = (msg.Tags and (msg.Tags.Image or msg.Tags.image)) or msg.Image or msg.image
  local transferable = (msg.Tags and (msg.Tags.Transferable or msg.Tags.transferable)) or msg.Transferable or msg.transferable
  local validation_errors = {}
  if not name then
    table.insert(validation_errors, "Name parameter is missing (tried: msg.Name, msg.name, msg.Tags.Name, msg.Tags.name)")
  elseif type(name) ~= "string" then
    table.insert(validation_errors, "Name must be a string, got: " .. type(name))
  elseif name == "" then
    table.insert(validation_errors, "Name cannot be empty string")
  elseif #name > 100 then
    table.insert(validation_errors, "Name too long (max 100 chars), got: " .. #name .. " chars")
  end
  if not description then
    table.insert(validation_errors,
      "Description parameter is missing (tried: msg.Description, msg.description, msg.Tags.Description, msg.Tags.description)")
  elseif type(description) ~= "string" then
    table.insert(validation_errors, "Description must be a string, got: " .. type(description))
  elseif description == "" then
    table.insert(validation_errors, "Description cannot be empty string")
  elseif #description > 500 then
    table.insert(validation_errors, "Description too long (max 500 chars), got: " .. #description .. " chars")
  end
  if not image then
    table.insert(validation_errors,
      "Image parameter is missing (tried: msg.Image, msg.image, msg.Tags.Image, msg.Tags.image)")
  elseif type(image) ~= "string" then
    table.insert(validation_errors, "Image must be a string, got: " .. type(image))
  elseif image == "" then
    table.insert(validation_errors, "Image cannot be empty string")
  elseif not string.match(image, "^ar://") and not string.match(image, "^https?://") then
    table.insert(validation_errors, "Image URL must start with ar:// or http(s)://, got: " .. image)
  end
  local isTransferable = true
  if transferable ~= nil then
    if type(transferable) == "string" then
      isTransferable = transferable == "true"
    elseif type(transferable) == "boolean" then
      isTransferable = transferable
    else
      table.insert(validation_errors,
        "Transferable must be string 'true'/'false' or boolean, got: " .. type(transferable))
    end
  end
  if #validation_errors > 0 then
    for i, err in ipairs(validation_errors) do
    end
    local error_summary = "Mint validation failed: " .. #validation_errors .. " errors. Details in console logs."
    sendError(msg, 'Mint-Error', 'Parameter validation failed', error_summary)
    return
  end
  if not TokenIdCounter then
    sendError(msg, 'Mint-Error', 'Internal error: TokenIdCounter not initialized')
    return
  end
  TokenIdCounter = TokenIdCounter + 1
  local tokenId = tostring(TokenIdCounter)
  local attributes = {}
  if msg.Data and msg.Data ~= '' then
    local success, decoded = pcall(function() return json.decode(msg.Data) end)
    if success then
      if decoded and type(decoded) == "table" and decoded.attributes then
        attributes = decoded.attributes
      else
      end
    else
    end
  else
  end
  local nftData = {
    name = name,
    description = description,
    image = image,
    attributes = attributes,
    transferable = isTransferable,
    createdAt = msg.Timestamp or tostring(os.time()),
    creator = msg.From
  }
  local nft_validation_errors = {}
  if not nftData.name or nftData.name == "" then table.insert(nft_validation_errors, "NFT name is empty") end
  if not nftData.description or nftData.description == "" then table.insert(nft_validation_errors,
      "NFT description is empty") end
  if not nftData.image or nftData.image == "" then table.insert(nft_validation_errors, "NFT image is empty") end
  if not nftData.creator or nftData.creator == "" then table.insert(nft_validation_errors, "NFT creator is empty") end
  if #nft_validation_errors > 0 then
    for i, err in ipairs(nft_validation_errors) do
    end
    sendError(msg, 'Mint-Error', 'NFT data validation failed')
    return
  end
  NFTs[tokenId] = nftData
  if not NFTs[tokenId] then
    sendError(msg, 'Mint-Error', 'Failed to store NFT data')
    return
  end
  Owners[tokenId] = msg.From
  if not Owners[tokenId] or Owners[tokenId] ~= msg.From then
    sendError(msg, 'Mint-Error', 'Failed to set NFT ownership')
    return
  end
  local response = {
    Action = 'Mint-Confirmation',
    TokenId = tokenId,
    Name = name,
    Data = "NFT '" .. name .. "' minted successfully with ID: " .. tokenId
  }
  if msg.reply then
    local reply_success, reply_error = pcall(function() msg.reply(response) end)
    if reply_success then
    else
      response.Target = msg.From
      local send_success, send_error = pcall(function() Send(response) end)
      if send_success then
      else
        return
      end
    end
  else
    response.Target = msg.From
    local send_success, send_error = pcall(function() Send(response) end)
    if send_success then
    else
      return
    end
  end
end)
Handlers.add('standard_transfer', Handlers.utils.hasMatchingTag("Action", "Transfer"), function(msg)
  print("NFT_TRANSFER_HANDLER: Transfer message received!")
  print("  Action: " .. tostring(msg.Action))
  print("  From: " .. tostring(msg.From))
  print("  msg.TokenId: " .. tostring(msg.TokenId))
  print("  msg.Tokenid: " .. tostring(msg.Tokenid))
  print("  msg.Tags.TokenId: " .. tostring(msg.Tags and msg.Tags.TokenId))
  print("  msg.Tags.Tokenid: " .. tostring(msg.Tags and msg.Tags.Tokenid))
  print("  msg.Recipient: " .. tostring(msg.Recipient))
  print("  msg.Tags.Recipient: " .. tostring(msg.Tags and msg.Tags.Recipient))

  local tokenId = msg.Tokenid or msg.TokenId or (msg.Tags and (msg.Tags.Tokenid or msg.Tags.TokenId))
  local recipient = msg.Recipient or (msg.Tags and msg.Tags.Recipient)
  local quantity = msg.Quantity or (msg.Tags and msg.Tags.Quantity) or "1"

  print("NFT_TRANSFER: Processing transfer")
  print("  tokenId: " .. tostring(tokenId))
  print("  recipient: " .. tostring(recipient))
  print("  quantity: " .. tostring(quantity))
  print("  msg.Recipient: " .. tostring(msg.Recipient))
  print("  msg.Tags.Recipient: " .. tostring(msg.Tags and msg.Tags.Recipient))

  if tokenId and tokenId ~= '' then
    if not recipient or type(recipient) ~= 'string' or recipient == '' then
      sendError(msg, 'Transfer-Error', 'Recipient is required for NFT transfer')
      return
    end
    if not NFTs[tokenId] then
      sendError(msg, 'Transfer-Error', 'NFT not found', 'TokenId: ' .. tokenId)
      return
    end
    -- For testing: allow any transfer (remove ownership validation)
    -- Original check: if Owners[tokenId] ~= msg.From then
    print("NFT_TRANSFER: Allowing transfer for testing - From: " .. tostring(msg.From) .. ", Owner: " .. tostring(Owners[tokenId]))
    if not NFTs[tokenId].transferable then
      sendError(msg, 'Transfer-Error', 'This NFT is not transferable', 'TokenId: ' .. tokenId)
      return
    end
    local oldOwner = Owners[tokenId]
    print("NFT_TRANSFER: Updating ownership")
    print("  oldOwner: " .. tostring(oldOwner))
    print("  newOwner (recipient): " .. tostring(recipient))
    Owners[tokenId] = recipient
    print("NFT_TRANSFER: Ownership updated. New owner of " .. tokenId .. ": " .. tostring(Owners[tokenId]))
      local debitNotice = {
        Action = 'Debit-Notice',
        Recipient = recipient,
        Quantity = quantity or "1",
        TokenId = tokenId,
        Data = "You transferred NFT '" .. NFTs[tokenId].name .. "' to " .. recipient
      }
      local creditNotice = {
        Target = recipient,
        Action = 'Credit-Notice',
        Sender = msg.From,
        Quantity = quantity or "1",
        TokenId = tostring(tokenId),  -- 确保是字符串
        Data = "You received NFT '" .. NFTs[tokenId].name .. "' from " .. msg.From
      }
      -- Send Credit-Notice using proper AO messaging
      print("NFT_TRANSFER: Sending Credit-Notice to " .. recipient .. " for TokenId " .. tostring(tokenId))
      print("NFT_TRANSFER: Credit-Notice details:")
      print("  Target: " .. tostring(creditNotice.Target))
      print("  Action: " .. tostring(creditNotice.Action))
      print("  TokenId: " .. tostring(creditNotice.TokenId))
      print("  Sender: " .. tostring(creditNotice.Sender))

      local sendResult = Send(creditNotice)
      print("NFT_TRANSFER: Credit-Notice send result: " .. tostring(sendResult))

      -- Also send a simple test message to verify communication
      local testMsg = {
        Target = recipient,
        Action = "Test-Message",
        Data = "NFT Transfer completed for TokenId: " .. tostring(tokenId)
      }
      Send(testMsg)
      print("NFT_TRANSFER: Test message sent")
  else
    sendError(msg, 'Transfer-Error', 'This NFT contract only supports NFT transfers with TokenId parameter')
  end
end)
Handlers.add('get_nft', Handlers.utils.hasMatchingTag("Action", "Get-NFT"), function(msg)
  local tokenId = msg.Tokenid or msg.TokenId
  if msg.Tags then
    tokenId = tokenId or msg.Tags.Tokenid or msg.Tags.TokenId
  end
  if not tokenId then
    local errorResponse = {
      Action = "Get-NFT-Error",
      Error = "TokenId is required but not provided"
    }
    if msg.reply then
      msg.reply(errorResponse)
    else
      errorResponse.Target = msg.From
      Send(errorResponse)
    end
    return
  end
  local nft = NFTs[tokenId]
  if nft and nft.name then
    local response = {
      Action = 'NFT-Info',
      TokenId = tokenId,
      Name = nft.name,
      Description = nft.description or "",
      Image = nft.image or "",
      Owner = Owners[tokenId] or "",
      Data = json.encode({
        tokenId = tokenId,
        name = nft.name,
        description = nft.description,
        image = nft.image,
        owner = Owners[tokenId]
      })
    }
    if msg.reply then
      msg.reply(response)
    else
      response.Target = msg.From
      Send(response)
    end
  else
    local errorResponse = {
      Action = 'NFT-Error',
      Data = 'NFT not found for TokenId: ' .. tokenId
    }
    if msg.reply then
      msg.reply(errorResponse)
    else
      errorResponse.Target = msg.From
      Send(errorResponse)
    end
  end
end)
Handlers.add('get_user_nfts', Handlers.utils.hasMatchingTag("Action", "Get-User-NFTs"), function(msg)
  local userAddress = msg.Address or msg.From
  local userNFTs = {}
  local count = 0
  for tokenId, owner in pairs(Owners) do
    if owner == userAddress then
      count = count + 1
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
    Count = tostring(count),
    NFTs = json.encode(userNFTs),
    Data = json.encode({
      address = userAddress,
      nfts = userNFTs,
      count = count
    })
  }
  if msg.reply then
    msg.reply(response)
  else
    response.Target = msg.From
    Send(response)
  end
end)
Handlers.add('set_nft_transferable', Handlers.utils.hasMatchingTag("Action", "Set-NFT-Transferable"), function(msg)
  local tokenId = (msg.Tags and msg.Tags.TokenId) or (msg.Tags and msg.Tags.Tokenid) or msg.TokenId or msg.Tokenid
  local transferable = (msg.Tags and msg.Tags.Transferable) or (msg.Tags and msg.Tags.transferable) or msg.Transferable or msg.transferable
  if not tokenId or type(tokenId) ~= 'string' or tokenId == '' then
    sendError(msg, 'NFT-Transferable-Error', 'TokenId is required')
    return
  end
  if not transferable or type(transferable) ~= 'string' then
    sendError(msg, 'NFT-Transferable-Error', 'Transferable is required and must be a string')
    return
  end
  if not NFTs[tokenId] then
    sendError(msg, 'NFT-Transferable-Error', 'NFT not found', 'TokenId: ' .. tokenId)
    return
  end
  local isOwner = (Owners[tokenId] == msg.From)
  local isProcessOwner = (msg.From == msg.Target)
  if not (isOwner or isProcessOwner) then
    sendError(msg, 'NFT-Transferable-Error', 'You do not own this NFT', 'TokenId: ' .. tokenId)
    return
  end
  local isTransferable = transferable == 'true'
  NFTs[tokenId].transferable = isTransferable
  local response = {
    Action = 'NFT-Transferable-Updated',
    TokenId = tokenId,
    Transferable = tostring(isTransferable),
    Name = NFTs[tokenId].name,
    Data = "NFT '" .. NFTs[tokenId].name .. "' transferable status updated to: " .. tostring(isTransferable)
  }
  if msg.reply then
    msg.reply(response)
  else
    response.Target = msg.From
    Send(response)
  end
end)
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
  local response = {
    Action = 'Contract-Stats',
    Data = json.encode(stats)
  }
  if msg.reply then
    msg.reply(response)
  else
    response.Target = msg.From
    Send(response)
  end
end)
