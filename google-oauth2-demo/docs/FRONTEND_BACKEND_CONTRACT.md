# 前后端分离架构与前后端契约文档

## 1. 问题背景

本项目采用前后端分离的架构，虽然目前支持 Thymeleaf 测试页面，但这不是主流方向，不是我们主要支持的方向。在分析代码时发现了以下问题：

### 1.1 SecurityConfig.java 中的重定向问题
- 使用 `response.sendRedirect()` 进行重定向，无法通过消息体返回 accessToken
- 仅设置了 HTTP-only cookie，确保了安全性
- 适用于浏览器直接访问的场景，不适用于跨域的资源服务器访问

### 1.2 前后端契约不明确
- 没有文档描述前后端之间的"契约"
- 集成我们认证/授权服务的项目需要自己实现前端页面
- 缺乏对前后端分离架构下如何处理认证和授权的明确指导

## 2. 前后端分离架构分析

### 2.1 现有代码中的重定向和转发

通过搜索代码，发现以下涉及重定向和转发的地方：

| 文件 | 代码 | 用途 | 类型 |
|------|------|------|------|
| SecurityConfig.java | `response.sendRedirect("/?message=binding_success")` | 绑定成功后的重定向 | 项目特定配置 |
| SecurityConfig.java | `response.sendRedirect("/")` | React SPA 登录成功后的重定向 | 项目特定配置 |
| SecurityConfig.java | `response.sendRedirect("/test")` | Thymeleaf 页面登录成功后的重定向 | 项目特定配置 |
| SecurityConfig.java | `response.sendRedirect("/?error=" + errorMsg)` | 错误处理重定向 | 项目特定配置 |
| SecurityConfig.java | `response.sendRedirect("/?error=oauth2_processing_failed")` | OAuth2 处理失败重定向 | 项目特定配置 |
| SpaController.java | `return "forward:/index.html"` | SPA 路由处理，转发到 index.html | 项目特定配置 |
| SpaController.java | `return "redirect:/"` | 非 React 前端类型的重定向 | 项目特定配置 |

### 2.2 项目特定配置分析

**SpaController.java** 中的转发和重定向：
- **目的**：用于处理 React SPA 的客户端路由，确保所有前端路由都能正确加载 React 应用
- **配置方式**：通过 `app.frontend.type` 配置项决定前端类型
- **影响范围**：仅影响当前项目的前端路由处理，不影响集成项目
- **合理性**：这些操作是合理的，因为它们是为了支持 React SPA 的客户端路由机制
- **建议**：保持不变，集成项目可以根据需要修改 `frontendType` 配置

**SecurityConfig.java** 中的重定向：
- **目的**：用于 OAuth2 登录成功后的页面跳转、绑定成功后的反馈、错误处理等
- **问题**：在前后端分离架构下，这些重定向操作存在以下问题：
  1. 无法通过消息体返回 accessToken，不适用于跨域资源服务器访问
  2. 通过 URL 参数传递错误信息，不符合 RESTful API 设计规范
  3. 后端主导前端页面跳转，不符合前后端分离的核心原则
- **建议**：对于集成项目，后端应该提供 JSON 响应而不是重定向，同时保留项目特定的重定向配置以支持当前的 demo 前端

### 2.3 前后端分离的核心问题

1. **重定向 vs. JSON 响应**：在前后端分离架构中，后端不应该主导前端的页面跳转，而应该通过 JSON 响应返回状态和数据
2. **Token 传递方式**：需要同时支持 HTTP-only cookie（安全性）和 JSON 响应体（跨域支持）
3. **前端路由控制**：前端应该完全控制自己的路由，后端只负责 API 响应
4. **错误处理**：后端应该通过 HTTP 状态码和 JSON 响应体返回错误信息，而不是通过 URL 参数传递错误信息

## 3. 前后端契约设计

### 3.1 核心原则

1. **API 优先**：后端以 RESTful API 为核心，不依赖前端技术栈
2. **状态通过 JSON 传递**：所有认证状态、错误信息等都通过 JSON 响应体传递
3. **Token 双重传递**：同时通过 HTTP-only cookie 和 JSON 响应体传递 token
4. **前端路由自主**：前端完全控制页面路由，后端只负责 API 响应
5. **标准化错误处理**：使用统一的错误响应格式

### 3.2 API 接口契约

#### 3.2.1 认证相关接口

| 接口 | 方法 | 功能 | 请求体 | 成功响应 (200 OK) | 失败响应 |
|------|------|------|--------|-------------------|----------|
| `/api/auth/login` | POST | 用户名密码登录 | `{"username": "...", "password": "..."}` | `{"user": {...}, "message": "Login successful", "authenticated": true, "accessToken": "...", "refreshToken": "...", "accessTokenExpiresIn": 3600, "refreshTokenExpiresIn": 604800, "tokenType": "Bearer"}` | `{"error": "Invalid credentials"}` (401) |
| `/api/auth/refresh` | POST | 刷新 token | N/A (从 cookie 获取 refreshToken) | `{"message": "Token refreshed successfully", "accessToken": "...", "refreshToken": "...", "accessTokenExpiresIn": 3600, "refreshTokenExpiresIn": 604800, "tokenType": "Bearer"}` | `{"error": "Refresh token not found"}` (401) |
| `/api/auth/logout` | POST | 登出 | N/A | `{"message": "Logged out successfully"}` | `{"message": "Logged out with warnings"}` |
| `/api/user` | GET | 获取当前用户信息 | N/A | `{"authenticated": true, "provider": "...", "userName": "...", "userEmail": "...", "userId": "...", "userAvatar": "...", "providerInfo": {...}}` | `{"error": "User not authenticated"}` (401) |

