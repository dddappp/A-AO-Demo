import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { AuthService } from '../services/authService';

/**
 * OAuth2 回调页面
 * 处理SSO登录后的回调，提取并存储Token
 */
const OAuth2CallbackPage = () => {
  const navigate = useNavigate();

  useEffect(() => {
    const handleCallback = async () => {
      try {
        // 检查URL中是否有错误参数
        const urlParams = new URLSearchParams(window.location.search);
        const error = urlParams.get('error');
        const errorDescription = urlParams.get('error_description');

        if (error) {
          console.error('OAuth2登录失败:', error, errorDescription);
          // 重定向到登录页面并显示错误
          navigate(`/login?error=${encodeURIComponent(errorDescription || error)}`);
          return;
        }

        console.log('=== 重定向模式处理：直接调用后端API刷新token ===');
        
        // 1. 直接调用后端API获取用户信息
        console.log('1. 直接调用后端API获取用户信息...');
        const userData = await AuthService.getCurrentUser();
        console.log('用户信息获取成功:', userData);
        // 存储用户信息到localStorage
        localStorage.setItem('auth_user', JSON.stringify(userData));
        console.log('用户信息存储成功');
        
        // 2. 直接调用后端API刷新token以获取access token
        console.log('2. 直接调用后端API刷新token以获取access token...');
        const refreshResponse = await AuthService.refreshToken();
        console.log('Token刷新成功:', refreshResponse);
        
        // 3. 存储access token到localStorage（用于访问不同域的资源服务器）
        if (refreshResponse.accessToken) {
          localStorage.setItem('accessToken', refreshResponse.accessToken);
          console.log('Access token存储成功（用于访问不同域的资源服务器）');
        } else {
          console.error('刷新token失败：响应中没有accessToken');
          throw new Error('刷新token失败：响应中没有accessToken');
        }
        
        // 4. 不存储refresh token到localStorage，保持在HttpOnly cookie中
        console.log('Refresh token保持在HttpOnly cookie中，不存储到localStorage');
        
        // 检查localStorage的当前状态
        console.log('=== 检查localStorage状态 ===');
        console.log('accessToken:', localStorage.getItem('accessToken') ? 'Present' : 'Missing');
        console.log('refreshToken:', localStorage.getItem('refreshToken') ? 'Present' : 'Missing');
        console.log('auth_user:', localStorage.getItem('auth_user') ? 'Present' : 'Missing');
        
        // 处理完成后重定向到首页
        console.log('OAuth2回调处理完成，准备重定向到首页');
        navigate('/');
      } catch (error) {
        console.error('处理OAuth2回调时出错:', error);
        navigate('/login?error=Callback%20processing%20failed');
      }
    };

    handleCallback();
  }, [navigate]);

  return (
    <div style={{
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      minHeight: '100vh',
      flexDirection: 'column'
    }}>
      <div style={{ marginBottom: '20px' }}>正在处理登录...</div>
      <div style={{
        width: '40px',
        height: '40px',
        border: '4px solid #f3f3f3',
        borderTop: '4px solid #3498db',
        borderRadius: '50%',
        animation: 'spin 1s linear infinite'
      }}></div>
      <style>{`
        @keyframes spin {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
      `}</style>
    </div>
  );
};

export default OAuth2CallbackPage;