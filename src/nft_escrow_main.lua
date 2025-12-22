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
            payer_address = payer,
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

                -- 直接设置Saga等待支付状态（简化实现）
                SagaInstances = SagaInstances or {}
                local saga_id = "saga_" .. escrow_id
                SagaInstances[saga_id] = {
                    id = saga_id,
                    escrowId = escrow_id,
                    current_step = "WaitForPayment",
                    completed = false,
                    context = {
                        EscrowId = escrow_id,
                        NftContract = escrow.nftContract or escrow.nft_contract,
                        TokenId = token_id,
                        TokenContract = escrow.tokenContract or escrow.token_contract,
                        Price = escrow.price,
                        SellerAddress = sender
                    },
                    waiting_state = {
                        event_type = "EscrowPaymentUsed",
                        context = {EscrowId = escrow_id},
                        continuation_handler = function(event_data, context)
                            -- 执行NFT转移
                            local nft_proxy = require("nft_transfer_proxy")
                            local result = nft_proxy.transfer({
                                from = ao.id,
                                to = event_data.buyerAddress,
                                nft_contract = context.NftContract,
                                token_id = context.TokenId,
                                escrow_id = context.EscrowId
                            })

                            SagaInstances[saga_id].current_step = "WaitForNftTransferConfirmation"
                            SagaInstances[saga_id].waiting_state = {
                                event_type = "NftTransferredToBuyer",
                                context = {EscrowId = context.EscrowId},
                                continuation_handler = function(event_data, context)
                                    -- 执行资金转移
                                    local token_proxy = require("token_transfer_proxy")
                                    local funds_result = token_proxy.transfer({
                                        token_contract = context.TokenContract,
                                        recipient = context.SellerAddress,
                                        amount = context.Price,
                                        escrow_id = context.EscrowId
                                    })

                                    SagaInstances[saga_id].completed = true
                                    SagaInstances[saga_id].current_step = "COMPLETED"
                                end
                            }
                        end
                    }
                }

                break
            end
            end
    end
)




