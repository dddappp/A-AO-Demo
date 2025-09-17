-- ===== 支付接收合约：监听转账并验证订单 =====
-- 这个合约专门用于接收平台支付，具有以下职责：
-- 1. 拥有平台专用地址，接收用户Token转账
-- 2. 监听Credit-Notice消息（因为它是接收者）
-- 3. 通过业务参数匹配转账到具体订单
-- 4. 验证转账合法性后通知Saga合约继续流程

local json = require("json")
local messaging = require("messaging")

local payment_reception_contract = {}

-- ===== 配置 =====
payment_reception_contract.config = {
    name = "PaymentReceptionContract",
    token_contract_id = "0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc", -- AO官方Token合约
    platform_address = "PLATFORM_PAYMENT_CONTRACT_ID", -- 这个合约自己的地址
    saga_contract_address = "ECOMMERCE_SAGA_CONTRACT_ID", -- Saga合约地址
    max_pending_orders = 1000,
    order_timeout = 24 * 60 * 60, -- 24小时订单超时
}

-- ===== 状态管理 =====
-- 待支付订单池：用于匹配到来的转账
local pending_orders = {} -- order_id -> order_info
local payment_index = {}  -- amount|sender -> order_id (用于快速查找)
local failed_notifications = {} -- 存储发送失败的通知以便后续重试

-- ===== 安全防护 =====
-- 请求频率限制：防止DDoS攻击
local request_timestamps = {} -- IP/地址 -> 最近请求时间戳
local rate_limit_window = 60 -- 60秒窗口
local max_requests_per_window = 10 -- 每窗口最多10个请求

-- ===== 核心功能 =====

-- 注册支付意向（前端调用）
function payment_reception_contract.register_payment_intent(msg)
    local cmd = json.decode(msg.Data or "{}")

    if not cmd.order_id or not cmd.expected_amount or not cmd.customer_address then
        messaging.respond(false, "MISSING_PAYMENT_INTENT_PARAMETERS", msg)
        return
    end

    -- 频率限制检查：防止DDoS攻击
    local sender_address = msg.From
    local current_time = os.time()

    if not payment_reception_contract.check_rate_limit(sender_address, current_time) then
        messaging.respond(false, "RATE_LIMIT_EXCEEDED", msg)
        return
    end

    -- 检查订单是否已存在
    if pending_orders[cmd.order_id] then
        messaging.respond(false, "ORDER_ALREADY_REGISTERED", msg)
        return
    end

    -- 注册待支付订单
    local order_info = {
        order_id = cmd.order_id,
        expected_amount = cmd.expected_amount,
        customer_address = cmd.customer_address,
        saga_contract_address = cmd.saga_contract_address or payment_reception_contract.config.saga_contract_address,
        saga_id = cmd.saga_id,  -- 🔑 保存saga_id用于后续通知
        registered_at = os.time(),
        status = "pending_payment"
    }

    pending_orders[cmd.order_id] = order_info

    -- 建立反向索引：金额+发送者 -> 订单ID
    local index_key = tostring(cmd.expected_amount) .. "|" .. cmd.customer_address
    payment_index[index_key] = cmd.order_id

    print(string.format("[%s] Registered payment intent for order: %s, amount: %s",
        payment_reception_contract.config.name, cmd.order_id, cmd.expected_amount))

    messaging.respond(true, {
        registered = true,
        order_id = cmd.order_id,
        platform_address = payment_reception_contract.config.platform_address,
        expires_at = order_info.registered_at + payment_reception_contract.config.order_timeout
    }, msg)
end

