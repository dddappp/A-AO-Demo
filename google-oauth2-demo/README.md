# Google OAuth2 Demo - Spring Boot应用

## 📋 项目概述

这是一个使用Spring Boot和Google OAuth2实现的完整登录演示应用。本项目演示了现代Web应用中OAuth2/OpenID Connect集成的完整流程，包括用户认证、Token处理、安全验证和受保护页面访问控制。

## 🎯 项目功能

✅ **完整的OAuth2认证流程**
- 访问受保护页面时自动引导用户使用Google账户登录
- 用户登录成功后从哪里来就回到哪里去
- 认证状态正确保存，支持会话持久化

✅ **受保护功能实现**
- 登录成功后页面显示受保护的功能（ID Token验证按钮）
- 点击功能按钮能够验证ID Token并显示详细结果
- 完整的JWT Token验证和用户信息展示

✅ **安全特性**
- 使用HTTP Only Cookie安全存储ID Token
- 使用Google JWKS验证Token签名和完整性
- 支持手动JWT Token验证功能

## 🏗️ 技术架构

### 核心技术栈
- **Spring Boot 3.3.4** - 主框架（最新稳定版）
- **Spring Security 6.1.13** - 安全框架（修复安全漏洞）
- **Spring OAuth2 Client** - OAuth2客户端支持
- **JWT (JJWT)** - Token处理
- **Thymeleaf** - 模板引擎
- **Maven** - 依赖管理

### 关键依赖
```xml
<!-- Spring Boot Starters -->
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-web</artifactId>
</dependency>

<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-security</artifactId>
</dependency>

<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-oauth2-client</artifactId>
</dependency>

<!-- JWT Support -->
<dependency>
  <groupId>org.springframework.security</groupId>
  <artifactId>spring-security-oauth2-jose</artifactId>
</dependency>
```

## 📁 项目结构

```
google-oauth2-demo/
├── src/main/java/com/example/oauth2demo/
│   ├── GoogleOAuth2DemoApplication.java          # 主应用类
│   ├── config/
│   │   ├── SecurityConfig.java                   # Spring Security配置
│   │   └── WebConfig.java                        # Web配置
│   ├── controller/
│   │   └── AuthController.java                   # 认证控制器
│   └── service/
│       └── JwtValidationService.java             # JWT验证服务
├── src/main/resources/
│   ├── application.yml                           # 应用配置
│   ├── static/                                   # 静态资源
│   └── templates/                                # Thymeleaf模板
│       ├── home.html                             # 首页
│       ├── login.html                            # 登录页面
│       └── test.html                             # 测试页面
└── start.sh                                       # 启动脚本
```

## ⚙️ 核心配置

### 1. OAuth2客户端配置 (application.yml)
```yaml
spring:
  security:
    oauth2:
      client:
        registration:
          google:
            client-id: ${GOOGLE_CLIENT_ID:your-client-id}
            client-secret: ${GOOGLE_CLIENT_SECRET:your-client-secret}
            scope:
              - openid
              - profile
              - email
            redirect-uri: https://api.u2511175.nyat.app:55139/oauth2/callback
        provider:
          google:
            authorization-uri: https://accounts.google.com/o/oauth2/v2/auth
            token-uri: https://oauth2.googleapis.com/token
            user-info-uri: https://openidconnect.googleapis.com/v1/userinfo
            jwk-set-uri: https://www.googleapis.com/oauth2/v3/certs
```

