import { useState, useEffect, useCallback } from 'react';
import { User } from '../types';
import { AuthService } from '../services/authService';

/**
 * 认证状态管理Hook
 */
export function useAuth() {
  // 从localStorage初始化用户状态
  const [user, setUser] = useState<User | null>(() => {
    const savedUser = localStorage.getItem('auth_user');
    return savedUser ? JSON.parse(savedUser) : null;
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // 当用户状态改变时，保存到localStorage
  useEffect(() => {
    if (user) {
      localStorage.setItem('auth_user', JSON.stringify(user));
    } else {
      localStorage.removeItem('auth_user');
    }
  }, [user]);

  // 检查认证状态
  const checkAuth = useCallback(async () => {
    // 总是检查认证状态，确保与后端同步

    // 在登录页面时，不自动检查认证状态
    if (window.location.pathname.includes('/login')) {
      setLoading(false);
      return;
    }

    try {
      setError(null);
      console.log('Checking authentication status...');
      const userData = await AuthService.getCurrentUser();
      console.log('User authenticated:', userData);
      setUser(userData);
    } catch (err) {
      console.log('Authentication check failed:', err);
      setUser(null);
      setError(err instanceof Error ? err.message : 'Authentication check failed');
      // 如果在受保护页面且认证失败，重定向到登录页面
      if (!window.location.pathname.includes('/login') && !window.location.pathname.includes('/')) {
        console.log('Redirecting to login due to authentication failure');
        window.location.href = '/login';
      }
    } finally {
      setLoading(false);
    }
  }, [loading]);

  // OAuth2登录
  const oauthLogin = (provider: 'google' | 'github' | 'x') => {  // ✅ X API v2：提供者名改为 'x'
    const loginUrl = AuthService.getLoginUrl(provider);
    // 重定向到OAuth2提供商
    window.location.href = loginUrl;
  };

  // 本地用户登录
  const localLogin = async (username: string, password: string) => {
    try {
      setLoading(true);
      setError(null);

      console.log('Starting local login...');
      const response = await AuthService.login(username, password);
      console.log('Local login successful:', response);

      // 本地用户登录成功后，设置用户信息状态并存储令牌
      setUser({
        id: response.user.id,
        username: response.user.username,
        email: response.user.email,
        displayName: response.user.displayName,
        avatarUrl: response.user.avatarUrl,
        provider: 'local'
      });
      
      // 存储令牌到localStorage，用于资源服务器认证
      if (response.accessToken) {
        localStorage.setItem('accessToken', response.accessToken);
        console.log('Access token stored to localStorage');
      }
      if (response.refreshToken) {
        localStorage.setItem('refreshToken', response.refreshToken);
        console.log('Refresh token stored to localStorage');
      }
      
      setError(null);

      return response;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Local login failed';
      setError(message);
      throw err;
    } finally {
      setLoading(false);
    }
  };

  // 用户注册
  const register = async (data: {
    username: string;
    email: string;
    password: string;
    displayName: string;
  }) => {
    try {
      setLoading(true);
      setError(null);

      console.log('Starting registration...');
      const response = await AuthService.register(data);
      console.log('Registration successful:', response);

      // 注册成功后可以自动登录
      await localLogin(data.username, data.password);

      return response;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Registration failed';
      setError(message);
      throw err;
    } finally {
      setLoading(false);
    }
  };

  // 刷新Token
  const refreshToken = useCallback(async () => {
    try {
      console.log('Starting token refresh...');
      const result = await AuthService.refreshToken();
      console.log('Token refresh successful:', result);
      return result;
    } catch (error) {
      console.error('Token refresh failed:', error);
      // 如果刷新失败，说明refresh token也过期了，需要重新登录
      logout();
      throw error;
    }
  }, []);

  // 登出
  const logout = useCallback(async () => {
    console.log('Starting logout process...');

    try {
      await AuthService.logout();
      console.log('Logout API call successful');
    } catch (err) {
      console.error('Logout failed:', err);
    }

    // 立即清除前端用户状态
    setUser(null);
    setError(null);

    // 清除所有可能的用户状态存储
    localStorage.removeItem('auth_user');
    localStorage.clear(); // 清除所有localStorage

    // 清除所有cookies
    document.cookie.split(";").forEach((c) => {
      document.cookie = c.replace(/^ +/, "").replace(/=.*/, "=;expires=" + new Date().toUTCString() + ";path=/");
    });

    console.log('All storage cleared, navigating to login...');

    // 直接导航到登录页面，避免页面刷新可能带来的缓存问题
    window.location.href = '/login';
  }, []);

  // 组件挂载时检查认证状态
  useEffect(() => {
    checkAuth();
  }, []); // 空依赖数组，确保只执行一次

  return {
    user,
    loading,
    error,
    oauthLogin,
    localLogin,
    register,
    logout,
    refreshToken,
    checkAuth,
    isAuthenticated: !!user
  };
}
