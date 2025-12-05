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

-- Callback function for NFT deposit success (similar to inventory_service callbacks)
function nft_escrow_service_local.process_nft_deposit_on_success(context, event_data)
    -- Validate that the NFT deposit matches our expectations
    if event_data.escrowId ~= context.EscrowId then
        -- Not for this escrow, this shouldn't happen but let's be safe
        local short_circuited = true
        local is_error = true
        local result_or_error = "NFT deposit escrowId mismatch"
        return short_circuited, is_error, result_or_error
    end

    -- Success: NFT has been deposited, continue with saga
    local short_circuited = false
    local is_error = false
    local result_or_error = nil
    return short_circuited, is_error, result_or_error
end

-- Callback function for NFT deposit success
function nft_escrow_service_local.process_nft_deposit_on_success(context, event_data)
    -- Validate that the NFT deposit matches our expectations
    if event_data.escrowId ~= context.EscrowId then
        -- Not for this escrow, this shouldn't happen but let's be safe
        local short_circuited = true
        local is_error = true
        local result_or_error = "NFT deposit escrowId mismatch"
        return short_circuited, is_error, result_or_error
    end

    -- Success: NFT has been deposited, continue with saga
    local short_circuited = false
    local is_error = false
    local result_or_error = nil
    return short_circuited, is_error, result_or_error
end

-- Callback function for NFT deposit failure
-- onFailure: No return value specification - must execute compensation flow
function nft_escrow_service_local.process_nft_deposit_on_failure(context, event_data)
    -- Handle NFT deposit failure/timeout - must execute compensation
    -- Cannot ignore failure or continue waiting - immediately rollback and trigger compensation
    -- This function does not return values - compensation is handled by the saga framework
end

-- UseEscrowPayment method implementation
function nft_escrow_service_local.create_nft_escrow_record(context)
    -- Generate escrow ID (simplified - in real implementation might use proper ID generation)
    local escrow_id = tostring(math.random(1000000, 9999999)) -- Simplified ID generation

    -- Create escrow record
    local escrow_record = {
        EscrowId = escrow_id,
        SellerAddress = context.SellerAddress,
        NftContract = context.NftContract,
        TokenId = context.TokenId,
        TokenContract = context.TokenContract,
        Price = context.Price,
        EscrowTerms = context.EscrowTerms,
        CreatedAt = os.time(),
        -- BuyerAddress will be set later when payment is applied
        -- PaymentId will be set later when payment is applied
    }

    -- Store the escrow record
    NftEscrowTable[escrow_id] = escrow_record

    -- Return result and commit function
    local result = { EscrowId = escrow_id }

    local commit = function()
        -- Record is already stored above
        -- Additional commit logic can be added here if needed
    end

    return result, commit
end

function nft_escrow_service_local.use_escrow_payment(context)
    local escrow_id = context.EscrowId
    local payment_id = context.PaymentId

    -- Get records (simplified - in real implementation would use proper error handling)
    local escrow_payment = EscrowPaymentTable[payment_id]
    if not escrow_payment or escrow_payment.Status ~= "AVAILABLE" then
        error("Invalid payment record")
    end

    local escrow_record = NftEscrowTable[escrow_id]
    if not escrow_record then
        error("Escrow record not found")
    end

    -- Match payment with escrow conditions
    if escrow_payment.TokenContract ~= escrow_record.TokenContract or
        escrow_payment.Amount ~= escrow_record.Price then
        error("Payment does not match escrow conditions")
    end

    -- Update records
    escrow_record.BuyerAddress = escrow_payment.PayerAddress
    escrow_record.PaymentId = payment_id
    NftEscrowTable[escrow_id] = escrow_record

    escrow_payment.Status = "USED"
    escrow_payment.UsedByEscrowId = escrow_id
    EscrowPaymentTable[payment_id] = escrow_payment

    -- Return success result and commit function
    local result = {
        escrowId = escrow_id,
        buyerAddress = escrow_payment.PayerAddress,
        paymentId = payment_id
    }

    local commit = function()
        -- Records are already updated above
        -- Trigger event (simplified)
        local saga_id = escrow_id
        saga.trigger_local_event(saga_id, "EscrowPaymentUsed", {
            escrowId = escrow_id,
            buyerAddress = escrow_payment.PayerAddress
        })
    end

    return result, commit
end

-- Only WaitForNftDeposit step has onSuccess/onFailure defined in YAML
-- Other steps do not have onSuccess/onFailure definitions, so no callback functions should be generated

return nft_escrow_service_local