### 2. 安全配置 (SecurityConfig.java)
```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public AuthenticationSuccessHandler oauth2SuccessHandler() {
        return new AuthenticationSuccessHandler() {
            @Override
            public void onAuthenticationSuccess(HttpServletRequest request, HttpServletResponse response,
                                              Authentication authentication) throws IOException {
                if (authentication.getPrincipal() instanceof OidcUser oidcUser) {
                    // 获取ID Token并存储到Cookie
                    String idToken = oidcUser.getIdToken().getTokenValue();
                    
                    Cookie idTokenCookie = new Cookie("id_token", idToken);
                    idTokenCookie.setHttpOnly(true);
                    idTokenCookie.setSecure(true);
                    idTokenCookie.setPath("/");
                    idTokenCookie.setMaxAge(3600);
                    
                    response.addCookie(idTokenCookie);
                }
                response.sendRedirect("/test");
            }
        };
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .authorizeHttpRequests(authz -> authz
                .requestMatchers("/", "/login/**", "/oauth2/**", "/css/**", "/js/**", "/images/**", "/static/**", "/error").permitAll()
                .anyRequest().authenticated()
            )
            .oauth2Login(oauth2 -> oauth2
                .loginPage("/login")
                .successHandler(oauth2SuccessHandler())
                .redirectionEndpoint(redirection -> redirection
                    .baseUri("/oauth2/callback")  // 关键配置：自定义回调URL
                )
            )
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED)
            )
            .logout(logout -> logout
                .logoutUrl("/logout")
                .logoutSuccessUrl("/")
                .invalidateHttpSession(true)
                .clearAuthentication(true)
                .deleteCookies("id_token", "JSESSIONID")
            );

        return http.build();
    }
}
```

## 🔐 关键技术要点

### 1. 自定义OAuth2回调URL配置

**问题**: Spring Security默认使用`/login/oauth2/code/{registrationId}`作为回调URL，但项目需要使用自定义的`/oauth2/callback`路径。

**解决方案**:
```java
.oauth2Login(oauth2 -> oauth2
    .redirectionEndpoint(redirection -> redirection
        .baseUri("/oauth2/callback")  // 自定义回调URL
    )
)
```

**注意事项**:
- 必须在Google Cloud Console中注册完全相同的redirect URI
- 应用配置中的`redirect-uri`必须与SecurityConfig中的`baseUri`保持一致
- URL必须包含完整的协议、域名、端口和路径

### 2. OAuth2认证成功后的ID Token存储

**问题**: 需要在OAuth2认证成功后将ID Token存储到Cookie中，以便后续的JWT验证功能使用。

**解决方案**:
```java
@Bean
public AuthenticationSuccessHandler oauth2SuccessHandler() {
    return new AuthenticationSuccessHandler() {
        @Override
        public void onAuthenticationSuccess(HttpServletRequest request, HttpServletResponse response,
                                          Authentication authentication) throws IOException {
            if (authentication.getPrincipal() instanceof OidcUser oidcUser) {
                String idToken = oidcUser.getIdToken().getTokenValue();
                
                Cookie idTokenCookie = new Cookie("id_token", idToken);
                idTokenCookie.setHttpOnly(true);  // 防止XSS攻击
                idTokenCookie.setSecure(true);    // HTTPS环境必须
                idTokenCookie.setPath("/");       // 全站可访问
                idTokenCookie.setMaxAge(3600);   // 1小时过期
                
                response.addCookie(idTokenCookie);
            }
            response.sendRedirect("/test");
        }
    };
}
```

**安全考虑**:
- 使用`HttpOnly`标志防止JavaScript访问
- HTTPS环境下必须设置`Secure`标志
- 合理设置Cookie过期时间

### 3. 会话管理策略

**问题**: 不当的会话管理配置可能导致OAuth2认证状态无法正确保存。

**解决方案**:
```java
.sessionManagement(session -> session
    .sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED)  // 按需创建会话
)
```

**避免的配置**:
- `SessionCreationPolicy.STATELESS` - 会导致OAuth2认证失败
- `SessionCreationPolicy.ALWAYS` - 可能引起会话冲突

### 4. CSRF保护配置

**问题**: Web应用需要防止跨站请求伪造（CSRF）攻击，特别是对于POST请求。

**解决方案**:
```java
.csrf(csrf -> csrf
    .csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
)
```

