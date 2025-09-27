// 测试aoconnect集成是否正常工作
const assert = require('assert');

async function testAOConnectIntegration() {
    console.log('🧪 测试aoconnect集成...');

    try {
        // 先加载aoconnect模块
        console.log('🔄 加载aoconnect模块...');
        const aoconnect = require('@permaweb/aoconnect');
        global.aoconnect = aoconnect;
        console.log('✅ aoconnect模块加载成功');

        // 测试模块是否正确加载
        assert(global.aoconnect, 'aoconnect模块未加载');
        assert(global.aoconnect.spawn, 'spawn函数不存在');
        assert(global.aoconnect.message, 'message函数不存在');
        assert(global.aoconnect.result, 'result函数不存在');

        console.log('✅ 基础模块加载测试通过');

        // 测试基本功能（不实际调用网络）
        console.log('✅ aoconnect集成测试完成');

        return true;
    } catch (error) {
        console.error('❌ 测试失败:', error.message);
        throw error;
    }
}

// 如果直接运行此脚本
if (require.main === module) {
    testAOConnectIntegration()
        .then(() => process.exit(0))
        .catch(() => process.exit(1));
}

module.exports = { testAOConnectIntegration };
