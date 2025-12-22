--- Implements the NftEscrow.LinkPayment method.
--
-- @module nft_escrow_link_payment_logic

local nft_escrow = require("nft_escrow")

local nft_escrow_link_payment_logic = {}


--- Verifies the NftEscrow.LinkPayment command.
-- @param _state table The current state of the NftEscrow
-- @param buyer_address string
-- @param payment_id bint
-- @param cmd table The command
-- @param msg any The original message. Properties of an AO msg may include `Timestamp`, `Block-Height`, `Owner`, `Nonce`, etc.
-- @param env table The environment context
-- @return table The event, can use `nft_escrow.new_link_payment_event` to create it
function nft_escrow_link_payment_logic.verify(_state, buyer_address, payment_id, cmd, msg, env)
    --- TODO: Before returning the event, we can check the arguments;
    -- if there are illegal arguments, throw error
    -- NOTE: Do not arbitrarily add parameters to functions or fields to structs.

    -- Create a simple event for link_payment
    local event = {
        event_type = "PaymentLinked",
        buyer_address = buyer_address,
        payment_id = payment_id
    }
    return event
end

--- Applies the event to the current state and returns the updated state.
-- @param state table The current state of the NftEscrow
-- @param event table The event
-- @param msg any The original message. Properties of an AO msg may include `Timestamp`, `Block-Height`, `Owner`, `Nonce`, etc.
-- @param env any The environment context
-- @return table The updated state of the NftEscrow
function nft_escrow_link_payment_logic.mutate(state, event, msg, env)
    -- Update the current state with the event properties
    state.buyer_address = event.buyer_address
    state.payment_id = event.payment_id
    return state
end

return nft_escrow_link_payment_logic

