-- ===== 跨合约库存调整服务 =====
-- 业务场景：纯自动化的跨合约Saga - 盘点库存调整
-- 这个场景展示了传统Saga模式：所有步骤都是程序自动执行，无需人介入
--
-- 📋 业务背景：
-- WMS（仓库管理系统）需要定期进行库存盘点，当发现实际库存与系统记录不一致时，
-- 需要调整库存记录，并同步更新相关的财务和报表系统。
--
-- 🎯 Saga目标：
-- 确保库存调整的原子性：要么全部系统都更新成功，要么全部回滚到初始状态
--
-- 💰 库存调整Saga的4个步骤：
-- 1. ✅ 调用Token合约：扣除库存调整费用（假设调整库存需要支付手续费）
-- 2. ✅ 调用库存合约：更新库存数量
-- 3. ✅ 调用财务合约：记录财务调整
-- 4. ✅ 调用报表合约：更新库存报表
--
-- ⚠️ 为什么需要Saga？
-- 这是一个典型的跨合约分布式事务场景：
-- - 步骤1成功但步骤2失败：用户付了费但库存没调整 ❌
-- - 步骤2成功但步骤3失败：库存调整了但财务记录不匹配 ❌
-- - 步骤3成功但步骤4失败：财务对了但报表没更新 ❌
--
-- Saga的价值：
-- - 确保所有合约状态要么全部更新，要么全部回滚
-- - 即使在AO的异步消息环境中也能保证最终一致性
-- - 自动处理各种异常情况和网络故障

local json = require("json")
local messaging = require("messaging")
local saga = require("saga")
local saga_messaging = require("saga_messaging")
local token_transfer_proxy = require("token_transfer_proxy")

local cross_contract_inventory_service = {}

local ERRORS = {
    INVALID_MESSAGE = "INVALID_MESSAGE",
    ADJUSTMENT_FAILED = "ADJUSTMENT_FAILED"
}

local ACTIONS = {
    PROCESS_INVENTORY_ADJUSTMENT = "CrossContract_InventoryAdjustment",

    -- 回调动作
    PROCESS_INVENTORY_ADJUSTMENT_FEE_CALLBACK = "CrossContract_InventoryAdjustment_Fee_Callback",
    PROCESS_INVENTORY_ADJUSTMENT_STOCK_CALLBACK = "CrossContract_InventoryAdjustment_Stock_Callback",
    PROCESS_INVENTORY_ADJUSTMENT_FINANCE_CALLBACK = "CrossContract_InventoryAdjustment_Finance_Callback",
    PROCESS_INVENTORY_ADJUSTMENT_REPORT_CALLBACK = "CrossContract_InventoryAdjustment_Report_Callback"
}

-- 注册代理合约
saga_messaging.register_proxy_contract("token_transfer", token_transfer_proxy)

-- ===== 核心业务逻辑：处理库存调整 =====
function cross_contract_inventory_service.process_inventory_adjustment(msg, env, response)
    -- 📋 解析库存调整请求
    local cmd
    local decode_success, decode_result = pcall(function()
        return json.decode(msg.Data)
    end)

    if not decode_success then
        messaging.respond(false, "INVALID_JSON_DATA: " .. decode_result, msg)
        return
    end
    cmd = decode_result

    -- 🛡️ 验证调整参数
    if not cmd.product_id or not cmd.location or not cmd.adjusted_quantity or not cmd.adjustment_reason then
        messaging.respond(false, "MISSING_REQUIRED_PARAMETERS", msg)
        return
    end

    -- 💰 计算调整费用（假设每调整1个库存单位需要0.1个Token）
    local adjustment_fee = math.abs(cmd.adjusted_quantity - cmd.current_quantity) * 0.1
    if adjustment_fee <= 0 then
        messaging.respond(false, "NO_ADJUSTMENT_NEEDED", msg)
        return
    end

    -- 📊 构建库存调整上下文
    local context = {
        -- 库存信息
        product_id = cmd.product_id,
        location = cmd.location,
        current_quantity = cmd.current_quantity,
        adjusted_quantity = cmd.adjusted_quantity,
        adjustment_reason = cmd.adjustment_reason,

        -- 费用信息
        adjustment_fee = adjustment_fee,
        fee_recipient = "WAREHOUSE_SYSTEM_FEE_ACCOUNT", -- 仓库系统的手续费账户

        -- 操作信息
        operator_id = cmd.operator_id or msg.From,
        adjustment_timestamp = os.time(),

        -- Saga步骤控制
        saga_steps = {
            { name = "pay_adjustment_fee", completed = false },
            { name = "update_inventory", completed = false },
            { name = "record_financial", completed = false },
            { name = "update_reports", completed = false }
        }
    }

    -- 🎯 创建库存调整Saga实例
    -- 为什么需要4个步骤？
    -- 1. 支付调整费用（调用Token合约）
    -- 2. 更新库存数量（调用库存合约）
    -- 3. 记录财务调整（调用财务合约）
    -- 4. 更新报表（调用报表合约）
    local saga_instance, saga_commit = saga.create_saga_instance(
        "INVENTORY_ADJUSTMENT_SAGA",  -- Saga类型标识符
        token_transfer_proxy.config.external_config.target, -- Token合约
        {
            Action = "ProxyCall",
            ["X-CallbackAction"] = ACTIONS.PROCESS_INVENTORY_ADJUSTMENT_FEE_CALLBACK
        },
        context,
        {
            from = msg.From,
            response_action = msg.Tags[messaging.X_TAGS.RESPONSE_ACTION],
            no_response_required = msg.Tags[messaging.X_TAGS.NO_RESPONSE_REQUIRED]
        },
        3  -- 预留3个本地步骤（库存更新、财务记录、报表更新）
    )

    -- 💸 准备费用支付请求
    local fee_payment_request = {
        Recipient = context.fee_recipient,
        Quantity = tostring(context.adjustment_fee),
        Memo = string.format("Inventory Adjustment Fee: %s-%s",
            context.product_id, context.location)
    }

    -- 🚀 发起代理调用，开始Saga流程
    messaging.commit_send_or_error(true, fee_payment_request, saga_commit,
        token_transfer_proxy.config.external_config.target, {
            Action = "ProxyCall",
            ["X-CallbackAction"] = ACTIONS.PROCESS_INVENTORY_ADJUSTMENT_FEE_CALLBACK
        })

    print(string.format("[InventoryAdjustment] Started saga for product %s at %s, fee: %s",
        context.product_id, context.location, context.adjustment_fee))
