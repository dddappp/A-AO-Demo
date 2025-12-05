--- Implements the EscrowPayment.Create method.
--
-- @module escrow_payment_create_logic

local escrow_payment = require("escrow_payment")

local escrow_payment_create_logic = {}


--- Verifies the EscrowPayment.Create command.
-- @param payment_id bint The PaymentId of the EscrowPayment
-- @param payer_address string 
-- @param token_contract string 
-- @param amount bint 
-- @param status string 
-- @param used_by_escrow_id bint 
-- @param cmd table The command
-- @param msg any The original message. Properties of an AO msg may include `Timestamp`, `Block-Height`, `Owner`, `Nonce`, etc.
-- @param env table The environment context
-- @return table The event, can use `escrow_payment.new_escrow_payment_created` to create it
function escrow_payment_create_logic.verify(payment_id, payer_address, token_contract, amount, status, used_by_escrow_id, cmd, msg, env)
    return escrow_payment.new_escrow_payment_created(payment_id, payer_address, token_contract, amount, status, used_by_escrow_id, msg.Timestamp)
end

--- Creates a new EscrowPayment
-- @param event table The event
-- @param msg any The original message. Properties of an AO msg may include `Timestamp`, `Block-Height`, `Owner`, `Nonce`, etc.
-- @param env any The environment context
-- @return table The state of the EscrowPayment
function escrow_payment_create_logic.new(event, msg, env)
    return escrow_payment.new(event.payer_address, event.token_contract, event.amount, event.status, event.used_by_escrow_id)
end

return escrow_payment_create_logic
