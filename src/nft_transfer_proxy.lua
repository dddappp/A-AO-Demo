-- NFT Transfer Proxy Module
-- Handles communication with external NFT contracts

local nft_transfer_proxy = {}

-- Transfer NFT to specified address
-- @param params table with fields: from, to, nft_contract, token_id
-- @return result table with transfer details
function nft_transfer_proxy.transfer(params)
    print("🔄 NFT_TRANSFER_PROXY: Starting NFT transfer")
    print("  - From: " .. tostring(params.from))
    print("  - To: " .. tostring(params.to))
    print("  - NFT Contract: " .. tostring(params.nft_contract))
    print("  - TokenId: " .. tostring(params.token_id))
    print("  - EscrowId: " .. tostring(params.escrow_id))

    -- Validate required parameters
    if not params.from or not params.to or not params.nft_contract or not params.token_id then
        print("❌ NFT_TRANSFER_PROXY: Missing required parameters")
        error("Missing required parameters for NFT transfer")
    end

    -- In AO, NFT transfers are initiated by the current owner
    -- This proxy sends a transfer message to the NFT contract
    local transfer_msg = {
        Target = params.nft_contract,
        Action = "Transfer",
        Recipient = params.to,
        TokenId = tostring(params.token_id),
        -- Include escrow context for event correlation
        EscrowId = params.escrow_id or "unknown"
    }

    print("🔄 NFT_TRANSFER_PROXY: Sending Transfer message to NFT contract")
    -- Send the message
    local result = Send(transfer_msg)
    print("✅ NFT_TRANSFER_PROXY: Transfer message sent, message_id: " .. tostring(result))

    return {
        success = true,
        message_id = result,
        from = params.from,
        to = params.to,
        nft_contract = params.nft_contract,
        token_id = params.token_id,
        escrow_id = params.escrow_id
    }
end

return nft_transfer_proxy