#### 3.2.2 OAuth2 相关接口

| 接口 | 方法 | 功能 | 请求体 | 成功响应 | 失败响应 |
|------|------|------|--------|----------|----------|
| `/oauth2/authorization/{provider}` | GET | 发起第三方登录 | N/A | 重定向到第三方认证页面 | N/A |
| `/login/oauth2/callback/{provider}` | GET | 第三方登录回调 | N/A | 重定向到前端页面（保持现有重定向 URL 配置不变） | 重定向到错误页面 |

**注意**：第三方平台 SSO 的重定向 URL 是在各平台预先配置的，不能随意修改。我们保持现有的重定向 URL 配置不变，以确保已有的功能正常运行。

### 3.3 Token 传递契约

1. **HTTP-only Cookie**：用于存储 token，防止 XSS 攻击
   - Cookie 名称：`accessToken` 和 `refreshToken`
   - 属性：`HttpOnly=true`, `SameSite=Lax`, `Path=/`
   - 过期时间：accessToken 1 小时，refreshToken 7 天

2. **JSON 响应体**：用于跨域资源服务器访问
   - 字段：`accessToken` 和 `refreshToken`
   - 同时返回过期时间和 token 类型

3. **前端处理**：
   - 优先使用 HTTP-only cookie 进行认证
   - 跨域请求时，从响应体中提取 token 并在请求头中使用
   - 实现 token 自动刷新机制

### 3.4 错误处理契约

1. **HTTP 状态码**：
   - 401 Unauthorized：未认证或 token 无效
   - 403 Forbidden：无权限
   - 400 Bad Request：请求参数错误
   - 500 Internal Server Error：服务器内部错误

2. **错误响应格式**：
   ```json
   {
     "error": "错误消息",
     "details": "详细错误信息（可选）"
   }
   ```

3. **前端处理**：
   - 根据 HTTP 状态码和错误响应体进行错误处理
   - 显示用户友好的错误信息
   - 处理 token 过期等特殊情况

### 3.5 前端集成指南

1. **认证流程**：
   - 用户名密码登录：调用 `/api/auth/login`，处理响应中的 token
   - 第三方登录：重定向到 `/oauth2/authorization/{provider}`，处理回调
   - token 刷新：实现自动刷新机制，调用 `/api/auth/refresh`
   - **受保护页面访问流程**：
     1. 前端进入受保护页面
     2. 检查用户是否已登录（检查 token 是否存在且有效）
     3. 未登录：保存当前页面 URL 到状态中，引导用户到登录页面
     4. 用户选择登录方式（系统用户名/密码或外部平台 SSO）
     5. 登录成功：从状态中获取之前保存的页面 URL，自动重定向到该页面
     6. 已登录：正常访问受保护页面

2. **API 调用**：
   - 携带 token 进行认证：优先使用 cookie，跨域时使用请求头
   - 处理 401 错误：触发 token 刷新或重新登录

3. **路由控制**：
   - 前端完全控制页面路由
   - 实现登录、注册、密码重置等页面
   - 处理认证状态变化
   - **实现受保护路由**：
     - 使用路由守卫（如 React Router 的 `Navigate` 或 Vue Router 的 `beforeEach`）
     - 检查用户认证状态
     - 未认证时保存当前路由信息并重定向到登录页面
     - 登录成功后根据保存的路由信息重定向回原页面

## 4. 改进方向

### 4.1 后端改进

1. **重构 SecurityConfig.java**：
   - **保留项目特定配置**：保留现有的重定向逻辑以支持当前的 demo 前端
   - **添加 JSON 响应支持**：同时实现 JSON 响应模式，通过配置或请求头判断返回方式
   - **Token 双重传递**：无论是重定向还是 JSON 响应，都同时通过 cookie 和响应体返回 token
   - **统一错误处理**：对 JSON 请求返回标准化的错误响应，对传统请求保留 URL 参数错误传递

2. **优化 OAuth2 回调处理**：
   - **保持现有重定向 URL 配置不变**：避免破坏已有的第三方平台配置
   - **支持多种回调模式**：
     - 对于当前项目：保留重定向到前端页面的逻辑
     - 对于集成项目：支持通过状态参数指定回调方式，返回 JSON 响应
   - **减少对特定前端技术栈的依赖**：通过配置或请求参数判断前端类型
   - **实现基于状态参数的 CSRF 保护**：确保 OAuth2 流程的安全性
   - **支持前端通过状态参数传递自定义信息**：如回调页面、前端状态等

3. **SpaController 配置说明**：
   - **项目特定配置**：SpaController 中的转发和重定向是为了支持当前项目的 React SPA
   - **集成项目处理**：集成项目可以根据需要修改 `app.frontend.type` 配置，或完全重写此控制器
   - **建议**：保持此控制器不变，集成项目通过配置调整行为

4. **增强 CORS 配置**：
   - 配置全局 CORS 策略，支持跨域请求
   - 允许特定的域名访问 API
   - 允许必要的 HTTP 方法和请求头
   - 配置凭证（credentials）支持

