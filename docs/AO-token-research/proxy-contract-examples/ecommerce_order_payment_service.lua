-- ===== 电商订单支付服务 =====
-- 业务场景：用户在AO电商平台购买商品的完整支付流程
-- 采用现实的"前端支付确认"模式，而非自动扣款
--
-- 📋 典型的用户旅程：
-- 1. 用户浏览商品，选择心仪的商品
-- 2. 添加到购物车，确认数量和规格
-- 3. 提交订单，系统生成订单号（如 ORDER_20241201_001），状态设为"待支付"
-- 4. 用户点击"立即支付"，前端跳转到支付确认页面
-- 5. 前端唤起钱包插件，用户手动确认Token转账给平台账户
-- 6. 转账完成后，前端发送"支付完成"消息给AO合约
-- 7. AO合约验证支付确实完成，开始执行Saga后续步骤
--
-- 💰 支付成功后的业务流程：
-- 订单状态流转：待支付 → 支付中 → 已支付 → 商家备货 → 已发货 → 确认收货
--
-- ⚠️ 为什么需要Saga模式？
-- 支付确认后流程涉及多个关键步骤，任何一个失败都需要回滚：
--
-- 支付Saga步骤：
-- 1. ✅ 验证用户Token转账确实到达平台账户（通过代理合约查询Token合约）
-- 2. ✅ 更新订单状态为"已支付"
-- 3. ✅ 通知商家开始备货处理
-- 4. ✅ 更新用户积分/优惠券使用状态
--
-- 🚨 如果第2步成功但第3步失败，会导致什么问题？
-- - 订单状态已更新为"已支付"，但商家没收到通知
-- - 商家不知道需要备货，用户可能等不到商品
-- - 系统数据不一致：订单状态更新但商家流程未触发
-- - 用户体验差，可能导致投诉
--
-- 🎯 Saga模式的价值：
-- - 确保支付验证后所有后续步骤要么全部成功，要么全部回滚
-- - 即使在分布式异步消息环境中也能保证最终一致性
-- - 提供完善的补偿机制，失败时能自动恢复到正确状态
--
-- 💡 关键设计：不自动扣款，而是验证前端支付结果
-- - 前端负责实际的Token转账（用户手动确认）
-- - AO合约只负责验证转账结果并执行后续业务逻辑
-- - 这样既安全又符合Web3用户习惯
--
-- 💡 为什么选择Token转账作为Saga第一步？
-- - Token转账是整个支付流程中最关键、最不可逆的一步
-- - 一旦转账成功，钱就从用户账户转出，这是不可逆的
-- - 如果后续步骤失败，必须通过补偿机制退款
-- - 这是一个完美的Saga使用场景

local json = require("json")
local messaging = require("messaging")
local saga = require("saga")
local saga_messaging = require("saga_messaging")
local token_transfer_proxy = require("token_transfer_proxy")

local ecommerce_payment_service = {}

-- ===== 配置 =====
ecommerce_payment_service.config = {
    platform_address = "PLATFORM_PAYMENT_CONTRACT_ID", -- 平台支付接收合约地址
    payment_reception_contract_address = "PAYMENT_RECEPTION_CONTRACT_ID", -- 支付接收合约地址
    saga_contract_address = "ECOMMERCE_SAGA_CONTRACT_ID", -- 这个Saga合约自己的地址
    token_contract_id = "0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc" -- AO官方Token合约
}

local ERRORS = {
    INVALID_MESSAGE = "INVALID_MESSAGE",
    COMPENSATION_FAILED = "COMPENSATION_FAILED",
    PAYMENT_FAILED = "PAYMENT_FAILED",
    INVALID_ORDER = "INVALID_ORDER",
    INSUFFICIENT_BALANCE = "INSUFFICIENT_BALANCE"
}

