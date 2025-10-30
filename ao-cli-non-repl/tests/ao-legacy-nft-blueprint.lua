-- AO Legacy NFT Blueprint
-- Fully compatible with Wander wallet NFT standard
-- Based on research report and actual AO network testing

local bint = require('.bint')(256)
local json = require('json')

-- NFT Contract State
NFTs = NFTs or {}
Owners = Owners or {}
TokenIdCounter = TokenIdCounter or 0

-- Utility functions
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


-- Balance handler - Exact match with Wander wallet expectations
Handlers.add('nft_balance', Handlers.utils.hasMatchingTag("Action", "Balance"), function(msg)
  -- Wander wallet sends: data: JSON.stringify({ Target: address })
  -- And expects: balance as string in Data field
  local targetAddress = nil

  -- Parse data field (Wander wallet approach)
  if msg.Data and msg.Data ~= '' then
    local success, decoded = pcall(function() return json.decode(msg.Data) end)
    if success and decoded and decoded.Target then
      targetAddress = decoded.Target
    end
  end

  -- Count NFTs owned by this address (exact match with Wander wallet logic)
  local nftCount = 0
  for tokenId, owner in pairs(Owners) do
    if owner == targetAddress then
      nftCount = nftCount + 1
    end
  end

  -- Return pure number as string in Data field (matching Wander wallet expectation)
  if msg.reply then
    msg.reply({ Data = tostring(nftCount) })
  else
    Send({
      Target = msg.From,
      Data = tostring(nftCount)  -- Pure number string, no extra fields
    })
  end
end)

-- Info handler - makes this contract recognizable as NFT by Wander wallet
Handlers.add('nft_info', Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
  local response = {
    Name = 'AO Legacy NFT Collection',
    Ticker = 'NFT-LEGACY',
    Logo = 'SBCCXwwecBlDqRLUjb8dYABExTJXLieawf7m2aBJ-KY',  -- Same as token blueprint
    Denomination = "0",  -- NFTs are whole units
    Transferable = "true"  -- This marks it as NFT for Wander wallet
  }

  if msg.reply then
    msg.reply(response)
  else
    response.Target = msg.From
    Send(response)
  end
end)

-- Mint NFT handler - Fully compatible with research report format
Handlers.add('mint_nft', Handlers.utils.hasMatchingTag("Action", "Mint-NFT"), function(msg)
  -- Direct parameter access
  local name = msg.Name
  local description = msg.Description
  local image = msg.Image

  -- Validate required parameters (following research report approach but with better error handling)
  if not name or type(name) ~= 'string' or name == '' then
    local errorMsg = { Action = 'Mint-Error', Error = 'Name is required and must be a non-empty string' }
    if msg.reply then msg.reply(errorMsg) else Send({Target = msg.From, Action = 'Mint-Error', Error = 'Name is required'}) end
    return
  end

  if not description or type(description) ~= 'string' or description == '' then
    local errorMsg = { Action = 'Mint-Error', Error = 'Description is required and must be a non-empty string' }
    if msg.reply then msg.reply(errorMsg) else Send({Target = msg.From, Action = 'Mint-Error', Error = 'Description is required'}) end
    return
  end

  if not image or type(image) ~= 'string' or image == '' then
    local errorMsg = { Action = 'Mint-Error', Error = 'Image is required and must be a non-empty string' }
    if msg.reply then msg.reply(errorMsg) else Send({Target = msg.From, Action = 'Mint-Error', Error = 'Image is required'}) end
    return
  end

  -- Increment token counter and create NFT
  TokenIdCounter = TokenIdCounter + 1
  local tokenId = tostring(TokenIdCounter)

  -- Parse attributes from Data field if provided (matching research report)
  local attributes = {}
  if msg.Data and msg.Data ~= '' then
    local success, decoded = pcall(function() return json.decode(msg.Data) end)
    if success and decoded and decoded.attributes then
      attributes = decoded.attributes
    end
  end

  -- Get transferable flag (matching research report: msg.Transferable == 'true')
  local transferable = msg.Transferable  -- Direct access, no AO conversion for this parameter
  local isTransferable = transferable == 'true'  -- Exact match with research report

  -- Create NFT data (matching research report structure)
  NFTs[tokenId] = {
    name = name,
    description = description,
    image = image,
    attributes = attributes,
    transferable = isTransferable,
    createdAt = msg.Timestamp or tostring(os.time()),
    creator = msg.From
  }

  -- Set ownership
  Owners[tokenId] = msg.From

  -- Send Mint-Confirmation (exactly matching research report format)
  local response = {
    Action = 'Mint-Confirmation',
    TokenId = tokenId,
    Name = name,
    Data = "NFT '" .. name .. "' minted successfully with ID: " .. tokenId
  }

  if msg.reply then
    msg.reply(response)
  else
    response.Target = msg.From
    Send(response)
  end
end)


