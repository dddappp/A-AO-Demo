-- AO Legacy Token Blueprint (compatible with legacy network)
-- Based on official AO Token Blueprint but adapted for legacy network compatibility
-- Source: https://ao_docs.ar.io/guides/aos/blueprints/token.html
-- Adapted for legacy network: uses Send() instead of ao.send(), simplified handlers

-- Initialize state (following official blueprint)
Balances = Balances or { [ao.id] = tostring(bint(10000 * 1e12)) }  -- 10000 tokens with 12 decimals
Name = Name or 'Points Coin'
Ticker = Ticker or 'PNTS'
Denomination = Denomination or 12
Logo = Logo or 'SBCCXwwecBlDqRLUjb8dYABExTJXLieawf7m2aBJ-KY'

-- Info handler
Handlers.add(
    "info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        Send({
            Target = msg.From,
            Action = "Info-Response",
            Name = Name,
            Ticker = Ticker,
            Logo = Logo,
            Denomination = tostring(Denomination)
        })
    end
)

-- Balance handler
Handlers.add(
    "balance",
    Handlers.utils.hasMatchingTag("Action", "Balance"),
    function(msg)
        local bal = '0'

        -- If not Target is provided, then return the Senders balance
        if (msg.Tags.Target and Balances[msg.Tags.Target]) then
            bal = Balances[msg.Tags.Target]
        elseif Balances[msg.From] then
            bal = Balances[msg.From]
        end

        Send({
            Target = msg.From,
            Action = "Balance-Response",
            Balance = bal,
            Ticker = Ticker,
            Account = msg.Tags.Target or msg.From,
            Data = bal
        })
    end
)

-- Balances handler
Handlers.add(
    "balances",
    Handlers.utils.hasMatchingTag("Action", "Balances"),
    function(msg)
        Send({
            Target = msg.From,
            Action = "Balances-Response",
            Data = json.encode(Balances)
        })
    end
)

-- Transfer handler
Handlers.add(
    "transfer",
    Handlers.utils.hasMatchingTag("Action", "Transfer"),
    function(msg)
        assert(type(msg.Tags.Recipient) == 'string', 'Recipient is required!')
        assert(type(msg.Tags.Quantity) == 'string', 'Quantity is required!')
        assert(bint.__lt(0, bint(msg.Tags.Quantity)), 'Quantity must be greater than 0')

        if not Balances[msg.From] then Balances[msg.From] = "0" end
        if not Balances[msg.Tags.Recipient] then Balances[msg.Tags.Recipient] = "0" end

        local qty = bint(msg.Tags.Quantity)
        local balance = bint(Balances[msg.From])

        if bint.__le(qty, balance) then
            Balances[msg.From] = tostring(bint.__sub(balance, qty))
            Balances[msg.Tags.Recipient] = tostring(bint.__add(bint(Balances[msg.Tags.Recipient]), qty))

            -- Send Debit-Notice to the Sender
            Send({
                Target = msg.From,
                Action = 'Debit-Notice',
                Recipient = msg.Tags.Recipient,
                Quantity = tostring(qty)
            })

            -- Send Credit-Notice to the Recipient
            Send({
                Target = msg.Tags.Recipient,
                Action = 'Credit-Notice',
                Sender = msg.From,
                Quantity = tostring(qty)
            })
        else
            Send({
                Target = msg.From,
                Action = 'Transfer-Error',
                ['Message-Id'] = msg.Id,
                Error = 'Insufficient Balance!'
            })
        end
    end
)

-- Mint handler
Handlers.add(
    "mint",
    Handlers.utils.hasMatchingTag("Action", "Mint"),
    function(msg)
        assert(type(msg.Tags.Quantity) == 'string', 'Quantity is required!')
        assert(bint.__lt(0, bint(msg.Tags.Quantity)), 'Quantity must be greater than zero!')

        if not Balances[ao.id] then Balances[ao.id] = "0" end

        if msg.From == ao.id then
            -- Add tokens to the token pool, according to Quantity
            Balances[ao.id] = tostring(bint.__add(bint(Balances[ao.id]), bint(msg.Tags.Quantity)))
            Send({
                Target = msg.From,
                Action = "Mint-Confirmation",
                Data = "Successfully minted " .. msg.Tags.Quantity .. " tokens"
            })
        else
            Send({
                Target = msg.From,
                Action = 'Mint-Error',
                ['Message-Id'] = msg.Id,
                Error = 'Only the Process Owner can mint new ' .. Ticker .. ' tokens!'
            })
        end
    end
)

-- Burn handler (added for completeness)
Handlers.add(
    "burn",
    Handlers.utils.hasMatchingTag("Action", "Burn"),
    function(msg)
        assert(type(msg.Tags.Quantity) == 'string', 'Quantity is required!')
        assert(bint.__lt(0, bint(msg.Tags.Quantity)), 'Quantity must be greater than zero!')

        if not Balances[msg.From] then Balances[msg.From] = "0" end

        local qty = bint(msg.Tags.Quantity)
        local balance = bint(Balances[msg.From])

        if bint.__le(qty, balance) then
            Balances[msg.From] = tostring(bint.__sub(balance, qty))
            Send({
                Target = msg.From,
                Action = "Burn-Success",
                Quantity = tostring(qty),
                Data = "Successfully burned " .. tostring(qty) .. " tokens"
            })
        else
            Send({
                Target = msg.From,
                Action = 'Burn-Error',
                ['Message-Id'] = msg.Id,
                Error = 'Insufficient Balance to burn!'
            })
        end
    end
)

-- Total Supply handler (added for completeness)
Handlers.add(
    "total_supply",
    Handlers.utils.hasMatchingTag("Action", "Total-Supply"),
    function(msg)
        local total = bint(0)
        for address, balance in pairs(Balances) do
            total = bint.__add(total, bint(balance))
        end

        Send({
            Target = msg.From,
            Action = "Total-Supply-Response",
            ["Total-Supply"] = tostring(total),
            Ticker = Ticker
        })
    end
)