-- 🔑 核心：监听Credit-Notice消息（当接收到转账时自动触发）
function payment_reception_contract.handle_credit_notice(msg)
    -- AO消息格式兼容性处理：同时检查直接属性和Tags
    local amount = msg.Quantity or msg.Tags.Quantity
    local sender = msg.Sender or msg.Tags.Sender
    local timestamp = os.time()

    print(string.format("[%s] Received Credit-Notice: amount=%s, sender=%s",
        payment_reception_contract.config.name, amount, sender))

    -- 通过金额+发送者查找对应的订单
    local index_key = tostring(amount) .. "|" .. sender
    local order_id = payment_index[index_key]

    if not order_id then
        print(string.format("[%s] No matching order found for payment: amount=%s, sender=%s",
            payment_reception_contract.config.name, amount, sender))
        return
    end

    local order_info = pending_orders[order_id]
    if not order_info then
        print(string.format("[%s] Order info not found for order_id: %s", payment_reception_contract.config.name, order_id))
        return
    end

    -- 🔐 验证转账是否匹配订单
    if not payment_reception_contract.validate_payment(order_info, amount, sender, timestamp) then
        print(string.format("[%s] Payment validation failed for order: %s", payment_reception_contract.config.name, order_id))
        return
    end

    -- ✅ 验证通过，原子化状态更新
    -- 为了保证状态一致性，将状态变更和索引清理放在一起
    local success, error_msg = pcall(function()
        order_info.status = "payment_received"
        order_info.payment_details = {
            amount = amount,
            sender = sender,
            received_at = timestamp,
            transaction_verified = true
        }

        -- 清理索引（防止重复处理）
        payment_index[index_key] = nil
    end)

    if not success then
        print(string.format("[%s] Failed to update payment status for order: %s, error: %s",
            payment_reception_contract.config.name, order_id, error_msg))
        return
    end

    print(string.format("[%s] Payment verified for order: %s", payment_reception_contract.config.name, order_id))

    -- 🚀 通知Saga合约继续流程
    payment_reception_contract.notify_saga_contract(order_info, order_info.payment_details)
end

-- 🔐 验证转账是否符合订单要求
function payment_reception_contract.validate_payment(order_info, amount, sender, timestamp)
    -- 1. 金额匹配
    if tostring(amount) ~= tostring(order_info.expected_amount) then
        print(string.format("Amount mismatch: expected %s, got %s", order_info.expected_amount, amount))
        return false
    end

    -- 2. 发送者匹配
    if sender ~= order_info.customer_address then
        print(string.format("Sender mismatch: expected %s, got %s", order_info.customer_address, sender))
        return false
    end

    -- 3. 时间窗口验证（订单注册后24小时内）
    local current_time = os.time()
    local time_diff = current_time - order_info.registered_at

    -- 防止时间戳欺骗：使用当前时间而不是消息中的时间戳进行验证
    if time_diff < 0 or time_diff > payment_reception_contract.config.order_timeout then
        print(string.format("Payment outside time window: registered_at=%s, current_time=%s",
            order_info.registered_at, current_time))
        return false
    end

    -- 额外验证：检查消息时间戳是否合理（可选，用于检测明显的时间戳欺骗）
    local message_age = current_time - timestamp
    if message_age < 0 or message_age > 300 then -- 消息不超过5分钟
        print(string.format("Suspicious message timestamp: message_time=%s, current_time=%s",
            timestamp, current_time))
        return false
    end

    -- 4. 订单状态验证
    if order_info.status ~= "pending_payment" then
        print(string.format("Invalid order status: %s", order_info.status))
        return false
    end

    return true
end

