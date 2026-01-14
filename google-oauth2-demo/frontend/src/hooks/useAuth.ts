import { useState, useEffect, useCallback } from 'react';
import { User } from '../types';
import { AuthService } from '../services/authService';

/**
 * 认证状态管理Hook
 */
export function useAuth() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // 检查认证状态
  const checkAuth = useCallback(async () => {
    // 避免重复检查
    if (!loading) return;

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
    } finally {
      setLoading(false);
    }
  }, [loading]);

  // 登录
  const login = (provider: 'google' | 'github' | 'twitter') => {
    const loginUrl = AuthService.getLoginUrl(provider);
    // 重定向到OAuth2提供商
    window.location.href = loginUrl;
  };

  // 登出
  const logout = async () => {
    try {
      console.log('Starting logout process...');
      await AuthService.logout();
      console.log('Logout API call successful');
      setUser(null);
      setError(null);
      // 强制刷新页面以清除所有缓存和状态
      window.location.reload();
    } catch (err) {
      console.error('Logout failed:', err);
      // 即使登出失败，也清除本地状态并刷新页面
      setUser(null);
      window.location.reload();
    }
  };

  // 组件挂载时检查认证状态
  useEffect(() => {
    let mounted = true;

    const initAuth = async () => {
      try {
        console.log('Checking authentication status...');
        const userData = await AuthService.getCurrentUser();
        console.log('User authenticated:', userData);
        if (mounted) {
          setUser(userData);
        }
      } catch (err) {
        console.log('Authentication check failed:', err);
        if (mounted) {
          setUser(null);
          setError(err instanceof Error ? err.message : 'Authentication check failed');
        }
      } finally {
        if (mounted) {
          setLoading(false);
        }
      }
    };

    initAuth();

    return () => {
      mounted = false;
    };
  }, []); // 空依赖数组，确保只执行一次

  return {
    user,
    loading,
    error,
    login,
    logout,
    checkAuth,
    isAuthenticated: !!user
  };
}
