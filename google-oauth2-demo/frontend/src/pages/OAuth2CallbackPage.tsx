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

        console.log('=== 重定向模式处理：从cookie中获取token ===');
        
        // 1. 从cookie中获取token并存储到localStorage
        console.log('1. 从cookie中获取token并存储到localStorage...');
        
        // 获取cookie的辅助函数
        const getCookie = (name: string) => {
          const value = `; ${document.cookie}`;
          const parts = value.split(`; ${name}=`);
          if (parts.length === 2) return parts.pop()?.split(';').shift();
          return null;
        };
        
        const accessToken = getCookie('accessToken');
        
        if (accessToken) {
          localStorage.setItem('accessToken', accessToken);
          console.log('Access token存储成功（从cookie获取）');
        } else {
          console.error('从cookie中获取accessToken失败，尝试调用refreshToken API...');
          // 尝试调用refreshToken API获取token
          try {
            const refreshResponse = await AuthService.refreshToken();
            console.log('Token刷新成功:', refreshResponse);
            if (refreshResponse.accessToken) {
              localStorage.setItem('accessToken', refreshResponse.accessToken);
              console.log('Access token存储成功（从API获取）');
            } else {
              throw new Error('刷新token失败：响应中没有accessToken');
            }
          } catch (error) {
            console.error('调用refreshToken API失败:', error);
            throw new Error('获取accessToken失败');
          }
        }
        
        // 2. 直接调用后端API获取用户信息
        console.log('2. 直接调用后端API获取用户信息...');
        const userData = await AuthService.getCurrentUser();
        console.log('用户信息获取成功:', userData);
        // 存储用户信息到localStorage
        localStorage.setItem('auth_user', JSON.stringify(userData));
        console.log('用户信息存储成功');
        
        // 3. 不存储refresh token到localStorage，保持在HttpOnly cookie中
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