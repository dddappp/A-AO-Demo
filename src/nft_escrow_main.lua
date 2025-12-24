NftEscrowTable = NftEscrowTable or {}
EscrowPaymentTable = EscrowPaymentTable or {}
SagaInstances = SagaInstances or {}


-- Global function for triggering saga events
function trigger_waiting_saga_event(event_type, event_data, matcher)
    matcher = matcher or function() return true end
    for saga_id, saga_instance in pairs(SagaInstances) do
        if saga_instance.waiting_state and
           (saga_instance.waiting_state.event_type == event_type or
            saga_instance.waiting_state.success_event_type == event_type) then
            if matcher(event_data, saga_instance.waiting_state.context) then
                local continuation_handler = saga_instance.waiting_state.continuation_handler
                saga_instance.waiting_state = nil
                if continuation_handler then
                    -- Call with proper parameters: saga_id, context, event_type, event_data, msg
                    continuation_handler(saga_id, saga_instance.context, event_type, event_data, {})
                end
            end
        end
    end
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
            amount = amount
        })
    end
)

Handlers.add(
    "nft_deposit_listener",
    function(msg)
        -- Simple debug: just log that we received a message
        print("NFT_DEPOSIT_LISTENER: Received message with Action=" .. tostring(msg.Action))

        local has_action = msg.Action == "Credit-Notice"
        local has_token_id = msg.TokenId or msg.Tokenid or (msg.Tags and (msg.Tags.TokenId or msg.Tags.Tokenid))

        if has_action and has_token_id then
            print("NFT_DEPOSIT_LISTENER: MATCHED Credit-Notice with TokenId!")
            return true
        else
            print("NFT_DEPOSIT_LISTENER: No match - Action='" .. tostring(msg.Action) .. "', has_token_id=" .. tostring(has_token_id))
            return false
        end
    end,
    function(msg, env)
        local token_id = msg.TokenId or msg.Tokenid or (msg.Tags and (msg.Tags.TokenId or msg.Tags.Tokenid))
        local sender = msg.Sender or (msg.Tags and msg.Tags.Sender) or "unknown"
        print("🎯 NFT_DEPOSIT_LISTENER: Credit-Notice received!")
        print("   TokenId: " .. tostring(token_id))
        print("   Sender: " .. tostring(sender))
        print("   Action: " .. tostring(msg.Action))
        print("   All msg fields: " .. require('json').encode(msg))

        -- Find matching escrow and trigger NftDeposited event
        for escrow_id, escrow in pairs(NftEscrowTable) do
            if (escrow.token_id == token_id or escrow.TokenId == token_id) and (escrow.status == "PENDING" or escrow.status == "PAYMENT_LINKED") then
                print("DEBUG: Found matching escrow " .. escrow_id .. ", triggering NftDeposited event")

                -- Update escrow status
                escrow.status = "NFT_DEPOSITED"
                escrow.seller_address = sender

                -- Trigger NftDeposited event for Saga
                trigger_waiting_saga_event("NftDeposited", {
                    escrowId = escrow_id,
                    tokenId = token_id,
                    seller = sender
                })

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
