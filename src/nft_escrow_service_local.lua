local nft_escrow_service_local = {}

-- Global tables will be available at runtime
local saga = require("saga")

-- Helper: trigger waiting sagas by event type and escrowId match
local function trigger_waiting_saga_event(event_type, escrow_id, event_data)
    for saga_id, saga_instance in pairs(SagaInstances or {}) do
        local waiting = saga_instance.waiting_state
        if waiting and waiting.is_waiting and waiting.success_event_type == event_type then
            local ctx = saga_instance.context or {}
            local ctx_escrow_id = ctx.EscrowId or ctx.escrow_id
            if ctx_escrow_id and tostring(ctx_escrow_id) == tostring(escrow_id) then
                saga.trigger_local_event(saga_id, event_type, event_data)
            end
        end
    end
end

function nft_escrow_service_local.transfer_nft_to_buyer(context)
    print("🔄 TRANSFER_NFT_TO_BUYER: Starting NFT transfer to buyer")

    -- Get escrow record and normalized fields
    local escrow_record = NftEscrowTable[context.EscrowId]
    local buyer_address = context.BuyerAddress or context.buyer_address
        or (escrow_record and (escrow_record.buyer_address or escrow_record.BuyerAddress))
    local nft_contract = context.NftContract or context.nft_contract
        or (escrow_record and (escrow_record.nft_contract or escrow_record.NftContract))
    local token_id = context.TokenId or context.token_id
        or (escrow_record and (escrow_record.token_id or escrow_record.TokenId))

    print("🔄 TRANSFER_NFT_TO_BUYER: Context values:")
    print("  - EscrowId: " .. tostring(context.EscrowId))
    print("  - BuyerAddress: " .. tostring(buyer_address))
    print("  - NftContract: " .. tostring(nft_contract))
    print("  - TokenId: " .. tostring(token_id))
    print("  - Current process: " .. tostring(ao.id))
    print("  - TOKEN_PROCESS_ID should be: " .. tostring(context.TokenContract or "unknown"))

    -- Debug: Check if NFT is actually owned by this process
    if escrow_record then
        print("🔄 TRANSFER_NFT_TO_BUYER: Escrow record details:")
        for k,v in pairs(escrow_record) do
            print("    " .. k .. " = " .. tostring(v))
        end
    end

    if not escrow_record or not buyer_address then
        print("❌ TRANSFER_NFT_TO_BUYER: Error - Escrow record not found or buyer address not set")
        print("  Escrow record exists: " .. tostring(escrow_record ~= nil))
        print("  Buyer address: " .. tostring(buyer_address))
        error("Escrow record not found or buyer address not set")
    end
    if not nft_contract or not token_id then
        print("❌ TRANSFER_NFT_TO_BUYER: Error - NFT contract or token_id missing")
        error("NFT contract or token_id missing")
    end

    -- Check if this process actually owns the NFT before attempting transfer
    print("🔄 TRANSFER_NFT_TO_BUYER: Checking NFT ownership before transfer...")
    local ownership_check = Send({
        Target = nft_contract,
        Action = "Get-NFT",
        TokenId = tostring(token_id)
    })
    print("🔄 TRANSFER_NFT_TO_BUYER: Ownership check sent, message_id: " .. tostring(ownership_check))

    print("🔄 TRANSFER_NFT_TO_BUYER: Calling nft_transfer_proxy.transfer")
    local nft_proxy = require("nft_transfer_proxy")
    local result = nft_proxy.transfer({
        from = ao.id,
        to = buyer_address,
        nft_contract = nft_contract,
        token_id = token_id,
        escrow_id = context.EscrowId
    })

    print("✅ TRANSFER_NFT_TO_BUYER: NFT transfer proxy called, result: " .. tostring(result and result.success))
    print("✅ TRANSFER_NFT_TO_BUYER: Transfer message sent to NFT contract: " .. tostring(nft_contract))
    print("✅ TRANSFER_NFT_TO_BUYER: Transfer target buyer: " .. tostring(buyer_address))

    -- Wait for actual Debit-Notice from NFT contract instead of immediately triggering event
    print("⏳ TRANSFER_NFT_TO_BUYER: Waiting for Debit-Notice from NFT contract to confirm transfer")

    -- Commit placeholder
    return result, function() end
end