local ACTIONS = {
    -- 主流程动作
    REGISTER_PAYMENT_INTENT = "EcommerceOrderPayment_RegisterPaymentIntent",

    -- 支付接收合约通知动作
    PAYMENT_RECEIVED = "EcommerceOrderPayment_PaymentReceived",

    -- 回调动作
    PROCESS_ORDER_PAYMENT_TRANSFER_CALLBACK = "EcommerceOrderPayment_ProcessOrderPayment_Transfer_Callback",
    PROCESS_ORDER_PAYMENT_UPDATE_ORDER_CALLBACK = "EcommerceOrderPayment_ProcessOrderPayment_UpdateOrder_Callback",
    PROCESS_ORDER_PAYMENT_NOTIFY_MERCHANT_CALLBACK = "EcommerceOrderPayment_ProcessOrderPayment_NotifyMerchant_Callback",
    PROCESS_ORDER_PAYMENT_UPDATE_USER_POINTS_CALLBACK = "EcommerceOrderPayment_ProcessOrderPayment_UpdateUserPoints_Callback",

    -- 补偿动作
    PROCESS_ORDER_PAYMENT_COMPENSATION_CALLBACK = "EcommerceOrderPayment_ProcessOrderPayment_Compensation_Callback"
}

-- 注册代理合约
saga_messaging.register_proxy_contract("token_transfer", token_transfer_proxy)

-- ===== 核心业务逻辑：创建订单，等待支付 =====
function ecommerce_payment_service.create_order(msg, env, response)
    -- 📋 解析订单创建请求
    local cmd
    local decode_success, decode_result = pcall(function()
        return json.decode(msg.Data)
    end)

    if not decode_success then
        messaging.respond(false, "INVALID_JSON_DATA: " .. decode_result, msg)
        return
    end
    cmd = decode_result

    -- 🛡️ 验证订单参数
    if not cmd.customer_id or not cmd.product_items or not cmd.total_amount then
        messaging.respond(false, "MISSING_REQUIRED_PARAMETERS", msg)
        return
    end

    if cmd.total_amount <= 0 then
        messaging.respond(false, "INVALID_ORDER_AMOUNT", msg)
        return
    end

    -- 📦 生成订单信息
    local order_id = string.format("ORDER_%s_%03d",
        os.date("%Y%m%d"), math.random(1, 999))

    local context = {
        -- 订单信息
        order_id = order_id,
        order_details = cmd,

        -- 客户信息
        customer_id = cmd.customer_id,
        customer_address = cmd.customer_address or msg.From,

        -- 支付信息
        platform_address = cmd.platform_address or "PLATFORM_WALLET_ADDRESS", -- 平台收款地址
        expected_amount = cmd.total_amount,
        payment_method = "ao_token",

        -- 业务信息
        merchant_id = cmd.merchant_id,
        product_items = cmd.product_items,

        -- 系统信息
        order_created_timestamp = os.time(),
        order_status = "pending_payment", -- 待支付
        request_from = msg.From,

        -- Saga控制信息（支付确认后创建）
        payment_saga_created = false
    }

    -- 💾 持久化订单信息（在实际实现中，这里会保存到状态存储）
    -- 这里模拟保存订单
    print(string.format("[EcommerceOrder] Created order %s for customer %s, amount: %s",
        order_id, context.customer_id, context.expected_amount))

    -- 📤 返回订单信息给前端
    messaging.respond(true, {
        order_id = order_id,
        status = "pending_payment",
        expected_amount = context.expected_amount,
        platform_address = context.platform_address,
        payment_instructions = {
            method = "ao_token",
            recipient = context.platform_address,
            amount = context.expected_amount,
            memo = string.format("Order Payment: %s", order_id)
        }
    }, msg)
end