end

-- ===== 步骤1回调：处理费用支付结果 =====
function cross_contract_inventory_service.process_fee_callback(msg, env, response)
    local saga_id = tonumber(msg.Tags[messaging.X_TAGS.SAGA_ID])
    local saga_instance = saga.get_saga_instance_copy(saga_id)

    if saga_instance.current_step ~= 1 or saga_instance.compensating then
        error(ERRORS.INVALID_MESSAGE)
    end

    local context = saga_instance.context
    local data = json.decode(msg.Data)

    if data.error then
        -- ❌ 费用支付失败：直接回滚整个Saga
        print(string.format("[InventoryAdjustment] Fee payment failed for saga %s: %s",
            saga_id, data.error))

        local rollback_commit = saga.rollback_saga_instance(saga_id, 1, nil, nil, context, data.error)
        rollback_commit()

        messaging.process_operation_result(false, {
            error = "ADJUSTMENT_FEE_PAYMENT_FAILED",
            reason = data.error,
            product_id = context.product_id,
            location = context.location
        }, function() end, saga_instance.original_message)

        return
    end

    -- ✅ 费用支付成功：推进到下一步
    print(string.format("[InventoryAdjustment] Fee payment successful for saga %s, tx: %s",
        saga_id, data.result.transaction_id))

    -- 标记第一步完成
    context.saga_steps[1].completed = true
    context.fee_transaction_id = data.result.transaction_id

    -- 🚀 推进Saga到下一步：更新库存
    local next_step_commit = saga.move_saga_instance_forward(saga_id, {
        step_name = "update_inventory",
        fee_transaction_id = context.fee_transaction_id,
        inventory_update_timestamp = os.time()
    }, context)

    -- 模拟调用库存合约更新库存（在实际实现中这会是异步消息调用）
    local function simulate_inventory_update()
        print(string.format("[InventoryAdjustment] Inventory updated for %s at %s: %s -> %s",
            context.product_id, context.location, context.current_quantity, context.adjusted_quantity))
        context.saga_steps[2].completed = true
        return true
    end

    if simulate_inventory_update() then
        next_step_commit()
        -- 继续下一步：记录财务
        cross_contract_inventory_service.continue_adjustment_saga(saga_id, 3)
    else
        cross_contract_inventory_service.rollback_adjustment_saga(saga_id, "INVENTORY_UPDATE_FAILED")
    end
end