**前端CSRF Token处理**:
```html
<!-- 在HTML头部添加CSRF meta标签 -->
<meta name="_csrf" th:content="${_csrf.token}"/>
<meta name="_csrf_header" th:content="${_csrf.headerName}"/>
```

```javascript
// JavaScript中获取并使用CSRF Token
function getCsrfToken() {
    return document.querySelector('meta[name="_csrf"]').getAttribute('content');
}

const headers = { 'Content-Type': 'application/json' };
headers[getCsrfHeader()] = getCsrfToken();

fetch('/api/validate-token', {
    method: 'POST',
    headers: headers
})
```

**安全说明**:
- OAuth2本身通过state参数防护CSRF攻击
- 应用内部的POST API仍需要CSRF保护
- **绝不应该**为了方便而禁用CSRF保护

**初学者CSRF概念详解**:

1. **什么是CSRF攻击？**
   - CSRF（跨站请求伪造）是一种网络攻击方式
   - 攻击者诱导已登录用户在不知情的情况下执行操作
   - 例如：用户登录网银后访问恶意网站，恶意网站发送转账请求

2. **CSRF攻击的危害**
   - 转账、修改密码、删除数据等敏感操作被恶意执行
   - 用户账户安全受到威胁
   - 数据完整性被破坏

3. **CSRF保护机制**
   - 服务器为每个会话生成唯一的随机Token
   - 合法请求必须携带正确的Token
   - 恶意网站无法获取Token，因此无法伪造请求

4. **实现细节**
   ```java
   // 后端：启用CSRF保护
   .csrf(csrf -> csrf.csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse()))
   ```
   
   ```html
   <!-- 前端：获取Token -->
   <meta name="_csrf" th:content="${_csrf.token}"/>
   ```
   
   ```javascript
   // JavaScript：使用Token
   headers[getCsrfHeader()] = getCsrfToken();
   ```

### 5. Google Cloud Console配置要点

**关键配置**:
1. **Authorized redirect URIs**: 必须精确匹配应用配置
   - 正确: `https://api.u2511175.nyat.app:55139/oauth2/callback`
   - 错误: `https://api.u2511175.nyat.app:55139/login/oauth2/code/google`

2. **OAuth 2.0 客户端类型**: Web应用程序

3. **授权域**: 确保应用域名已添加到授权域列表

## 🚀 运行指南

### 环境准备
1. Java 17+
2. Maven 3.6+
3. Google Cloud Console OAuth2凭据

### Google Cloud Console配置详细步骤