5. **增强 API 文档**：
   - 使用 Swagger 或 SpringDoc 生成 API 文档
   - 详细描述每个接口的请求和响应格式
   - 提供示例代码

### 4.2 前端改进

1. **实现完整的认证流程**：
   - 用户名密码登录
   - 第三方登录
   - token 自动刷新
   - 登出

2. **优化用户体验**：
   - 实现加载状态
   - 友好的错误提示
   - 响应式设计

3. **增强安全性**：
   - 防止 XSS 攻击
   - 防止 CSRF 攻击
   - 安全存储 token

## 5. 集成指南

### 5.1 前端部署方式

集成"我们的项目"的前端应用有两种主要部署方式，每种方式对重定向和转发代码的执行有不同影响：

#### 5.1.1 方式一：使用专用的web服务器（如Nginx）作为反向代理

**特点**：
- 前端资源完全由Nginx提供，静态资源直接部署在Nginx上
- API请求通过反向代理转发到Spring Boot应用
- 前端路由完全由前端框架控制

**对重定向和转发代码的影响**：
- 我们的`SpaController`和相关重定向逻辑根本不会执行
- Spring Boot应用只需要处理API请求，不需要处理静态资源和前端路由
- 集成项目可以完全忽略重定向和转发代码，只关注API接口和Token传递

#### 5.1.2 方式二：直接使用Spring Boot应用作为web服务器

**特点**：
- 前端资源打包后放在Spring Boot的静态资源目录中
- Spring Boot应用同时提供API和静态资源服务
- 适合快速原型开发和小型应用
- 便于向第三方项目展示集成能力

**对重定向和转发代码的影响**：
- 我们的`SpaController`和相关重定向逻辑会执行
- 需要根据实际情况修改配置和代码

**详细实施步骤**：

1. **前端项目配置**：
   - **项目结构建议**：
     - 使用标准的React项目结构
     - 认证相关的代码放在单独的文件中，例如`src/services/authService.js`
     - 路由配置放在单独的文件中，例如`src/routes/AppRouter.jsx`
     - 组件按照功能模块化组织
   - **构建配置修改**：
     - 在React项目中，使用Vite作为构建工具时，修改`vite.config.js`文件：
       ```javascript
       // vite.config.js
       export default {
         base: './', // 使用相对路径
         // 其他配置...
       }
       ```
     - 使用Webpack作为构建工具时，修改`webpack.config.js`文件，确保输出路径配置正确
     - 确保`package.json`中的构建脚本正确，例如：
       ```json
       "scripts": {
         "build": "vite build"
       }
       ```

2. **前端资源打包**：
   - 执行构建命令，例如：`npm run build`
   - 构建完成后，会生成`dist`目录，包含所有静态资源

3. **部署到Spring Boot**：
   - 将`dist`目录中的所有文件复制到Spring Boot项目的`src/main/resources/static`目录中
   - 确保`index.html`位于`static`目录的根目录

4. **Spring Boot配置**：
   - 在`application.yml`或`application.properties`中设置：
     ```yaml
     app:
       frontend:
         type: react
     ```
   - 确保Spring Boot正确配置了静态资源目录（默认情况下，Spring Boot会自动配置`/static`、`/public`等目录）

5. **SpaController配置**：
   - 保留`SpaController`中的所有方法，确保前端路由能正确处理
   - 实际的`SpaController.java`文件包含以下方法：
     ```java
     package com.example.oauth2demo.controller;

     import org.springframework.beans.factory.annotation.Value;
     import org.springframework.stereotype.Controller;
     import org.springframework.web.bind.annotation.GetMapping;
     import org.springframework.web.bind.annotation.PathVariable;

     /**
      * SPA路由控制器
      * 处理React应用的客户端路由
      */
     @Controller
     public class SpaController {

         @Value("${app.frontend.type:react}")
         private String frontendType;

         /**
          * SPA路由处理 - 对于React应用，返回index.html
          * 这确保所有前端路由都能正确加载React应用
          */
         @GetMapping("/login")
         public String loginPage() {
             if ("react".equals(frontendType)) {
                 return "forward:/index.html";
             }
             return "redirect:/";
         }

         @GetMapping("/test")
         public String testPage() {
             if ("react".equals(frontendType)) {
                 return "forward:/index.html";
             }
             return "redirect:/";
         }

         @GetMapping("/{path:[^\\.]*}")
         public String spaRoutes(@PathVariable String path) {
             // 排除API路径、静态资源等
             if (path.startsWith("api/") || path.startsWith("oauth2/") ||
                 path.startsWith("h2-console/") || path.equals("favicon.ico")) {
                 return null; // 不处理这些路径
             }

             if ("react".equals(frontendType)) {
                 return "forward:/index.html";
             }
             return "redirect:/";
         }
     }
     ```

6. **SecurityConfig调整**：
   - 确保登录成功后重定向到正确的前端页面
   - 实际的`SecurityConfig.java`文件中，OAuth2登录成功处理器会根据前端类型重定向：
     ```java
     // 根据前端类型重定向
     if ("react".equals(frontendType)) {
         response.sendRedirect("/");  // React SPA
     } else {
         response.sendRedirect("/test");  // Thymeleaf页面
     }
     ```
   - 确保`SecurityConfig`中的授权规则正确配置，允许访问前端静态资源：
     ```java
     // 授权规则
     .authorizeHttpRequests(authz -> authz
         .requestMatchers("/", "/login/**", "/oauth2/**", "/css/**", "/js/**",
                        "/images/**", "/static/**", "/index.html", "/assets/**",
                        "/favicon.ico", "/error").permitAll()
         .requestMatchers("/api/auth/**").permitAll()  // 认证API公开
         .requestMatchers("/api/user").authenticated()  // 所有认证用户都可以访问
         .requestMatchers("/api/admin/**").hasRole("ADMIN")  // 只有ADMIN角色可以访问
         .requestMatchers("/api/manager/**").hasAnyRole("ADMIN", "MANAGER")  // ADMIN或MANAGER角色可以访问
         .anyRequest().authenticated()
     )
     ```

