import { useState, useEffect } from 'react';
import { useAuth } from '../hooks/useAuth';

export default function LoginPage() {
  const { user, oauthLogin, localLogin, register, loading, error } = useAuth();
  const [isRegisterMode, setIsRegisterMode] = useState(false);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [formData, setFormData] = useState({
    username: '',
    email: '',
    password: '',
    displayName: ''
  });

  // 如果用户已登录，重定向到首页
  useEffect(() => {
    if (user) {
      window.location.href = '/';
    }
  }, [user]);

  const handleOAuthLogin = (provider: 'google' | 'github' | 'x') => {  // ✅ X API v2：提供者名改为 'x'
    oauthLogin(provider);
  };

  const handleLocalAuth = async (e: React.FormEvent) => {
    e.preventDefault();
    setSuccessMessage(null);

    try {
      if (isRegisterMode) {
        await register(formData);
        setSuccessMessage('注册成功！请登录。');
        setIsRegisterMode(false); // 切换到登录模式
      } else {
        await localLogin(formData.username, formData.password);
        setSuccessMessage('登录成功！正在跳转...');
        // 用户状态变化会触发重定向
      }
    } catch (err) {
      // 错误已经在useAuth中处理
    }
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value
    });
  };

  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
      padding: '20px'
    }}>
      <div style={{
        maxWidth: '450px',
        width: '100%',
        padding: '40px',
        background: 'white',
        borderRadius: '10px',
        boxShadow: '0 15px 35px rgba(0,0,0,0.1)',
        textAlign: 'center'
      }}>
        <div style={{
          background: '#ff6b6b',
          color: 'white',
          padding: '12px',
          borderRadius: '8px',
          marginBottom: '20px',
          fontSize: '16px',
          fontWeight: 'bold'
        }}>
          🚀 当前使用：React 前端实现 (Modern SPA)
        </div>

        {/* 切换标签 */}
        <div style={{
          display: 'flex',
          marginBottom: '30px',
          border: '1px solid #e0e0e0',
          borderRadius: '8px',
          overflow: 'hidden'
        }}>
          <button
            onClick={() => setIsRegisterMode(false)}
            style={{
              flex: 1,
              padding: '12px',
              border: 'none',
              background: isRegisterMode ? '#f8f9fa' : '#007bff',
              color: isRegisterMode ? '#666' : 'white',
              fontSize: '16px',
              fontWeight: 'bold',
              cursor: 'pointer',
              transition: 'all 0.3s ease'
            }}
          >
            登录
          </button>
          <button
            onClick={() => setIsRegisterMode(true)}
            style={{
              flex: 1,
              padding: '12px',
              border: 'none',
              background: isRegisterMode ? '#007bff' : '#f8f9fa',
              color: isRegisterMode ? 'white' : '#666',
              fontSize: '16px',
              fontWeight: 'bold',
              cursor: 'pointer',
              transition: 'all 0.3s ease'
            }}
          >
            注册
          </button>
        </div>

        {/* 成功信息 */}
        {successMessage && (
          <div style={{
            background: '#d4edda',
            color: '#155724',
            padding: '12px',
            borderRadius: '8px',
            marginBottom: '20px',
            fontSize: '14px',
            fontWeight: 'bold'
          }}>
            ✅ {successMessage}
          </div>
        )}

        {/* 错误信息 */}
        {error && (
          <div style={{
            background: '#f8d7da',
            color: '#721c24',
            padding: '12px',
            borderRadius: '8px',
            marginBottom: '20px',
            fontSize: '14px'
          }}>
            {error}
          </div>
        )}

        {/* 本地用户表单 */}
        <form onSubmit={handleLocalAuth} style={{ marginBottom: '30px' }}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '15px' }}>
            <input
              type="text"
              name="username"
              placeholder="用户名"
              value={formData.username}
              onChange={handleInputChange}
              required
              style={{
                padding: '12px',
                border: '1px solid #ddd',
                borderRadius: '8px',
                fontSize: '16px',
                outline: 'none'
              }}
            />

            {isRegisterMode && (
              <>
                <input
                  type="email"
                  name="email"
                  placeholder="邮箱"
                  value={formData.email}
                  onChange={handleInputChange}
                  required
                  style={{
                    padding: '12px',
                    border: '1px solid #ddd',
                    borderRadius: '8px',
                    fontSize: '16px',
                    outline: 'none'
                  }}
                />

                <input
                  type="text"
                  name="displayName"
                  placeholder="显示名称"
                  value={formData.displayName}
                  onChange={handleInputChange}
                  required
                  style={{
                    padding: '12px',
                    border: '1px solid #ddd',
                    borderRadius: '8px',
                    fontSize: '16px',
                    outline: 'none'
                  }}
                />
              </>
            )}

            <input
              type="password"
              name="password"
              placeholder="密码"
              value={formData.password}
              onChange={handleInputChange}
              required
              style={{
                padding: '12px',
                border: '1px solid #ddd',
                borderRadius: '8px',
                fontSize: '16px',
                outline: 'none'
              }}
            />

            <button
              type="submit"
              disabled={loading}
              style={{
                backgroundColor: loading ? '#ccc' : '#28a745',
                color: 'white',
                border: 'none',
                padding: '15px 20px',
                borderRadius: '8px',
                fontSize: '16px',
                fontWeight: 'bold',
                cursor: loading ? 'not-allowed' : 'pointer',
                transition: 'all 0.3s ease'
              }}
            >
              {loading ? '处理中...' : (isRegisterMode ? '注册' : '登录')}
            </button>
          </div>
        </form>

        {/* 分割线 */}
        <div style={{
          margin: '20px 0',
          position: 'relative',
          textAlign: 'center'
        }}>
          <div style={{
            borderTop: '1px solid #eee',
            position: 'absolute',
            top: '50%',
            left: 0,
            right: 0
          }}></div>
          <span style={{
            background: 'white',
            padding: '0 10px',
            color: '#666',
            fontSize: '14px'
          }}>
            或使用第三方登录
          </span>
        </div>

        {/* OAuth2登录按钮 */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
          <button
            onClick={() => handleOAuthLogin('google')}
            style={{
              backgroundColor: '#db4437',
              color: 'white',
              border: 'none',
              padding: '12px 15px',
              borderRadius: '8px',
              fontSize: '14px',
              fontWeight: 'bold',
              cursor: 'pointer',
              transition: 'all 0.3s ease',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '8px'
            }}
            onMouseOver={(e) => {
              e.currentTarget.style.backgroundColor = '#c23321';
              e.currentTarget.style.transform = 'translateY(-1px)';
            }}
            onMouseOut={(e) => {
              e.currentTarget.style.backgroundColor = '#db4437';
              e.currentTarget.style.transform = 'translateY(0)';
            }}
          >
            <span style={{ fontSize: '16px' }}>🌐</span>
            Google 登录
          </button>

          <button
            onClick={() => handleOAuthLogin('github')}
            style={{
              backgroundColor: '#24292e',
              color: 'white',
              border: 'none',
              padding: '12px 15px',
              borderRadius: '8px',
              fontSize: '14px',
              fontWeight: 'bold',
              cursor: 'pointer',
              transition: 'all 0.3s ease',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '8px'
            }}
            onMouseOver={(e) => {
              e.currentTarget.style.backgroundColor = '#1a1a1a';
              e.currentTarget.style.transform = 'translateY(-1px)';
            }}
            onMouseOut={(e) => {
              e.currentTarget.style.backgroundColor = '#24292e';
              e.currentTarget.style.transform = 'translateY(0)';
            }}
          >
            <span style={{ fontSize: '16px' }}>🐙</span>
            GitHub 登录
          </button>

          <button
            onClick={() => handleOAuthLogin('x')}
            style={{
              backgroundColor: '#1da1f2',
              color: 'white',
              border: 'none',
              padding: '12px 15px',
              borderRadius: '8px',
              fontSize: '14px',
              fontWeight: 'bold',
              cursor: 'pointer',
              transition: 'all 0.3s ease',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '8px'
            }}
            onMouseOver={(e) => {
              e.currentTarget.style.backgroundColor = '#0d8ecf';
              e.currentTarget.style.transform = 'translateY(-1px)';
            }}
            onMouseOut={(e) => {
              e.currentTarget.style.backgroundColor = '#1da1f2';
              e.currentTarget.style.transform = 'translateY(0)';
            }}
          >
            <span style={{ fontSize: '16px' }}>🐦</span>
            Twitter 登录
          </button>
        </div>

        <a
          href="/"
          style={{
            display: 'inline-block',
            marginTop: '20px',
            color: '#007bff',
            textDecoration: 'none',
            fontSize: '14px'
          }}
        >
          ← 返回首页
        </a>
      </div>
    </div>
  );
}