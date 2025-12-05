--- Implements the EscrowPayment.Refund method.
--
-- @module escrow_payment_refund_logic

local escrow_payment = require("escrow_payment")

local escrow_payment_refund_logic = {}


--- Verifies the EscrowPayment.Refund command.
-- @param _state table The current state of the EscrowPayment
-- @param cmd table The command
-- @param msg any The original message. Properties of an AO msg may include `Timestamp`, `Block-Height`, `Owner`, `Nonce`, etc.
-- @param env table The environment context
-- @return table The event, can use `escrow_payment.new_refund_event` to create it
function escrow_payment_refund_logic.verify(_state, cmd, msg, env)
    --- TODO: Before returning the event, we can check the arguments; 
    -- if there are illegal arguments, throw error
    -- NOTE: Do not arbitrarily add parameters to functions or fields to structs.
    return escrow_payment.new_refund_event(
        _state -- type: table
    )
end

--- Applies the event to the current state and returns the updated state.
-- @param state table The current state of the EscrowPayment
-- @param event table The event
-- @param msg any The original message. Properties of an AO msg may include `Timestamp`, `Block-Height`, `Owner`, `Nonce`, etc.
-- @param env any The environment context
-- @return table The updated state of the EscrowPayment
function escrow_payment_refund_logic.mutate(state, event, msg, env)
    -- Update the current state with the event properties
    state.status = "REFUNDED"
    return state
end

return escrow_payment_refund_logic