7. **测试集成流程**：
   - 启动Spring Boot应用：`mvn spring-boot:run`
   - 访问应用根路径，例如：`http://localhost:8080`
   - 测试登录、登出、访问受保护页面等功能
   - 测试第三方SSO登录功能

**向第三方项目展示集成能力的建议**：

1. **创建集成示例项目**：
   - 基于第二种部署方式创建一个完整的集成示例
   - 包含前端和后端代码，展示完整的集成流程

2. **提供详细的集成文档**：
   - 详细说明每一步的实施过程
   - 提供代码示例和配置示例
   - 说明常见问题和解决方案

3. **演示集成流程**：
   - 从创建前端项目开始
   - 配置认证服务
   - 实现登录页面
   - 部署到Spring Boot
   - 测试所有功能

4. **提供集成模板**：
   - 创建可复用的前端认证服务模板
   - 提供Spring Boot配置模板
   - 减少第三方项目的集成工作量

**常见问题和解决方案**：

1. **前端路由404问题**：
   - 确保`SpaController`正确配置，将所有非API路径转发到`index.html`

2. **静态资源加载失败**：
   - 确保前端构建配置正确，使用相对路径
   - 确保静态资源正确部署到`static`目录

3. **登录后重定向问题**：
   - 确保`SecurityConfig`中的重定向逻辑正确配置，重定向到前端应用的根路径

4. **OAuth2回调问题**：
   - 确保第三方平台的重定向URL配置正确
   - 确保`SpaController`正确处理回调路径

**优势**：
- 部署简单，不需要额外的web服务器
- 便于开发和测试
- 适合向第三方项目展示集成能力
- 减少部署和配置的复杂性

### 5.2 后端集成

1. **添加依赖**：
   - 引入 JWT 相关依赖
   - 配置 OAuth2 客户端

2. **配置认证**：
   - 配置 JWT 密钥
   - 配置 OAuth2 提供商
   - 配置 token 存储

3. **实现资源服务器**：
   - 验证 JWT token
   - 实现权限控制
   - 处理跨域请求

### 5.3 前端集成

1. **创建认证服务**：
   - 封装登录、登出、token 刷新等方法
   - 处理 token 存储和过期

2. **实现登录页面**：
   - 支持用户名密码登录
   - 支持第三方登录
   - 处理错误和加载状态

3. **集成到现有项目**：
   - 在路由中添加认证保护
   - 在 API 请求中添加 token
   - 处理认证状态变化

## 6. 代码示例

### 6.1 前端认证服务示例

