NftEscrowTable = NftEscrowTable or {}
EscrowPaymentTable = EscrowPaymentTable or {}
SagaInstances = SagaInstances or {}

-- Debug variables for testing
_DEBUG = _DEBUG or {}
_DEBUG.nft_credit_notices_received = _DEBUG.nft_credit_notices_received or 0


-- Global function for triggering saga events
function trigger_waiting_saga_event(event_type, event_data, matcher)
    matcher = matcher or function() return true end
    for saga_id, saga_instance in pairs(SagaInstances or {}) do
        if saga_instance.waiting_state and
           saga_instance.waiting_state.is_waiting and
           (saga_instance.waiting_state.event_type == event_type or
            saga_instance.waiting_state.success_event_type == event_type) then
            if matcher(event_data, saga_instance.waiting_state.context) then
                local continuation_handler = saga_instance.waiting_state.continuation_handler
                saga_instance.waiting_state = nil
                SagaInstances[saga_id] = saga_instance -- Save the updated instance
                if continuation_handler then
                    continuation_handler(saga_id, saga_instance.context, event_type, event_data, event_data.msg or {})
                end
            end
        end
    end
end

-- Helper function
function table_keys(t)
    if not t then return {} end
    local keys = {}
    for k, v in pairs(t) do
        table.insert(keys, tostring(k))
    end
    return keys
end

-- Make it globally available
_G.trigger_waiting_saga_event = trigger_waiting_saga_event

Handlers.add(
    "token_deposit_listener",
    function(msg)
        return (msg.Action == "Credit-Notice") and
        not (msg.TokenId or msg.Tokenid or (msg.Tags and (msg.Tags.TokenId or msg.Tags.Tokenid)))
    end,
    function(msg, env)
        local payer = msg.Sender or (msg.Tags and msg.Tags.Sender) or "unknown"
        local amount = msg.Quantity or (msg.Tags and msg.Tags.Quantity) or "0"
        local payment_id = tostring(#EscrowPaymentTable + 1)
        EscrowPaymentTable[payment_id] = {
            id = payment_id,
            payer_address = payer,
            amount = amount,
            status = "CREATED",
            createdAt = msg.Timestamp or os.time()
        }

        print("DEBUG: Token deposit detected - PaymentId: " .. payment_id .. ", Payer: " .. payer .. ", Amount: " .. amount)
        -- Trigger EscrowPaymentCreated event for Saga
        trigger_waiting_saga_event("EscrowPaymentCreated", {
            paymentId = payment_id,
            payer = payer,
            amount = amount,
            msg = msg  -- Pass the original message for timestamp access
        })
    end
)

Handlers.add(
    "nft_deposit_listener",
    function(msg)
        -- Match any Credit-Notice with TokenId for debugging
        if msg.Action == "Credit-Notice" then
            local has_token = msg.TokenId or msg.Tokenid or (msg.Tags and (msg.Tags.TokenId or msg.Tags.Tokenid))
            if has_token then
                print("🎯 NFT_DEPOSIT_LISTENER: Matched Credit-Notice with TokenId")
                return true
            end
        end
        return false
    end,
    function(msg, env)
        -- Increment debug counter for testing
        _DEBUG.nft_credit_notices_received = _DEBUG.nft_credit_notices_received + 1

        print("🎯 NFT_DEPOSIT_LISTENER: Processing Credit-Notice #" .. _DEBUG.nft_credit_notices_received)
        print("  Action: " .. tostring(msg.Action))
        print("  TokenId: " .. tostring(msg.TokenId))
        print("  Sender: " .. tostring(msg.Sender))
        print("  From: " .. tostring(msg.From))

        local token_id = msg.TokenId or msg.Tokenid or (msg.Tags and (msg.Tags.TokenId or msg.Tags.Tokenid))
        local sender = msg.Sender or (msg.Tags and msg.Tags.Sender) or "unknown"

        print("🎯 NFT_DEPOSIT_LISTENER: Extracted token_id=" .. tostring(token_id) .. ", sender=" .. tostring(sender))

        for escrow_id, escrow in pairs(NftEscrowTable or {}) do
            local escrow_token_id = escrow.token_id or escrow.TokenId
            print("🎯 NFT_DEPOSIT_LISTENER: Checking escrow " .. escrow_id .. " with token_id=" .. tostring(escrow_token_id) .. ", status=" .. tostring(escrow.status))
            if (escrow_token_id == token_id) and (escrow.status == "PENDING" or escrow.status == "PAYMENT_LINKED") then
                print("✅ NFT_DEPOSIT_LISTENER: Found matching escrow, triggering NftDeposited event")
                -- Trigger NftDeposited event for Saga FIRST
                trigger_waiting_saga_event("NftDeposited", {
                    escrowId = escrow_id,
                    tokenId = token_id,
                    seller = sender,
                    msg = msg
                }, function(event_data, saga_context)
                    print("🎯 NFT_DEPOSIT_LISTENER: Matcher checking " .. tostring(event_data.escrowId) .. " vs " .. tostring(saga_context.EscrowId))
                    return event_data.escrowId == saga_context.EscrowId
                end)

                -- Update escrow status AFTER triggering event
                escrow.status = "NFT_DEPOSITED"
                escrow.seller_address = sender
                NftEscrowTable[escrow_id] = escrow
                print("✅ NFT_DEPOSIT_LISTENER: Escrow status updated to NFT_DEPOSITED")

                break
            end
        end
    end
)


-- Debug: Add a catch-all message listener
Handlers.add(
    "debug_all_messages",
    function(msg)
        return true  -- Catch all messages
    end,
    function(msg, env)
        print("📨 ESCROW RECEIVED: Action=" .. tostring(msg.Action) .. ", From=" .. tostring(msg.From))
        if msg.Action == "Credit-Notice" then
            print("🎯 CREDIT NOTICE: TokenId=" .. tostring(msg.TokenId) .. ", Sender=" .. tostring(msg.Sender))
        elseif msg.Action == "Test-Message" then
            print("🧪 TEST MESSAGE: " .. tostring(msg.Data))
        end
    end
)

-- Load Saga service after handlers are registered
print("🔧 Loading Saga service...")
local success, error_msg = pcall(function()
    return require("nft_escrow_service")
end)
if success then
    print("✅ Saga service loaded successfully")
else
    print("❌ Failed to load Saga service: " .. tostring(error_msg))
end
