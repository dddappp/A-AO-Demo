# ⚡ 快速参考手册

**版本:** 3.0.0  
**最后更新:** 2026年1月

---

## 核心概念速查

### 三个 Token

| Token | 存储 | 有效期 | 用途 | 前端可访问 |
|-------|------|--------|------|----------|
| **accessToken** | HttpOnly Cookie | 1 小时 | API 认证 | ❌ |
| **refreshToken** | HttpOnly Cookie | 7 天 | 获取新 accessToken | ❌ |
| **idToken** | localStorage | 1 小时 | 用户信息展示 | ✅ |

### Cookie 配置

```javascript
ResponseCookie
  .httpOnly(true)     // XSS 防护
  .secure(true)       // HTTPS 强制
  .sameSite("Strict") // CSRF 防护
  .path("/api")       // 路径限制
  .maxAge(3600)       // 有效期
```

---

## 项目启动

### 开发环境

```bash
# 后端 (SQLite)
cd backend
mvn spring-boot:run
# http://localhost:8080/api

# 前端 (新终端)
cd frontend
npm run dev
# http://localhost:5173

# 测试用户
# 用户名: test@example.com
# 密码: password123
```

### 生产环境

```bash
# Docker 启动
export GOOGLE_CLIENT_ID=your-id
export GOOGLE_CLIENT_SECRET=your-secret
docker-compose up -d

# 访问
# https://yourdomain.com
```

---

## 后端关键文件

### 配置文件

```
src/main/resources/
├── application.yml           # 基础配置
├── application-dev.yml       # 开发配置 (SQLite)
└── application-prod.yml      # 生产配置 (PostgreSQL)
```

### 核心类

```
src/main/java/com/example/auth/
├── config/
│   ├── AuthorizationServerConfig   # Spring Authorization Server
│   ├── ResourceServerConfig        # API 保护
│   └── CorsConfig                  # CORS 配置
├── entity/
│   ├── UserEntity                  # 用户表
│   └── TokenBlacklistEntity        # Token 黑名单
├── service/
│   ├── CustomUserDetailsService    # 用户认证
│   ├── UserService                 # 业务逻辑
│   └── TokenBlacklistService       # Token 管理
└── controller/
    └── UserController              # API 端点
```

---

## 前端关键文件

### 核心模块

```
src/
├── api/
│   ├── client.ts      # axios 配置 (withCredentials: true)
│   ├── authApi.ts     # 认证 API
│   └── userApi.ts     # 用户 API
├── services/
│   └── tokenService.ts  # Token 存储 (localStorage)
├── hooks/
│   ├── useAuth.ts       # 认证状态
│   └── useTokenRefresh.ts # 自动刷新
└── components/
    └── ProtectedRoute.tsx # 路由保护
```

### 关键配置

```typescript
// axios 必须设置
axios.create({
  withCredentials: true  // ✅ 允许发送 Cookie
});

// 前端只保存 idToken
tokenService.saveTokens(response.data.idToken);

// accessToken/refreshToken 由浏览器自动管理
```

---

## API 端点总览

### 认证端点

| 方法 | 端点 | 功能 | Cookie 响应 |
|------|------|------|----------|
| POST | `/api/auth/login` | 本地登录 | ✅ accessToken, refreshToken |
| POST | `/api/auth/register` | 注册 | ✅ accessToken, refreshToken |
| POST | `/api/auth/logout` | 登出 | ✅ 清除 Cookie |
| POST | `/oauth2/token` | 刷新 Token | ✅ 新 accessToken |

### 业务端点 (受保护)

| 方法 | 端点 | 功能 | 认证 |
|------|------|------|------|
| GET | `/api/user/me` | 获取当前用户 | 需要 accessToken |
| GET | `/api/user/profile` | 用户详情 | 需要 accessToken |
| PUT | `/api/user/profile` | 更新个人信息 | 需要 accessToken |
| POST | `/api/password/change` | 修改密码 | 需要 accessToken |

---

## 常用 SQL

### 查询用户

```sql
-- 查找用户
SELECT * FROM users WHERE email = 'user@example.com';

-- 查看用户权限
SELECT * FROM user_authorities WHERE user_id = 1;

-- 重置密码
UPDATE users SET password_hash = '$2a$10$...' WHERE id = 1;

-- 删除用户
DELETE FROM users WHERE id = 1;
```

### 查看 Token

```sql
-- 查看黑名单
SELECT * FROM token_blacklist WHERE expires_at > NOW();

-- 清理过期 Token
DELETE FROM token_blacklist WHERE expires_at < NOW();
```

---

## 开发工作流

### 1. 本地开发

```bash
# 启动后端和前端
mvn spring-boot:run  # 后端
npm run dev         # 前端

# 修改代码，自动热重载
# 后端: DevTools 自动重启
# 前端: Vite 自动更新
```

### 2. 测试

```bash
# 后端单元测试
mvn test

# 前端测试
npm test

# 集成测试
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test@example.com","password":"password123"}'
```

### 3. 打包

```bash
# 后端构建
mvn clean package -DskipTests
# target/user-auth-system-*.jar

# 前端构建
npm run build
# dist/ 目录
```

### 4. 部署

