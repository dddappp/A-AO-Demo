import { Link } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';

export default function HomePage() {
  const { isAuthenticated } = useAuth();

  return (
    <div style={{
      maxWidth: '800px',
      margin: '0 auto',
      padding: '20px',
      fontFamily: 'Arial, sans-serif'
    }}>
      <div style={{
        background: '#28a745',
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
        marginBottom: '30px'
      }}>
        React OAuth2 登录演示
      </h1>

      <div style={{
        background: 'white',
        padding: '30px',
        borderRadius: '10px',
        boxShadow: '0 2px 10px rgba(0,0,0,0.1)',
        marginBottom: '20px'
      }}>
        <p style={{
          color: '#666',
          lineHeight: '1.6',
          marginBottom: '30px',
          textAlign: 'center'
        }}>
          这是一个使用 React 构建的现代化 OAuth2 登录演示应用。<br/>
          支持 Google、GitHub 和 Twitter 三种登录方式。
        </p>

        <div style={{
          textAlign: 'center'
        }}>
          {isAuthenticated ? (
            <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
              <Link
                to="/test"
                style={{
                  display: 'inline-block',
                  backgroundColor: '#007bff',
                  color: 'white',
                  padding: '12px 30px',
                  textDecoration: 'none',
                  borderRadius: '5px',
                  fontSize: '16px',
                  fontWeight: 'bold',
                  transition: 'background-color 0.3s'
                }}
              >
                查看用户信息和Token验证 →
              </Link>
              <Link
                to="/resource-test"
                style={{
                  display: 'inline-block',
                  backgroundColor: '#9333ea',
                  color: 'white',
                  padding: '12px 30px',
                  textDecoration: 'none',
                  borderRadius: '5px',
                  fontSize: '16px',
                  fontWeight: 'bold',
                  transition: 'background-color 0.3s'
                }}
              >
                🌐 测试异构资源服务器 →
              </Link>
            </div>
          ) : (
            <Link
              to="/login"
              style={{
                display: 'inline-block',
                backgroundColor: '#28a745',
                color: 'white',
                padding: '12px 30px',
                textDecoration: 'none',
                borderRadius: '5px',
                fontSize: '16px',
                fontWeight: 'bold',
                transition: 'background-color 0.3s'
              }}
            >
              开始登录测试 →
            </Link>
          )}
        </div>
      </div>

      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))',
        gap: '20px'
      }}>
        <div style={{
          background: 'white',
          padding: '20px',
          borderRadius: '8px',
          boxShadow: '0 2px 10px rgba(0,0,0,0.1)',
          textAlign: 'center'
        }}>
          <div style={{ fontSize: '2em', marginBottom: '10px' }}>🔐</div>
          <h3 style={{ marginBottom: '10px', color: '#333' }}>安全认证</h3>
          <p style={{ color: '#666', fontSize: '14px' }}>
            支持Google、GitHub、Twitter OAuth2登录，确保用户数据安全
          </p>
        </div>

        <div style={{
          background: 'white',
          padding: '20px',
          borderRadius: '8px',
          boxShadow: '0 2px 10px rgba(0,0,0,0.1)',
          textAlign: 'center'
        }}>
          <div style={{ fontSize: '2em', marginBottom: '10px' }}>⚡</div>
          <h3 style={{ marginBottom: '10px', color: '#333' }}>现代化前端</h3>
          <p style={{ color: '#666', fontSize: '14px' }}>
            使用React构建的单页应用，提供流畅的用户体验
          </p>
        </div>

        <div style={{
          background: 'white',
          padding: '20px',
          borderRadius: '8px',
          boxShadow: '0 2px 10px rgba(0,0,0,0.1)',
          textAlign: 'center'
        }}>
          <div style={{ fontSize: '2em', marginBottom: '10px' }}>🔄</div>
          <h3 style={{ marginBottom: '10px', color: '#333' }}>Token验证</h3>
          <p style={{ color: '#666', fontSize: '14px' }}>
            完整的Token验证功能，支持JWT和OAuth2 Token
          </p>
        </div>
      </div>
    </div>
  );
}