```javascript
// authService.js
class AuthService {
  constructor() {
    this.baseUrl = 'http://localhost:8080';
    this.apiUrl = `${this.baseUrl}/api/auth`;
  }

  // 用户名密码登录
  async login(username, password) {
    const response = await fetch(`${this.apiUrl}/login`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ username, password })
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error);
    }

    const loginResponse = await response.json();
    // 登录成功后设置 token 自动刷新
    this.setupTokenAutoRefresh();
    return loginResponse;
  }

  // 刷新 token
  async refreshToken() {
    const response = await fetch(`${this.apiUrl}/refresh`, {
      method: 'POST',
      credentials: 'include' // 包含 cookie
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error);
    }

    return await response.json();
  }

  // 处理 token 刷新失败的情况
  handleTokenRefreshFailure() {
    // 清除认证状态
    authStateManager.clearAuthState();
    // 重定向到登录页面
    window.location.href = '/login';
  }

  // 自动刷新 token 的辅助方法
  setupTokenAutoRefresh() {
    // 每 55 分钟刷新一次 token（比 token 过期时间提前 5 分钟）
    const refreshInterval = setInterval(async () => {
      try {
        if (authStateManager.getIsAuthenticated()) {
          await this.refreshToken();
          // 刷新成功后更新认证状态
          const accessToken = authStateManager.getTokenFromCookie('accessToken');
          if (accessToken) {
            authStateManager.setAuthState(null, accessToken);
          }
        }
      } catch (error) {
        console.error('Token refresh failed:', error);
        // 清除定时器
        clearInterval(refreshInterval);
        // 处理刷新失败
        this.handleTokenRefreshFailure();
      }
    }, 55 * 60 * 1000);

    // 存储定时器 ID，以便在需要时清除
    this.refreshIntervalId = refreshInterval;
  }

  // 清除 token 自动刷新
  clearTokenAutoRefresh() {
    if (this.refreshIntervalId) {
      clearInterval(this.refreshIntervalId);
      this.refreshIntervalId = null;
    }
  }

  // 登出
  async logout() {
    try {
      const response = await fetch(`${this.apiUrl}/logout`, {
        method: 'POST',
        credentials: 'include'
      });

      // 清除认证状态
      authStateManager.clearAuthState();
      // 清除 token 自动刷新定时器
      this.clearTokenAutoRefresh();

      return await response.json();
    } catch (error) {
      console.error('Logout failed:', error);
      // 即使登出失败，也要清除本地状态
      authStateManager.clearAuthState();
      this.clearTokenAutoRefresh();
      throw error;
    }
  }

  // 获取当前用户信息
  async getCurrentUser() {
    const response = await fetch(`${this.baseUrl}/api/user`, {
      credentials: 'include'
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error);
    }

    return await response.json();
  }
}

export default new AuthService();

// 前端认证状态管理示例
class AuthStateManager {
  constructor() {
    this.isAuthenticated = false;
    this.user = null;
    this.tokenExpiry = null;
  }

  // 设置认证状态
  setAuthState(user, accessToken) {
    this.isAuthenticated = true;
    this.user = user;
    // 解析 token 过期时间
    if (accessToken) {
      const payload = JSON.parse(atob(accessToken.split('.')[1]));
      this.tokenExpiry = payload.exp * 1000;
    }
    localStorage.setItem('authState', JSON.stringify({
      isAuthenticated: this.isAuthenticated,
      user: this.user,
      tokenExpiry: this.tokenExpiry
    }));
  }

  // 清除认证状态
  clearAuthState() {
    this.isAuthenticated = false;
    this.user = null;
    this.tokenExpiry = null;
    localStorage.removeItem('authState');
  }

  // 加载认证状态
  loadAuthState() {
    const savedState = localStorage.getItem('authState');
    if (savedState) {
      const state = JSON.parse(savedState);
      this.isAuthenticated = state.isAuthenticated;
      this.user = state.user;
      this.tokenExpiry = state.tokenExpiry;
      // 检查 token 是否过期
      if (this.tokenExpiry && Date.now() > this.tokenExpiry) {
        this.clearAuthState();
      }
    }
  }

  // 检查是否已认证
  getIsAuthenticated() {
    // 检查本地状态
    if (!this.isAuthenticated) {
      this.loadAuthState();
    }
    // 检查 token 是否过期
    if (this.tokenExpiry && Date.now() > this.tokenExpiry) {
      this.clearAuthState();
    }
    return this.isAuthenticated;
  }

  // 从 cookie 中获取 token（辅助方法）
  getTokenFromCookie(name) {
    const cookieValue = document.cookie
      .split('; ')
      .find(row => row.startsWith(name + '='))
      ?.split('=')[1];
    return cookieValue ? decodeURIComponent(cookieValue) : null;
  }

  // 获取用户信息
  getUser() {
    if (!this.user) {
      this.loadAuthState();
    }
    return this.user;
  }
}

// 导出单例
export const authStateManager = new AuthStateManager();

// 前端路由守卫示例（React Router）
import { useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import AuthService from './authService';
import { authStateManager } from './authStateManager';

const ProtectedRoute = ({ children }) => {
  const navigate = useNavigate();
  const location = useLocation();

  useEffect(() => {
    const checkAuth = async () => {
      try {
        // 先检查本地认证状态
        if (!authStateManager.getIsAuthenticated()) {
          // 本地状态未认证，检查服务器状态
          await AuthService.getCurrentUser();
          // 如果成功，更新本地状态
          const accessToken = authStateManager.getTokenFromCookie('accessToken');
          authStateManager.setAuthState(null, accessToken);
        }
        // 已登录，正常渲染子组件
      } catch (error) {
        // 未登录，保存当前路径并重定向到登录页面
        navigate('/login', {
          state: { from: location.pathname }
        });
      }
    };

    checkAuth();
  }, [navigate, location.pathname]);

  return children;
};

// 登录页面示例
import { useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import AuthService from './authService';
import { authStateManager } from './authStateManager';

const LoginPage = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  // 获取之前保存的路径，默认为首页
  const from = location.state?.from || '/';

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      // 用户名密码登录
      const loginResponse = await AuthService.login(username, password);
      // 登录成功，更新认证状态
      authStateManager.setAuthState(loginResponse.user, loginResponse.accessToken);
      // 重定向到之前的页面
      navigate(from, { replace: true });
    } catch (err) {
      setError(err.message);
    }
  };

  const handleSSOLogin = (provider) => {
    // 保存之前的路径到本地存储，用于第三方登录回调后重定向
    localStorage.setItem('redirectPath', from);
    // 重定向到第三方登录页面
    window.location.href = `/oauth2/authorization/${provider}`;
  };

  return (
    <div>
      <h1>Login</h1>
      {error && <div className="error">{error}</div>}
      <form onSubmit={handleSubmit}>
        <input
          type="text"
          placeholder="Username"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
        />
        <input
          type="password"
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
        <button type="submit">Login</button>
      </form>
      <div>
        <h2>Or login with</h2>
        <button onClick={() => handleSSOLogin('google')}>Google</button>
        <button onClick={() => handleSSOLogin('github')}>GitHub</button>
        <button onClick={() => handleSSOLogin('x')}>X</button>
      </div>
    </div>
  );
};

// OAuth2 回调处理示例
import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import AuthService from './authService';
import { authStateManager } from './authStateManager';

const OAuth2CallbackHandler = () => {
  const navigate = useNavigate();

  useEffect(() => {
    const handleCallback = async () => {
      try {
        // 回调时，后端会设置 token 到 cookie
        // 这里获取用户信息并更新认证状态
        const userInfo = await AuthService.getCurrentUser();
        // 从 cookie 中获取 accessToken
        const accessToken = authStateManager.getTokenFromCookie('accessToken');
        // 更新认证状态
        authStateManager.setAuthState(userInfo, accessToken);
        // 设置 token 自动刷新
        AuthService.setupTokenAutoRefresh();
        // 获取之前保存的路径并重定向
        const redirectPath = localStorage.getItem('redirectPath') || '/';
        localStorage.removeItem('redirectPath');
        navigate(redirectPath, { replace: true });
      } catch (error) {
        // 处理回调错误
        console.error('Callback error:', error);
        navigate('/login', { replace: true });
      }
    };

    handleCallback();
  }, [navigate]);

  return <div>Processing login...</div>;
};
```

