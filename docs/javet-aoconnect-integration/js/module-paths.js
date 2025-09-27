// Javet 中使用的模块路径配置
// 这个文件会被 Java 代码加载来配置 Node.js 模块搜索路径

console.log('🔧 配置 Node.js 模块搜索路径...');

// 添加项目特定的模块路径
require('module').globalPaths.push(process.cwd() + '/node_modules');
require('module').globalPaths.push(__dirname);

// 加载 aoconnect
try {
    global.aoconnect = require('@permaweb/aoconnect');
    console.log('✅ aoconnect 模块加载成功');
} catch (error) {
    console.error('❌ aoconnect 模块加载失败:', error.message);
    throw error;
}

console.log('📍 模块搜索路径:', require('module').globalPaths);
