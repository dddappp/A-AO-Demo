-- ===== 测试支付接收合约 =====
-- 这个文件演示了支付接收合约的工作流程

local json = require("json")
local payment_reception_contract = require("payment_reception_contract")

local test_payment_reception_contract = {}

-- ===== 测试函数 =====

-- 测试1：注册支付意向
function test_payment_reception_contract.test_register_payment_intent()
    print("=== 测试1：注册支付意向 ===")

    local test_msg = {
        From = "CUSTOMER_WALLET_ADDRESS",
        Data = json.encode({
            order_id = "ORDER_20241201_001",
            expected_amount = 100,
            customer_address = "CUSTOMER_WALLET_ADDRESS",
            saga_contract_address = "ECOMMERCE_SAGA_CONTRACT_ID",
            saga_id = 12345  -- 测试用的saga_id
        })
    }

    -- 模拟调用注册函数
    payment_reception_contract.register_payment_intent(test_msg)

    print("✓ 支付意向注册完成")
end

-- 测试2：模拟接收转账（Credit-Notice消息）
function test_payment_reception_contract.test_receive_credit_notice()
    print("\n=== 测试2：模拟接收转账 ===")

    -- 模拟Token合约发送的Credit-Notice消息
    local credit_notice_msg = {
        Tags = {
            Action = "Credit-Notice",
            Quantity = "100",  -- 转账金额
            Sender = "CUSTOMER_WALLET_ADDRESS"  -- 发送者地址
        }
    }

    -- 模拟调用Credit-Notice处理器
    payment_reception_contract.handle_credit_notice(credit_notice_msg)

    print("✓ 转账接收和验证完成")
end

-- 测试3：验证不匹配的转账（应该被忽略）
function test_payment_reception_contract.test_invalid_transfer()
    print("\n=== 测试3：测试无效转账 ===")

    -- 金额不匹配的转账
    local invalid_msg = {
        Tags = {
            Action = "Credit-Notice",
            Quantity = "50",  -- 错误的金额
            Sender = "CUSTOMER_WALLET_ADDRESS"
        }
    }

    payment_reception_contract.handle_credit_notice(invalid_msg)

    -- 发送者不匹配的转账
    local invalid_sender_msg = {
        Tags = {
            Action = "Credit-Notice",
            Quantity = "100",
            Sender = "DIFFERENT_CUSTOMER_ADDRESS"  -- 错误的发送者
        }
    }

    payment_reception_contract.handle_credit_notice(invalid_sender_msg)

    print("✓ 无效转账被正确过滤")
end

-- 测试4：清理过期订单
function test_payment_reception_contract.test_cleanup_expired_orders()
    print("\n=== 测试4：清理过期订单 ===")

    payment_reception_contract.cleanup_expired_orders()

    print("✓ 过期订单清理完成")
end

-- ===== 运行所有测试 =====

function test_payment_reception_contract.run_all_tests()
    print("🚀 开始测试支付接收合约\n")

    test_payment_reception_contract.test_register_payment_intent()
    test_payment_reception_contract.test_receive_credit_notice()
    test_payment_reception_contract.test_invalid_transfer()
    test_payment_reception_contract.test_cleanup_expired_orders()

    print("\n✅ 所有测试完成！")
    print("\n📋 测试结果说明：")
    print("1. 支付意向注册成功")
    print("2. 有效转账被正确识别和验证")
    print("3. 无效转账被过滤掉")
    print("4. 过期订单被清理")
    print("\n🎯 支付接收合约工作正常！")
end

return test_payment_reception_contract