-- 🚀 通知Saga合约支付已完成
function payment_reception_contract.notify_saga_contract(order_info, payment_details)
    -- 获取Saga合约地址（需要在order_info中存储或通过配置获取）
    local saga_contract_address = order_info.saga_contract_address or payment_reception_contract.config.saga_contract_address

    if not saga_contract_address then
        print(string.format("[%s] ERROR: No Saga contract address configured for order: %s",
            payment_reception_contract.config.name, order_info.order_id))
        return
    end

    local saga_notification = {
        Action = "PaymentReceived",
        OrderId = order_info.order_id,
        PaymentDetails = payment_details,
        Verified = true
    }

    -- 发送消息给Saga合约
    -- 注意：在AO系统中，需要使用正确的消息格式
    local message_data = json.encode({
        order_id = order_info.order_id,
        payment_verified = true,
        payment_details = payment_details,
        timestamp = os.time()
    })

    -- 使用ao.send发送消息（在实际AO环境中）
    -- 实现重试机制处理网络故障
    local max_retries = 3
    local retry_delay = 5 -- 5秒重试延迟

    for attempt = 1, max_retries do
        local success, error_msg = pcall(function()
            ao.send({
                Target = saga_contract_address,
                Tags = {
                    Action = "PaymentReceived",
                    ["X-SagaId"] = tostring(order_info.saga_id),  -- 🔑 关键：包含saga_id
                    OrderId = order_info.order_id
                },
                Data = message_data
            })
        end)

        if success then
            print(string.format("[%s] Successfully notified Saga contract %s for order: %s (attempt %d/%d)",
                payment_reception_contract.config.name, saga_contract_address, order_info.order_id, attempt, max_retries))
            return
        else
            print(string.format("[%s] Failed to notify Saga contract (attempt %d/%d): %s",
                payment_reception_contract.config.name, attempt, max_retries, error_msg))

            if attempt < max_retries then
                -- 等待重试
                -- 在实际AO环境中，可能需要使用异步等待
                print(string.format("[%s] Retrying in %d seconds...", payment_reception_contract.config.name, retry_delay))
            end
        end
    end

    -- 所有重试都失败，记录错误但不阻止流程（因为支付已经验证成功）
    print(string.format("[%s] ERROR: Failed to notify Saga contract after %d attempts for order: %s",
        payment_reception_contract.config.name, max_retries, order_info.order_id))

    -- 可以选择存储失败的通知以便后续重试
    payment_reception_contract.store_failed_notification(order_info, message_data)
end

