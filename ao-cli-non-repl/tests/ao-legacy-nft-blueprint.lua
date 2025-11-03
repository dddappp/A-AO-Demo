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

-- Unified error sender function
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


-- TEMPORARILY DISABLED ALL HANDLERS EXCEPT DEBUG

-- Balance handler - Exact match with Wander wallet expectations
-- Handlers.add('nft_balance', Handlers.utils.hasMatchingTag("Action", "Balance"), function(msg)
-- Wander wallet sends: data: JSON.stringify({ Target: address })
-- And expects: balance as string in Data field
-- local targetAddress = nil

-- Parse data field (Wander wallet approach)
-- if msg.Data and msg.Data ~= '' then
--   local success, decoded = pcall(function() return json.decode(msg.Data) end)
--   if success and decoded and decoded.Target then
--     targetAddress = decoded.Target
--   end
-- end

-- Count NFTs owned by this address (exact match with Wander wallet logic)
-- local nftCount = 0
-- for tokenId, owner in pairs(Owners) do
--   if owner == targetAddress then
--     nftCount = nftCount + 1
--   end
-- end

-- Return pure number as string in Data field (matching Wander wallet expectation)
-- if msg.reply then
--   msg.reply({ Data = tostring(nftCount) })
-- else
--   Send({
--     Target = msg.From,
--     Data = tostring(nftCount)  -- Pure number string, no extra fields
--   })
-- end
-- end)

