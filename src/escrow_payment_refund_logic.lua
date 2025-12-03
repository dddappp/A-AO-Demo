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
    --- TODO: Update the current state with the event properties then return it
    -- state.{STATE_PROPERTY} = event.{EVENT_PROPERTY}
    -- return state
    --
    --- Alternatively, you can choose to return a recreated state:
    --[[
    return escrow_payment.new(
        payer_address, -- type: string
        token_contract, -- type: string
        amount, -- type: bint
        status, -- type: string
        used_by_escrow_id -- type: bint
    )
    ]]
    --- There is some overhead in creating new objects. 
    -- However, this approach does not modify the original state, 
    -- and it is possible that other parts of the code depend on the invariance of the original state - although this is unlikely to happen.
    --
end

return escrow_payment_refund_logic