function nft_escrow_service_local.transfer_funds_to_seller(context)
    print("🔄 TRANSFER_FUNDS_TO_SELLER: Starting funds transfer to seller")

    local escrow_record = NftEscrowTable[context.EscrowId]
    local payment_id = escrow_record and (escrow_record.payment_id or escrow_record.PaymentId)
    print("🔄 TRANSFER_FUNDS_TO_SELLER: EscrowId=" .. tostring(context.EscrowId) .. ", PaymentId=" .. tostring(payment_id))

    if not escrow_record or not payment_id then
        print("❌ TRANSFER_FUNDS_TO_SELLER: Error - Escrow record not found or payment not linked")
        error("Escrow record not found or payment not linked")
    end

    local escrow_payment = EscrowPaymentTable[payment_id]
    if not escrow_payment then
        print("❌ TRANSFER_FUNDS_TO_SELLER: Error - Payment record not found")
        error("Payment record not found")
    end

    local seller_address = context.SellerAddress or context.seller_address
        or (escrow_record and (escrow_record.seller_address or escrow_record.SellerAddress))
    local token_contract = escrow_payment.token_contract or escrow_payment.TokenContract
    local amount = escrow_payment.amount or escrow_payment.Amount

    print("🔄 TRANSFER_FUNDS_TO_SELLER: Seller=" .. tostring(seller_address) .. ", TokenContract=" .. tostring(token_contract) .. ", Amount=" .. tostring(amount))

    if not seller_address then
        print("❌ TRANSFER_FUNDS_TO_SELLER: Error - Seller address missing")
        error("Seller address missing")
    end

    print("🔄 TRANSFER_FUNDS_TO_SELLER: Calling token_transfer_proxy")
    local token_proxy = require("token_transfer_proxy")
    local result = token_proxy.transfer({
        token_contract = token_contract,
        recipient = seller_address,
        amount = amount,
        escrow_id = context.EscrowId
    })

    print("✅ TRANSFER_FUNDS_TO_SELLER: Token transfer proxy called, result: " .. tostring(result and result.success))

    -- Wait for actual Debit-Notice from token contract instead of immediately triggering event
    print("⏳ TRANSFER_FUNDS_TO_SELLER: Waiting for Debit-Notice from token contract to confirm transfer")

    return result, function() end
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

-- Callback function for NFT deposit failure
-- onFailure: No return value specification - must execute compensation flow
function nft_escrow_service_local.process_nft_deposit_on_failure(context, event_data)
    -- Handle NFT deposit failure/timeout - must execute compensation
    -- Cannot ignore failure or continue waiting - immediately rollback and trigger compensation
    -- This function does not return values - compensation is handled by the saga framework
end

-- UseEscrowPayment method implementation
function nft_escrow_service_local.create_nft_escrow_record(context)
    -- Create escrow record using the provided EscrowId (which comes from saga_id)
    NftEscrowTable = NftEscrowTable or {}
    local escrow_id = context.EscrowId

    NftEscrowTable[escrow_id] = {
        escrow_id = escrow_id,
        seller_address = context.SellerAddress or context.seller_address,
        buyer_address = nil,
        nft_contract = context.NftContract or context.nft_contract,
        token_id = context.TokenId or context.token_id,
        token_contract = context.TokenContract or context.token_contract,
        price = context.Price or context.price,
        payment_id = nil,
        escrow_terms = context.EscrowTerms or context.escrow_terms,
        status = "PENDING",
        created_at = context.Timestamp or os.time()
    }

    print("✅ Created NftEscrow record with SagaId as EscrowId: " .. escrow_id)

    local result = { EscrowId = escrow_id }
    local commit = function()
        -- Already committed above - record is directly added to table
    end

    return result, commit
end