-- ===== 继续Saga流程的辅助函数 =====
function cross_contract_inventory_service.continue_adjustment_saga(saga_id, step_number)
    local saga_instance = saga.get_saga_instance_copy(saga_id)
    local context = saga_instance.context

    if step_number == 3 then
        -- 💰 步骤3：记录财务调整
        print(string.format("[InventoryAdjustment] Recording financial adjustment for saga %s", saga_id))

        local finance_commit = saga.move_saga_instance_forward(saga_id, {
            step_name = "record_financial",
            financial_record_timestamp = os.time()
        }, context)

        -- 模拟调用财务合约记录调整
        local function simulate_financial_record()
            print(string.format("[InventoryAdjustment] Financial record created for adjustment fee: %s",
                context.adjustment_fee))
            context.saga_steps[3].completed = true
            return true
        end

        if simulate_financial_record() then
            finance_commit()
            -- 继续最后一步：更新报表
            cross_contract_inventory_service.continue_adjustment_saga(saga_id, 4)
        else
            cross_contract_inventory_service.rollback_adjustment_saga(saga_id, "FINANCIAL_RECORD_FAILED")
        end

    elseif step_number == 4 then
        -- 📊 步骤4：更新报表
        print(string.format("[InventoryAdjustment] Updating reports for saga %s", saga_id))

        local report_commit = saga.complete_saga_instance(saga_id, {
            status = "adjustment_completed",
            product_id = context.product_id,
            location = context.location,
            original_quantity = context.current_quantity,
            adjusted_quantity = context.adjusted_quantity,
            adjustment_fee = context.adjustment_fee,
            fee_transaction_id = context.fee_transaction_id,
            operator_id = context.operator_id,
            completion_timestamp = os.time(),
            all_steps_completed = true
        }, context)

        -- 模拟调用报表合约更新报表
        local function simulate_report_update()
            print(string.format("[InventoryAdjustment] Reports updated for product %s adjustment",
                context.product_id))
            context.saga_steps[4].completed = true
            return true
        end

        if simulate_report_update() then
            report_commit()

            -- 🎉 库存调整完全成功！
            messaging.process_operation_result(true, {
                status = "INVENTORY_ADJUSTMENT_COMPLETED",
                product_id = context.product_id,
                location = context.location,
                original_quantity = context.current_quantity,
                adjusted_quantity = context.adjusted_quantity,
                adjustment_fee = context.adjustment_fee,
                fee_transaction_id = context.fee_transaction_id,
                completion_timestamp = os.time()
            }, function() end, saga_instance.original_message)

            print(string.format("[InventoryAdjustment] Adjustment completed successfully for product %s!",
                context.product_id))

        else
            cross_contract_inventory_service.rollback_adjustment_saga(saga_id, "REPORT_UPDATE_FAILED")
        end
    end
end

-- ===== 回滚Saga的辅助函数 =====
function cross_contract_inventory_service.rollback_adjustment_saga(saga_id, reason)
    local saga_instance = saga.get_saga_instance_copy(saga_id)
    local context = saga_instance.context

    print(string.format("[InventoryAdjustment] Rolling back adjustment for saga %s, reason: %s",
        saga_id, reason))

    -- 根据失败阶段决定补偿策略
    local need_fee_refund = false

    if saga_instance.current_step >= 1 then
        -- 如果已经过了费用支付步骤，需要退款
        need_fee_refund = true
    end

    local refund_func = nil
    if need_fee_refund then
        -- 退还调整费用
        local compensation_config = {
            type = "refund_tokens",
            proxy_contract = "token_transfer",
            compensation_data = {
                original_sender = context.fee_recipient, -- 从手续费账户退回
                quantity = context.adjustment_fee,
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

    -- 通知调整失败
    messaging.process_operation_result(false, {
        error = "INVENTORY_ADJUSTMENT_FAILED",
        reason = reason,
        product_id = context.product_id,
        location = context.location,
        original_quantity = context.current_quantity,
        attempted_quantity = context.adjusted_quantity,
        refund_needed = need_fee_refund,
        refund_amount = context.adjustment_fee,
        rollback_timestamp = os.time()
    }, function() end, saga_instance.original_message)
end

-- ===== 查询调整状态 =====
function cross_contract_inventory_service.get_adjustment_status(msg, env, response)
    local adjustment_id = msg.Tags.AdjustmentId

    if not adjustment_id then
        messaging.respond(false, "MISSING_ADJUSTMENT_ID", msg)
        return
    end

    -- 在实际应用中，这里会查询Saga实例状态
    messaging.respond(true, {
        adjustment_id = adjustment_id,
        status = "completed", -- 或 "processing", "failed", "rolled_back"
        product_id = "PRODUCT_001",
        location = "WAREHOUSE_A",
        original_quantity = 100,
        adjusted_quantity = 95,
        adjustment_fee = 0.5,
        fee_transaction_id = "TX_FEE_001",
        timestamp = os.time(),
        details = {
            fee_paid = true,
            inventory_updated = true,
            financial_recorded = true,
            reports_updated = true
        }
    }, msg)
end

return cross_contract_inventory_service