-- Standard Transfer handler - Compatible with Wander wallet NFT transfers
Handlers.add('standard_transfer', Handlers.utils.hasMatchingTag("Action", "Transfer"), function(msg)
  -- Check if this is an NFT transfer (has TokenId tag) - this is how Wander wallet identifies NFT transfers
  -- AO converts first char to lowercase: TokenId -> Tokenid
  local tokenId = msg.Tokenid  -- Use AO-converted name directly
  local recipient = msg.Recipient
  local quantity = msg.Quantity

  if tokenId and tokenId ~= '' then

    -- Validate NFT transfer parameters (matching Wander wallet expectations)
    if not recipient or type(recipient) ~= 'string' or recipient == '' then
      local errorMsg = { Action = 'Transfer-Error', Error = 'Recipient is required for NFT transfer' }
      if msg.reply then msg.reply(errorMsg) else Send({Target = msg.From, Action = 'Transfer-Error', Error = 'Recipient is required'}) end
      return
    end

    -- Validate NFT exists
    if not NFTs[tokenId] then
      local errorMsg = { Action = 'Transfer-Error', TokenId = tokenId, Error = 'NFT not found' }
      if msg.reply then msg.reply(errorMsg) else Send({Target = msg.From, Action = 'Transfer-Error', TokenId = tokenId, Error = 'NFT not found'}) end
      return
    end

    -- Validate ownership
    if Owners[tokenId] ~= msg.From then
      local errorMsg = { Action = 'Transfer-Error', TokenId = tokenId, Error = 'You do not own this NFT' }
      if msg.reply then msg.reply(errorMsg) else Send({Target = msg.From, Action = 'Transfer-Error', TokenId = tokenId, Error = 'You do not own this NFT'}) end
      return
    end

    -- Validate transferable
    if not NFTs[tokenId].transferable then
      local errorMsg = { Action = 'Transfer-Error', TokenId = tokenId, Error = 'This NFT is not transferable' }
      if msg.reply then msg.reply(errorMsg) else Send({Target = msg.From, Action = 'Transfer-Error', TokenId = tokenId, Error = 'This NFT is not transferable'}) end
      return
    end

    -- Perform NFT transfer
    local oldOwner = Owners[tokenId]
    Owners[tokenId] = recipient

    -- Send Debit-Notice and Credit-Notice (matching Wander wallet expectations)
    if not msg.Cast then
      -- Debit-Notice (to sender)
      local debitNotice = {
        Action = 'Debit-Notice',
        Recipient = recipient,
        Quantity = quantity or "1",  -- Use provided quantity or default to 1
        TokenId = tokenId,
        Data = "You transferred NFT '" .. NFTs[tokenId].name .. "' to " .. recipient
      }

      -- Credit-Notice (to recipient)
      local creditNotice = {
        Target = recipient,
        Action = 'Credit-Notice',
        Sender = msg.From,
        Quantity = quantity or "1",
        TokenId = tokenId,
        Data = "You received NFT '" .. NFTs[tokenId].name .. "' from " .. msg.From
      }

      -- Send notifications (matching Wander wallet logic)
      if msg.reply then
        msg.reply(debitNotice)
      else
        Send(debitNotice)
      end
      Send(creditNotice)
    end
  else
    -- Regular token transfer - not supported by this NFT contract
    local errorMsg = { Action = 'Transfer-Error', Error = 'This NFT contract only supports NFT transfers with TokenId parameter' }
    if msg.reply then msg.reply(errorMsg) else Send({Target = msg.From, Action = 'Transfer-Error', Error = 'NFT transfers require TokenId parameter'}) end
  end
end)

