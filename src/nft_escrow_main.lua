NftEscrowTable = NftEscrowTable or {}
EscrowPaymentTable = EscrowPaymentTable or {}
SagaInstances = SagaInstances or {}

local function trigger_waiting_saga_event(event_type, event_data, matcher)
    matcher = matcher or function() return true end
    for saga_id, saga_instance in pairs(SagaInstances) do
        if saga_instance.waiting_state and saga_instance.waiting_state.event_type == event_type then
            if matcher(event_data, saga_instance.waiting_state.context) then
                local continuation_handler = saga_instance.waiting_state.continuation_handler
                saga_instance.waiting_state = nil
                if continuation_handler then
                    continuation_handler(event_data, saga_instance.context)
                end
            end
        end
    end
end

Handlers.add(
    "token_deposit_listener",
    function(msg)
        return (msg.Action == "Credit-Notice") and not (msg.TokenId or msg.Tokenid or (msg.Tags and (msg.Tags.TokenId or msg.Tags.Tokenid)))
    end,
    function(msg, env)
        local payer = msg.Sender or (msg.Tags and msg.Tags.Sender) or "unknown"
        local amount = msg.Quantity or (msg.Tags and msg.Tags.Quantity) or "0"
        local payment_id = tostring(#EscrowPaymentTable + 1)
        EscrowPaymentTable[payment_id] = {
            id = payment_id,
            payer = payer,
            amount = amount,
            status = "CREATED",
            createdAt = msg.Timestamp or os.time()
        }
        trigger_waiting_saga_event("EscrowPaymentCreated", {paymentId = payment_id, payer = payer, amount = amount})
    end
)

Handlers.add(
    "nft_deposit_listener",
    function(msg)
        return (msg.Action == "Credit-Notice") and (msg.TokenId or msg.Tokenid or (msg.Tags and (msg.Tags.TokenId or msg.Tags.Tokenid)))
    end,
    function(msg, env)
        local token_id = msg.TokenId or msg.Tokenid or (msg.Tags and (msg.Tags.TokenId or msg.Tags.Tokenid))
        local sender = msg.Sender or (msg.Tags and msg.Tags.Sender) or "unknown"
        for escrow_id, escrow in pairs(NftEscrowTable) do
            if escrow.nftTokenId == token_id and escrow.status == "CREATED" then
                escrow.status = "NFT_DEPOSITED"
                trigger_waiting_saga_event("NftDeposited", {escrowId = escrow_id, tokenId = token_id, depositor = sender})
                break
            end
        end
    end
)

Handlers.add(
    "NftEscrowService_ExecuteNftEscrowTransaction",
    Handlers.utils.hasMatchingTag("Action", "NftEscrowService_ExecuteNftEscrowTransaction"),
    function(msg, env)
        local escrow_id = tostring(#NftEscrowTable + 1)
        NftEscrowTable[escrow_id] = {
            id = escrow_id,
            nftTokenId = msg.Tags.NftTokenId or "1",
            seller = msg.From,
            buyerAddress = msg.Tags.BuyerAddress,
            paymentAmount = msg.Tags.PaymentAmount or "100000000000000",
            status = "CREATED",
            createdAt = msg.Timestamp or os.time()
        }
        local saga_id = "saga_" .. escrow_id
        SagaInstances[saga_id] = {
            id = saga_id,
            escrowId = escrow_id,
            current_step = "WaitForNftDeposit",
            completed = false,
            context = {
                EscrowId = escrow_id,
                NftTokenId = msg.Tags.NftTokenId or "1",
                BuyerAddress = msg.Tags.BuyerAddress,
                PaymentAmount = msg.Tags.PaymentAmount or "100000000000000"
            },
            waiting_state = {
                event_type = "NftDeposited",
                context = {EscrowId = escrow_id},
                continuation_handler = function(event_data, context)
                    SagaInstances[saga_id].current_step = "WaitForPayment"
                    SagaInstances[saga_id].waiting_state = {
                        event_type = "EscrowPaymentUsed",
                        context = {EscrowId = escrow_id},
                        continuation_handler = function(event_data, context)
                            SagaInstances[saga_id].completed = true
                        end
                    }
                end
            }
        }
    end
)

Handlers.add(
    "NftEscrowService_UseEscrowPayment",
    Handlers.utils.hasMatchingTag("Action", "NftEscrowService_UseEscrowPayment"),
    function(msg, env)
        local escrow_id = msg.Tags.EscrowId
        local payment_id = msg.Tags.PaymentId
        local escrow = NftEscrowTable[escrow_id]
        if escrow and escrow.status == "NFT_DEPOSITED" then
            escrow.buyerAddress = msg.From
            escrow.status = "PAYMENT_LINKED"
            local payment = EscrowPaymentTable[payment_id]
            if payment then
                payment.status = "USED"
                payment.usedForEscrow = escrow_id
            end
            trigger_waiting_saga_event("EscrowPaymentUsed", {escrowId = escrow_id, paymentId = payment_id})
        end
    end
)

Handlers.add(
    "Info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg, env)
        return {
            NftEscrowTable = NftEscrowTable,
            EscrowPaymentTable = EscrowPaymentTable,
            SagaInstances = SagaInstances
        }
    end
)
