import { useState, useEffect } from 'react';
import { AuthService } from '../services/authService';
import { useAuth } from '../hooks/useAuth';
import { TokenRefreshResult } from '../types';

interface TokenValidationResult {
  valid: boolean;
  error?: string;
  [key: string]: any;
}

interface LoginMethod {
  id: number;
  authProvider: string;
  localUsername?: string;
  providerEmail?: string;
  providerUsername?: string;
  isPrimary: boolean;
  isVerified: boolean;
  linkedAt: string;
  lastUsedAt?: string;
}

export default function TestPage() {
  const { user, logout: authLogout, refreshToken } = useAuth();
  const [tokenValidationLoading, setTokenValidationLoading] = useState<string | null>(null);
  const [tokenRefreshResult, setTokenRefreshResult] = useState<TokenRefreshResult | null>(null);
  
  // 多登录方式管理状态
  const [loginMethods, setLoginMethods] = useState<LoginMethod[]>([]);
  const [loadingLoginMethods, setLoadingLoginMethods] = useState(true);
  const [bindingProvider, setBindingProvider] = useState<string | null>(null);
  const [bindingMessage, setBindingMessage] = useState<{ type: 'success' | 'error', text: string } | null>(null);
  const [removingMethodId, setRemovingMethodId] = useState<number | null>(null);
  const [settingPrimaryId, setSettingPrimaryId] = useState<number | null>(null);

  // 加载登录方式
  useEffect(() => {
    loadLoginMethods();
  }, []);

  const loadLoginMethods = async () => {
    try {
      setLoadingLoginMethods(true);
      const response = await AuthService.getLoginMethods();
      setLoginMethods(response.loginMethods || []);
    } catch (error) {
      console.error('Failed to load login methods:', error);
      setLoginMethods([]);
    } finally {
      setLoadingLoginMethods(false);
    }
  };

  const handleBindLoginMethod = async (provider: string) => {
    setBindingProvider(provider);
    setBindingMessage(null);
    try {
      // 重定向到OAuth2授权端点
      const loginUrl = AuthService.getLoginUrl(provider as 'google' | 'github' | 'x');
      window.location.href = loginUrl;
    } catch (error) {
      setBindingMessage({
        type: 'error',
        text: `绑定${provider}失败: ${error instanceof Error ? error.message : '未知错误'}`
      });
      setBindingProvider(null);
    }
  };

  const handleRemoveLoginMethod = async (methodId: number) => {
    if (!confirm('确认删除这个登录方式吗？此操作不可撤销。')) {
      return;
    }
    setRemovingMethodId(methodId);
    try {
      await AuthService.removeLoginMethod(methodId);
      setBindingMessage({
        type: 'success',
        text: '登录方式已删除'
      });
      await loadLoginMethods();
    } catch (error: any) {
      setBindingMessage({
        type: 'error',
        text: `删除失败: ${error.response?.data?.error || error.message}`
      });
    } finally {
      setRemovingMethodId(null);
    }
  };

  const handleSetPrimaryLoginMethod = async (methodId: number) => {
    setSettingPrimaryId(methodId);
    try {
      await AuthService.setPrimaryLoginMethod(methodId);
      setBindingMessage({
        type: 'success',
        text: '主登录方式已更新'
      });
      await loadLoginMethods();
    } catch (error: any) {
      setBindingMessage({
        type: 'error',
        text: `设置失败: ${error.response?.data?.error || error.message}`
      });
    } finally {
      setSettingPrimaryId(null);
    }
  };

  // 添加本地密码表单状态
  const [showAddLocalForm, setShowAddLocalForm] = useState(false);
  const [localFormData, setLocalFormData] = useState({
    username: '',
    password: '',
    passwordConfirm: ''
  });
  const [addingLocalLogin, setAddingLocalLogin] = useState(false);

  const handleAddLocalLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    
    // 验证输入
    if (!localFormData.username.trim()) {
      setBindingMessage({ type: 'error', text: '用户名不能为空' });
      return;
    }
    
    if (!localFormData.password) {
      setBindingMessage({ type: 'error', text: '密码不能为空' });
      return;
    }
    
    if (localFormData.password.length < 6) {
      setBindingMessage({ type: 'error', text: '密码长度至少6个字符' });
      return;
    }
    
    if (localFormData.password !== localFormData.passwordConfirm) {
      setBindingMessage({ type: 'error', text: '两次输入的密码不一致' });
      return;
    }

    setAddingLocalLogin(true);
    try {
      await AuthService.addLocalLoginMethod(
        localFormData.username,
        localFormData.password,
        localFormData.passwordConfirm
      );
      
      setBindingMessage({
        type: 'success',
        text: '本地登录方式添加成功！'
      });
      
      // 重置表单
      setLocalFormData({ username: '', password: '', passwordConfirm: '' });
      setShowAddLocalForm(false);
      
      // 重新加载登录方式
      await loadLoginMethods();
    } catch (error: any) {
      setBindingMessage({
        type: 'error',
        text: `添加失败: ${error.response?.data?.error || error.message}`
      });
    } finally {
      setAddingLocalLogin(false);
    }
  };

  // 认证检查由useAuth hook处理，这里不需要额外的检查

  const logout = async () => {
    // 使用 useAuth hook 的 logout 方法，它会正确处理状态清除
    await authLogout();
  };

  const handleTokenRefresh = async () => {
    try {
      setTokenValidationLoading('refresh');
      const result = await refreshToken();
      setTokenRefreshResult(result);
    } catch (error) {
      setTokenRefreshResult({
        message: 'Token refresh failed',
        accessToken: '',
        refreshToken: '',
        accessTokenExpiresIn: 0,
        refreshTokenExpiresIn: 0
      });
    } finally {
      setTokenValidationLoading(null);
    }
  };
  const [googleTokenResult, setGoogleTokenResult] = useState<TokenValidationResult | null>(null);
  const [githubTokenResult, setGithubTokenResult] = useState<TokenValidationResult | null>(null);
  const [xTokenResult, setXTokenResult] = useState<TokenValidationResult | null>(null);  // ✅ X API v2：变量名更新
  // Token验证加载状态已在上方声明

  const validateToken = async (provider: 'google' | 'github' | 'x') => {  // ✅ X API v2：提供者名改为 'x'
    if (!user) return;

    setTokenValidationLoading(provider);
    try {
      let result: TokenValidationResult;

      switch (provider) {
        case 'google':
          result = await AuthService.validateGoogleToken();
          break;
        case 'github':
          result = await AuthService.validateGithubToken();
          break;
        case 'x':  // ✅ X API v2：提供者名改为 'x'
          result = await AuthService.validateXToken();
          break;
        default:
          result = { valid: false, error: '不支持的提供商' };
      }

      switch (provider) {
        case 'google': setGoogleTokenResult(result); break;
        case 'github': setGithubTokenResult(result); break;
        case 'x': setXTokenResult(result); break;
      }
    } catch (error) {
      const result = {
        valid: false,
        error: error instanceof Error ? error.message : '验证失败'
      };

      switch (provider) {
        case 'google': setGoogleTokenResult(result); break;
        case 'github': setGithubTokenResult(result); break;
        case 'x': setXTokenResult(result); break;
      }
    } finally {
      setTokenValidationLoading(null);
    }
  };

  if (!user) {
    return <div style={{ textAlign: 'center', padding: '50px' }}>加载中...</div>;
  }

  return (
    <div style={{
      maxWidth: '900px',
      margin: '0 auto',
      padding: '20px',
      fontFamily: 'Arial, sans-serif'
    }}>
      <div style={{
        background: '#ff6b6b',
        color: 'white',
        padding: '12px',
        borderRadius: '8px',
        marginBottom: '20px',
        fontSize: '16px',
        fontWeight: 'bold',
        textAlign: 'center'
      }}>
        🚀 当前使用：React 前端实现 (Modern SPA)
      </div>

      <h1 style={{
        color: '#333',
        textAlign: 'center',
        marginBottom: '20px'
      }}>
        React OAuth2 ID Token 验证测试
      </h1>

      {/* 用户信息显示 */}
      <div style={{
        background: 'white',
        padding: '20px',
        borderRadius: '8px',
        boxShadow: '0 2px 10px rgba(0,0,0,0.1)',
        marginBottom: '20px'
      }}>
        <h2 style={{ color: '#333', marginBottom: '15px' }}>用户信息</h2>

        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          gap: '15px'
        }}>
          <div>
            <strong>登录提供商：</strong>
            <span style={{ textTransform: 'capitalize' }}>{user.provider}</span>
          </div>
          <div>
            <strong>用户名：</strong>
            {user.userName}
          </div>
          {user.userEmail && (
            <div>
              <strong>邮箱：</strong>
              {user.userEmail}
            </div>
          )}
          <div>
            <strong>用户ID：</strong>
            {user.userId}
          </div>
          {user.userAvatar && (
            <div style={{ gridColumn: 'span 2' }}>
              <strong>头像：</strong>
              <img
                src={user.userAvatar}
                alt="用户头像"
                style={{
                  width: '50px',
                  height: '50px',
                  borderRadius: '50%',
                  marginTop: '5px'
                }}
              />
            </div>
          )}
        </div>

        {/* 提供商特定信息 */}
        {user.provider === 'github' && user.providerInfo?.htmlUrl && (
          <div style={{
            marginTop: '20px',
            padding: '15px',
            background: '#f8f9fa',
            borderRadius: '5px'
          }}>
            <h3 style={{ marginBottom: '10px', color: '#333' }}>GitHub 特定信息</h3>
            <div style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))',
              gap: '10px'
            }}>
              <div>
                <strong>公开仓库：</strong>
                {user.providerInfo?.publicRepos || 0}
              </div>
              <div>
                <strong>粉丝数：</strong>
                {user.providerInfo?.followers || 0}
              </div>
              <div>
                <strong>GitHub主页：</strong>
                <a
                  href={user.providerInfo?.htmlUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  style={{ color: '#007bff' }}
                >
                  查看资料
                </a>
              </div>
            </div>
          </div>
        )}

        {user.provider === 'x' && (
          <div style={{
            marginTop: '20px',
            padding: '15px',
            background: '#f8f9fa',
            borderRadius: '5px'
          }}>
            <h3 style={{ marginBottom: '10px', color: '#333' }}>Twitter 特定信息</h3>
            <div style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))',
              gap: '10px'
            }}>
              <div>
                <strong>位置：</strong>
                {user.providerInfo?.location || '未设置'}
              </div>
              <div>
                <strong>验证状态：</strong>
                {user.providerInfo?.verified ? '已验证' : '未验证'}
              </div>
              <div>
                <strong>个人简介：</strong>
                {user.providerInfo?.description || '未设置'}
              </div>
            </div>
          </div>
        )}
      </div>

      {/* 多登录方式管理 */}
      <div style={{
        background: 'white',
        padding: '20px',
        borderRadius: '8px',
        boxShadow: '0 2px 10px rgba(0,0,0,0.1)',
        marginBottom: '20px'
      }}>
        <h2 style={{ color: '#333', marginBottom: '15px' }}>🔐 多登录方式管理</h2>

        {/* 绑定消息 */}
        {bindingMessage && (
          <div style={{
            padding: '12px',
            borderRadius: '5px',
            marginBottom: '15px',
            backgroundColor: bindingMessage.type === 'success' ? '#d4edda' : '#f8d7da',
            color: bindingMessage.type === 'success' ? '#155724' : '#721c24',
            border: `1px solid ${bindingMessage.type === 'success' ? '#c3e6cb' : '#f5c6cb'}`
          }}>
            {bindingMessage.type === 'success' ? '✅' : '❌'} {bindingMessage.text}
          </div>
        )}

        {/* 已绑定的登录方式列表 */}
        <div style={{ marginBottom: '20px' }}>
          <h3 style={{ color: '#555', marginBottom: '10px' }}>已绑定的登录方式 ({loginMethods.length})</h3>
          
          {loadingLoginMethods ? (
            <div style={{ color: '#999', textAlign: 'center', padding: '20px' }}>加载中...</div>
          ) : loginMethods.length === 0 ? (
            <div style={{ color: '#999', textAlign: 'center', padding: '20px' }}>暂无登录方式</div>
          ) : (
            <div style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fill, minmax(250px, 1fr))',
              gap: '12px'
            }}>
              {loginMethods.map((method) => (
                <div key={method.id} style={{
                  border: `2px solid ${method.isPrimary ? '#28a745' : '#ddd'}`,
                  borderRadius: '8px',
                  padding: '15px',
                  backgroundColor: method.isPrimary ? '#f0f8f4' : '#f9f9f9',
                  position: 'relative'
                }}>
                  {/* 主方式标记 */}
                  {method.isPrimary && (
                    <div style={{
                      position: 'absolute',
                      top: '5px',
                      right: '5px',
                      backgroundColor: '#28a745',
                      color: 'white',
                      padding: '3px 8px',
                      borderRadius: '3px',
                      fontSize: '12px',
                      fontWeight: 'bold'
                    }}>
                      ⭐ 主登录
                    </div>
                  )}

                  {/* 登录方式信息 */}
                  <h4 style={{ margin: '0 0 10px 0', color: '#333', textTransform: 'uppercase' }}>
                    {method.authProvider}
                  </h4>

                  {method.authProvider === 'LOCAL' ? (
                    <div style={{ fontSize: '14px', color: '#666', marginBottom: '8px' }}>
                      👤 {method.localUsername}
                    </div>
                  ) : (
                    <>
                      {method.providerEmail && (
                        <div style={{ fontSize: '14px', color: '#666', marginBottom: '5px' }}>
                          📧 {method.providerEmail}
                        </div>
                      )}
                      {method.providerUsername && (
                        <div style={{ fontSize: '14px', color: '#666', marginBottom: '8px' }}>
                          👤 {method.providerUsername}
                        </div>
                      )}
                    </>
                  )}

                  {/* 验证状态 */}
                  <div style={{ fontSize: '12px', color: '#999', marginBottom: '10px' }}>
                    {method.isVerified ? '✅ 已验证' : '⏳ 未验证'} | 绑定于: {new Date(method.linkedAt).toLocaleDateString('zh-CN')}
                  </div>

                  {/* 操作按钮 */}
                  <div style={{
                    display: 'flex',
                    gap: '8px',
                    marginTop: '12px'
                  }}>
                    {/* 如果不是主登录方式，显示"设为主登录"按钮 */}
                    {!method.isPrimary && (
                      <button
                        onClick={() => handleSetPrimaryLoginMethod(method.id)}
                        disabled={settingPrimaryId === method.id}
                        style={{
                          flex: 1,
                          padding: '6px 10px',
                          backgroundColor: '#007bff',
                          color: 'white',
                          border: 'none',
                          borderRadius: '4px',
                          fontSize: '12px',
                          cursor: settingPrimaryId === method.id ? 'not-allowed' : 'pointer',
                          opacity: settingPrimaryId === method.id ? 0.6 : 1
                        }}
                      >
                        {settingPrimaryId === method.id ? '设置中...' : '设为主登录'}
                      </button>
                    )}

                    {/* 如果登录方式多于1个，显示删除按钮 */}
                    {loginMethods.length > 1 && (
                      <button
                        onClick={() => handleRemoveLoginMethod(method.id)}
                        disabled={removingMethodId === method.id}
                        style={{
                          flex: 1,
                          padding: '6px 10px',
                          backgroundColor: '#dc3545',
                          color: 'white',
                          border: 'none',
                          borderRadius: '4px',
                          fontSize: '12px',
                          cursor: removingMethodId === method.id ? 'not-allowed' : 'pointer',
                          opacity: removingMethodId === method.id ? 0.6 : 1
                        }}
                      >
                        {removingMethodId === method.id ? '删除中...' : '删除'}
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* 绑定新的登录方式 */}
        <div>
          <h3 style={{ color: '#555', marginBottom: '10px' }}>绑定新的登录方式</h3>
          <p style={{ color: '#999', fontSize: '14px', marginBottom: '12px' }}>
            点击下方按钮绑定新的登录方式。绑定完成后会自动返回此页面。
          </p>

          {/* SSO用户添加本地密码 */}
          {!loginMethods.find(m => m.authProvider === 'LOCAL') && (
            <div style={{
              marginBottom: '15px',
              padding: '15px',
              backgroundColor: '#f8f9fa',
              borderRadius: '8px',
              border: '1px solid #dee2e6'
            }}>
              <h4 style={{ margin: '0 0 12px 0', color: '#333' }}>🔐 添加本地用户名/密码</h4>
              
              {!showAddLocalForm ? (
                <button
                  onClick={() => setShowAddLocalForm(true)}
                  style={{
                    padding: '10px 16px',
                    backgroundColor: '#6f42c1',
                    color: 'white',
                    border: 'none',
                    borderRadius: '5px',
                    fontSize: '14px',
                    fontWeight: 'bold',
                    cursor: 'pointer'
                  }}
                >
                  + 添加本地登录方式
                </button>
              ) : (
                <form onSubmit={handleAddLocalLogin} style={{
                  display: 'grid',
                  gap: '10px'
                }}>
                  <input
                    type="text"
                    placeholder="用户名"
                    value={localFormData.username}
                    onChange={(e) => setLocalFormData({...localFormData, username: e.target.value})}
                    style={{
                      padding: '8px 12px',
                      border: '1px solid #ddd',
                      borderRadius: '4px',
                      fontSize: '14px'
                    }}
                  />
                  
                  <input
                    type="password"
                    placeholder="密码（至少6个字符）"
                    value={localFormData.password}
                    onChange={(e) => setLocalFormData({...localFormData, password: e.target.value})}
                    style={{
                      padding: '8px 12px',
                      border: '1px solid #ddd',
                      borderRadius: '4px',
                      fontSize: '14px'
                    }}
                  />
                  
                  <input
                    type="password"
                    placeholder="确认密码"
                    value={localFormData.passwordConfirm}
                    onChange={(e) => setLocalFormData({...localFormData, passwordConfirm: e.target.value})}
                    style={{
                      padding: '8px 12px',
                      border: '1px solid #ddd',
                      borderRadius: '4px',
                      fontSize: '14px'
                    }}
                  />
                  
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
                    <button
                      type="submit"
                      disabled={addingLocalLogin}
                      style={{
                        padding: '8px 12px',
                        backgroundColor: '#28a745',
                        color: 'white',
                        border: 'none',
                        borderRadius: '4px',
                        fontSize: '14px',
                        fontWeight: 'bold',
                        cursor: addingLocalLogin ? 'not-allowed' : 'pointer',
                        opacity: addingLocalLogin ? 0.6 : 1
                      }}
                    >
                      {addingLocalLogin ? '添加中...' : '✓ 确认添加'}
                    </button>
                    
                    <button
                      type="button"
                      onClick={() => {
                        setShowAddLocalForm(false);
                        setLocalFormData({ username: '', password: '', passwordConfirm: '' });
                      }}
                      style={{
                        padding: '8px 12px',
                        backgroundColor: '#6c757d',
                        color: 'white',
                        border: 'none',
                        borderRadius: '4px',
                        fontSize: '14px',
                        fontWeight: 'bold',
                        cursor: 'pointer'
                      }}
                    >
                      ✕ 取消
                    </button>
                  </div>
                </form>
              )}
            </div>
          )}

          {/* OAuth2绑定按钮 */}
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(120px, 1fr))',
            gap: '10px'
          }}>
            {/* Google 绑定按钮 */}
            {!loginMethods.find(m => m.authProvider === 'GOOGLE') && (
              <button
                onClick={() => handleBindLoginMethod('google')}
                disabled={bindingProvider === 'google'}
                style={{
                  padding: '12px 16px',
                  backgroundColor: '#db4437',
                  color: 'white',
                  border: 'none',
                  borderRadius: '5px',
                  fontSize: '14px',
                  fontWeight: 'bold',
                  cursor: bindingProvider === 'google' ? 'not-allowed' : 'pointer',
                  opacity: bindingProvider === 'google' ? 0.6 : 1,
                  transition: 'background-color 0.3s'
                }}
              >
                {bindingProvider === 'google' ? '绑定中...' : '🔗 Google'}
              </button>
            )}

            {/* GitHub 绑定按钮 */}
            {!loginMethods.find(m => m.authProvider === 'GITHUB') && (
              <button
                onClick={() => handleBindLoginMethod('github')}
                disabled={bindingProvider === 'github'}
                style={{
                  padding: '12px 16px',
                  backgroundColor: '#24292e',
                  color: 'white',
                  border: 'none',
                  borderRadius: '5px',
                  fontSize: '14px',
                  fontWeight: 'bold',
                  cursor: bindingProvider === 'github' ? 'not-allowed' : 'pointer',
                  opacity: bindingProvider === 'github' ? 0.6 : 1,
                  transition: 'background-color 0.3s'
                }}
              >
                {bindingProvider === 'github' ? '绑定中...' : '🔗 GitHub'}
              </button>
            )}

            {/* Twitter/X 绑定按钮 */}
            {!loginMethods.find(m => m.authProvider === 'TWITTER') && (
              <button
                onClick={() => handleBindLoginMethod('x')}
                disabled={bindingProvider === 'x'}
                style={{
                  padding: '12px 16px',
                  backgroundColor: '#1da1f2',
                  color: 'white',
                  border: 'none',
                  borderRadius: '5px',
                  fontSize: '14px',
                  fontWeight: 'bold',
                  cursor: bindingProvider === 'x' ? 'not-allowed' : 'pointer',
                  opacity: bindingProvider === 'x' ? 0.6 : 1,
                  transition: 'background-color 0.3s'
                }}
              >
                {bindingProvider === 'x' ? '绑定中...' : '🔗 Twitter/X'}
              </button>
            )}
          </div>

          {/* 已绑定提示 */}
          {loginMethods.find(m => m.authProvider === 'GOOGLE') &&
            loginMethods.find(m => m.authProvider === 'GITHUB') &&
            loginMethods.find(m => m.authProvider === 'TWITTER') && (
            <div style={{
              marginTop: '15px',
              padding: '12px',
              backgroundColor: '#e7f3ff',
              color: '#004085',
              borderRadius: '5px',
              fontSize: '14px'
            }}>
              🎉 您已绑定所有可用的登录方式！
            </div>
          )}
        </div>
      </div>

      {/* Token验证区域 */}
      <div style={{
        background: 'white',
        padding: '20px',
        borderRadius: '8px',
        boxShadow: '0 2px 10px rgba(0,0,0,0.1)',
        marginBottom: '20px'
      }}>
        <h2 style={{ color: '#333', marginBottom: '15px' }}>Token 验证</h2>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '15px' }}>
          {/* Google Token验证 */}
          {user.provider === 'google' && (
            <div style={{
              padding: '15px',
              border: '1px solid #ddd',
              borderRadius: '5px'
            }}>
              <div style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                marginBottom: '10px'
              }}>
                <h3 style={{ margin: 0, color: '#333' }}>Google ID Token 验证</h3>
                <button
                  onClick={() => validateToken('google')}
                  disabled={tokenValidationLoading === 'google'}
                  style={{
                    backgroundColor: '#007bff',
                    color: 'white',
                    border: 'none',
                    padding: '8px 16px',
                    borderRadius: '4px',
                    cursor: tokenValidationLoading === 'google' ? 'not-allowed' : 'pointer',
                    opacity: tokenValidationLoading === 'google' ? 0.6 : 1
                  }}
                >
                  {tokenValidationLoading === 'google' ? '验证中...' : '验证'}
                </button>
              </div>
              {googleTokenResult && (
                <div style={{
                  padding: '10px',
                  borderRadius: '4px',
                  backgroundColor: googleTokenResult.valid ? '#d4edda' : '#f8d7da',
                  color: googleTokenResult.valid ? '#155724' : '#721c24'
                }}>
                  <strong>{googleTokenResult.valid ? '✅ Google验证成功!' : '❌ Google验证失败'}</strong>
                  {googleTokenResult.valid ? (
                    <pre style={{
                      marginTop: '10px',
                      backgroundColor: '#f8f9fa',
                      padding: '10px',
                      borderRadius: '4px',
                      fontSize: '12px',
                      overflow: 'auto',
                      whiteSpace: 'pre-wrap',
                      wordBreak: 'break-all',
                      textAlign: 'left'
                    }}>
                      {JSON.stringify(googleTokenResult, null, 2)}
                    </pre>
                  ) : (
                    googleTokenResult.error && (
                      <div style={{ marginTop: '5px', fontSize: '14px' }}>
                        {googleTokenResult.error}
                      </div>
                    )
                  )}
                </div>
              )}
            </div>
          )}

          {/* GitHub Token验证 */}
          {user.provider === 'github' && (
            <div style={{
              padding: '15px',
              border: '1px solid #ddd',
              borderRadius: '5px'
            }}>
              <div style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                marginBottom: '10px'
              }}>
                <h3 style={{ margin: 0, color: '#333' }}>GitHub Access Token 验证</h3>
                <button
                  onClick={() => validateToken('github')}
                  disabled={tokenValidationLoading === 'github'}
                  style={{
                    backgroundColor: '#24292e',
                    color: 'white',
                    border: 'none',
                    padding: '8px 16px',
                    borderRadius: '4px',
                    cursor: tokenValidationLoading === 'github' ? 'not-allowed' : 'pointer',
                    opacity: tokenValidationLoading === 'github' ? 0.6 : 1
                  }}
                >
                  {tokenValidationLoading === 'github' ? '验证中...' : '验证'}
                </button>
              </div>
              {githubTokenResult && (
                <div style={{
                  padding: '10px',
                  borderRadius: '4px',
                  backgroundColor: githubTokenResult.valid ? '#d4edda' : '#f8d7da',
                  color: githubTokenResult.valid ? '#155724' : '#721c24'
                }}>
                  <strong>{githubTokenResult.valid ? '✅ GitHub验证成功!' : '❌ GitHub验证失败'}</strong>
                  {githubTokenResult.valid ? (
                    <pre style={{
                      marginTop: '10px',
                      backgroundColor: '#f8f9fa',
                      padding: '10px',
                      borderRadius: '4px',
                      fontSize: '12px',
                      overflow: 'auto',
                      whiteSpace: 'pre-wrap',
                      wordBreak: 'break-all',
                      textAlign: 'left'
                    }}>
                      {JSON.stringify(githubTokenResult, null, 2)}
                    </pre>
                  ) : (
                    githubTokenResult.error && (
                      <div style={{ marginTop: '5px', fontSize: '14px' }}>
                        {githubTokenResult.error}
                      </div>
                    )
                  )}
                </div>
              )}
            </div>
          )}

          {/* Twitter Token验证 */}
          {user.provider === 'x' && (
            <div style={{
              padding: '15px',
              border: '1px solid #ddd',
              borderRadius: '5px'
            }}>
              <div style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                marginBottom: '10px'
              }}>
                <h3 style={{ margin: 0, color: '#333' }}>X Access Token 验证</h3>
                <button
                  onClick={() => validateToken('x')}
                  disabled={tokenValidationLoading === 'x'}
                  style={{
                    backgroundColor: '#1da1f2',
                    color: 'white',
                    border: 'none',
                    padding: '8px 16px',
                    borderRadius: '4px',
                    cursor: tokenValidationLoading === 'x' ? 'not-allowed' : 'pointer',
                    opacity: tokenValidationLoading === 'x' ? 0.6 : 1
                  }}
                >
                  {tokenValidationLoading === 'x' ? '验证中...' : '验证'}
                </button>
              </div>
              {xTokenResult && (
                <div style={{
                  padding: '10px',
                  borderRadius: '4px',
                  backgroundColor: xTokenResult.valid ? '#d4edda' : '#f8d7da',
                  color: xTokenResult.valid ? '#155724' : '#721c24'
                }}>
                  <strong>{xTokenResult.valid ? '✅ X验证成功!' : '❌ X验证失败'}</strong>
                  {xTokenResult.valid ? (
                    <pre style={{
                      marginTop: '10px',
                      backgroundColor: '#f8f9fa',
                      padding: '10px',
                      borderRadius: '4px',
                      fontSize: '12px',
                      overflow: 'auto',
                      whiteSpace: 'pre-wrap',
                      wordBreak: 'break-all',
                      textAlign: 'left'
                    }}>
                      {JSON.stringify(xTokenResult, null, 2)}
                    </pre>
                  ) : (
                    xTokenResult.error && (
                      <div style={{ marginTop: '5px', fontSize: '14px' }}>
                        {xTokenResult.error}
                      </div>
                    )
                  )}
                </div>
              )}
            </div>
          )}
        </div>
      </div>

        {/* Token刷新测试 */}
        <div style={{
          background: 'white',
          padding: '20px',
          borderRadius: '8px',
          boxShadow: '0 2px 10px rgba(0,0,0,0.1)',
          marginBottom: '20px'
        }}>
          <h2 style={{ color: '#333', marginBottom: '15px' }}>Token 刷新测试</h2>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '15px' }}>
            <div style={{
              padding: '15px',
              border: '1px solid #ddd',
              borderRadius: '5px'
            }}>
              <div style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                marginBottom: '10px'
              }}>
                <h3 style={{ margin: 0, color: '#333' }}>JWT Token 刷新</h3>
                <button
                  onClick={handleTokenRefresh}
                  disabled={tokenValidationLoading === 'refresh'}
                  style={{
                    backgroundColor: '#28a745',
                    color: 'white',
                    border: 'none',
                    padding: '8px 16px',
                    borderRadius: '4px',
                    cursor: tokenValidationLoading === 'refresh' ? 'not-allowed' : 'pointer',
                    opacity: tokenValidationLoading === 'refresh' ? 0.6 : 1
                  }}
                >
                  {tokenValidationLoading === 'refresh' ? '刷新中...' : '刷新Token'}
                </button>
              </div>
              <p style={{ margin: '5px 0', color: '#666', fontSize: '14px' }}>
                测试JWT Token自动刷新功能。正常情况下应该成功获取新的access token。
              </p>
              {tokenRefreshResult && (
                <div style={{
                  padding: '10px',
                  borderRadius: '4px',
                  backgroundColor: tokenRefreshResult.message.includes('success') ? '#d4edda' : '#f8d7da',
                  color: tokenRefreshResult.message.includes('success') ? '#155724' : '#721c24',
                  marginTop: '10px'
                }}>
                  <strong>{tokenRefreshResult.message}</strong>
                  {tokenRefreshResult.accessTokenExpiresIn > 0 && (
                    <div style={{ marginTop: '5px', fontSize: '14px' }}>
                      Access Token有效期: {Math.floor(tokenRefreshResult.accessTokenExpiresIn / 60)}分钟<br/>
                      Refresh Token有效期: {Math.floor(tokenRefreshResult.refreshTokenExpiresIn / 86400)}天
                    </div>
                  )}
                </div>
              )}
            </div>

            {/* 模拟Token过期测试 */}
            <div style={{
              padding: '15px',
              border: '1px solid #ddd',
              borderRadius: '5px'
            }}>
              <div style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                marginBottom: '10px'
              }}>
                <h3 style={{ margin: 0, color: '#333' }}>模拟Token过期测试</h3>
                <button
                  onClick={async () => {
                    // 模拟token过期
                    setTokenValidationLoading('simulateExpiry');
                    try {
                      // 获取当前token
                      const currentToken = localStorage.getItem('accessToken');
                      if (!currentToken) {
                        throw new Error('No access token found');
                      }

                      // 解析token
                      const payload = JSON.parse(atob(currentToken.split('.')[1]));
                      // 修改过期时间为1分钟前
                      payload.exp = Math.floor(Date.now() / 1000) - 60;
                      // 重新编码token（注意：这里只是模拟，实际token需要签名）
                      const modifiedPayload = btoa(JSON.stringify(payload));
                      const modifiedToken = currentToken.split('.')[0] + '.' + modifiedPayload + '.' + currentToken.split('.')[2];
                      // 保存修改后的token
                      localStorage.setItem('accessToken', modifiedToken);
                      
                      console.log('Token expiry simulated');
                      
                      // 触发自动刷新
                      setTimeout(async () => {
                        try {
                          await AuthService.refreshToken();
                          console.log('Token automatically refreshed');
                          // 重新加载用户信息
                          window.location.reload();
                        } catch (error) {
                          console.error('Token refresh failed:', error);
                        } finally {
                          setTokenValidationLoading(null);
                        }
                      }, 1000);
                    } catch (error) {
                      console.error('Failed to simulate token expiry:', error);
                      setTokenValidationLoading(null);
                    }
                  }}
                  disabled={tokenValidationLoading === 'simulateExpiry'}
                  style={{
                    backgroundColor: '#ffc107',
                    color: '#212529',
                    border: 'none',
                    padding: '8px 16px',
                    borderRadius: '4px',
                    cursor: tokenValidationLoading === 'simulateExpiry' ? 'not-allowed' : 'pointer',
                    opacity: tokenValidationLoading === 'simulateExpiry' ? 0.6 : 1
                  }}
                >
                  {tokenValidationLoading === 'simulateExpiry' ? '模拟中...' : '模拟Token过期'}
                </button>
              </div>
              <p style={{ margin: '5px 0', color: '#666', fontSize: '14px' }}>
                测试Token过期后自动刷新功能。点击按钮后，系统会模拟token过期并触发自动刷新流程。
              </p>
              {tokenValidationLoading === 'simulateExpiry' && (
                <div style={{
                  padding: '10px',
                  borderRadius: '4px',
                  backgroundColor: '#fff3cd',
                  color: '#856404',
                  marginTop: '10px'
                }}>
                  <strong>🔄 模拟Token过期中...</strong>
                  <p style={{ marginTop: '5px', marginBottom: 0 }}>正在模拟token过期并触发自动刷新流程，请稍候...</p>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* 登出按钮 */}
        <div style={{ textAlign: 'center' }}>
          <button
            onClick={logout}
            style={{
              backgroundColor: '#dc3545',
              color: 'white',
              border: 'none',
              padding: '12px 30px',
              borderRadius: '5px',
              fontSize: '16px',
              fontWeight: 'bold',
              cursor: 'pointer',
              transition: 'background-color 0.3s'
            }}
            onMouseOver={(e) => {
              e.currentTarget.style.backgroundColor = '#c82333';
            }}
            onMouseOut={(e) => {
              e.currentTarget.style.backgroundColor = '#dc3545';
            }}
          >
            登出
          </button>
        </div>
    </div>
  );
}