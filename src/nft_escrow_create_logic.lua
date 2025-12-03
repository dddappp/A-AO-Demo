--- Implements the NftEscrow.Create method.
--
-- @module nft_escrow_create_logic

local nft_escrow = require("nft_escrow")

local nft_escrow_create_logic = {}


--- Verifies the NftEscrow.Create command.
-- @param escrow_id bint The EscrowId of the NftEscrow
-- @param seller_address string 
-- @param buyer_address string 
-- @param nft_contract string 
-- @param token_id bint 
-- @param token_contract string 
-- @param price bint 
-- @param payment_id bint 
-- @param escrow_terms string 
-- @param cmd table The command
-- @param msg any The original message. Properties of an AO msg may include `Timestamp`, `Block-Height`, `Owner`, `Nonce`, etc.
-- @param env table The environment context
-- @return table The event, can use `nft_escrow.new_nft_escrow_created` to create it
function nft_escrow_create_logic.verify(escrow_id, seller_address, buyer_address, nft_contract, token_id, token_contract, price, payment_id, escrow_terms, cmd, msg, env)
    return nft_escrow.new_nft_escrow_created(escrow_id, seller_address, buyer_address, nft_contract, token_id, token_contract, price, payment_id, escrow_terms, created_at)
end

--- Creates a new NftEscrow
-- @param event table The event
-- @param msg any The original message. Properties of an AO msg may include `Timestamp`, `Block-Height`, `Owner`, `Nonce`, etc.
-- @param env any The environment context
-- @return table The state of the NftEscrow
function nft_escrow_create_logic.new(event, msg, env)
    return nft_escrow.new(event.escrow_id, event.seller_address, event.buyer_address, event.nft_contract, event.token_id, event.token_contract, event.price, event.payment_id, event.escrow_terms)
end

return nft_escrow_create_logic
