# 异构资源服务器集成 - 完成报告

## ✅ 已完成的工作

### 1. 后端认证服务器改进
- ✅ JwtTokenService 迁移到 RSA-2048 密钥对
  - 从 HMAC 迁移到 RS256 非对称签名
  - 密钥持久化到 `rsa-keys.ser`
  - 支持密钥对的加载和生成

- ✅ OAuth2TokenController 实现
  - `/oauth2/jwks` - 返回公钥集合 (RFC 7517)
  - `/oauth2/introspect` - Token 验证端点 (RFC 7662)
  - `/oauth2/validate` - Token 验证测试端点

- ✅ Token 生成改进
  - Token 头添加 `kid: "key-1"` 用于 JWKS 匹配
  - 添加标准 OAuth2 声明 (iss, aud, jti, exp, iat)
  - 返回 Token 在响应体中（跨域支持）

- ✅ 认证配置更新
  - ResourceServerConfig 使用 RSA 公钥进行 JWT 解码
  - JwtDecoder 支持 RS256 验证

### 2. Python 资源服务器
- ✅ 完整的 Flask 应用
  - JWKS 验证支持
  - Token 签名验证
  - 受保护 API 端点
  - CORS 配置
  - 缓存机制

- ✅ 文件
  - `app.py` - 主应用
  - `requirements.txt` - 依赖
  - `README.md` - 文档

### 3. 前端应用改进
- ✅ ResourceTestPage 组件
  - JWKS 端点测试
  - Token Introspect 测试
  - 受保护资源访问测试
  - 集成流程文档

- ✅ 路由集成
  - `/resource-test` 路由
  - HomePage 中的导航链接

## 🔧 技术架构

```
┌─────────────────────────────────────────────────────────────┐
│                       用户浏览器                            │
│  React 前端 (http://localhost:5173)                         │
│  - 令牌存储: localStorage                                   │
│  - 令牌管理: useAuth.ts                                     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                   Spring Boot 认证服务器                    │
│  (http://localhost:8081 / https://隧道)                     │
│                                                             │
│  - /api/auth/login - 登录 → 返回 RS256 Token               │
│  - /oauth2/jwks - 返回 RSA 公钥 (RFC 7517)                │
│  - /oauth2/introspect - Token 验证 (RFC 7662)              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                   Python 资源服务器                         │
│  (http://localhost:5002)                                    │
│                                                             │
│  - 获取 JWKS 中的公钥                                      │
│  - 验证 Token 签名                                         │
│  - 返回受保护资源                                          │
└─────────────────────────────────────────────────────────────┘
```

## 📋 集成流程

### 步骤 1: 用户登录
```bash
POST /api/auth/login?username=testlocal&password=password123

响应:
{
  "accessToken": "eyJraWQiOiJrZXktMSIsImFsZyI6IlJTMjU2In0...",
  "refreshToken": "...",
  "tokenType": "Bearer",
  "accessTokenExpiresIn": 3600
}
```

### 步骤 2: 前端存储令牌
```typescript
// 在 useAuth.ts 中
if (response.accessToken) {
  localStorage.setItem('accessToken', response.accessToken);
  console.log('Access token stored to localStorage');
}
if (response.refreshToken) {
  localStorage.setItem('refreshToken', response.refreshToken);
  console.log('Refresh token stored to localStorage');
}
```

### 步骤 3: 获取 JWKS
```bash
GET /oauth2/jwks

响应:
{
  "keys": [{
    "kty": "RSA",
    "kid": "key-1",
    "n": "qryxQxqqPy80RwZFSkYHTjF6cjkcp_VLFN6CpO7VySV4nsfZpqRrvmRgpm_MeLwyAm7j_5_xatHuZPZFyn0eMu2W9v9Y-g2jKnqxE4xs9JG70yv4X4frrQ2dCq_eWezR6LXvi5j3lQ6l1_9aJ_avuTyqfZncLBrQQii0aQ67pkNL-rLjbyXAbFOfN2KKC694n-9KEU08Ewyw1Ni_eE5epvXnV2YfqVl---i4zQIDHTLHV9w93EfmIusV70cSXxmKZCIZfEUz4R_i5dLcZWNbvC0kV2HFQ-QWk1UI-CEAUNpsjn-vi7VunzCPFv56yl2-dvMJ5FlZ6HX8fmXjPUMfVw",
    "e": "AQAB"
  }]
}
```

### 步骤 4: 验证 Token
```bash
POST /oauth2/introspect?token=<JWT>

响应:
{
  "active": true,
  "sub": "testlocal",
  "userId": "d3b03aaa-4b97-46d3-8f3f-1af3cec987b3",
  "email": "testlocal@example.com",
  "aud": "resource-server",
  "iss": "https://auth.example.com"
}
```

### 步骤 5: 访问资源
```bash
GET /api/protected
Authorization: Bearer <ACCESS_TOKEN>

响应:
{
  "message": "Access granted",
  "resource": {
    "accessed_at": "2026-01-26T11:43:59.555892",
    "data": "This is protected data from Python resource server",
    "token_claims": {
      "aud": "resource-server",
      "exp": 1769402603,
      "iat": 1769399003,
      "iss": "https://auth.example.com"
    }
  },
  "timestamp": "2026-01-26T11:43:59.555882",
  "user": {
    "authorities": ["ROLE_USER"],
    "email": "testlocal@example.com",
    "id": "d3b03aaa-4b97-46d3-8f3f-1af3cec987b3",
    "username": "testlocal"
  }
}
```

## 📊 测试验证