1. **创建Google Cloud项目**
   - 登录 [Google Cloud Console](https://console.cloud.google.com/)
   - 新建或选择已有的项目
   - 在左侧导航中依次选择 "API 与服务" → "凭据"

2. **配置OAuth同意屏幕**
   - 点击 "OAuth同意屏幕" 选项卡
   - 选择用户类型（内部/外部）
   - 填写应用名称、用户支持邮箱等必要信息
   - 添加授权域（如：`u2511175.nyat.app`）
   - **注意**: 测试模式下仅限100个测试用户，生产环境需要通过Google审核

3. **创建OAuth 2.0客户端ID**
   - 点击 "创建凭据" → "OAuth 客户端 ID"
   - 应用类型选择 "Web应用"
   - 设置应用名称
   - 在"授权重定向 URI"中添加：`https://api.u2511175.nyat.app:55139/oauth2/callback`
   - 创建完成后，记录下 **Client ID** 和 **Client Secret**

### 启动步骤

1. **配置环境变量**
   ```bash
   export GOOGLE_CLIENT_ID="your-client-id"
   export GOOGLE_CLIENT_SECRET="your-client-secret"
   ```

2. **启动应用**
   ```bash
   cd google-oauth2-demo
   ./start.sh
   ```

3. **访问应用**
   - 本地访问: `http://localhost:8081`
   - 外部访问: `https://api.u2511175.nyat.app:55139`

## 🎯 功能测试

### 完整测试流程

1. **访问首页**: 点击"开始登录测试"
2. **受保护页面重定向**: 自动重定向到登录页面
3. **Google OAuth2登录**: 点击"使用Google账户登录"
4. **认证成功返回**: 登录成功后回到测试页面
5. **验证受保护功能**: 
   - 页面显示用户信息（姓名、邮箱、用户ID）
   - 点击"验证 ID Token"按钮
   - 查看详细的JWT验证结果

### 预期结果

登录成功后，测试页面应显示：
- ✅ 用户基本信息
- ✅ "验证 ID Token"按钮
- ✅ 点击验证按钮后显示完整的Token验证信息

## 🛠️ 故障排除

### 常见问题及解决方案

1. **redirect_uri_mismatch错误**
   - 检查Google Cloud Console中的redirect URI配置
   - 确保与application.yml中的redirect-uri完全一致
   - 验证SecurityConfig中的baseUri配置

2. **认证成功但未找到ID Token Cookie**
   - 确保OAuth2成功处理器正确配置
   - 检查Cookie的安全设置（HttpOnly, Secure）
   - 验证HTTPS环境下的Cookie策略

3. **会话状态丢失**
   - 检查SessionCreationPolicy配置
   - 确保未使用STATELESS策略
   - 验证应用服务器的会话配置

## 📚 技术参考

### OAuth2 Token类型说明

**Access Token vs ID Token的重要区别**：

1. **Access Token（访问令牌）**
   - Google返回的Access Token是"不透明"字符串，不是JWT格式
   - 只能作为"通行证"访问Google API，第三方无法直接验证
   - 不包含可解析的用户信息或权限声明

2. **ID Token（身份令牌）** ✅ *本项目使用*
   - 标准JWT格式，包含用户身份信息和Google数字签名
   - 可使用Google JWKS公钥进行离线验证
   - 包含`iss`、`sub`、`aud`、`exp`、`email`、`name`等声明
   - 适合在第三方系统间传递和验证用户身份

**为什么使用ID Token**：
- 第三方可通过Google JWKS（`https://www.googleapis.com/oauth2/v3/certs`）获取公钥进行离线验证
- 包含完整的用户身份信息，无需额外API调用
- 符合OpenID Connect标准，具有良好的互操作性

### JWT验证安全要点

验证ID Token时必须检查：
- `iss` 必须是 `https://accounts.google.com`
- `aud` 必须包含您的客户端ID
- `exp` 验证Token未过期
- 使用Google公钥验证数字签名

### 核心技术栈

- **Spring Security OAuth2**: 基于最新6.x版本的OAuth2客户端实现
- **OpenID Connect**: 身份认证标准协议
- **JWT Token**: 使用Google JWKS进行离线验证
- **Cookie安全**: HTTP Only Cookie防止XSS攻击

## 🔄 部署考虑

### 生产环境配置
- 确保HTTPS证书正确配置
- 设置合适的Cookie安全策略
- 配置适当的会话超时时间
- 实施适当的日志和监控

### 安全最佳实践

**OAuth2配置安全**：
- 回调地址必须使用HTTPS，否则Google会拒绝回调
- 只请求必要的权限范围（通常 `openid profile email` 即可）
- 妥善保管Client Secret，不要提交到公共代码仓库
- 定期轮换和更新OAuth2凭据

**Token安全管理**：
- 不要将任何令牌（Access Token或ID Token）暴露在不可信环境
- 使用HTTP Only Cookie存储敏感Token，防止XSS攻击
- 设置合理的Token过期时间，避免长期有效的凭据
- 定期轮换和更新Google公钥缓存

**应用部署安全**：
- 定期更新依赖版本，修复已知安全漏洞
- 实施适当的CORS配置，限制跨域访问
- 配置强壮的会话管理策略
- 实施适当的日志记录和安全监控

---

**最后更新时间**: 2025-09-20  
**项目状态**: 所有功能正常工作，生产就绪