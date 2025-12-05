-- NFT Transfer Proxy Module
-- Handles communication with external NFT contracts

local nft_transfer_proxy = {}

-- Transfer NFT to specified address
-- @param params table with fields: from, to, nft_contract, token_id
-- @return result table with transfer details
function nft_transfer_proxy.transfer(params)
    -- Validate required parameters
    if not params.from or not params.to or not params.nft_contract or not params.token_id then
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

    -- Send the message
    local result = Send(transfer_msg)

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