-- Get NFT information handler - Compatible with research report format
Handlers.add('get_nft', Handlers.utils.hasMatchingTag("Action", "Get-NFT"), function(msg)
  -- Debug logging
  print("=== Get-NFT Handler Called ===")
  print("msg.From: " .. tostring(msg.From))
  print("msg.Action: " .. tostring(msg.Action))

  -- Direct parameter access - AO converts TokenId to Tokenid
  local tokenId = msg.TokenId or msg.Tokenid or msg.Tags.TokenId or msg.Tags.Tokenid
  print("tokenId extracted: " .. tostring(tokenId))

  -- Validate parameter
  if not tokenId or type(tokenId) ~= 'string' or tokenId == '' then
    print("ERROR: TokenId validation failed")
    local errorMsg = {
      Action = 'NFT-Error',
      Error = 'TokenId is required and must be a string',
      Data = 'TokenId parameter missing or invalid'
    }
    if msg.reply then
      msg.reply(errorMsg)
    else
      Send({
        Target = msg.From,
        Action = 'NFT-Error',
        Error = 'TokenId is required and must be a string',
        ['Data-Protocol'] = 'ao',
        Type = 'NFT-Error'
      })
    end
    return
  end

  -- Check if NFT exists
  local nft = NFTs[tokenId]
  print("NFT lookup for tokenId '" .. tokenId .. "': " .. tostring(nft ~= nil))
  if not nft then
    print("ERROR: NFT not found")
    local errorMsg = {
      Action = 'NFT-Error',
      TokenId = tokenId,
      Error = 'NFT not found',
      Data = 'The requested NFT does not exist'
    }
    if msg.reply then
      msg.reply(errorMsg)
    else
      Send({
        Target = msg.From,
        Action = 'NFT-Error',
        TokenId = tokenId,
        Error = 'NFT not found',
        ['Data-Protocol'] = 'ao',
        Type = 'NFT-Error'
      })
    end
    return
  end

  print("SUCCESS: NFT found, sending response")

  -- Return NFT information
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
    Transferable = tostring(nft.transferable),
    Data = json.encode({
      tokenId = tokenId,
      name = nft.name,
      description = nft.description,
      image = nft.image,
      attributes = nft.attributes,
      owner = Owners[tokenId],
      creator = nft.creator,
      createdAt = nft.createdAt,
      transferable = nft.transferable
    })
  }

  if msg.reply then
    print("Using msg.reply()")
    msg.reply(response)
  else
    print("Using Send()")
    Send({
      Target = msg.From,
      Action = 'NFT-Info',
      TokenId = tokenId,
      Name = nft.name,
      Description = nft.description,
      Image = nft.image,
      Owner = Owners[tokenId],
      Creator = nft.creator,
      CreatedAt = nft.createdAt,
      Transferable = tostring(nft.transferable),
      ['Data-Protocol'] = 'ao',
      Type = 'NFT-Info',
      Data = json.encode({
        tokenId = tokenId,
        name = nft.name,
        description = nft.description,
        image = nft.image,
        attributes = nft.attributes,
        owner = Owners[tokenId],
        creator = nft.creator,
        createdAt = nft.createdAt,
        transferable = nft.transferable
      })
    })
  end
  print("Response sent successfully")
