// TypeScript类型定义

export interface User {
  authenticated: boolean;
  provider: 'google' | 'github' | 'twitter' | 'unknown';
  userName: string;
  userEmail?: string;
  userId: string;
  userAvatar?: string;
  providerInfo: {
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
  name: 'google' | 'github' | 'twitter';
  displayName: string;
  color: string;
  icon: string;
}