### 6.2 后端认证控制器示例

```java
// CORS 配置示例
@Configuration
public class CorsConfig {
    @Bean
    public WebMvcConfigurer corsConfigurer() {
        return new WebMvcConfigurer() {
            @Override
            public void addCorsMappings(CorsRegistry registry) {
                registry.addMapping("/api/**")
                        .allowedOrigins("http://localhost:3000", "http://localhost:8080")
                        .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                        .allowedHeaders("*").allowCredentials(true);
            }
        };
    }
}

// LoginRequest.java 示例
public class LoginRequest {
    private String username;
    private String password;
    
    // getters and setters
    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }
    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }
}

// AuthController.java 示例改进
@PostMapping("/login")
public ResponseEntity<?> login(@RequestBody LoginRequest loginRequest, HttpServletResponse response) {
    try {
        // 验证用户名密码
        UserDetails userDetails = authenticationManager.authenticate(
            new UsernamePasswordAuthenticationToken(loginRequest.getUsername(), loginRequest.getPassword())
        ).getPrincipal();

        // 生成 token
        String accessToken = jwtTokenService.generateAccessToken(
            userDetails.getUsername(),
            // 其他参数
        );

        String refreshToken = jwtTokenService.generateRefreshToken(
            userDetails.getUsername(),
            // 其他参数
        );

        // 设置 cookie
        setTokenCookies(response, accessToken, refreshToken);

        // 返回 JSON 响应
        return ResponseEntity.ok(Map.of(
            "user", userDetails,
            "message", "Login successful",
            "authenticated", true,
            "accessToken", accessToken,
            "refreshToken", refreshToken,
            "accessTokenExpiresIn", 3600,
            "refreshTokenExpiresIn", 604800,
            "tokenType", "Bearer"
        ));

    } catch (Exception e) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
            .body(Map.of("error", "Invalid credentials"));
    }
}

private void setTokenCookies(HttpServletResponse response, String accessToken, String refreshToken) {
    // 设置 accessToken cookie
    Cookie accessTokenCookie = new Cookie("accessToken", accessToken);
    accessTokenCookie.setHttpOnly(true);
    accessTokenCookie.setPath("/");
    accessTokenCookie.setMaxAge(3600);
    accessTokenCookie.setSecure(false);
    accessTokenCookie.setAttribute("SameSite", "Lax");
    response.addCookie(accessTokenCookie);

    // 设置 refreshToken cookie
    Cookie refreshTokenCookie = new Cookie("refreshToken", refreshToken);
    refreshTokenCookie.setHttpOnly(true);
    refreshTokenCookie.setPath("/");
    refreshTokenCookie.setMaxAge(604800);
    refreshTokenCookie.setSecure(false);
    refreshTokenCookie.setAttribute("SameSite", "Lax");
    response.addCookie(refreshTokenCookie);
}
```

## 7. 结论

前后端分离架构是现代 Web 应用的主流选择，它提供了更好的灵活性、可维护性和可扩展性。通过明确的前后端契约，我们可以确保：

1. **安全性**：使用 HTTP-only cookie 防止 XSS 攻击
2. **灵活性**：通过 JSON 响应体支持跨域资源服务器访问
3. **可维护性**：明确的接口契约减少了前后端之间的耦合
4. **可扩展性**：前端和后端可以独立演进，使用不同的技术栈

集成我们认证/授权服务的项目团队应该根据本文档的指导，实现适合自己项目的前端页面和集成逻辑。我们将持续改进后端 API，确保它与前端的集成更加简单和可靠。

## 8. 版本历史

| 版本 | 日期 | 变更内容 |
|------|------|----------|
| 1.0 | 2026-01-26 | 初始版本，定义前后端契约 |

## 9. 项目现状与改进建议

### 9.1 项目现状

#### 9.1.1 已实现的功能

1. **前端部署方式**：
   - 成功使用第二种部署方式（直接使用 Spring Boot 作为 web 服务器）
   - 前端资源打包后放在 Spring Boot 的静态资源目录中
   - Spring Boot 应用同时提供 API 和静态资源服务

2. **认证流程**：
   - 本地用户登录（用户名密码登录）
   - SSO 登录（Google、GitHub、X）
   - Token 自动刷新机制
   - 登出功能

3. **Token 管理**：
   - HTTP-only cookie 存储 Token，防止 XSS 攻击
   - 本地用户登录实现了 Token 双重传递（cookie + JSON 响应体）
   - 令牌刷新实现了 Token 双重传递

4. **前端集成**：
   - 实现了完整的认证流程
   - 支持访问异构资源服务器
   - 实现了受保护路由

