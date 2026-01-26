// TypeScript类型定义

export interface User {
  id?: number;
  username?: string;
  email?: string;
  displayName?: string;
  avatarUrl?: string;
  provider: 'google' | 'github' | 'x' | 'local' | 'unknown';  // ✅ X API v2：提供者名改为 'x'
  authenticated?: boolean;
  userName?: string;
  userEmail?: string;
  userId?: string;
  userAvatar?: string;
  providerInfo?: {
    // Google特有
    sub?: string;
    // GitHub特有
    htmlUrl?: string;
    publicRepos?: number;
    followers?: number;
    // Twitter特有
    location?: string;
    verified?: boolean;
    description?: string;
  };
}

export interface ApiResponse<T> {
  data?: T;
  error?: string;
}

export interface TokenValidationResult {
  valid: boolean;
  user?: any;
  error?: string;
}

export interface LoginProvider {
  name: 'google' | 'github' | 'x';  // ✅ X API v2：提供者名改为 'x'
  displayName: string;
  color: string;
  icon: string;
}

export interface TokenRefreshResult {
  message: string;
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresIn: number;
  refreshTokenExpiresIn: number;
  tokenType?: string;
}