end)

-- Get user NFTs handler - Compatible with research report format
Handlers.add('get_user_nfts', Handlers.utils.hasMatchingTag("Action", "Get-User-NFTs"), function(msg)
  -- Direct parameter access
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
    print("Using msg.reply() for User-NFTs")
    msg.reply(response)
  else
    print("Using Send() for User-NFTs")
    Send({
      Target = msg.From,
      Action = 'User-NFTs',
      Address = userAddress,
      Count = tostring(count),
      ['Data-Protocol'] = 'ao',
      Type = 'User-NFTs',
      Data = json.encode({
        address = userAddress,
        nfts = userNFTs,
        count = count
      })
    })
  end
  print("User-NFTs response sent successfully")
end)

-- Set NFT transferable status handler - Compatible with research report format
Handlers.add('set_nft_transferable', Handlers.utils.hasMatchingTag("Action", "Set-NFT-Transferable"), function(msg)
  -- Direct parameter access
  local tokenId = msg.TokenId or msg.Tokenid
  local transferable = msg.Transferable

  -- Validate parameters (following research report approach but with better error handling)
  if not tokenId or type(tokenId) ~= 'string' or tokenId == '' then
    local errorMsg = { Action = 'NFT-Transferable-Error', Error = 'TokenId is required' }
    if msg.reply then msg.reply(errorMsg) else Send({Target = msg.From, Action = 'NFT-Transferable-Error', Error = 'TokenId is required'}) end
    return
  end

  if not transferable or type(transferable) ~= 'string' then
    local errorMsg = { Action = 'NFT-Transferable-Error', Error = 'Transferable is required and must be a string' }
    if msg.reply then msg.reply(errorMsg) else Send({Target = msg.From, Action = 'NFT-Transferable-Error', Error = 'Transferable is required'}) end
    return
  end

  -- Check if NFT exists
  if not NFTs[tokenId] then
    local errorMsg = { Action = 'NFT-Transferable-Error', TokenId = tokenId, Error = 'NFT not found' }
    if msg.reply then msg.reply(errorMsg) else Send({Target = msg.From, Action = 'NFT-Transferable-Error', TokenId = tokenId, Error = 'NFT not found'}) end
    return
  end

  -- Check ownership
  if Owners[tokenId] ~= msg.From then
    local errorMsg = { Action = 'NFT-Transferable-Error', TokenId = tokenId, Error = 'You do not own this NFT' }
    if msg.reply then msg.reply(errorMsg) else Send({Target = msg.From, Action = 'NFT-Transferable-Error', TokenId = tokenId, Error = 'You do not own this NFT'}) end
    return
  end

  -- Update transferable status (matching research report: transferable == 'true')
  local isTransferable = transferable == 'true'
  NFTs[tokenId].transferable = isTransferable

  -- Send confirmation (matching research report format)
  local response = {
    Action = 'NFT-Transferable-Updated',
    TokenId = tokenId,
    Transferable = isTransferable,  -- Boolean value matching research report
    Data = "NFT '" .. NFTs[tokenId].name .. "' transferable status updated to: " .. tostring(isTransferable)
  }

  if msg.reply then
    msg.reply(response)  -- Direct response matching research report
  else
    response.Target = msg.From
    Send(response)
  end
end)

-- Get contract statistics handler
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



print("AO Legacy NFT Blueprint loaded successfully!")
print("Available actions:")
print("- Info: Get contract information")
print("- Mint-NFT: Mint a new NFT")
print("- Transfer: Transfer NFT (standard action)")
print("- Get-NFT: Get NFT information")
print("- Get-User-NFTs: Get user's NFTs")
print("- Set-NFT-Transferable: Set NFT transferable status")
print("- Get-Contract-Stats: Get contract statistics")
print("- Notification handler: Accepts Debit/Credit notices")
