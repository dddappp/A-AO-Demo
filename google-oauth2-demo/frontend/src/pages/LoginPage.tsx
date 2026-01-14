import { AuthService } from '../services/authService';

export default function LoginPage() {
  const handleLogin = (provider: 'google' | 'github' | 'twitter') => {
    AuthService.getLoginUrl(provider);
    // 重定向到OAuth2提供商
    window.location.href = AuthService.getLoginUrl(provider);
  };

  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)'
    }}>
      <div style={{
        maxWidth: '400px',
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

        <h1 style={{
          color: '#333',
          marginBottom: '10px',
          fontSize: '28px'
        }}>
          选择登录方式
        </h1>

        <p style={{
          color: '#666',
          marginBottom: '30px',
          fontSize: '16px'
        }}>
          请选择您喜欢的登录方式：
        </p>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '15px' }}>
          {/* Google登录按钮 */}
          <button
            onClick={() => handleLogin('google')}
            style={{
              backgroundColor: '#db4437',
              color: 'white',
              border: 'none',
              padding: '15px 20px',
              borderRadius: '8px',
              fontSize: '16px',
              fontWeight: 'bold',
              cursor: 'pointer',
              transition: 'all 0.3s ease',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '10px'
            }}
            onMouseOver={(e) => {
              e.currentTarget.style.backgroundColor = '#c23321';
              e.currentTarget.style.transform = 'translateY(-2px)';
            }}
            onMouseOut={(e) => {
              e.currentTarget.style.backgroundColor = '#db4437';
              e.currentTarget.style.transform = 'translateY(0)';
            }}
          >
            <span style={{ fontSize: '20px' }}>🌐</span>
            使用 Google 账户登录
          </button>

          {/* GitHub登录按钮 */}
          <button
            onClick={() => handleLogin('github')}
            style={{
              backgroundColor: '#24292e',
              color: 'white',
              border: 'none',
              padding: '15px 20px',
              borderRadius: '8px',
              fontSize: '16px',
              fontWeight: 'bold',
              cursor: 'pointer',
              transition: 'all 0.3s ease',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '10px'
            }}
            onMouseOver={(e) => {
              e.currentTarget.style.backgroundColor = '#1a1a1a';
              e.currentTarget.style.transform = 'translateY(-2px)';
            }}
            onMouseOut={(e) => {
              e.currentTarget.style.backgroundColor = '#24292e';
              e.currentTarget.style.transform = 'translateY(0)';
            }}
          >
            <span style={{ fontSize: '20px' }}>🐙</span>
            使用 GitHub 账户登录
          </button>

          {/* Twitter登录按钮 */}
          <button
            onClick={() => handleLogin('twitter')}
            style={{
              backgroundColor: '#1da1f2',
              color: 'white',
              border: 'none',
              padding: '15px 20px',
              borderRadius: '8px',
              fontSize: '16px',
              fontWeight: 'bold',
              cursor: 'pointer',
              transition: 'all 0.3s ease',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '10px'
            }}
            onMouseOver={(e) => {
              e.currentTarget.style.backgroundColor = '#0d8ecf';
              e.currentTarget.style.transform = 'translateY(-2px)';
            }}
            onMouseOut={(e) => {
              e.currentTarget.style.backgroundColor = '#1da1f2';
              e.currentTarget.style.transform = 'translateY(0)';
            }}
          >
            <span style={{ fontSize: '20px' }}>🐦</span>
            使用 Twitter 账户登录
          </button>
        </div>

        <div style={{
          marginTop: '30px',
          paddingTop: '20px',
          borderTop: '1px solid #eee',
          color: '#666',
          fontSize: '14px'
        }}>
          <p>这是一个OAuth2认证演示应用</p>
          <p>支持Google、GitHub和Twitter登录</p>
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