-- Simple test for Set-NFT-Transferable Inbox delivery
-- Minimal NFT contract with just the problematic handler

-- Initialize global state
NFTs = NFTs or {}
Owners = Owners or {}

-- Simple Set-NFT-Transferable handler for testing Inbox delivery
Handlers.add('set_nft_transferable', Handlers.utils.hasMatchingTag("Action", "Set-NFT-Transferable"), function(msg)
  print("SET-NFT-TRANSFERABLE: Handler called")

  -- Extract tokenId
  local tokenId = msg.TokenId or msg.Tokenid or (msg.Tags and (msg.Tags.TokenId or msg.Tags.Tokenid))
  print("SET-NFT-TRANSFERABLE: Extracted tokenId=" .. tostring(tokenId))

  -- Extract transferable
  local transferable = msg.Transferable or msg.transferable or (msg.Tags and (msg.Tags.Transferable or msg.Tags.transferable))
  print("SET-NFT-TRANSFERABLE: Extracted transferable=" .. tostring(transferable))

  -- Create response
  local response = {
    Action = 'Set-NFT-Transferable-Confirmation',
    TokenId = tokenId,
    Transferable = transferable,
    Data = "NFT transferable status updated to: " .. tostring(transferable)
  }

  print("SET-NFT-TRANSFERABLE: Sending response...")

  -- Send response using the same pattern as Mint-NFT
  print("SET-NFT-TRANSFERABLE: Using same pattern as Mint-NFT")
  if msg.reply then
    print("SET-NFT-TRANSFERABLE: Using msg.reply()")
    msg.reply(response)
    print("SET-NFT-TRANSFERABLE: Response sent via msg.reply()")
  else
    print("SET-NFT-TRANSFERABLE: Using Send() with response.Target = msg.From")
    response.Target = msg.From
    Send(response)
    print("SET-NFT-TRANSFERABLE: Response sent via Send() with Target=msg.From")
  end

  print("SET-NFT-TRANSFERABLE: Handler completed")
end)

print("Simple Set-NFT-Transferable test contract loaded")