-- ===== 核心业务逻辑：注册支付意向 =====
function ecommerce_payment_service.register_payment_intent(msg, env, response)
    -- 📋 解析支付意向请求（前端发送）
    local cmd
    local decode_success, decode_result = pcall(function()
        return json.decode(msg.Data)
    end)

    if not decode_success then
        messaging.respond(false, "INVALID_JSON_DATA: " .. decode_result, msg)
        return
    end
    cmd = decode_result

    -- 🛡️ 验证支付意向参数
    if not cmd.order_id or not cmd.expected_amount or not cmd.customer_address then
        messaging.respond(false, "MISSING_PAYMENT_INTENT_PARAMETERS", msg)
        return
    end

    -- 🔍 查找订单信息并验证
    local order_info = ecommerce_payment_service.get_order_info(cmd.order_id)
    if not order_info then
        messaging.respond(false, "ORDER_NOT_FOUND", msg)
        return
    end

    -- 验证请求者身份
    if msg.From ~= order_info.customer_address then
        messaging.respond(false, "UNAUTHORIZED_REQUESTER", msg)
        return
    end

    -- 验证金额匹配
    if cmd.expected_amount ~= order_info.total_amount then
        messaging.respond(false, "AMOUNT_MISMATCH", msg)
        return
    end

    -- 🎯 创建订单支付Saga实例
    -- Saga起点：注册支付意向后启动，等待支付接收合约的通知
    -- 为什么需要3个步骤？（支付验证已由支付接收合约自动化处理）
    -- 1. 更新订单状态为已支付
    -- 2. 通知商家开始备货
    -- 3. 更新用户积分（奖励消费行为）
    local context = {
        order_id = cmd.order_id,
        customer_id = order_info.customer_id,
        customer_address = cmd.customer_address,
        platform_address = order_info.platform_address,
        expected_amount = cmd.expected_amount,
        payment_registered_at = os.time(),
        request_from = msg.From,

        -- Saga控制信息
        saga_steps = {
            { name = "update_order_status", completed = false },
            { name = "notify_merchant", completed = false },
            { name = "update_user_points", completed = false }
        }
    }

    local saga_instance, saga_commit = saga.create_saga_instance(
        "ECOMMERCE_ORDER_PAYMENT_SAGA",  -- Saga类型标识符
        ecommerce_payment_service.config.platform_address, -- 平台支付接收合约地址
        {
            Action = "PaymentReceived",  -- 等待支付接收合约的通知
        },
        context,
        {
            from = msg.From,
            response_action = msg.Tags[messaging.X_TAGS.RESPONSE_ACTION],
            no_response_required = msg.Tags[messaging.X_TAGS.NO_RESPONSE_REQUIRED]
        },
        3  -- 预留3个本地步骤（更新订单、通知商家、更新积分）
    )

    -- 🚀 向支付接收合约注册支付意向
    -- 支付接收合约会监听Credit-Notice消息并自动验证支付
    messaging.commit_send_or_error(true, {
        order_id = cmd.order_id,
        expected_amount = cmd.expected_amount,
        customer_address = cmd.customer_address,
        saga_contract_address = ecommerce_payment_service.config.saga_contract_address,
        saga_id = saga_instance.saga_id  -- 🔑 关键：传递saga_id给支付接收合约
    }, saga_commit,
        ecommerce_payment_service.config.payment_reception_contract_address, {
            Action = "PaymentReception_RegisterPaymentIntent"
        })

    print(string.format("[EcommercePayment] Registered payment intent for order %s, waiting for payment",
        cmd.order_id))
end

-- ===== 处理支付接收合约的通知 =====
function ecommerce_payment_service.handle_payment_received(msg, env, response)
    local saga_id = tonumber(msg.Tags["X-SagaId"])
    local saga_instance = saga.get_saga_instance_copy(saga_id)

    -- 解析支付验证结果
    local payment_data = json.decode(msg.Data or "{}")

    if not payment_data.verified then
        -- 支付验证失败，终止Saga
        local commit = saga.rollback_saga_instance(saga_id, 0, nil, nil, saga_instance.context, "PAYMENT_VERIFICATION_FAILED")
        commit()
        return
    end

    -- ✅ 支付验证成功，继续Saga流程
    saga_instance.context.payment_verified = true
    saga_instance.context.payment_details = payment_data.payment_details

    print(string.format("[EcommercePayment] Payment verified for saga %s, proceeding with business logic", saga_id))

    -- 🚀 执行第一个Saga步骤：更新订单状态
    local commit = ecommerce_payment_service.update_order_status(saga_instance)
    commit()
end

-- ⚠️ 注意：支付验证已移至支付接收合约
-- 这里不再需要前端验证函数

-- 🔍 辅助函数：获取订单信息
function ecommerce_payment_service.get_order_info(order_id)
    -- 在实际实现中，这里会从持久化存储中查询订单
    -- 这里是模拟实现
    return {
        order_id = order_id,
        customer_id = "CUSTOMER_123",
        customer_address = "CUSTOMER_WALLET_ADDRESS",
        platform_address = "PLATFORM_WALLET_ADDRESS",
        total_amount = 100,
        status = "pending_payment",
        created_timestamp = os.time() - 3600  -- 1小时前创建
    }
end

