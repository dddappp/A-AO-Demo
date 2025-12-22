-- Token Transfer Proxy Module
-- Handles communication with external token contracts

local token_transfer_proxy = {}

-- Transfer tokens to specified address
-- @param params table with fields: token_contract, recipient, amount
-- @return result table with transfer details
function token_transfer_proxy.transfer(params)
    print("🔄 TOKEN_TRANSFER_PROXY: Starting token transfer")
    print("  - TokenContract: " .. tostring(params.token_contract))
    print("  - Recipient: " .. tostring(params.recipient))
    print("  - Amount: " .. tostring(params.amount))
    print("  - EscrowId: " .. tostring(params.escrow_id))

    -- Validate required parameters
    if not params.token_contract or not params.recipient or not params.amount then
        print("❌ TOKEN_TRANSFER_PROXY: Missing required parameters")
        error("Missing required parameters for token transfer")
    end

    -- In AO, token transfers use the Transfer action
    -- This proxy sends a transfer message to the token contract
    local transfer_msg = {
        Target = params.token_contract,
        Action = "Transfer",
        Recipient = params.recipient,
        Quantity = tostring(params.amount),
        -- Include escrow context for event correlation
        EscrowId = params.escrow_id or "unknown"
    }

    print("🔄 TOKEN_TRANSFER_PROXY: Sending Transfer message to token contract")
    -- Send the message
    local result = Send(transfer_msg)
    print("✅ TOKEN_TRANSFER_PROXY: Transfer message sent, message_id: " .. tostring(result))

    return {
        success = true,
        message_id = result,
        token_contract = params.token_contract,
        recipient = params.recipient,
        amount = params.amount,
        escrow_id = params.escrow_id
    }
end

return token_transfer_proxy
