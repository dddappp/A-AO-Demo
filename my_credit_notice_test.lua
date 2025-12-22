-- Simple test process to verify Credit-Notice handler works
print("Simple Credit-Notice Test Process Loaded")

-- Track Credit-Notice events
CreditNoticeEvents = CreditNoticeEvents or {}

Handlers.add(
    "simple_credit_notice_handler",
    Handlers.utils.hasMatchingTag("Action", "Credit-Notice"),
    function(msg, env, response)
        print("SIMPLE CREDIT-NOTICE HANDLER TRIGGERED!")
        print("Message details:")
        print("  Action: " .. tostring(msg.Action))
        print("  From: " .. tostring(msg.From))
        print("  Sender: " .. tostring(msg.Sender))
        print("  Quantity: " .. tostring(msg.Quantity))

        -- Record the event
        table.insert(CreditNoticeEvents, {
            timestamp = msg.Timestamp or os.time(),
            from = msg.From,
            sender = msg.Sender,
            quantity = msg.Quantity,
            action = msg.Action
        })

        print("Credit-Notice processed! Total events: " .. #CreditNoticeEvents)
    end
)

print("Simple Credit-Notice handler registered")