```bash
# Docker 部署
docker-compose up -d

# 查看日志
docker-compose logs -f backend

# 停止服务
docker-compose down
```

---

## 调试技巧

### 后端调试

```bash
# 启用 DEBUG 日志
export LOGGING_LEVEL_ROOT=DEBUG
export LOGGING_LEVEL_ORG_SPRINGFRAMEWORK_SECURITY=DEBUG

mvn spring-boot:run
```

### 前端调试

```typescript
// 打印 Token 信息
console.log('idToken:', tokenService.getIdToken());
console.log('userInfo:', tokenService.getUserInfo());

// 检查 Cookie
document.cookie  // 查看所有 Cookie

// 监控网络请求
// 浏览器 DevTools → Network → 查看请求头中的 Cookie
```

### 数据库调试

```bash
# PostgreSQL 连接
psql -U auth_user -d auth_db

# SQLite 连接
sqlite3 auth-dev.db

# 查看表结构
\dt           # PostgreSQL
.schema       # SQLite
```

---

## 性能优化

### 后端

```yaml
# 数据库连接池
spring:
  datasource:
    hikari:
      maximum-pool-size: 20      # 最大连接数
      minimum-idle: 5            # 最小空闲连接
      connection-timeout: 30000  # 连接超时 (ms)
```

### 前端

```typescript
// 使用 React.memo 避免不必要渲染
const UserProfile = React.memo(({ user }) => {
  return <div>{user.name}</div>;
});

// 使用 useMemo 缓存计算结果
const expiredTokens = useMemo(
  () => tokens.filter(t => isExpired(t)),
  [tokens]
);

// 懒加载路由
const Dashboard = lazy(() => import('./pages/Dashboard'));
```

---

## 安全检查清单

### 部署前检查

- [ ] 生产环境配置 (application-prod.yml)
- [ ] 启用 HTTPS (Let's Encrypt)
- [ ] 配置 CORS (明确指定源)
- [ ] 设置强密码策略
- [ ] 启用审计日志
- [ ] 配置备份策略
- [ ] 设置监控告警
- [ ] Token 有效期设置合理
- [ ] 移除调试端点 (/actuator)
- [ ] 验证 SQL 注入防护
- [ ] 检查敏感信息是否泄露
- [ ] 测试密码重置流程
- [ ] 测试 Token 刷新流程
- [ ] 测试登出后访问权限被拒

---

## 常见错误代码

| 错误 | 原因 | 解决 |
|------|------|------|
| 401 Unauthorized | Token 无效或过期 | 刷新 Token |
| 403 Forbidden | 权限不足 | 检查用户角色 |
| 400 Bad Request | 请求参数错误 | 检查 API 文档 |
| 500 Server Error | 服务器错误 | 查看后端日志 |
| CORS Error | 跨域请求被拒 | 检查 CORS 配置 |
| Cookie Not Saved | Cookie 设置错误 | 检查 withCredentials |

---

## 常用命令

### Maven

```bash
mvn clean                  # 清理构建目录
mvn compile                # 编译
mvn test                   # 测试
mvn package                # 打包
mvn spring-boot:run        # 运行
mvn spring-boot:build-image # 构建 Docker 镜像
```

### npm

```bash
npm install               # 安装依赖
npm run dev              # 开发模式
npm run build            # 生产构建
npm run preview          # 预览构建
npm test                 # 测试
```

### Docker

```bash
docker-compose up -d     # 启动
docker-compose down      # 停止
docker-compose logs -f   # 查看日志
docker-compose ps        # 查看容器状态
```

### PostgreSQL

```bash
psql -U auth_user -d auth_db          # 连接
\dt                                    # 查看表
\d users                               # 查看表结构
SELECT * FROM users;                   # 查询
\q                                     # 退出
```

---

## 文档链接

- [01-Architecture-Design.md](01-Architecture-Design.md) - 架构设计
- [02-Backend-Implementation.md](02-Backend-Implementation.md) - 后端实现
- [03-Frontend-Implementation.md](03-Frontend-Implementation.md) - 前端实现
- [04-Database-Setup.md](04-Database-Setup.md) - 数据库设置
- [05-Deployment-Guide.md](05-Deployment-Guide.md) - 部署指南

---

## 技术支持

### 常见问题

**Q: 如何修改 Token 有效期?**

A: 在 `AuthorizationServerConfig.java` 中修改:
```java
.accessTokenTimeToLive(Duration.ofHours(2))  // 修改为 2 小时
```

**Q: 如何添加新的权限?**

A: 在用户表的 `authorities` 字段添加:
```sql
INSERT INTO user_authorities (user_id, authority) 
VALUES (1, 'ROLE_ADMIN');
```

**Q: 如何禁用 Google SSO?**

A: 在 `application.yml` 中注释掉 Google 配置，或在 `SecurityConfig` 中移除 `.oauth2Login()`

**Q: 生产环境如何处理 HTTPS?**

A: 使用 Let's Encrypt 获取免费证书，配置在 Nginx 中。参见 [05-Deployment-Guide.md](05-Deployment-Guide.md)

---

**文档版本:** 3.0.0  
**最后更新:** 2026年1月  
**维护者:** Your Team