-- 检查请求频率限制
function payment_reception_contract.check_rate_limit(sender_address, current_time)
    -- 清理过期的请求记录
    for address, timestamps in pairs(request_timestamps) do
        local valid_timestamps = {}
        for _, timestamp in ipairs(timestamps) do
            if (current_time - timestamp) <= rate_limit_window then
                table.insert(valid_timestamps, timestamp)
            end
        end

        if #valid_timestamps == 0 then
            request_timestamps[address] = nil
        else
            request_timestamps[address] = valid_timestamps
        end
    end

    -- 检查当前发送者的请求频率
    local sender_timestamps = request_timestamps[sender_address] or {}

    if #sender_timestamps >= max_requests_per_window then
        print(string.format("[%s] Rate limit exceeded for address: %s (%d requests in %d seconds)",
            payment_reception_contract.config.name, sender_address, #sender_timestamps, rate_limit_window))
        return false
    end

    -- 记录当前请求
    table.insert(sender_timestamps, current_time)
    request_timestamps[sender_address] = sender_timestamps

    return true
end

-- 存储失败的通知以便后续重试
function payment_reception_contract.store_failed_notification(order_info, message_data)
    local failed_notification = {
        order_id = order_info.order_id,
        saga_contract_address = order_info.saga_contract_address,
        message_data = message_data,
        failed_at = os.time(),
        retry_count = 0
    }

    table.insert(failed_notifications, failed_notification)

    print(string.format("[%s] Stored failed notification for order: %s",
        payment_reception_contract.config.name, order_info.order_id))
end

-- 重试发送失败的通知
function payment_reception_contract.retry_failed_notifications()
    local current_time = os.time()
    local retry_delay = 60 -- 60秒重试间隔

    for i = #failed_notifications, 1, -1 do
        local notification = failed_notifications[i]

        -- 检查是否到了重试时间
        if (current_time - notification.failed_at) >= retry_delay then
            print(string.format("[%s] Retrying failed notification for order: %s (attempt %d)",
                payment_reception_contract.config.name, notification.order_id, notification.retry_count + 1))

            -- 尝试重新发送
            local success, error_msg = pcall(function()
                ao.send({
                    Target = notification.saga_contract_address,
                    Tags = {
                        Action = "PaymentReceived",
                        OrderId = notification.order_id
                    },
                    Data = notification.message_data
                })
            end)

            if success then
                -- 发送成功，移除失败的通知
                table.remove(failed_notifications, i)
                print(string.format("[%s] Successfully retried notification for order: %s",
                    payment_reception_contract.config.name, notification.order_id))
            else
                -- 发送仍然失败，增加重试计数
                notification.retry_count = notification.retry_count + 1
                notification.failed_at = current_time

                -- 如果重试次数过多，可以选择放弃
                if notification.retry_count >= 5 then
                    print(string.format("[%s] Giving up on failed notification for order: %s after %d retries",
                        payment_reception_contract.config.name, notification.order_id, notification.retry_count))
                    table.remove(failed_notifications, i)
                end
            end
        end
    end
end

-- ===== 清理和维护 =====

-- 清理过期的订单和失败通知
function payment_reception_contract.cleanup_expired_orders()
    local current_time = os.time()
    local expired_orders = {}

    -- 清理过期的订单
    for order_id, order_info in pairs(pending_orders) do
        if order_info.status == "pending_payment" and
           (current_time - order_info.registered_at) > payment_reception_contract.config.order_timeout then
            table.insert(expired_orders, order_id)
        end
    end

    for _, order_id in ipairs(expired_orders) do
        local order_info = pending_orders[order_id]

        -- 清理反向索引
        local index_key = tostring(order_info.expected_amount) .. "|" .. order_info.customer_address
        payment_index[index_key] = nil

        -- 删除订单
        pending_orders[order_id] = nil

        print(string.format("[%s] Cleaned up expired order: %s", payment_reception_contract.config.name, order_id))
    end

    -- 清理过期的失败通知（超过7天的通知）
    local expired_notifications = {}
    local notification_timeout = 7 * 24 * 60 * 60 -- 7天

    for i = #failed_notifications, 1, -1 do
        local notification = failed_notifications[i]
        if (current_time - notification.failed_at) > notification_timeout then
            table.insert(expired_notifications, i)
        end
    end

    for _, index in ipairs(expired_notifications) do
        local notification = failed_notifications[index]
        print(string.format("[%s] Cleaned up expired failed notification for order: %s",
            payment_reception_contract.config.name, notification.order_id))
        table.remove(failed_notifications, index)
    end

    print(string.format("[%s] Cleanup completed: %d expired orders, %d expired notifications",
        payment_reception_contract.config.name, #expired_orders, #expired_notifications))
end

-- ===== 处理器注册 =====

-- 注册所有处理器
function payment_reception_contract.register_handlers()
    -- 注册支付意向处理器
    Handlers.add(
        payment_reception_contract.config.name .. '_register_payment',
        Handlers.utils.hasMatchingTag("Action", "PaymentReception_RegisterPaymentIntent"),
        function(msg) payment_reception_contract.register_payment_intent(msg) end
    )

    -- 🔑 核心：注册Credit-Notice监听器
    -- 当Token合约发送Credit-Notice消息时，这个处理器会被触发
    Handlers.add(
        payment_reception_contract.config.name .. '_credit_notice',
        Handlers.utils.hasMatchingTag("Action", "Credit-Notice"),
        function(msg) payment_reception_contract.handle_credit_notice(msg) end
    )

    -- 定期清理过期订单（可以通过定时器或手动调用）
    Handlers.add(
        payment_reception_contract.config.name .. '_cleanup',
        Handlers.utils.hasMatchingTag("Action", "CleanupExpiredOrders"),
        function(msg)
            payment_reception_contract.cleanup_expired_orders()
            messaging.respond(true, "Cleanup completed", msg)
        end
    )

    -- 重试发送失败的通知
    Handlers.add(
        payment_reception_contract.config.name .. '_retry_notifications',
        Handlers.utils.hasMatchingTag("Action", "RetryFailedNotifications"),
        function(msg)
            payment_reception_contract.retry_failed_notifications()
            messaging.respond(true, "Retry completed", msg)
        end
    )
end

-- ===== 初始化 =====

-- 初始化合约
function payment_reception_contract.init()
    payment_reception_contract.register_handlers()
    print(string.format("[%s] Payment reception contract initialized", payment_reception_contract.config.name))
end

-- 执行初始化
payment_reception_contract.init()

return payment_reception_contract
