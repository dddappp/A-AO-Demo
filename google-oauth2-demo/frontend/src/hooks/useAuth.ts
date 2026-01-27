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

  // 检查认证状态
  const checkAuth = useCallback(async () => {
    // 在登录页面时，不自动检查认证状态
    if (window.location.pathname.includes('/login')) {
      setLoading(false);
      return;
    }

    try {
      setError(null);
      console.log('Checking authentication status...');
      
      // 首先从cookie中获取token并存储到localStorage
      // 这样可以确保SSO登录后token也能被正确存储
      const getCookie = (name: string) => {
        const value = `; ${document.cookie}`;
        const parts = value.split(`; ${name}=`);
        if (parts.length === 2) return parts.pop()?.split(';').shift();
        return null;
      };
      
      console.log('Current cookies:', document.cookie);
      
      const accessToken = getCookie('accessToken');
      const refreshToken = getCookie('refreshToken');
      
      console.log('Access token from cookie:', accessToken ? 'Present' : 'Missing');
      console.log('Refresh token from cookie:', refreshToken ? 'Present' : 'Missing');
      
      if (accessToken) {
        localStorage.setItem('accessToken', accessToken);
        console.log('Stored access token from cookie to localStorage');
      } else {
        console.log('No access token found in cookie');
        // 尝试调用refreshToken API获取token
        try {
          console.log('Attempting to refresh token...');
          const refreshResponse = await AuthService.refreshToken();
          console.log('Token refresh response:', refreshResponse);
          if (refreshResponse.accessToken) {
            localStorage.setItem('accessToken', refreshResponse.accessToken);
            console.log('Stored access token from API to localStorage');
          }
        } catch (error) {
          console.log('Token refresh failed:', error);
          // 如果token刷新失败，跳转到登录页面
          if (!window.location.pathname.includes('/login')) {
            console.log('Redirecting to login due to token refresh failure');
            window.location.href = '/login';
          }
          setLoading(false);
          return;
        }
      }
      
      if (refreshToken) {
        localStorage.setItem('refreshToken', refreshToken);
        console.log('Stored refresh token from cookie to localStorage');
      }
      
      console.log('LocalStorage after cookie check:', {
        accessToken: localStorage.getItem('accessToken') ? 'Present' : 'Missing',
        refreshToken: localStorage.getItem('refreshToken') ? 'Present' : 'Missing',
        auth_user: localStorage.getItem('auth_user') ? 'Present' : 'Missing'
      });
      
      // 然后尝试获取用户信息
      const userData = await AuthService.getCurrentUser();
      console.log('User authenticated:', userData);
      setUser(userData);
    } catch (err) {
      console.log('Authentication check failed:', err);
      setUser(null);
      setError(err instanceof Error ? err.message : 'Authentication check failed');
      // 如果在受保护页面且认证失败，重定向到登录页面
      if (!window.location.pathname.includes('/login')) {
        console.log('Redirecting to login due to authentication failure');
        window.location.href = '/login';
      }
    } finally {
      setLoading(false);
    }
  }, []);

  // 解析JWT token，获取过期时间
  const getTokenExpiry = useCallback(() => {
    const token = localStorage.getItem('accessToken');
    if (!token) return null;

    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      return payload.exp * 1000; // 转换为毫秒
    } catch (error) {
      console.error('Failed to parse token:', error);
      return null;
    }
  }, []);

  // 检查token是否即将过期（剩余时间少于5分钟）
  const isTokenExpiring = useCallback(() => {
    const expiry = getTokenExpiry();
    if (!expiry) return true;

    const now = Date.now();
    const timeUntilExpiry = expiry - now;
    return timeUntilExpiry < 5 * 60 * 1000; // 5分钟
  }, [getTokenExpiry]);

  // 刷新Token
  const refreshToken = useCallback(async () => {
    try {
      console.log('Starting token refresh...');
      const result = await AuthService.refreshToken();
      console.log('Token refresh successful:', result);
      
      // 存储新令牌到localStorage，用于前端测试和异构资源服务器集成
      if (result.accessToken) {
        localStorage.setItem('accessToken', result.accessToken);
      }
      if (result.refreshToken) {
        localStorage.setItem('refreshToken', result.refreshToken);
      }
      
      return result;
    } catch (error) {
      console.error('Token refresh failed:', error);
      // 如果刷新失败，说明refresh token也过期了，需要重新登录
      logout();
      throw error;
    }
  }, [logout]);

  // 自动刷新token
  const autoRefreshToken = useCallback(async () => {
    // 在登录页面时，不自动刷新token
    if (window.location.pathname.includes('/login')) {
      return;
    }
    
    if (isTokenExpiring()) {
      try {
        console.log('Token is expiring, refreshing...');
        const result = await AuthService.refreshToken();
        console.log('Token refresh successful:', result);

        // 存储新令牌到localStorage，用于前端测试和异构资源服务器集成
        if (result.accessToken) {
          localStorage.setItem('accessToken', result.accessToken);
        }
        if (result.refreshToken) {
          localStorage.setItem('refreshToken', result.refreshToken);
        }

        // 刷新token后，重新获取用户信息以确保状态同步
        await checkAuth();
      } catch (error) {
        console.error('Auto token refresh failed:', error);
        // 刷新失败，清除用户状态并跳转到登录页
        logout();
      }
    }
  }, [isTokenExpiring, logout, checkAuth]);

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
      
      // 存储令牌到localStorage，用于前端测试和异构资源服务器集成
      if (response.accessToken) {
        localStorage.setItem('accessToken', response.accessToken);
      }
      if (response.refreshToken) {
        localStorage.setItem('refreshToken', response.refreshToken);
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

  // 自动刷新token的定时器
  useEffect(() => {
    if (user) {
      // 设置定时器，每1分钟检查一次
      const intervalId = setInterval(autoRefreshToken, 60 * 1000); // 1分钟

      // 清除定时器
      return () => clearInterval(intervalId);
    }
  }, [user, autoRefreshToken]);

  // 检查URL参数中的错误信息
  useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search);
    const errorParam = urlParams.get('error');
    if (errorParam) {
      setError(decodeURIComponent(errorParam));
      // 清除URL中的错误参数，避免刷新页面后再次显示错误
      const newUrl = new URL(window.location.href);
      newUrl.searchParams.delete('error');
      window.history.replaceState({}, '', newUrl.toString());
    }
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