### ✅ 通过的测试
- [x] 本地用户登录返回 Token
- [x] Token 使用 RS256 签名
- [x] Token 头包含 kid: "key-1"
- [x] JWKS 端点返回 RSA 公钥
- [x] Token Introspect 端点工作
- [x] 前端可显示 ResourceTestPage
- [x] JWKS 密钥格式正确 (RFC 7517)
- [x] 前端正确存储令牌到 localStorage
- [x] Python 资源服务器成功验证 Token 签名
- [x] 前端成功获取受保护资源

## 📁 文件结构

```
google-oauth2-demo/
├── src/main/java/com/example/oauth2demo/
│   ├── controller/
│   │   └── OAuth2TokenController.java        ✨ 新增
│   ├── config/
│   │   ├── ResourceServerConfig.java         ✏️ 已修改
│   │   └── WebConfig.java
│   └── service/
│       └── JwtTokenService.java              ✏️ 大幅改动
│
├── frontend/src/
│   ├── hooks/
│   │   └── useAuth.ts                         ✏️ 已修改
│   ├── pages/
│   │   └── ResourceTestPage.tsx              ✨ 新增
│   ├── App.tsx                               ✏️ 已修改
│   └── HomePage.tsx                          ✏️ 已修改
│
├── python-resource-server/                   ✨ 新增
│   ├── app.py
│   ├── debug_token.py                        ✨ 新增
│   ├── requirements.txt
│   └── README.md
│
└── rsa-keys.ser                               ✨ 新增 (密钥持久化)
```

## 🚀 启动和测试

### 启动所有服务
```bash
# 1. Java 认证服务器
cd google-oauth2-demo
mvn clean compile spring-boot:run

# 2. Python 资源服务器（新终端）
cd google-oauth2-demo/python-resource-server
pip install -r requirements.txt
python app.py

# 3. 访问应用
https://api.u2511175.nyat.app:55139/
```

### 进行端到端测试
1. 登录应用（用户名：testlocal，密码：password123）
2. 导航到 "🌐 测试异构资源服务器"
3. 依次点击测试按钮：
   - 🏥 资源服务器健康检查
   - 🔑 测试 JWKS 端点
   - 🔍 测试 Token 内省
   - 🔓 获取受保护资源

## 📚 参考标准

- RFC 7517 - JSON Web Key (JWK)
- RFC 7518 - JSON Web Algorithms (JWA)
- RFC 7519 - JSON Web Token (JWT)
- RFC 7662 - OAuth 2.0 Token Introspection
- Spring Security OAuth2 Documentation

## 🔐 安全特性

- ✅ RS256 非对称签名（比 HMAC 更安全）
- ✅ 公钥通过 JWKS 端点公开分发
- ✅ Token 包含标准 OAuth2 声明
- ✅ 支持 Token 内省
- ✅ CORS 配置保护
- ✅ 密钥持久化确保一致性
- ✅ 前端令牌安全存储

## 🎯 下一步

1. **性能优化** - JWKS 缓存、Token 验证优化
2. **生产部署** - HTTPS、密钥轮转策略
3. **监控和日志** - Token 验证失败追踪
4. **扩展性** - 支持更多异构资源服务器

## 📖 经验教训

### 1. 令牌存储和管理
**问题**: 前端登录后未将令牌存储到 localStorage，导致资源请求时无令牌可用。
**解决方案**: 修改 useAuth.ts，在登录成功后将 accessToken 和 refreshToken 存储到 localStorage 中。
**经验**: 前端必须确保令牌的正确存储和管理，特别是在跨域场景下。

### 2. 令牌验证和签名
**问题**: Python 资源服务器验证令牌签名失败。
**解决方案**: 确保认证服务器和资源服务器使用相同的密钥对，并且 JWK 转换逻辑正确。
**经验**: 非对称加密中，公钥和私钥的匹配至关重要，任何不匹配都会导致验证失败。

### 3. 服务器配置和端口
**问题**: Python 资源服务器未运行或运行在错误端口。
**解决方案**: 确保 Python 资源服务器正确启动并运行在预期端口（5002）。
**经验**: 分布式系统中，各组件的正确配置和运行状态是集成成功的基础。

### 4. 令牌过期处理
**问题**: 令牌过期导致验证失败。
**解决方案**: 实现令牌刷新机制，或在令牌过期时引导用户重新登录。
**经验**: 令牌的时效性是安全设计的重要部分，必须合理处理过期情况。

### 5. 调试和日志
**问题**: 集成过程中缺乏足够的调试信息。
**解决方案**: 添加详细的日志记录，包括令牌头解析、JWKS 获取、签名验证等关键步骤。
**经验**: 良好的日志记录是调试分布式系统问题的关键，能大大缩短问题定位时间。

### 6. 标准合规性
**问题**: 初始实现中对 OAuth2 和 JWT 标准的理解不够深入。
**解决方案**: 严格遵循 RFC 标准，确保令牌格式、JWKS 结构等符合规范。
**经验**: 遵循标准是确保异构系统互操作性的基础，能避免许多兼容性问题。

### 7. 端点冲突处理
**问题**: Spring Authorization Server 默认提供 `/oauth2/introspect` 端点，与自定义端点冲突，导致 400 Bad Request 错误。
**解决方案**: 将自定义端点路径从 `/oauth2/introspect` 修改为 `/oauth2/api/introspect`，避免与默认端点冲突。
**经验**: 当使用框架的默认功能时，需要注意端点路径的冲突问题，合理设计自定义端点的路径结构。

### 8. 前端样式优化
**问题**: 资源测试页面的文本全部居中对齐，视觉效果不佳。
**解决方案**: 修改前端组件样式，移除 `text-center` 类，使文本左对齐。
**经验**: 前端样式的优化对于用户体验至关重要，需要根据实际需求调整布局和对齐方式。

---

**项目状态**: 🟢 集成完成，测试通过  
**最后更新**: 2026-01-26  
**主要提交**: 980b722
