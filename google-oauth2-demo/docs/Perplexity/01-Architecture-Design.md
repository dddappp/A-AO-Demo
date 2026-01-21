# 📐 用户系统架构设计（完整版）

**版本:** 3.0.0 - Spring Authorization Server Native  
**最后更新:** 2026年1月  
**适用场景:** 自有用户 + Google SSO 的完整用户认证系统

---

## 📋 目录

1. [核心架构](#核心架构)
2. [方案对比](#方案对比)
3. [技术栈选择](#技术栈选择)
4. [三个 Token 的职责](#三个-token-的职责)
5. [HttpOnly Cookie 安全方案](#httponly-cookie-安全方案)
6. [数据库设计](#数据库设计)
7. [安全考虑](#安全考虑)

---

## 核心架构

### 整体架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                    前端应用 (React/TypeScript)                   │
│                                                                   │
│  内存存储:                                                        │
│  ├─ idToken (用户信息展示)                                       │
│  │                                                               │
│  LocalStorage:                                                   │
│  ├─ idToken (页面刷新恢复)                                       │
│  │                                                               │
│  HttpOnly Cookie (浏览器自动管理):                               │
│  ├─ accessToken (API 请求认证)                                 │
│  ├─ refreshToken (Token 刷新)                                  │
│  │                                                               │
│  关键特性:                                                        │
│  ├─ XSS 攻击无法访问 accessToken/refreshToken                   │
│  ├─ CSRF 由 SameSite=Strict 防护                               │
│  └─ 自动跨域发送 (credentials: include)                         │
└────────────────────┬──────────────────────────────────────────┘
                     │ HTTP 请求
                     │ Cookie: accessToken, refreshToken
                     │ Authorization: Bearer idToken (可选)
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│          Spring Authorization Server (授权服务器)               │
│                                                                   │
│  核心职责:                                                        │
│  ├─ OAuth2 认证 (授权码、Token 交换等)                          │
│  ├─ JWT Token 生成 & 签名                                       │
│  ├─ Google SSO 集成                                             │
│  ├─ 权限管理 (使用 Spring Security GrantedAuthority)           │
│  ├─ Token 存储 (JDBC + 数据库)                                 │
│  └─ Token 撤销 & 黑名单管理                                    │
│                                                                   │
│  内置组件:                                                        │
│  ├─ OAuth2AuthorizationServerConfiguration                      │
│  ├─ OAuth2TokenGenerator (自动生成 JWT)                        │
│  ├─ JdbcOAuth2AuthorizationService (使用数据库存储)            │
│  ├─ UserDetailsService (Spring Security)                        │
│  └─ GrantedAuthority & GrantedAuthoritiesMapper (权限映射)    │
└────────────────────┬──────────────────────────────────────────┘
                     │ /oauth2/authorize
                     │ /oauth2/token (生成 Token)
                     │ /oauth2/jwks (发布公钥)
                     │ /oauth2/revoke (撤销 Token)
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│           OAuth2 Resource Server (业务 API 服务)                │
│                                                                   │
│  核心职责:                                                        │
│  ├─ 验证 Bearer Token (使用授权服务器的公钥)                     │
│  ├─ 提取用户信息 & 权限                                         │
│  ├─ 执行业务逻辑                                                │
│  └─ 返回受保护的资源                                            │
│                                                                   │
│  受保护的端点示例:                                                │
│  ├─ GET  /api/user/me (获取当前用户信息)                       │
│  ├─ GET  /api/user/profile (用户详细信息)                      │
│  ├─ POST /api/orders (创建订单)                                │
│  ├─ PUT  /api/comments/123 (更新评论)                          │
│  └─ DELETE /api/documents/456 (删除文档)                       │
│                                                                   │
│  BearerTokenAuthenticationFilter:                                │
│  ├─ 从 Cookie 或 Authorization 头提取 Token                    │
│  ├─ 验证签名 (使用公钥)                                        │
│  ├─ 有效期检查                                                  │
│  └─ 权限提取 (claims → GrantedAuthority)                       │
└─────────────────────────────────────────────────────────────────┘
                     ↕ 数据库读写
┌─────────────────────────────────────────────────────────────────┐
│          数据库 (SQLite 开发 / PostgreSQL 生产)                 │
│                                                                   │
│  表结构:                                                          │
│  ├─ users (用户基本信息)                                        │
│  ├─ user_authorities (用户权限关联)                             │
│  ├─ oauth2_registered_client (OAuth2 客户端)                   │
│  ├─ oauth2_authorization (授权记录)                             │
│  ├─ oauth2_authorization_consent (用户授权同意)                 │
│  └─ token_blacklist (Token 黑名单)                             │
│                                                                   │
│  特性:                                                            │
│  ├─ 无需 Redis (使用数据库存储 Token)                          │
│  ├─ 所有数据持久化                                              │
│  ├─ 支持事务                                                    │
│  └─ 易于备份和恢复                                              │
└─────────────────────────────────────────────────────────────────┘
```

### 关键特性说明

#### ✅ HttpOnly Cookie 方案的优势

```javascript
// 1. XSS 防护
Attacker 无法通过以下代码访问 Token:
document.cookie  // ❌ HttpOnly Cookie 不可见
localStorage.getItem('token')  // ❌ idToken 除外

// 2. CSRF 防护 (SameSite=Strict)
跨站点请求无法自动发送 Cookie
例: <img src="https://attacker.com/steal-data">
    ❌ accessToken Cookie 不会被发送

// 3. 跨域简化
前端无需手动添加 Authorization 头
fetch(url, { credentials: 'include' })  // 自动发送 Cookie
axios.create({ withCredentials: true })  // 自动发送 Cookie

// 4. Token 刷新自动化
API 返回 Set-Cookie 响应
浏览器自动更新 accessToken Cookie
无需前端额外处理
```

#### ✅ Spring Authorization Server 的优势

```
不重新造轮子，充分利用现成方案:

✅ UserDetailsService
   ├─ 用户认证 (本地用户名/密码)
   └─ Spring Authorization Server 直接使用

✅ GrantedAuthority
   ├─ 权限管理
   ├─ 自动映射到 JWT Claims
   └─ 无需手动处理权限 Claims

✅ GrantedAuthoritiesMapper
   ├─ OAuth2 Provider 用户的权限映射
   └─ Google SSO 用户自动关联权限

✅ OAuth2TokenGenerator
   ├─ JWT 生成和签名
   ├─ 自动处理 exp, iat, jti
   └─ 支持 Token 自定义

✅ JDBC Token 存储
   ├─ 授权信息保存
   ├─ 不需要 Redis
   └─ 数据库自动持久化
```

---

## 方案对比

### 自实现 vs Spring Authorization Server

| 功能模块 | 自实现方案 | Spring Authorization Server |
|---------|---------|----------------------------|
| **Token 生成** | 手动 (JwtTokenProvider) | ✅ 自动 |
| **Token 验证** | 手动 (Filter) | ✅ 自动 (BearerTokenAuthenticationFilter) |
| **密钥管理** | 本地 secret | ✅ RSA 密钥对 + 公钥发布 |
| **用户认证** | 手动 (UserDetailsService) | ✅ 内置支持 |
| **权限管理** | 手动 (Claim 设置) | ✅ 内置 (GrantedAuthority) |
| **OAuth2 流程** | 手动 (OAuth2Client) | ✅ 完整实现 |
| **Google SSO** | 手动处理 | ✅ 配置即可 |
| **Token 刷新** | 手动实现 | ✅ 内置支持 |
| **Token 撤销** | 需要 Redis 黑名单 | ✅ JDBC 黑名单 |
| **代码行数** | ~2000 行 | ~500 行 |
| **维护成本** | 高 | 低 |
| **安全漏洞风险** | 高 | 低 (官方维护) |

### Redis vs JDBC Token 存储

| 方面 | Redis | JDBC (数据库) |
|------|-------|-------------|
| **基础设施成本** | ❌ 需要单独部署 Redis | ✅ 直接使用现有数据库 |
| **开发环境** | ❌ 需要启动 Redis 服务 | ✅ SQLite 内置，无需启动 |
| **数据持久化** | ⚠️ 可配置，但容易丢失 | ✅ 数据库自动持久化 |
| **性能** | ✅ 超快 | ⚠️ 稍慢 (但足够) |
| **故障恢复** | ❌ 数据可能丢失 | ✅ 数据库备份 |
| **维护难度** | ⚠️ 需要监控、升级、备份 | ✅ 数据库已有完整工具 |
| **扩展性** | ✅ 支持集群 | ✅ 数据库集群 |
| **成本** | ⚠️ 额外成本 | ✅ 0 额外成本 |

**结论:** 对于大多数应用，JDBC 足够。Token 操作不是性能瓶颈。

---

## 技术栈选择

### 后端

```
✅ Spring Boot 3.2+
   └─ 最新的 LTS 版本

✅ Spring Authorization Server 1.1.5+
   └─ OAuth2 + OpenID Connect 完整实现

✅ Spring Security 6.2+
   └─ 内置 GrantedAuthority 支持

✅ Spring Data JPA
   └─ ORM 框架，简化数据库操作

✅ Spring Boot OAuth2 Client
   └─ Google SSO 集成

✅ 数据库
   ├─ 开发: SQLite (零配置)
   └─ 生产: PostgreSQL (企业级)

❌ Redis
   └─ 移除！使用 JDBC 替代

❌ MySQL
   └─ 不使用。PostgreSQL 更好

依赖库:
├─ Nimbus JOSE + JWT (Spring Authorization Server 内置)
├─ Lombok (代码简化)
├─ Spring DevTools (开发体验)
└─ Spring Boot Actuator (健康检查)
```

### 前端

```
✅ React 18+
   └─ 现代 UI 框架

✅ TypeScript
   └─ 类型安全

✅ Vite
   └─ 快速构建工具

✅ axios
   └─ HTTP 客户端 (自动处理 Cookie)

✅ react-router
   └─ 路由管理

依赖库:
├─ js-cookie (Cookie 操作)
├─ jwt-decode (解析 JWT)
└─ usehooks-ts (自定义 Hook)
```

---

## 三个 Token 的职责

### Access Token (JWT)

```json
{
  "sub": "user-123",
  "username": "john@example.com",
  "authorities": ["ROLE_USER", "ROLE_ADMIN"],
  "scope": "api profile",
  "iat": 1705840000,
  "exp": 1705843600,
  "type": "Bearer",
  "jti": "5f8c3a29-1234-5678-abcd-efgh1234ijk"
}
```

**职责:**
- ✅ 标识当前用户身份
- ✅ 包含用户权限 (authorities)
- ✅ 用于 API 请求认证
- ✅ 短期有效 (1 小时)

**存储:** HttpOnly Cookie (`accessToken`)

**使用流程:**
```
1. 前端发起 API 请求
2. 浏览器自动添加 Cookie: accessToken
3. 后端验证签名 + 有效期
4. 提取 claims → 设置 SecurityContext
5. 执行业务逻辑
6. 返回响应
```

### Refresh Token (JWT)

```json
{
  "sub": "user-123",
  "username": "john@example.com",
  "type": "REFRESH",
  "iat": 1705840000,
  "exp": 1705927200,
  "jti": "7g9d4b30-5678-9012-bcde-fghijk1234lm"
}
```

**职责:**
- ✅ 用于获取新的 access token
- ✅ 长期有效 (7 天)
- ✅ 支持 Token 轮转 (每次刷新生成新 token)
- ✅ 可被撤销 (加入黑名单)

**存储:** HttpOnly Cookie (`refreshToken`)

**使用流程:**
```
1. 前端检测 accessToken 即将过期
2. 调用 POST /api/oauth2/token (refresh_token grant)
3. 浏览器自动发送 Cookie: refreshToken
4. 后端验证 + 检查黑名单
5. 生成新的 accessToken 和 refreshToken
6. 返回 Set-Cookie 响应
7. 浏览器自动更新 Cookie
```

**为什么需要刷新?**
```
1. Access Token 被盗时，影响范围限制在 1 小时
2. Refresh Token 只有刷新 API 才会用到
3. 支持 Token 轮转 (旧 token 自动失效)
4. 用户可以随时撤销 refreshToken (登出)
```

### ID Token (JWT)

```json
{
  "sub": "user-123",
  "username": "john@example.com",
  "email": "john@example.com",
  "name": "John Doe",
  "picture": "https://...",
  "iat": 1705840000,
  "exp": 1705843600
}
```

**职责:**
- ✅ 用户身份证明 (OpenID Connect)
- ✅ 包含用户基本信息 (不含权限)
- ✅ 用于前端显示用户信息
- ✅ 可以在前端 JavaScript 中访问 (不含敏感权限)

**存储:** localStorage (前端可读)

**为什么分离?**
```
1. accessToken 包含权限信息，必须保密
2. idToken 只含用户信息，可以公开
3. 前端需要显示用户名/头像，不能访问 accessToken
4. 三个 Token 各司其职，提高安全性
```

---

## HttpOnly Cookie 安全方案

### Cookie 配置

```yaml
# HttpOnly Cookie 标志
HttpOnly: true
  ├─ JavaScript 无法访问 (document.cookie 看不到)
  ├─ 自动防护 XSS 攻击
  └─ CSRF 攻击虽然能发送 Cookie，但 SameSite 防护

Secure: true
  ├─ 仅在 HTTPS 连接时发送
  ├─ 开发环境禁用此标志
  └─ 生产环境强制启用

SameSite: Strict
  ├─ 仅在同一站点请求时发送
  ├─ 完全防护 CSRF 攻击
  └─ 如果 SameSite=Lax，则允许顶级导航

Path: /api
  ├─ 限制 Cookie 仅对 /api 路径有效
  ├─ 其他路径无法访问
  └─ 提高安全性
```

### 防护矩阵

| 攻击类型 | HttpOnly | Secure | SameSite | 防护 |
|---------|---------|--------|----------|------|
| XSS 盗取 Token | ✅ | - | - | ✅ |
| CSRF 伪造请求 | - | - | ✅ | ✅ |
| 中间人截取 | - | ✅ | - | ✅ |
| 跨域 Cookie | - | - | ✅ | ✅ |
| Script 访问 | ✅ | - | - | ✅ |

---

## 数据库设计

### 用户表 (users)

```sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255),
    display_name VARCHAR(255),
    avatar_url TEXT,
    email_verified BOOLEAN DEFAULT false,
    auth_provider VARCHAR(50) DEFAULT 'LOCAL',
    provider_user_id VARCHAR(255),
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP,
    CONSTRAINT unique_provider_id UNIQUE (auth_provider, provider_user_id)
);
```

**字段说明:**
- `username`: 本地用户名 (邮箱)
- `password_hash`: BCrypt 加密密码 (仅本地用户)
- `auth_provider`: LOCAL 或 GOOGLE
- `provider_user_id`: OAuth2 provider 的用户 ID (仅 OAuth2 用户)
- `email_verified`: 邮箱是否已验证

### 权限表 (user_authorities)

```sql
CREATE TABLE user_authorities (
    user_id BIGINT NOT NULL,
    authority VARCHAR(50) NOT NULL,
    PRIMARY KEY (user_id, authority),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

**权限说明:**
- `ROLE_USER`: 普通用户
- `ROLE_ADMIN`: 管理员
- `ROLE_MODERATOR`: 版主

### OAuth2 表 (Spring Authorization Server)

```sql
CREATE TABLE oauth2_authorization (
    id VARCHAR(100) PRIMARY KEY,
    registered_client_id VARCHAR(100) NOT NULL,
    principal_name VARCHAR(255) NOT NULL,
    authorization_grant_type VARCHAR(100),
    authorized_scopes VARCHAR(1000),
    
    access_token_value BYTEA,
    access_token_issued_at TIMESTAMP,
    access_token_expires_at TIMESTAMP,
    access_token_type VARCHAR(100),
    
    refresh_token_value BYTEA,
    refresh_token_issued_at TIMESTAMP,
    refresh_token_expires_at TIMESTAMP,
    
    oidc_id_token_value BYTEA,
    oidc_id_token_issued_at TIMESTAMP,
    oidc_id_token_expires_at TIMESTAMP,
    
    FOREIGN KEY (registered_client_id) REFERENCES oauth2_registered_client(id)
);
```

### Token 黑名单表 (token_blacklist)

```sql
CREATE TABLE token_blacklist (
    id BIGSERIAL PRIMARY KEY,
    jti VARCHAR(255) UNIQUE NOT NULL,
    token_type VARCHAR(50),
    user_id BIGINT,
    expires_at TIMESTAMP NOT NULL,
    blacklisted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reason VARCHAR(255),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);
```

---

## 安全考虑

### 认证安全

```
✅ 密码加密
   ├─ 使用 BCrypt (自适应算法)
   ├─ 盐值自动生成
   ├─ 密码长度至少 8 字符
   └─ 支持特殊字符

✅ 登录尝试限制
   ├─ 失败 5 次后锁定 15 分钟
   ├─ 记录登录失败事件
   ├─ 异常登录告警
   └─ IP 限制

✅ Token 安全
   ├─ 使用 RSA 密钥对 (非对称加密)
   ├─ 公钥公开发布 (/oauth2/jwks)
   ├─ 私钥安全存储
   ├─ 定期轮转密钥
   └─ Token 有效期短 (1 小时)
```

### 传输安全

```
✅ HTTPS 强制
   ├─ 生产环境强制 HTTPS
   ├─ HTTP 重定向到 HTTPS
   ├─ HSTS 头部设置
   └─ 证书有效期监控

✅ CORS 配置
   ├─ 明确指定允许的源
   ├─ 不使用 "*"
   ├─ 允许 credentials
   └─ 允许必要的 HTTP 方法

✅ 请求签名
   ├─ 使用 CSRF Token (可选，SameSite 足够)
   ├─ 验证 Origin 头部
   ├─ 验证 Referer 头部
   └─ 请求签名验证
```

### 数据安全

```
✅ SQL 注入防护
   ├─ 使用 Spring Data JPA (自动参数化)
   ├─ 避免字符串拼接 SQL
   ├─ JPA Query Methods 类型安全
   └─ 输入验证

✅ 数据加密
   ├─ 敏感数据加密存储
   ├─ 传输时 HTTPS 加密
   ├─ 密钥妥善保管
   └─ 定期轮转密钥

✅ 审计日志
   ├─ 记录登录事件
   ├─ 记录敏感操作
   ├─ 不记录密码
   └─ 定期审计报告
```

---

**下一步:** 查看 [02-Backend-Implementation.md] 获取完整的代码实现
