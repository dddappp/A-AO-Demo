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
    try {
      const url = `${API_BASE_URL}/api/auth/register`;
      console.log('Register URL:', url);
      const response = await axios.post(url, data, {
        withCredentials: true
      });
      return response.data;
    } catch (error) {
      console.error('Register error:', error);
      throw this.handleApiError(error, '注册失败');
    }
  }

  /**
   * 用户登录 (本地账户)
   */
  static async login(username: string, password: string): Promise<any> {
    try {
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
    } catch (error) {
      console.error('Login error:', error);
      throw this.handleApiError(error, '登录失败');
    }
  }

  /**
   * 获取当前用户信息
   */
  static async getCurrentUser(): Promise<User> {
    try {
      // 从localStorage获取accessToken
      const accessToken = localStorage.getItem('accessToken');
      
      const response = await axios.get(`${API_BASE_URL}/api/user`, {
        withCredentials: true,
        headers: {
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          ...(accessToken && { 'Authorization': `Bearer ${accessToken}` })
        },
        params: {
          _t: Date.now() // 添加时间戳参数避免缓存
        }
      });
      return response.data;
    } catch (error) {
      console.error('Get current user error:', error);
      throw this.handleApiError(error, '获取用户信息失败');
    }
  }

  /**
   * 刷新JWT Token
   */
  static async refreshToken(): Promise<TokenRefreshResult> {
    try {
      const response = await axios.post(`${API_BASE_URL}/api/auth/refresh`, {}, {
        withCredentials: true,
        headers: {
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache'
        }
      });
      // 确保返回的是响应数据，而不是完整的响应对象
      const result = response.data || response;
      console.log('Refresh token response:', result);
      return result;
    } catch (error) {
      console.error('Refresh token error:', error);
      throw this.handleApiError(error, '刷新Token失败');
    }
  }

  /**
   * 用户登出
   */
  static async logout(): Promise<void> {
    try {
      await axios.post(`${API_BASE_URL}/api/auth/logout`, {}, {
        withCredentials: true
      });
    } catch (error) {
      console.error('Logout error:', error);
      // 登出失败不抛出错误，继续执行
    }
  }

  /**
   * 验证Google Token
   */
  static async validateGoogleToken(): Promise<TokenValidationResult> {
    try {
      const accessToken = localStorage.getItem('accessToken');
      const response = await axios.post(`${API_BASE_URL}/api/validate-google-token`,
        {},
        {
          withCredentials: true,
          headers: {
            ...(accessToken && { 'Authorization': `Bearer ${accessToken}` })
          }
        }
      );
      return response.data;
    } catch (error) {
      console.error('Validate Google token error:', error);
      throw this.handleApiError(error, '验证Google Token失败');
    }
  }

  /**
   * 验证GitHub Token
   */
  static async validateGithubToken(): Promise<TokenValidationResult> {
    try {
      const accessToken = localStorage.getItem('accessToken');
      const response = await axios.post(`${API_BASE_URL}/api/validate-github-token`,
        {},
        {
          withCredentials: true,
          headers: {
            ...(accessToken && { 'Authorization': `Bearer ${accessToken}` })
          }
        }
      );
      return response.data;
    } catch (error) {
      console.error('Validate GitHub token error:', error);
      throw this.handleApiError(error, '验证GitHub Token失败');
    }
  }

  /**
   * 验证Twitter Token
   */
  static async validateXToken(): Promise<TokenValidationResult> {  // ✅ X API v2：方法名更新
    try {
      const accessToken = localStorage.getItem('accessToken');
      const response = await axios.post(`${API_BASE_URL}/api/validate-x-token`,  // ✅ X API v2：API端点更新
        new URLSearchParams(),
        {
          withCredentials: true,
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            ...(accessToken && { 'Authorization': `Bearer ${accessToken}` })
          }
        }
      );
      return response.data;
    } catch (error) {
      console.error('Validate X token error:', error);
      throw this.handleApiError(error, '验证Twitter Token失败');
    }
  }

  /**
   * 获取用户的所有登录方式
   */
  static async getLoginMethods(): Promise<any> {
    try {
      const accessToken = localStorage.getItem('accessToken');
      const response = await axios.get(`${API_BASE_URL}/api/user/login-methods`, {
        withCredentials: true,
        headers: {
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          ...(accessToken && { 'Authorization': `Bearer ${accessToken}` })
        }
      });
      return response.data;
    } catch (error) {
      console.error('Get login methods error:', error);
      throw this.handleApiError(error, '获取登录方式失败');
    }
  }

  /**
   * 删除一个登录方式
   */
  static async removeLoginMethod(methodId: number): Promise<any> {
    try {
      const accessToken = localStorage.getItem('accessToken');
      const response = await axios.delete(`${API_BASE_URL}/api/user/login-methods/${methodId}`, {
        withCredentials: true,
        headers: {
          ...(accessToken && { 'Authorization': `Bearer ${accessToken}` })
        }
      });
      return response.data;
    } catch (error) {
      console.error('Remove login method error:', error);
      throw this.handleApiError(error, '删除登录方式失败');
    }
  }

  /**
   * 设置主登录方式
   */
  static async setPrimaryLoginMethod(methodId: number): Promise<any> {
    try {
      const response = await axios.put(`${API_BASE_URL}/api/user/login-methods/${methodId}/primary`, {}, {
        withCredentials: true
      });
      return response.data;
    } catch (error) {
      console.error('Set primary login method error:', error);
      throw this.handleApiError(error, '设置主登录方式失败');
    }
  }

  /**
   * 为SSO用户添加本地登录方式
   */
  static async addLocalLoginMethod(username: string, password: string, passwordConfirm: string): Promise<any> {
    try {
      const response = await axios.post(`${API_BASE_URL}/api/user/login-methods/add-local-login`, {
        username,
        password,
        passwordConfirm
      }, {
        withCredentials: true
      });
      return response.data;
    } catch (error) {
      console.error('Add local login method error:', error);
      throw this.handleApiError(error, '添加本地登录方式失败');
    }
  }

  /**
   * 处理API错误，返回更友好的错误信息
   */
  private static handleApiError(error: any, defaultMessage: string): Error {
    if (error.response) {
      // 服务器返回错误状态码
      const errorData = error.response.data;
      const errorMessage = errorData.error || errorData.message || defaultMessage;
      return new Error(errorMessage);
    } else if (error.request) {
      // 请求已发送但没有收到响应
      return new Error('网络错误，请检查您的网络连接');
    } else {
      // 请求配置出错
      return new Error(defaultMessage);
    }
  }

  /**
   * 获取OAuth2登录URL
   */
  static getLoginUrl(provider: 'google' | 'github' | 'x'): string {  // ✅ X API v2：提供者名改为 'x'
    const state = {
      response_type: 'redirect',
      redirect_uri: '/'  // 登录成功后重定向到首页
    };
    const stateParam = encodeURIComponent(JSON.stringify(state));
    const baseUrl = `${API_BASE_URL}/oauth2/authorization/${provider}?state=${stateParam}`;
    console.log('OAuth2 login URL:', baseUrl);
    return baseUrl;
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

// 响应拦截器 - 处理认证错误和SSO登录回调
axios.interceptors.response.use(
  (response) => {
    // 检查是否是SSO登录成功的响应或token刷新成功的响应
    if (response.data && response.data.accessToken) {
      console.log('Token获取成功，存储Token...');
      // 存储Token到localStorage，用于前端测试和异构资源服务器集成
      if (response.data.accessToken) {
        localStorage.setItem('accessToken', response.data.accessToken);
      }
      // 不要存储refreshToken到localStorage，保持在HttpOnly cookie中
      // 存储用户信息
      if (response.data.user) {
        localStorage.setItem('auth_user', JSON.stringify(response.data.user));
      }
    }
    return response;
  },
  async (error) => {
    // 在登录页面时，不尝试刷新token，直接返回错误
    if (window.location.pathname.includes('/login')) {
      return Promise.reject(error);
    }
    
    if (error.response?.status === 401) {
      // 尝试刷新token
      try {
        console.log('Token过期，尝试刷新...');
        const refreshResponse = await axios.post(`${API_BASE_URL}/api/auth/refresh`, {}, {
          withCredentials: true,
          headers: {
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache'
          }
        });
        
        if (refreshResponse.data && refreshResponse.data.accessToken) {
          console.log('Token刷新成功，重新发起请求...');
          // 存储新token
          localStorage.setItem('accessToken', refreshResponse.data.accessToken);
          if (refreshResponse.data.user) {
            localStorage.setItem('auth_user', JSON.stringify(refreshResponse.data.user));
          }
          
          // 重新发起失败的请求
          const originalRequest = error.config;
          originalRequest.headers['Authorization'] = `Bearer ${refreshResponse.data.accessToken}`;
          return axios(originalRequest);
        }
      } catch (refreshError) {
        console.error('Token刷新失败，跳转到登录页...', refreshError);
        // 刷新失败，跳转到登录页
        if (!window.location.pathname.includes('/login')) {
          window.location.href = '/login';
        }
        // 清除localStorage中的用户状态
        localStorage.removeItem('auth_user');
        localStorage.removeItem('accessToken');
        localStorage.removeItem('refreshToken');
      }
    }
    return Promise.reject(error);
  }
);
