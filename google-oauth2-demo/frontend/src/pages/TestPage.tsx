import { useState, useEffect } from 'react';
import { AuthService } from '../services/authService';
import { User } from '../types';

interface TokenValidationResult {
  valid: boolean;
  error?: string;
  [key: string]: any;
}

export default function TestPage() {
  const [user, setUser] = useState<User | null>(null);
  const [authLoading, setAuthLoading] = useState(true);
  const [tokenValidationLoading, setTokenValidationLoading] = useState<string | null>(null);

  // 暂时保留authLoading以备将来使用
  console.log(authLoading);

  // 检查认证状态
  useEffect(() => {
    const checkAuth = async () => {
      try {
        const userData = await AuthService.getCurrentUser();
        setUser(userData);
      } catch (err) {
        setUser(null);
        // 如果未认证，重定向到登录页面
        window.location.href = '/login';
      } finally {
        setAuthLoading(false);
      }
    };

    checkAuth();
  }, []);

  const logout = async () => {
    try {
      setAuthLoading(true);
      await AuthService.logout();
      setUser(null);
      window.location.href = '/login';
    } catch (err) {
      console.error('Logout failed:', err);
    } finally {
      setAuthLoading(false);
    }
  };
  const [googleTokenResult, setGoogleTokenResult] = useState<TokenValidationResult | null>(null);
  const [githubTokenResult, setGithubTokenResult] = useState<TokenValidationResult | null>(null);
  const [twitterTokenResult, setTwitterTokenResult] = useState<TokenValidationResult | null>(null);
  // Token验证加载状态已在上方声明

  const validateToken = async (provider: 'google' | 'github' | 'twitter') => {
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
        case 'twitter':
          result = await AuthService.validateTwitterToken();
          break;
        default:
          result = { valid: false, error: '不支持的提供商' };
      }

      switch (provider) {
        case 'google': setGoogleTokenResult(result); break;
        case 'github': setGithubTokenResult(result); break;
        case 'twitter': setTwitterTokenResult(result); break;
      }
    } catch (error) {
      const result = {
        valid: false,
        error: error instanceof Error ? error.message : '验证失败'
      };

      switch (provider) {
        case 'google': setGoogleTokenResult(result); break;
        case 'github': setGithubTokenResult(result); break;
        case 'twitter': setTwitterTokenResult(result); break;
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
        {user.provider === 'github' && user.providerInfo.htmlUrl && (
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
                {user.providerInfo.publicRepos || 0}
              </div>
              <div>
                <strong>粉丝数：</strong>
                {user.providerInfo.followers || 0}
              </div>
              <div>
                <strong>GitHub主页：</strong>
                <a
                  href={user.providerInfo.htmlUrl}
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

        {user.provider === 'twitter' && (
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
                {user.providerInfo.location || '未设置'}
              </div>
              <div>
                <strong>验证状态：</strong>
                {user.providerInfo.verified ? '已验证' : '未验证'}
              </div>
              <div>
                <strong>个人简介：</strong>
                {user.providerInfo.description || '未设置'}
              </div>
            </div>
          </div>
        )}
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
                  <strong>{googleTokenResult.valid ? '✓ Token 有效' : '✗ Token 无效'}</strong>
                  {googleTokenResult.error && (
                    <div style={{ marginTop: '5px', fontSize: '14px' }}>
                      {googleTokenResult.error}
                    </div>
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
                  <strong>{githubTokenResult.valid ? '✓ Token 有效' : '✗ Token 无效'}</strong>
                  {githubTokenResult.error && (
                    <div style={{ marginTop: '5px', fontSize: '14px' }}>
                      {githubTokenResult.error}
                    </div>
                  )}
                </div>
              )}
            </div>
          )}

          {/* Twitter Token验证 */}
          {user.provider === 'twitter' && (
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
                <h3 style={{ margin: 0, color: '#333' }}>Twitter Access Token 验证</h3>
                <button
                  onClick={() => validateToken('twitter')}
                  disabled={tokenValidationLoading === 'twitter'}
                  style={{
                    backgroundColor: '#1da1f2',
                    color: 'white',
                    border: 'none',
                    padding: '8px 16px',
                    borderRadius: '4px',
                    cursor: tokenValidationLoading === 'twitter' ? 'not-allowed' : 'pointer',
                    opacity: tokenValidationLoading === 'twitter' ? 0.6 : 1
                  }}
                >
                  {tokenValidationLoading === 'twitter' ? '验证中...' : '验证'}
                </button>
              </div>
              {twitterTokenResult && (
                <div style={{
                  padding: '10px',
                  borderRadius: '4px',
                  backgroundColor: twitterTokenResult.valid ? '#d4edda' : '#f8d7da',
                  color: twitterTokenResult.valid ? '#155724' : '#721c24'
                }}>
                  <strong>{twitterTokenResult.valid ? '✓ Token 有效' : '✗ Token 无效'}</strong>
                  {twitterTokenResult.error && (
                    <div style={{ marginTop: '5px', fontSize: '14px' }}>
                      {twitterTokenResult.error}
                    </div>
                  )}
                </div>
              )}
            </div>
          )}
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