# 🎨 前端完整实现指南 (React + TypeScript)

**版本:** 3.0.0  
**重点:** HttpOnly Cookie + Token 管理

---

## 目录

1. [项目初始化](#项目初始化)
2. [Token 存储策略](#token-存储策略)
3. [HTTP 客户端配置](#http-客户端配置)
4. [认证 Hook](#认证-hook)
5. [登录流程](#登录流程)
6. [Token 刷新](#token-刷新)
7. [受保护路由](#受保护路由)

---

## 项目初始化

### 使用 Vite 创建项目

```bash
# 创建 React + TypeScript 项目
npm create vite@latest frontend -- --template react-ts

cd frontend

# 安装依赖
npm install
npm install axios react-router-dom
npm install -D typescript

# 启动开发服务器
npm run dev
```

### 项目结构

```
frontend/
├── src/
│   ├── api/
│   │   ├── client.ts          # HTTP 客户端配置
│   │   ├── authApi.ts         # 认证 API
│   │   └── userApi.ts         # 用户 API
│   ├── services/
│   │   ├── tokenService.ts    # Token 管理
│   │   └── storageService.ts  # LocalStorage 管理
│   ├── hooks/
│   │   ├── useAuth.ts         # 认证状态 Hook
│   │   └── useTokenRefresh.ts # Token 刷新 Hook
│   ├── pages/
│   │   ├── Login.tsx
│   │   ├── Register.tsx
│   │   ├── Dashboard.tsx
│   │   └── Profile.tsx
│   ├── components/
│   │   ├── ProtectedRoute.tsx # 路由保护
│   │   ├── Header.tsx
│   │   └── Loading.tsx
│   ├── types/
│   │   └── index.ts           # TypeScript 类型定义
│   ├── App.tsx
│   ├── main.tsx
│   └── index.css
├── .env.example
├── tsconfig.json
├── vite.config.ts
└── package.json
```

---

## Token 存储策略

### 存储方案说明

```typescript
/**
 * ✅ 我们的方案:
 *
 * 1. accessToken & refreshToken → HttpOnly Cookie
 *    └─ 后端设置，浏览器自动管理
 *    └─ JavaScript 无法访问 (XSS 防护)
 *    └─ 自动随 API 请求发送 (credentials: include)
 *
 * 2. idToken → localStorage
 *    └─ 前端手动保存，用于显示用户信息
 *    └─ JavaScript 可以访问
 *    └─ 页面刷新时从 localStorage 恢复
 */
```

### tokenService.ts

```typescript
import jwtDecode from 'jwt-decode';

interface DecodedToken {
  sub: string;
  email: string;
  name: string;
  picture?: string;
  exp: number;
  iat: number;
}

class TokenService {
  private readonly ID_TOKEN_KEY = 'idToken';
  private idToken: string | null = null;

  /**
   * 保存 Token 信息
   * ✅ accessToken 和 refreshToken 由后端设置在 HttpOnly Cookie 中
   * ✅ 我们只需保存 idToken 到 localStorage
   */
  public saveTokens(idToken: string): void {
    this.idToken = idToken;
    localStorage.setItem(this.ID_TOKEN_KEY, idToken);
    console.debug('Tokens saved (idToken in localStorage, access/refresh in Cookie)');
  }

  /**
   * 获取 idToken
   */
  public getIdToken(): string | null {
    // 如果内存中没有，尝试从 localStorage 恢复
    if (!this.idToken) {
      this.idToken = localStorage.getItem(this.ID_TOKEN_KEY);
    }
    return this.idToken;
  }

  /**
   * 检查 Token 是否有效
   */
  public isTokenValid(token: string | null): boolean {
    if (!token) return false;

    try {
      const decoded: DecodedToken = jwtDecode(token);
      const now = Math.floor(Date.now() / 1000);
      return decoded.exp > now;
    } catch (error) {
      return false;
    }
  }

  /**
   * 检查 Token 是否即将过期 (5 分钟内)
   */
  public isTokenExpiringSoon(token: string | null, minuteThreshold: number = 5): boolean {
    if (!token) return false;

    try {
      const decoded: DecodedToken = jwtDecode(token);
      const now = Math.floor(Date.now() / 1000);
      const expiresIn = (decoded.exp - now) / 60;  // 转换为分钟
      return expiresIn < minuteThreshold;
    } catch (error) {
      return false;
    }
  }

  /**
   * 解析 Token 获取用户信息
   */
  public getUserInfo(): Partial<DecodedToken> | null {
    const idToken = this.getIdToken();
    if (!idToken || !this.isTokenValid(idToken)) {
      return null;
    }

    try {
      return jwtDecode(idToken);
    } catch (error) {
      console.error('Error decoding token:', error);
      return null;
    }
  }

  /**
   * 清除所有 Token
   */
  public clearTokens(): void {
    this.idToken = null;
    localStorage.removeItem(this.ID_TOKEN_KEY);
    console.debug('Tokens cleared');
  }
}

export const tokenService = new TokenService();
```

---

## HTTP 客户端配置

### api/client.ts

```typescript
import axios, { AxiosInstance, InternalAxiosRequestConfig } from 'axios';
import { tokenService } from '../services/tokenService';

// 创建 axios 实例
const client: AxiosInstance = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'http://localhost:8080/api',
  withCredentials: true,  // ✅ 关键: 允许跨域发送 Cookie
  headers: {
    'Content-Type': 'application/json',
  },
});

/**
 * 请求拦截器
 */
client.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    // ✅ Cookie 由浏览器自动发送，无需手动添加 accessToken

    return config;
  },
  (error) => Promise.reject(error)
);

/**
 * 响应拦截器
 */
client.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;

    // 如果是 401 错误且还没有重试过
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;

      try {
        // ✅ 调用刷新 Token 端点
        // 浏览器自动发送 refreshToken Cookie
        // 后端返回新的 accessToken Cookie
        const response = await client.post('/oauth2/token', {
          grant_type: 'refresh_token',
        });

        // 后端返回的 idToken
        if (response.data.idToken) {
          tokenService.saveTokens(response.data.idToken);
        }

        // 重试原始请求
        return client(originalRequest);
      } catch (refreshError) {
        console.error('Token refresh failed, redirecting to login');
        tokenService.clearTokens();
        window.location.href = '/login';
        return Promise.reject(refreshError);
      }
    }

    return Promise.reject(error);
  }
);

export default client;
```

### api/authApi.ts

```typescript
import client from './client';
import { tokenService } from '../services/tokenService';

interface LoginResponse {
  idToken: string;
  tokenType: string;
  expiresIn: number;
  user: {
    id: number;
    username: string;
    email: string;
    displayName: string;
    avatarUrl: string;
  };
}

interface RegisterRequest {
  username: string;
  email: string;
  password: string;
  displayName: string;
}

export const authApi = {
  /**
   * 本地登录
   */
  login: async (username: string, password: string): Promise<LoginResponse> => {
    const response = await client.post<LoginResponse>('/auth/login', {
      username,
      password,
    });

    // ✅ 保存 Token
    tokenService.saveTokens(response.data.idToken);

    return response.data;
  },

  /**
   * 本地注册
   */
  register: async (data: RegisterRequest): Promise<LoginResponse> => {
    const response = await client.post<LoginResponse>('/auth/register', data);

    // ✅ 保存 Token
    tokenService.saveTokens(response.data.idToken);

    return response.data;
  },

  /**
   * 登出
   */
  logout: async (): Promise<void> => {
    try {
      await client.post('/auth/logout');
    } finally {
      tokenService.clearTokens();
    }
  },

  /**
   * 刷新 Token
   */
  refreshToken: async (): Promise<void> => {
    const response = await client.post<LoginResponse>('/oauth2/token', {
      grant_type: 'refresh_token',
    });

    // ✅ 保存新的 Token
    if (response.data.idToken) {
      tokenService.saveTokens(response.data.idToken);
    }
  },
};
```

---

## 认证 Hook

### hooks/useAuth.ts

```typescript
import { useEffect, useState } from 'react';
import { tokenService } from '../services/tokenService';
import { authApi } from '../api/authApi';

interface User {
  id: number;
  username: string;
  email: string;
  displayName: string;
  avatarUrl?: string;
}

export const useAuth = () => {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [error, setError] = useState<string | null>(null);

  /**
   * 初始化认证状态 (页面加载时)
   */
  useEffect(() => {
    const initAuth = async () => {
      try {
        setLoading(true);
        const userInfo = tokenService.getUserInfo();

        if (userInfo && tokenService.isTokenValid(tokenService.getIdToken())) {
          setUser(userInfo as User);
          setIsAuthenticated(true);
        } else {
          setIsAuthenticated(false);
          tokenService.clearTokens();
        }
      } catch (err) {
        console.error('Error initializing auth:', err);
        setError('Failed to initialize authentication');
        setIsAuthenticated(false);
      } finally {
        setLoading(false);
      }
    };

    initAuth();
  }, []);

  /**
   * 登录
   */
  const login = async (username: string, password: string) => {
    try {
      setLoading(true);
      setError(null);

      const response = await authApi.login(username, password);
      setUser(response.user);
      setIsAuthenticated(true);

      return response;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Login failed';
      setError(message);
      setIsAuthenticated(false);
      throw err;
    } finally {
      setLoading(false);
    }
  };

  /**
   * 登出
   */
  const logout = async () => {
    try {
      setLoading(true);
      await authApi.logout();
      setUser(null);
      setIsAuthenticated(false);
    } catch (err) {
      console.error('Logout error:', err);
    } finally {
      setLoading(false);
    }
  };

  return {
    user,
    loading,
    isAuthenticated,
    error,
    login,
    logout,
  };
};
```

---

## Token 刷新

### hooks/useTokenRefresh.ts

```typescript
import { useEffect, useRef } from 'react';
import { tokenService } from '../services/tokenService';
import { authApi } from '../api/authApi';

/**
 * 自动刷新 Token
 * 当 Token 即将过期时触发
 */
export const useTokenRefresh = () => {
  const timeoutRef = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    const scheduleRefresh = () => {
      // 清除已有的定时器
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }

      const idToken = tokenService.getIdToken();
      if (!idToken) {
        return;
      }

      // 计算 Token 剩余时间
      try {
        const decoded: any = require('jwt-decode').default(idToken);
        const now = Math.floor(Date.now() / 1000);
        const expiresIn = decoded.exp - now;
        const refreshBefore = 5 * 60; // 提前 5 分钟刷新

        if (expiresIn < 0) {
          // Token 已过期，清除并重定向到登录
          tokenService.clearTokens();
          window.location.href = '/login';
          return;
        }

        // 计算刷新延迟时间
        const delayMs = (expiresIn - refreshBefore) * 1000;

        timeoutRef.current = setTimeout(async () => {
          try {
            await authApi.refreshToken();
            // 刷新成功后，重新调度
            scheduleRefresh();
          } catch (error) {
            console.error('Token refresh failed:', error);
            tokenService.clearTokens();
            window.location.href = '/login';
          }
        }, Math.max(0, delayMs));
      } catch (error) {
        console.error('Error scheduling token refresh:', error);
      }
    };

    scheduleRefresh();

    // 清理函数
    return () => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
    };
  }, []);
};
```

---

## 受保护路由

### components/ProtectedRoute.tsx

```typescript
import React from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';
import { Loading } from './Loading';

interface ProtectedRouteProps {
  children: React.ReactNode;
  requiredRoles?: string[];
}

export const ProtectedRoute: React.FC<ProtectedRouteProps> = ({
  children,
  requiredRoles = [],
}) => {
  const { isAuthenticated, loading, user } = useAuth();

  if (loading) {
    return <Loading />;
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  // 如果指定了所需角色，检查用户是否具有
  if (requiredRoles.length > 0) {
    const userRoles = (user as any)?.authorities || [];
    const hasRequiredRole = requiredRoles.some((role) =>
      userRoles.includes(role)
    );

    if (!hasRequiredRole) {
      return <Navigate to="/unauthorized" replace />;
    }
  }

  return <>{children}</>;
};
```

---

## 配置环境变量

### .env.example

```bash
VITE_API_URL=http://localhost:8080/api
VITE_GOOGLE_CLIENT_ID=your-google-client-id
```

### .env.development

```bash
VITE_API_URL=http://localhost:8080/api
VITE_GOOGLE_CLIENT_ID=your-dev-google-client-id
```

### .env.production

```bash
VITE_API_URL=https://yourdomain.com/api
VITE_GOOGLE_CLIENT_ID=your-prod-google-client-id
```

---

**下一步:** 查看 [04-Database-Setup.md] 获取数据库设置