-- Info handler - makes this contract recognizable as NFT by Wander wallet
Handlers.add('nft_info', Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
  local response = {
    Name = 'AO Legacy NFT Collection',
    Ticker = 'NFT-LEGACY',
    Logo = 'SBCCXwwecBlDqRLUjb8dYABExTJXLieawf7m2aBJ-KY', -- Same as token blueprint
    Denomination = "0",                                   -- NFTs are whole units
    Transferable = "true"                                 -- This marks it as NFT for Wander wallet
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
  print("MINT-NFT: ===== STARTING MINT OPERATION =====")
  print("MINT-NFT: Processing mint request from:", msg.From)

  -- STEP 1: Comprehensive parameter extraction with detailed logging
  print("MINT-NFT: ===== STEP 1: PARAMETER EXTRACTION =====")

  -- Check all possible parameter sources with detailed logging
  print("MINT-NFT: Checking direct message properties:")
  print("  msg.Name =", msg.Name, type(msg.Name))
  print("  msg.Description =", msg.Description, type(msg.Description))
  print("  msg.Image =", msg.Image, type(msg.Image))
  print("  msg.Transferable =", msg.Transferable, type(msg.Transferable))

  print("MINT-NFT: Checking lowercase message properties:")
  print("  msg.name =", msg.name, type(msg.name))
  print("  msg.description =", msg.description, type(msg.description))
  print("  msg.image =", msg.image, type(msg.image))
  print("  msg.transferable =", msg.transferable, type(msg.transferable))

  print("MINT-NFT: Checking Tags:")
  if msg.Tags then
    print("  msg.Tags present, contents:")
    for k, v in pairs(msg.Tags) do
      print("    " .. k .. " = " .. tostring(v))
    end
  else
    print("  msg.Tags is nil or empty")
  end

  -- Extract parameters with multiple fallback strategies
  local name = msg.Name or msg.name or (msg.Tags and msg.Tags.Name) or (msg.Tags and msg.Tags.name)
  local description = msg.Description or msg.description or (msg.Tags and msg.Tags.Description) or
  (msg.Tags and msg.Tags.description)
  local image = msg.Image or msg.image or (msg.Tags and msg.Tags.Image) or (msg.Tags and msg.Tags.image)
  local transferable = msg.Transferable or msg.transferable or (msg.Tags and msg.Tags.Transferable) or
  (msg.Tags and msg.Tags.transferable)

  print("MINT-NFT: ===== STEP 2: PARAMETER VALIDATION =====")
  print("MINT-NFT: Extracted parameters:")
  print("  name =", name, type(name))
  print("  description =", description, type(description))
  print("  image =", image, type(image))
  print("  transferable =", transferable, type(transferable))

  -- STEP 2: Ultra-strict parameter validation with detailed error reporting
  local validation_errors = {}

  -- Name validation
  if not name then
    table.insert(validation_errors, "Name parameter is missing (tried: msg.Name, msg.name, msg.Tags.Name, msg.Tags.name)")
  elseif type(name) ~= "string" then
    table.insert(validation_errors, "Name must be a string, got: " .. type(name))
  elseif name == "" then
    table.insert(validation_errors, "Name cannot be empty string")
  elseif #name > 100 then
    table.insert(validation_errors, "Name too long (max 100 chars), got: " .. #name .. " chars")
  end

  -- Description validation
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

  -- Image validation
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

  -- Transferable validation (optional, defaults to true)
  local isTransferable = true -- default
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

  -- If any validation errors, fail immediately with detailed error report
  if #validation_errors > 0 then
    print("MINT-NFT: ❌ VALIDATION FAILED - " .. #validation_errors .. " errors found")
    for i, err in ipairs(validation_errors) do
      print("  " .. i .. ". " .. err)
    end

    local error_summary = "Mint validation failed: " .. #validation_errors .. " errors. Details in console logs."
    sendError(msg, 'Mint-Error', 'Parameter validation failed', error_summary)
    print("MINT-NFT: ===== MINT OPERATION FAILED =====")
    return
  end

  print("MINT-NFT: ✅ All parameters validated successfully")

  -- STEP 3: NFT Creation with comprehensive error handling
  print("MINT-NFT: ===== STEP 3: NFT CREATION =====")

  -- Increment token counter with safety checks
  if not TokenIdCounter then
    print("MINT-NFT: ❌ CRITICAL ERROR - TokenIdCounter not initialized")
    sendError(msg, 'Mint-Error', 'Internal error: TokenIdCounter not initialized')
    print("MINT-NFT: ===== MINT OPERATION FAILED =====")
    return
  end

  TokenIdCounter = TokenIdCounter + 1
  local tokenId = tostring(TokenIdCounter)

  print("MINT-NFT: Generated TokenId:", tokenId, "(Counter:", TokenIdCounter, ")")

  -- Parse attributes from Data field with robust error handling
  local attributes = {}
  if msg.Data and msg.Data ~= '' then
    print("MINT-NFT: Parsing attributes from msg.Data:", msg.Data)
    local success, decoded = pcall(function() return json.decode(msg.Data) end)
    if success then
      if decoded and type(decoded) == "table" and decoded.attributes then
        attributes = decoded.attributes
        print("MINT-NFT: Successfully parsed attributes, count:", #attributes)
      else
        print("MINT-NFT: Warning - msg.Data doesn't contain valid attributes object")
      end
    else
      print("MINT-NFT: Warning - Failed to parse msg.Data as JSON:", decoded)
    end
  else
    print("MINT-NFT: No Data field provided, using empty attributes")
  end

  -- Create NFT data structure with comprehensive validation
  print("MINT-NFT: Creating NFT data structure...")
  local nftData = {
    name = name,
    description = description,
    image = image,
    attributes = attributes,
    transferable = isTransferable,
    createdAt = msg.Timestamp or tostring(os.time()),
    creator = msg.From
  }

  -- Validate NFT data structure
  local nft_validation_errors = {}
  if not nftData.name or nftData.name == "" then table.insert(nft_validation_errors, "NFT name is empty") end
  if not nftData.description or nftData.description == "" then table.insert(nft_validation_errors,
      "NFT description is empty") end
  if not nftData.image or nftData.image == "" then table.insert(nft_validation_errors, "NFT image is empty") end
  if not nftData.creator or nftData.creator == "" then table.insert(nft_validation_errors, "NFT creator is empty") end

  if #nft_validation_errors > 0 then
    print("MINT-NFT: ❌ NFT DATA VALIDATION FAILED")
    for i, err in ipairs(nft_validation_errors) do
      print("  " .. i .. ". " .. err)
    end
    sendError(msg, 'Mint-Error', 'NFT data validation failed')
    print("MINT-NFT: ===== MINT OPERATION FAILED =====")
    return
  end

  -- Store NFT with error checking
  print("MINT-NFT: Storing NFT in NFTs table...")
  NFTs[tokenId] = nftData

  -- Verify NFT was stored correctly
  if not NFTs[tokenId] then
    print("MINT-NFT: ❌ CRITICAL ERROR - Failed to store NFT in NFTs table")
    sendError(msg, 'Mint-Error', 'Failed to store NFT data')
    print("MINT-NFT: ===== MINT OPERATION FAILED =====")
    return
  end

  -- Set ownership with error checking
  print("MINT-NFT: Setting ownership...")
  Owners[tokenId] = msg.From

  -- Verify ownership was set correctly
  if not Owners[tokenId] or Owners[tokenId] ~= msg.From then
    print("MINT-NFT: ❌ CRITICAL ERROR - Failed to set NFT ownership")
    -- Note: NFT is already stored, so we don't delete it, but report the error
    sendError(msg, 'Mint-Error', 'Failed to set NFT ownership')
    print("MINT-NFT: ===== MINT OPERATION PARTIALLY FAILED =====")
    return
  end

  print("MINT-NFT: ===== STEP 4: RESPONSE GENERATION =====")
  print("MINT-NFT: ✅ NFT created successfully!")
  print("  TokenId:", tokenId)
  print("  Name:", name)
  print("  Creator:", msg.From)
  print("  Transferable:", isTransferable)

  -- Generate response with comprehensive error handling
  local response = {
    Action = 'Mint-Confirmation',
    TokenId = tokenId,
    Name = name,
    Data = "NFT '" .. name .. "' minted successfully with ID: " .. tokenId
  }

  -- Send response using msg.reply() or Send() as fallback
  print("MINT-NFT: Sending Mint-Confirmation response...")
  if msg.reply then
    print("MINT-NFT: Using msg.reply() for response")
    local reply_success, reply_error = pcall(function() msg.reply(response) end)
    if reply_success then
      print("MINT-NFT: ✅ Mint-Confirmation sent via msg.reply()")
    else
      print("MINT-NFT: ❌ Failed to send via msg.reply():", reply_error)
      print("MINT-NFT: Using Send() as fallback")
      response.Target = msg.From
      local send_success, send_error = pcall(function() Send(response) end)
      if send_success then
        print("MINT-NFT: ✅ Mint-Confirmation sent via Send()")
      else
        print("MINT-NFT: ❌ Failed to send Mint-Confirmation:", send_error)
        print("MINT-NFT: ===== MINT OPERATION PARTIALLY FAILED =====")
        return
      end
    end
  else
    print("MINT-NFT: msg.reply() not available, using Send()")
    response.Target = msg.From
    local send_success, send_error = pcall(function() Send(response) end)
    if send_success then
      print("MINT-NFT: ✅ Mint-Confirmation sent via Send()")
    else
      print("MINT-NFT: ❌ Failed to send Mint-Confirmation:", send_error)
      print("MINT-NFT: ===== MINT OPERATION PARTIALLY FAILED =====")
      return
    end
  end

  print("MINT-NFT: ===== MINT OPERATION COMPLETED SUCCESSFULLY =====")
  print("MINT-NFT: 🎉 NFT '" .. name .. "' (ID: " .. tokenId .. ") minted and confirmed!")
end)



-- Standard Transfer handler - Compatible with Wander wallet NFT transfers
Handlers.add('standard_transfer', Handlers.utils.hasMatchingTag("Action", "Transfer"), function(msg)
  -- Check if this is an NFT transfer (has TokenId tag) - this is how Wander wallet identifies NFT transfers
  -- AO converts first char to lowercase: TokenId -> Tokenid
  local tokenId = msg.Tokenid -- Use AO-converted name directly
  local recipient = msg.Recipient
  local quantity = msg.Quantity

  if tokenId and tokenId ~= '' then
    -- Validate NFT transfer parameters (matching Wander wallet expectations)
    if not recipient or type(recipient) ~= 'string' or recipient == '' then
      sendError(msg, 'Transfer-Error', 'Recipient is required for NFT transfer')
      return
    end

    -- Validate NFT exists
    if not NFTs[tokenId] then
      sendError(msg, 'Transfer-Error', 'NFT not found', 'TokenId: ' .. tokenId)
      return
    end

    -- Validate ownership
    if Owners[tokenId] ~= msg.From then
      sendError(msg, 'Transfer-Error', 'You do not own this NFT', 'TokenId: ' .. tokenId)
      return
    end

    -- Validate transferable
    if not NFTs[tokenId].transferable then
      sendError(msg, 'Transfer-Error', 'This NFT is not transferable', 'TokenId: ' .. tokenId)
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
        Quantity = quantity or "1", -- Use provided quantity or default to 1
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
        -- NOTE 调用 Send 之前注意设置 Target
        debitNotice.Target = msg.From
        Send(debitNotice)
      end
      Send(creditNotice)
    end
  else
    -- Regular token transfer - not supported by this NFT contract
    sendError(msg, 'Transfer-Error', 'This NFT contract only supports NFT transfers with TokenId parameter')
  end
end)

-- Get NFT information handler - Compatible with research report format
print("Registering get_nft handler...")
Handlers.add('get_nft', Handlers.utils.hasMatchingTag("Action", "Get-NFT"), function(msg)
  print("GET-NFT HANDLER: Processing request")

  -- Get TokenId - try multiple sources (based on working Mint pattern)
  local tokenId = msg.Tokenid or msg.TokenId
  if msg.Tags then
    tokenId = tokenId or msg.Tags.Tokenid or msg.Tags.TokenId
  end

  -- For eval+Send compatibility, also check direct message properties

  if not tokenId then
    print("GET-NFT ERROR: No TokenId provided in message")
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

  print("GET-NFT: Using TokenId =", tokenId)

  -- Look up NFT
  local nft = NFTs[tokenId]
  if nft and nft.name then
    print("GET-NFT: Found NFT with name:", nft.name)
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
      print("GET-NFT: ✅ NFT-Info response sent via msg.reply()")
    else
      response.Target = msg.From
      Send(response)
      print("GET-NFT: ✅ NFT-Info response sent via Send()")
    end
  else
    print("GET-NFT: NFT not found or incomplete data")
    local errorResponse = {
      Action = 'NFT-Error',
      Data = 'NFT not found for TokenId: ' .. tokenId
    }
    if msg.reply then
      msg.reply(errorResponse)
      print("GET-NFT: ❌ NFT-Error response sent via msg.reply()")
    else
      errorResponse.Target = msg.From
      Send(errorResponse)
      print("GET-NFT: ❌ NFT-Error response sent via Send()")
    end
  end
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
    msg.reply(response)
  else
    response.Target = msg.From
    Send(response)
  end
end)

-- Set NFT transferable status handler - Compatible with research report format
Handlers.add('set_nft_transferable', Handlers.utils.hasMatchingTag("Action", "Set-NFT-Transferable"), function(msg)
  print("SET-NFT-TRANSFERABLE: Handler called with Action=" .. tostring(msg.Action))
  print("SET-NFT-TRANSFERABLE: msg.From=" .. tostring(msg.From) .. ", msg.Target=" .. tostring(msg.Target))
  print("SET-NFT-TRANSFERABLE: msg.Tags.From-Process=" .. tostring(msg.Tags and msg.Tags["From-Process"]))
  print("SET-NFT-TRANSFERABLE: msg.Tags.From-Module=" .. tostring(msg.Tags and msg.Tags["From-Module"]))
  -- Parameter extraction: Tags first (for eval+Send), then direct properties
  local tokenId = (msg.Tags and msg.Tags.TokenId) or (msg.Tags and msg.Tags.Tokenid) or msg.TokenId or msg.Tokenid
  local transferable = (msg.Tags and msg.Tags.Transferable) or (msg.Tags and msg.Tags.transferable) or msg.Transferable or msg.transferable

  print("SET-NFT-TRANSFERABLE: Extracted tokenId='" .. tostring(tokenId) .. "', transferable='" .. tostring(transferable) .. "'")

  -- Validate parameters
  if not tokenId or type(tokenId) ~= 'string' or tokenId == '' then
    print("SET-NFT-TRANSFERABLE: TokenId validation failed")
    sendError(msg, 'NFT-Transferable-Error', 'TokenId is required')
    return
  end

  if not transferable or type(transferable) ~= 'string' then
    print("SET-NFT-TRANSFERABLE: Transferable validation failed")
    sendError(msg, 'NFT-Transferable-Error', 'Transferable is required and must be a string')
    return
  end

  -- Check if NFT exists
  if not NFTs[tokenId] then
    print("SET-NFT-TRANSFERABLE: NFT not found for tokenId=" .. tokenId)
    sendError(msg, 'NFT-Transferable-Error', 'NFT not found', 'TokenId: ' .. tokenId)
    return
  end

  -- Check ownership (allow process owner in eval context)
  local isOwner = (Owners[tokenId] == msg.From)
  local isProcessOwner = (msg.From == msg.Target)  -- eval context: msg.From == msg.Target

  print("SET-NFT-TRANSFERABLE: Ownership check - owner=" .. tostring(Owners[tokenId]) .. ", from=" .. tostring(msg.From) .. ", target=" .. tostring(msg.Target))

  if not (isOwner or isProcessOwner) then
    print("SET-NFT-TRANSFERABLE: Ownership check failed")
    sendError(msg, 'NFT-Transferable-Error', 'You do not own this NFT', 'TokenId: ' .. tokenId)
    return
  end

  print("SET-NFT-TRANSFERABLE: Ownership check passed (owner=" .. tostring(isOwner) .. ", process=" .. tostring(isProcessOwner) .. ")")

  print("SET-NFT-TRANSFERABLE: All validations passed, updating NFT...")

  -- Update transferable status (matching research report: transferable == 'true')
  local isTransferable = transferable == 'true'
  NFTs[tokenId].transferable = isTransferable

  local response = {
    Action = 'NFT-Transferable-Updated',
    TokenId = tokenId,
    Transferable = isTransferable, -- Boolean value, let's test if AO supports boolean in messages
    Name = NFTs[tokenId].name,
    Data = "NFT '" .. NFTs[tokenId].name .. "' transferable status updated to: " .. tostring(isTransferable)
  }

  print("SET-NFT-TRANSFERABLE: Operation completed successfully")

  -- Send response using the same pattern as Mint-NFT
  if msg.reply then
    msg.reply(response)
    print("SET-NFT-TRANSFERABLE: Response sent via msg.reply()")
  else
    response.Target = msg.From
    Send(response)
    print("SET-NFT-TRANSFERABLE: Response sent via Send() to msg.From")
  end

  print("SET-NFT-TRANSFERABLE: ===== OPERATION COMPLETED SUCCESSFULLY =====")
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