5. **后端 API**：
   - 实现了完整的 RESTful API
   - 支持 JWT Token 验证
   - 支持 OAuth2 登录

#### 9.1.2 存在的问题

1. **SSO 登录未实现 Token 双重传递**：
   - SSO 登录成功后只将 Token 存储到 cookie 中
   - 未在响应体中返回 Token，不符合前后端分离原则
   - 前端无法直接获取 Token 用于访问异构资源服务器
   - 目前前端通过"马上刷新token"的方式绕过这个问题，增加了额外的网络请求和延迟
   - 代码逻辑复杂，不符合前后端分离的优雅实现

2. **OAuth2 登录成功后使用重定向**：
   - 不符合前后端分离原则，应该返回 JSON 响应
   - 不利于前端灵活处理登录成功后的逻辑
   - 无法在登录成功后直接获取用户信息和 Token

3. **部分错误使用 URL 参数传递**：
   - 不符合标准化错误处理原则
   - 不利于前端统一处理错误
   - 错误信息暴露在 URL 中，存在安全风险

4. **缺少全局 CORS 配置**：
   - 不支持跨域请求
   - 不利于异构资源服务器集成
   - 前端无法从不同域名访问 API

5. **前端 Token 存储**：
   - 为了支持异构资源服务器访问，将 Token 存储到 localStorage
   - 存在一定的安全风险，需要权衡安全性和灵活性
   - 可能导致 XSS 攻击风险

6. **缺少 API 文档**：
   - 没有使用 Swagger 或 SpringDoc 生成 API 文档
   - 不利于第三方项目集成
   - 接口信息不够透明

### 9.2 改进建议

改进要点：
- 我们当前项目的 Spring Boot 应用其**主体应该是一个无头服务**。
- 不管是像当前项目一样，将前端页面部署到 Spring Boot 应用（应用同时也作为 Web 服务器），还是可能使用外部的 Web 服务器/反向代理（如 Nginx），我们的项目都应该支持。
- 支持“集成当前项目”的项目客制化实现**整套自己想要的页面**。
- 这就需要由“前端”来主导页面的跳转流程。这里的“前端”主导，包括前端团队或者运维人员按照前端的要求通过配置 Web 服务器/反向代理来实现页面的按需跳转——而不是我们的 Spring Boot 应用代码中“硬编码页面跳转逻辑”。

#### 9.2.1 后端改进

1. **实现 SSO 登录的 Token 双重传递**：
   - 修改 `SecurityConfig.java` 中的 `oauth2SuccessHandler` 方法
   - 在 SSO 登录成功后，同时通过 cookie 和 JSON 响应体传递 Token
   - 支持返回 JSON 响应或重定向，根据前端需求选择
   - **技术方案**：
     - 检测请求头中的 `Accept` 字段，如果包含 `application/json`，返回 JSON 响应
     - 否则，保持现有重定向逻辑
     - 在 JSON 响应中包含用户信息、Token 和过期时间
     - 同时设置 HTTP-only cookie 存储 Token

2. **优化 OAuth2 回调处理**：
   - 减少对特定前端技术栈的依赖
   - 实现基于状态参数的 CSRF 保护
   - **技术方案**：
     - 解析 OAuth2 状态参数，支持前端传递自定义信息
     - 支持 `response_type` 参数，允许前端指定响应类型
     - 为集成项目提供 JSON 响应模式

3. **统一错误处理**：
   - 使用统一的错误响应格式
   - 对 JSON 请求返回标准化的错误响应
   - 对传统请求保留 URL 参数错误传递
   - **技术方案**：
     - 实现全局异常处理器
     - 根据请求类型返回不同格式的错误信息
     - 确保错误信息的安全性和一致性

4. **添加全局 CORS 配置**：
   - 配置全局 CORS 策略，支持跨域请求
   - 允许特定的域名访问 API
   - 允许必要的 HTTP 方法和请求头
   - 配置凭证（credentials）支持
   - **技术方案**：
     - 使用 Spring 的 `WebMvcConfigurer` 配置 CORS
     - 允许所有跨域请求（生产环境中应限制特定域名）
     - 支持凭证传递，确保 cookie 能够正确发送

5. **增强 API 文档**：
   - 使用 Swagger 或 SpringDoc 生成 API 文档
   - 详细描述每个接口的请求和响应格式
   - 提供示例代码
   - **技术方案**：
     - 添加 SpringDoc 依赖
     - 配置 API 文档生成器
     - 为每个接口添加详细的注释和示例

#### 9.2.2 前端改进

1. **优化 Token 管理**：
   - 实现更安全的 Token 存储方式
   - 考虑使用会话存储或内存存储，减少 XSS 攻击风险
   - 实现 Token 过期检测和自动刷新
   - **技术方案**：
     - 优先使用 HTTP-only cookie 进行认证
     - 对于需要访问异构资源服务器的场景，使用会话存储
     - 实现 Token 过期前自动刷新机制
     - 定期检查 Token 状态，确保认证有效性

2. **增强错误处理**：
   - 实现统一的错误处理机制
   - 显示用户友好的错误信息
   - 处理 Token 过期等特殊情况
   - **技术方案**：
     - 使用 axios 拦截器统一处理错误
     - 实现错误分类和优先级处理
     - 为不同类型的错误提供不同的用户提示
     - 处理网络错误、认证错误等特殊情况