function nft_escrow_service_local.use_escrow_payment(context)
    print("🔗 USE_ESCROW_PAYMENT: Starting with EscrowId=" .. tostring(context.EscrowId) .. ", PaymentId=" .. tostring(context.PaymentId))

    local escrow_id = context.EscrowId
    local payment_id = context.PaymentId

    local escrow_payment = EscrowPaymentTable[payment_id]
    local payment_status = escrow_payment and (escrow_payment.status or escrow_payment.Status)
    print("🔗 USE_ESCROW_PAYMENT: Payment status check - exists: " .. tostring(escrow_payment ~= nil) .. ", status: " .. tostring(payment_status))
    if not escrow_payment or payment_status ~= "AVAILABLE" then
        print("❌ USE_ESCROW_PAYMENT: Invalid or unavailable payment record")
        error("Invalid or unavailable payment record")
    end

    local escrow_record = NftEscrowTable[escrow_id]
    print("🔗 USE_ESCROW_PAYMENT: Escrow record check - exists: " .. tostring(escrow_record ~= nil))
    if not escrow_record then
        print("❌ USE_ESCROW_PAYMENT: Escrow record not found")
        error("Escrow record not found")
    end

    local payment_token = escrow_payment.token_contract or escrow_payment.TokenContract
    local payment_amount = escrow_payment.amount or escrow_payment.Amount
    local escrow_token = escrow_record.token_contract or escrow_record.TokenContract
    local escrow_price = escrow_record.price or escrow_record.Price

    print("🔗 USE_ESCROW_PAYMENT: Token/Amount validation:")
    print("  Payment token: " .. tostring(payment_token))
    print("  Escrow token: " .. tostring(escrow_token))
    print("  Payment amount: " .. tostring(payment_amount))
    print("  Escrow price: " .. tostring(escrow_price))
    print("  Token match: " .. tostring(payment_token == escrow_token))
    print("  Amount match: " .. tostring(tostring(payment_amount) == tostring(escrow_price)))

    if payment_token ~= escrow_token or tostring(payment_amount) ~= tostring(escrow_price) then
        print("❌ USE_ESCROW_PAYMENT: Payment does not match escrow conditions")
        error("Payment does not match escrow conditions")
    end

    local buyer_address = escrow_payment.payer_address or escrow_payment.PayerAddress
    context.BuyerAddress = buyer_address
    print("🔗 USE_ESCROW_PAYMENT: Buyer address set to: " .. tostring(buyer_address))

    local nft_escrow_aggregate = require("nft_escrow_aggregate")
    local escrow_payment_aggregate = require("escrow_payment_aggregate")

    print("🔗 USE_ESCROW_PAYMENT: About to call link_payment")
    local success, result_or_error = pcall(function()
        return nft_escrow_aggregate.link_payment(
            escrow_id,
            buyer_address,
            payment_id,
            context,
            {}
        )
    end)

    if not success then
        print("❌ USE_ESCROW_PAYMENT: link_payment pcall failed with error: " .. tostring(result_or_error))
        error("link_payment failed: " .. tostring(result_or_error))
    end

    print("🔗 USE_ESCROW_PAYMENT: link_payment pcall succeeded")
    local escrow_event, escrow_commit = result_or_error[1], result_or_error[2]
    print("🔗 USE_ESCROW_PAYMENT: link_payment returned event with buyer_address=" .. tostring(escrow_event and escrow_event.buyer_address))

    local payment_event, payment_commit = escrow_payment_aggregate.mark_as_used(
        payment_id,
        escrow_id,
        context,
        {}
    )

    local result = {
        escrowId = escrow_id,
        buyerAddress = buyer_address,
        paymentId = payment_id
    }

    local commit = function()
        print("🔗 USE_ESCROW_PAYMENT: Executing commit - calling escrow_commit()")
        escrow_commit()
        print("🔗 USE_ESCROW_PAYMENT: escrow_commit() completed")

        payment_commit()
        print("🔗 USE_ESCROW_PAYMENT: payment_commit() completed")

        -- Check if NftEscrow was updated correctly
        local updated_escrow = NftEscrowTable[escrow_id]
        print("🔗 USE_ESCROW_PAYMENT: NftEscrow buyer_address after commit: " .. tostring(updated_escrow and updated_escrow.buyer_address))

        trigger_waiting_saga_event("EscrowPaymentUsed", escrow_id, {
            escrowId = escrow_id,
            buyerAddress = buyer_address,
            msg = { Timestamp = os.time() * 1000 }  -- Provide timestamp since we don't have the original message
        })
        print("🔗 USE_ESCROW_PAYMENT: EscrowPaymentUsed event triggered")
    end

    return result, commit
end

-- Compensation logic functions for Saga
function nft_escrow_service_local.return_nft_to_seller(context)
    -- Compensation: Return NFT to seller when escrow fails after NFT deposit
    -- Get escrow record to find seller address
    local escrow_record = NftEscrowTable[context.EscrowId]
    local seller_address = escrow_record and (escrow_record.seller_address or escrow_record.SellerAddress)
    if not escrow_record or not seller_address then
        error("Escrow record not found or seller address not set")
    end

    -- Call NFT transfer proxy (simplified implementation)
    local nft_proxy = require("nft_transfer_proxy")
    local result = nft_proxy.transfer({
        from = ao.id,
        to = seller_address,
        nft_contract = context.NftContract or context.nft_contract or escrow_record.nft_contract,
        token_id = context.TokenId or context.token_id or escrow_record.token_id
    })

    -- Return result and commit function
    return result, function()
        -- Message sent, waiting for external confirmation
    end
end

function nft_escrow_service_local.unlock_escrow_payment(context)
    -- Compensation: Unlock escrow payment when escrow fails after payment is applied
    -- Get escrow record to find PaymentId
    local escrow_record = NftEscrowTable[context.EscrowId]
    local payment_id = escrow_record and (escrow_record.payment_id or escrow_record.PaymentId)
    if not escrow_record or not payment_id then
        error("Escrow record not found or payment not linked")
    end

    -- Get payment record and unlock it
    local escrow_payment = EscrowPaymentTable[payment_id]
    if not escrow_payment then
        error("Payment record not found")
    end

    -- Reset payment status to AVAILABLE and clear escrow link
    escrow_payment.status = "AVAILABLE"
    escrow_payment.used_by_escrow_id = nil
    EscrowPaymentTable[payment_id] = escrow_payment

    -- Also clear payment link from escrow record
    escrow_record.payment_id = nil
    escrow_record.buyer_address = nil
    NftEscrowTable[context.EscrowId] = escrow_record

    -- Return result and commit function
    local result = {
        paymentId = payment_id,
        escrowId = context.EscrowId
    }

    local commit = function()
        -- Records are already updated above
    end

    return result, commit
end

-- Only WaitForNftDeposit step has onSuccess/onFailure defined in YAML
-- Other steps do not have onSuccess/onFailure definitions, so no callback functions should be generated

return nft_escrow_service_local
