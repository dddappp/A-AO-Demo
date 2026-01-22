import axios from 'axios';
import { TokenRefreshResult } from '../types';
import { User, TokenValidationResult } from '../types';

// API基础URL - 使用相对路径，Vite代理会处理开发环境
const API_BASE_URL = (import.meta as any).env?.VITE_API_BASE_URL || '';

/**
 * 认证相关API服务
 */
export class AuthService {

  /**
   * 用户注册
   */
  static async register(data: {
    username: string;
    email: string;
    password: string;
    displayName: string;
  }): Promise<User> {
    const url = `${API_BASE_URL}/api/auth/register`;
    console.log('Register URL:', url);
    const response = await axios.post(url, data, {
      withCredentials: true
    });
    return response.data;
  }

  /**
   * 用户登录 (本地账户)
   */
  static async login(username: string, password: string): Promise<any> {
    const params = new URLSearchParams();
    params.append('username', username);
    params.append('password', password);

    const response = await axios.post(`${API_BASE_URL}/api/auth/login`, params, {
      withCredentials: true,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    });
    return response.data;
  }

  /**
   * 获取当前用户信息
   */
  static async getCurrentUser(): Promise<User> {
    const response = await axios.get(`${API_BASE_URL}/api/user`, {
      withCredentials: true,
      headers: {
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache'
      },
      params: {
        _t: Date.now() // 添加时间戳参数避免缓存
      }
    });
    return response.data;
  }

  /**
   * 刷新JWT Token
   */
  static async refreshToken(): Promise<TokenRefreshResult> {
    const response = await axios.post(`${API_BASE_URL}/api/auth/refresh`, {}, {
      withCredentials: true,
      headers: {
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache'
      }
    });
    return response.data;
  }

  /**
   * 用户登出
   */
  static async logout(): Promise<void> {
    await axios.post(`${API_BASE_URL}/api/auth/logout`, {}, {
      withCredentials: true
    });
  }

  /**
   * 验证Google Token
   */
  static async validateGoogleToken(): Promise<TokenValidationResult> {
    const response = await axios.post(`${API_BASE_URL}/api/validate-google-token`,
      {},
      {
        withCredentials: true
      }
    );
    return response.data;
  }

  /**
   * 验证GitHub Token
   */
  static async validateGithubToken(): Promise<TokenValidationResult> {
    const response = await axios.post(`${API_BASE_URL}/api/validate-github-token`,
      {},
      {
        withCredentials: true
      }
    );
    return response.data;
  }

  /**
   * 验证Twitter Token
   */
  static async validateXToken(): Promise<TokenValidationResult> {  // ✅ X API v2：方法名更新
    const response = await axios.post(`${API_BASE_URL}/api/validate-x-token`,  // ✅ X API v2：API端点更新
      new URLSearchParams(),
      {
        withCredentials: true,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        }
      }
    );
    return response.data;
  }

  /**
   * 获取OAuth2登录URL
   */
  static getLoginUrl(provider: 'google' | 'github' | 'x'): string {  // ✅ X API v2：提供者名改为 'x'
    return `${API_BASE_URL}/oauth2/authorization/${provider}`;
  }

  /**
   * 检查用户是否已认证
   */
  static async checkAuthStatus(): Promise<boolean> {
    try {
      await this.getCurrentUser();
      return true;
    } catch (error) {
      return false;
    }
  }
}

// 配置axios默认设置
axios.defaults.withCredentials = true;

// 请求拦截器 - 添加CSRF token
axios.interceptors.request.use((config) => {
  // 从cookie中获取CSRF token
  const csrfToken = document.cookie
    .split('; ')
    .find(row => row.startsWith('XSRF-TOKEN='))
    ?.split('=')[1];

  if (csrfToken) {
    config.headers['X-XSRF-TOKEN'] = csrfToken;
  }

  return config;
});

// 响应拦截器 - 处理认证错误
axios.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // 未认证，跳转到登录页（但不在登录页面时）
      if (!window.location.pathname.includes('/login')) {
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);