-- ===== 步骤1回调：处理支付验证结果 =====
function ecommerce_payment_service.process_order_payment_transfer_callback(msg, env, response)
    local saga_id = tonumber(msg.Tags[messaging.X_TAGS.SAGA_ID])
    local saga_instance = saga.get_saga_instance_copy(saga_id)

    if saga_instance.current_step ~= 1 or saga_instance.compensating then
        error(ERRORS.INVALID_MESSAGE)
    end

    local context = saga_instance.context
    local data = json.decode(msg.Data)

    if data.error then
        -- ❌ 支付验证失败：说明前端上报的交易可能有问题
        print(string.format("[EcommercePayment] Payment verification failed for order %s: %s",
            context.order_id, data.error))

        -- 执行Saga回滚（支付验证失败，无需退款，因为钱还没收到）
        local rollback_commit = saga.rollback_saga_instance(saga_id, 1, nil, nil, context, data.error)
        rollback_commit()

        -- 通知用户支付验证失败
        messaging.process_operation_result(false, {
            error = "PAYMENT_VERIFICATION_FAILED",
            reason = data.error,
            order_id = context.order_id,
            transaction_id = context.transaction_id
        }, function() end, saga_instance.original_message)

        return
    end

    -- ✅ 支付验证成功：确认Token确实到达平台账户
    print(string.format("[EcommercePayment] Payment verified for order %s, amount: %s",
        context.order_id, context.expected_amount))

    -- 标记第一步完成
    context.saga_steps[1].completed = true
    context.verification_timestamp = os.time()

    -- 🚀 推进Saga到下一步：更新订单状态
    local next_step_commit = saga.move_saga_instance_forward(saga_id, {
        step_name = "update_order_status",
        verification_timestamp = context.verification_timestamp,
        payment_confirmed = true
    }, context)

    -- 模拟调用订单服务更新状态（在实际应用中这会是异步消息调用）
    -- 这里为了演示，我们直接"模拟"成功
    local function simulate_order_update()
        print(string.format("[EcommercePayment] Order %s status updated to PAID", context.order_id))
        context.saga_steps[2].completed = true
        return true
    end

    if simulate_order_update() then
        next_step_commit()
        -- 继续下一步：通知商家
        ecommerce_payment_service.continue_payment_saga(saga_id, 3)
    else
        -- 订单更新失败，回滚整个流程
        ecommerce_payment_service.rollback_payment_saga(saga_id, "ORDER_UPDATE_FAILED")
    end
end

-- ===== 继续Saga流程的辅助函数 =====
function ecommerce_payment_service.continue_payment_saga(saga_id, step_number)
    local saga_instance = saga.get_saga_instance_copy(saga_id)
    local context = saga_instance.context

    if step_number == 3 then
        -- 📢 步骤3：通知商家
        print(string.format("[EcommercePayment] Notifying merchant for order %s", context.order_id))

        local notify_commit = saga.move_saga_instance_forward(saga_id, {
            step_name = "notify_merchant",
            notification_timestamp = os.time()
        }, context)

        -- 模拟通知商家（实际会发送消息给商家服务）
        local function simulate_merchant_notification()
            print(string.format("[EcommercePayment] Merchant %s notified for order %s",
                context.merchant_id, context.order_id))
            context.saga_steps[3].completed = true
            return true
        end

        if simulate_merchant_notification() then
            notify_commit()
            -- 继续最后一步：更新用户积分
            ecommerce_payment_service.continue_payment_saga(saga_id, 4)
        else
            ecommerce_payment_service.rollback_payment_saga(saga_id, "MERCHANT_NOTIFICATION_FAILED")
        end

    elseif step_number == 4 then
        -- 🎁 步骤4：更新用户积分
        print(string.format("[EcommercePayment] Updating user points for customer %s", context.customer_id))

        local points_commit = saga.complete_saga_instance(saga_id, {
            status = "payment_completed",
            order_id = context.order_id,
            transaction_id = context.transaction_id,
            total_amount = context.amount,
            completion_timestamp = os.time(),
            all_steps_completed = true
        }, context)

        -- 模拟更新用户积分
        local function simulate_points_update()
            local bonus_points = math.floor(context.amount / 10) -- 每消费10个Token获得1积分
            print(string.format("[EcommercePayment] Added %d points to customer %s",
                bonus_points, context.customer_id))
            context.saga_steps[4].completed = true
            return true
        end

        if simulate_points_update() then
            points_commit()

            -- 🎉 支付流程完全成功！
            messaging.process_operation_result(true, {
                status = "PAYMENT_COMPLETED",
                order_id = context.order_id,
                transaction_id = context.transaction_id,
                amount = context.amount,
                bonus_points = math.floor(context.amount / 10),
                completion_timestamp = os.time()
            }, function() end, saga_instance.original_message)

            print(string.format("[EcommercePayment] Payment completed successfully for order %s!",
                context.order_id))

        else
            ecommerce_payment_service.rollback_payment_saga(saga_id, "POINTS_UPDATE_FAILED")
        end
    end
