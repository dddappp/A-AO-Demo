import axios from 'axios';
import { User, TokenValidationResult } from '../types';

// API基础URL - 在单体应用模式下使用相对路径
const API_BASE_URL = (import.meta as any).env?.VITE_API_BASE_URL || 'https://api.u2511175.nyat.app:55139';

/**
 * 认证相关API服务
 */
export class AuthService {

  /**
   * 获取当前用户信息
   */
  static async getCurrentUser(): Promise<User> {
    const response = await axios.get(`${API_BASE_URL}/api/user`, {
      withCredentials: true
    });
    return response.data;
  }

  /**
   * 用户登出
   */
  static async logout(): Promise<void> {
    await axios.post(`${API_BASE_URL}/api/logout`, {}, {
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
  static async validateTwitterToken(): Promise<TokenValidationResult> {
    const response = await axios.post(`${API_BASE_URL}/api/validate-twitter-token`,
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
  static getLoginUrl(provider: 'google' | 'github' | 'twitter'): string {
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
      // 未认证，跳转到登录页
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);