3. **优化用户体验**：
   - 实现加载状态
   - 友好的错误提示
   - 响应式设计
   - **技术方案**：
     - 为所有异步操作添加加载状态
     - 实现全局通知系统，统一管理错误和成功提示
     - 确保在各种设备上的良好显示效果
     - 优化登录和认证流程的用户体验

4. **增强安全性**：
   - 防止 XSS 攻击
   - 防止 CSRF 攻击
   - 安全存储敏感信息
   - **技术方案**：
     - 使用 React 的 dangerouslySetInnerHTML 时进行安全检查
     - 正确处理 CSRF token
     - 避免在 localStorage 中存储敏感信息
     - 实现内容安全策略（CSP）

#### 9.2.3 集成改进

1. **提供集成模板**：
   - 创建可复用的前端认证服务模板
   - 提供 Spring Boot 配置模板
   - 减少第三方项目的集成工作量
   - **技术方案**：
     - 创建前端认证服务 npm 包
     - 提供后端集成 starter 模块
     - 为不同前端框架（React、Vue、Angular）提供模板
     - 包含完整的认证流程实现

2. **完善集成文档**：
   - 详细说明每一步的实施过程
   - 提供代码示例和配置示例
   - 说明常见问题和解决方案
   - **技术方案**：
     - 创建详细的集成指南，分步骤说明
     - 提供不同场景的配置示例
     - 维护常见问题和解决方案的知识库
     - 为每个集成步骤提供测试方法

3. **创建集成示例项目**：
   - 基于第二种部署方式创建一个完整的集成示例
   - 包含前端和后端代码，展示完整的集成流程
   - **技术方案**：
     - 创建完整的示例项目，包含前端和后端
     - 展示不同的集成场景和配置
     - 提供详细的 README 和注释
     - 包含测试用例和部署指南

### 9.3 实施优先级

1. **高优先级**：
   - 实现 SSO 登录的 Token 双重传递
   - 添加全局 CORS 配置
   - 统一错误处理

2. **中优先级**：
   - 优化 OAuth2 回调处理
   - 增强 API 文档
   - 优化前端 Token 管理
   - 增强前端错误处理

3. **低优先级**：
   - 优化用户体验
   - 增强安全性

---

## 10. 当前进展总结

### 10.1 已完成的核心功能

1. **完整的认证流程**：
   - 实现了本地用户登录（用户名密码）
   - 集成了 Google、GitHub、X 三大 SSO 登录
   - 实现了 Token 自动刷新机制
   - 支持完整的登出功能

2. **安全的 Token 管理**：
   - 使用 HTTP-only cookie 存储 Token，防止 XSS 攻击
   - 本地用户登录和令牌刷新实现了 Token 双重传递（cookie + JSON 响应体）
   - 支持 JWT Token 验证和管理

3. **前端集成**：
   - 成功部署 React 前端到 Spring Boot 静态资源目录
   - 实现了完整的认证状态管理
   - 支持访问异构资源服务器（Python 资源服务器）
   - 实现了受保护路由和路由守卫

4. **后端 API**：
   - 实现了完整的 RESTful API
   - 支持 JWT Token 验证和 OAuth2 登录
   - 提供了 JWKS 端点用于公钥获取
   - 实现了令牌内省和验证功能

5. **异构资源服务器集成**：
   - 前端成功访问 Python 资源服务器
   - 实现了跨域资源访问
   - 健康检查功能正常工作

### 10.2 技术亮点

1. **前后端分离架构**：
   - 采用 API 优先设计原则
   - 前端完全控制页面路由和状态
   - 后端专注于 API 响应和认证

2. **安全最佳实践**：
   - HTTP-only cookie 存储敏感信息
   - JWT Token 签名验证
   - 支持 Token 自动刷新
   - 防止 XSS 和 CSRF 攻击

3. **灵活的部署方式**：
   - 支持直接使用 Spring Boot 作为 web 服务器
   - 便于快速原型开发和测试
   - 适合向第三方项目展示集成能力

4. **完整的集成示例**：
   - 提供了详细的前后端集成文档
   - 包含完整的代码示例和配置
   - 展示了异构资源服务器的集成方案

> 修改过程记录：[FRONTEND_BACKEND_improvement-20260127](./drafts/FRONTEND_BACKEND_improvement-20260127.md)

### 10.3 后续改进方向

1. **完善 SSO 登录的 Token 双重传递**：
   - 实现 SSO 登录成功后同时通过 cookie 和 JSON 响应体传递 Token
   - 符合前后端分离原则，便于前端直接获取 Token

2. **优化 OAuth2 回调处理**：
   - 减少对特定前端技术栈的依赖
   - 支持基于状态参数的 CSRF 保护
   - 为集成项目提供 JSON 响应模式

3. **增强系统安全性**：
   - 添加全局 CORS 配置
   - 统一错误处理机制
   - 实现更安全的 Token 存储方式

4. **提升开发体验**：
   - 使用 Swagger 或 SpringDoc 生成 API 文档
   - 提供集成模板和示例项目
   - 完善错误处理和用户提示

### 10.4 项目状态

项目已成功实现了核心的认证和授权功能，包括本地用户登录、SSO 登录、Token 管理和异构资源服务器集成。前端和后端的集成已经完成，系统可以正常运行。

后续将按照优先级逐步完善剩余功能，特别是 SSO 登录的 Token 双重传递、OAuth2 回调处理优化和系统安全性增强，以确保项目完全符合前后端分离架构的最佳实践。
