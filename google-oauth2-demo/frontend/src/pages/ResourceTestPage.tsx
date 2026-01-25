import React, { useState } from 'react';

/**
 * 异构资源服务器集成测试页面
 * 测试从 Python 资源服务器获取受保护资源
 */
const ResourceTestPage: React.FC = () => {
  const [resourceData, setResourceData] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [testStatus, setTestStatus] = useState<'idle' | 'testing' | 'success' | 'error'>('idle');

  const fetchProtectedResource = async () => {
    setLoading(true);
    setError(null);
    setResourceData(null);
    setTestStatus('testing');

    try {
      // 从 localStorage 获取 access token
      const accessToken = localStorage.getItem('accessToken');

      if (!accessToken) {
        setError('❌ No access token found. Please login first.');
        setTestStatus('error');
        setLoading(false);
        return;
      }

      console.log('📤 Fetching protected resource from Python server...');

      // 调用 Python 资源服务器
      const response = await fetch('http://localhost:5001/api/protected', {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        credentials: 'include',
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || `HTTP ${response.status}: ${response.statusText}`);
      }

      const data = await response.json();
      console.log('✅ Protected resource retrieved:', data);
      setResourceData(data);
      setTestStatus('success');
    } catch (err: any) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      console.error('❌ Error fetching resource:', errorMessage);
      setError(errorMessage);
      setTestStatus('error');
    } finally {
      setLoading(false);
    }
  };

  const testHealthCheck = async () => {
    setLoading(true);
    setError(null);
    setResourceData(null);
    setTestStatus('testing');

    try {
      console.log('🏥 Testing resource server health...');
      const response = await fetch('http://localhost:5001/health');

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data = await response.json();
      console.log('✅ Health check passed:', data);
      setResourceData(data);
      setTestStatus('success');
    } catch (err: any) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      console.error('❌ Health check failed:', errorMessage);
      setError(errorMessage);
      setTestStatus('error');
    } finally {
      setLoading(false);
    }
  };

  const testJwks = async () => {
    setLoading(true);
    setError(null);
    setResourceData(null);
    setTestStatus('testing');

    try {
      console.log('🔑 Fetching JWKS from auth server...');
      const response = await fetch('/oauth2/jwks');

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data = await response.json();
      console.log('✅ JWKS retrieved:', data);
      setResourceData(data);
      setTestStatus('success');
    } catch (err: any) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      console.error('❌ JWKS fetch failed:', errorMessage);
      setError(errorMessage);
      setTestStatus('error');
    } finally {
      setLoading(false);
    }
  };

  const testIntrospect = async () => {
    setLoading(true);
    setError(null);
    setResourceData(null);
    setTestStatus('testing');

    try {
      const accessToken = localStorage.getItem('accessToken');

      if (!accessToken) {
        setError('❌ No access token found. Please login first.');
        setTestStatus('error');
        setLoading(false);
        return;
      }

      console.log('🔍 Testing Token introspection...');
      const response = await fetch(`/oauth2/introspect?token=${encodeURIComponent(accessToken)}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data = await response.json();
      console.log('✅ Introspect response:', data);
      setResourceData(data);
      setTestStatus('success');
    } catch (err: any) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      console.error('❌ Introspect failed:', errorMessage);
      setError(errorMessage);
      setTestStatus('error');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="container mx-auto p-6 bg-gray-50 min-h-screen">
      <h1 className="text-4xl font-bold mb-2 text-gray-800">🌐 异构资源服务器集成测试</h1>
      <p className="text-gray-600 mb-6">验证 Python 资源服务器与 Spring Boot OAuth2 认证服务器的集成</p>

      {/* 说明区域 */}
      <div className="bg-blue-50 border-l-4 border-blue-500 p-4 mb-6 rounded">
        <h2 className="font-semibold text-blue-900 mb-3">📋 测试说明</h2>
        <ul className="text-sm text-blue-800 space-y-2">
          <li>✅ 确保 Java 认证服务器运行在 8081 端口</li>
          <li>✅ 确保 Python 资源服务器运行在 5001 端口</li>
          <li>✅ 先登录获取 access token</li>
          <li>✅ 依次点击下方按钮进行集成测试</li>
          <li>✅ 查看控制台输出了解详细过程</li>
        </ul>
      </div>

      {/* 测试按钮区域 */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        {/* 健康检查 */}
        <button
          onClick={testHealthCheck}
          disabled={loading}
          className="bg-green-500 hover:bg-green-600 disabled:bg-gray-400 text-white font-bold py-3 px-4 rounded flex items-center justify-center gap-2 transition"
        >
          {loading ? '⏳ 检测中...' : '🏥 资源服务器健康检查'}
        </button>

        {/* JWKS 测试 */}
        <button
          onClick={testJwks}
          disabled={loading}
          className="bg-blue-500 hover:bg-blue-600 disabled:bg-gray-400 text-white font-bold py-3 px-4 rounded flex items-center justify-center gap-2 transition"
        >
          {loading ? '⏳ 获取中...' : '🔑 测试 JWKS 端点'}
        </button>

        {/* Token 验证 */}
        <button
          onClick={testIntrospect}
          disabled={loading}
          className="bg-purple-500 hover:bg-purple-600 disabled:bg-gray-400 text-white font-bold py-3 px-4 rounded flex items-center justify-center gap-2 transition"
        >
          {loading ? '⏳ 验证中...' : '🔍 测试 Token 内省'}
        </button>

        {/* 获取资源 */}
        <button
          onClick={fetchProtectedResource}
          disabled={loading}
          className="bg-red-500 hover:bg-red-600 disabled:bg-gray-400 text-white font-bold py-3 px-4 rounded flex items-center justify-center gap-2 transition"
        >
          {loading ? '⏳ 获取中...' : '🔓 获取受保护资源'}
        </button>
      </div>

      {/* 错误显示 */}
      {error && (
        <div className="bg-red-100 border-l-4 border-red-500 text-red-700 p-4 mb-4 rounded">
          <h3 className="font-semibold mb-2">❌ 错误信息</h3>
          <p className="text-sm font-mono">{error}</p>
        </div>
      )}

      {/* 成功响应显示 */}
      {resourceData && testStatus === 'success' && (
        <div className="bg-green-100 border-l-4 border-green-500 text-green-700 p-4 rounded">
          <h3 className="font-semibold mb-2">✅ 测试成功</h3>
          <pre className="bg-white p-4 rounded text-xs overflow-auto max-h-96 border border-green-300 text-gray-800">
            {JSON.stringify(resourceData, null, 2)}
          </pre>
        </div>
      )}

      {/* 测试进行中 */}
      {loading && (
        <div className="bg-yellow-100 border-l-4 border-yellow-500 text-yellow-700 p-4 rounded">
          <h3 className="font-semibold">⏳ 测试进行中...</h3>
          <p className="text-sm">请稍候，正在发送请求...</p>
        </div>
      )}

      {/* 初始状态信息 */}
      {!resourceData && !error && !loading && testStatus === 'idle' && (
        <div className="bg-gray-100 border-l-4 border-gray-500 text-gray-700 p-4 rounded">
          <h3 className="font-semibold">ℹ️ 就绪</h3>
          <p className="text-sm">点击上方按钮开始测试异构资源服务器集成</p>
        </div>
      )}

      {/* 集成流程说明 */}
      <div className="mt-8 bg-white p-6 rounded border border-gray-300">
        <h2 className="text-2xl font-bold mb-4 text-gray-800">🔄 集成流程</h2>
        
        <div className="space-y-4">
          <div className="flex gap-4">
            <div className="flex-shrink-0 w-8 h-8 bg-blue-500 text-white rounded-full flex items-center justify-center font-bold">1</div>
            <div>
              <h3 className="font-semibold text-gray-800">用户登录</h3>
              <p className="text-gray-600 text-sm">用户在 Spring Boot 应用中登录，获得 JWT Token</p>
            </div>
          </div>

          <div className="flex gap-4">
            <div className="flex-shrink-0 w-8 h-8 bg-blue-500 text-white rounded-full flex items-center justify-center font-bold">2</div>
            <div>
              <h3 className="font-semibold text-gray-800">Token 存储</h3>
              <p className="text-gray-600 text-sm">Token 存储在浏览器 localStorage 中</p>
            </div>
          </div>

          <div className="flex gap-4">
            <div className="flex-shrink-0 w-8 h-8 bg-blue-500 text-white rounded-full flex items-center justify-center font-bold">3</div>
            <div>
              <h3 className="font-semibold text-gray-800">获取公钥</h3>
              <p className="text-gray-600 text-sm">Python 资源服务器从 JWKS 端点获取认证服务器的公钥</p>
            </div>
          </div>

          <div className="flex gap-4">
            <div className="flex-shrink-0 w-8 h-8 bg-blue-500 text-white rounded-full flex items-center justify-center font-bold">4</div>
            <div>
              <h3 className="font-semibold text-gray-800">验证 Token</h3>
              <p className="text-gray-600 text-sm">Python 资源服务器使用公钥验证 Token 签名</p>
            </div>
          </div>

          <div className="flex gap-4">
            <div className="flex-shrink-0 w-8 h-8 bg-blue-500 text-white rounded-full flex items-center justify-center font-bold">5</div>
            <div>
              <h3 className="font-semibold text-gray-800">访问资源</h3>
              <p className="text-gray-600 text-sm">验证成功后，前端可以访问 Python 资源服务器的受保护资源</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ResourceTestPage;
