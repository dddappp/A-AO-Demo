// Javet演示项目模块路径配置
// 这个文件用于在Javet中配置Node.js模块搜索路径

console.log('🔧 配置Node.js模块搜索路径...');

// 添加项目node_modules路径
require('module').globalPaths.push(process.cwd() + '/node_modules');

// 加载aoconnect
try {
    global.aoconnect = require('@permaweb/aoconnect');
    console.log('✅ aoconnect模块加载成功');
} catch (error) {
    console.error('❌ aoconnect模块加载失败:', error.message);
    throw error;
}

console.log('📍 模块搜索路径:', require('module').globalPaths);