end

-- ===== 回滚Saga的辅助函数 =====
function ecommerce_payment_service.rollback_payment_saga(saga_id, reason)
    local saga_instance = saga.get_saga_instance_copy(saga_id)
    local context = saga_instance.context

    print(string.format("[EcommercePayment] Rolling back payment for order %s, reason: %s",
        context.order_id, reason))

    -- 根据失败阶段决定是否需要退款
    local need_refund = false
    local refund_amount = 0

    if saga_instance.current_step >= 2 then
        -- 如果已经过了支付验证步骤，说明钱已经确认到达平台，需要退款
        need_refund = true
        refund_amount = context.expected_amount
    end
    -- 如果只在支付验证步骤失败，说明钱还没收到，无需退款

    local refund_func = nil
    if need_refund then
        -- 执行补偿：退款
        local compensation_config = {
            type = "refund_tokens",
            proxy_contract = "token_transfer",
            compensation_data = {
                original_sender = context.customer_address, -- 退款给客户
                quantity = refund_amount,
                reason = reason
            }
        }
        refund_func = saga_messaging.get_proxy_compensation_function(
            saga_instance, compensation_config, reason)
    end

    -- Saga回滚
    local rollback_commit = saga.rollback_saga_instance(saga_id, saga_instance.current_step, nil, nil, context, reason)

    -- 原子性执行回滚
    local function execute_full_rollback()
        if refund_func then refund_func() end
        rollback_commit()
    end
    execute_full_rollback()

    -- 通知支付失败
    messaging.process_operation_result(false, {
        error = "PAYMENT_FAILED",
        reason = reason,
        order_id = context.order_id,
        amount = context.expected_amount,
        refund_needed = need_refund,
        refund_amount = refund_amount,
        rollback_timestamp = os.time()
    }, function() end, saga_instance.original_message)
end

-- ===== 查询支付状态 =====
function ecommerce_payment_service.get_payment_status(msg, env, response)
    local order_id = msg.Tags.OrderId

    if not order_id then
        messaging.respond(false, "MISSING_ORDER_ID", msg)
        return
    end

    -- 在实际应用中，这里会查询Saga实例状态
    -- 为了演示，返回模拟状态
    messaging.respond(true, {
        order_id = order_id,
        status = "completed", -- 或 "processing", "failed", "refunded"
        transaction_id = "TX_20241201_001",
        amount = 100,
        timestamp = os.time(),
        details = {
            transfer_completed = true,
            order_updated = true,
            merchant_notified = true,
            points_updated = true
        }
    }, msg)
end

-- ===== 处理器注册 =====

-- 注册支付意向处理器
Handlers.add(
    "ecommerce_register_payment_intent",
    Handlers.utils.hasMatchingTag("Action", "RegisterPaymentIntent"),
    function(msg) ecommerce_payment_service.register_payment_intent(msg) end
)

-- 注册支付接收通知处理器
Handlers.add(
    "ecommerce_payment_received",
    Handlers.utils.hasMatchingTag("Action", "PaymentReceived"),
    function(msg) ecommerce_payment_service.handle_payment_received(msg) end
)

-- 注册其他Saga步骤回调处理器
Handlers.add(
    "ecommerce_update_order_callback",
    Handlers.utils.hasMatchingTag("Action", ACTIONS.PROCESS_ORDER_PAYMENT_UPDATE_ORDER_CALLBACK),
    function(msg) ecommerce_payment_service.process_order_payment_update_order_callback(msg) end
)

Handlers.add(
    "ecommerce_notify_merchant_callback",
    Handlers.utils.hasMatchingTag("Action", ACTIONS.PROCESS_ORDER_PAYMENT_NOTIFY_MERCHANT_CALLBACK),
    function(msg) ecommerce_payment_service.process_order_payment_notify_merchant_callback(msg) end
)

Handlers.add(
    "ecommerce_update_user_points_callback",
    Handlers.utils.hasMatchingTag("Action", ACTIONS.PROCESS_ORDER_PAYMENT_UPDATE_USER_POINTS_CALLBACK),
    function(msg) ecommerce_payment_service.process_order_payment_update_user_points_callback(msg) end
)

return ecommerce_payment_service
