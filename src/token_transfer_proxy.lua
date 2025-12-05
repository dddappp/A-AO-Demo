-- Token Transfer Proxy Module
-- Handles communication with external token contracts

local token_transfer_proxy = {}

-- Transfer tokens to specified address
-- @param params table with fields: token_contract, recipient, amount
-- @return result table with transfer details
function token_transfer_proxy.transfer(params)
    -- Validate required parameters
    if not params.token_contract or not params.recipient or not params.amount then
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

    -- Send the message
    local result = Send(transfer_msg)

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
