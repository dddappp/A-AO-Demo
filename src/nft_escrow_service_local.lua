local nft_escrow_service_local = {}

-- Global tables will be available at runtime

function nft_escrow_service_local.transfer_nft_to_buyer(context)
    -- Get escrow record to find buyer address
    local escrow_record = NftEscrowTable[context.EscrowId]
    if not escrow_record or not escrow_record.BuyerAddress then
        error("Escrow record not found or buyer address not set")
    end

    -- Call NFT transfer proxy (simplified implementation)
    local nft_proxy = require("nft_transfer_proxy")
    local result = nft_proxy.transfer({
        from = ao.id,
        to = escrow_record.BuyerAddress,
        nft_contract = context.NftContract,
        token_id = context.TokenId
    })

    -- Return result and commit function
    return result, function()
        -- Message sent, waiting for external confirmation
    end
end

function nft_escrow_service_local.transfer_funds_to_seller(context)
    -- Get escrow record to find PaymentId, then get payment record
    local escrow_record = NftEscrowTable[context.EscrowId]
    if not escrow_record or not escrow_record.PaymentId then
        error("Escrow record not found or payment not linked")
    end

    local escrow_payment = EscrowPaymentTable[escrow_record.PaymentId]
    if not escrow_payment then
        error("Payment record not found")
    end

    -- Call token transfer proxy (simplified implementation)
    local token_proxy = require("token_transfer_proxy")
    local result = token_proxy.transfer({
        token_contract = escrow_payment.TokenContract,
        recipient = context.SellerAddress,
        amount = escrow_payment.Amount
    })

    -- Return result and commit function
    return result, function()
        -- Message sent, waiting for external confirmation
    end
end


return nft_escrow_service_local
