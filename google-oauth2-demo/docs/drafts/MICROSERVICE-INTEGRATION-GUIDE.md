# 微服务架构集成指南：SSO + 业务服务整合

## 📌 概述

本指南帮助你将 `google-oauth2-demo` 项目作为**独立的认证微服务**运行，并通过反向代理整合后端的业务服务。

### 集成特性
- ✅ **独立微服务** - 认证服务与业务服务完全分离
- ✅ **反向代理整合** - 支持 Nginx 和 Spring MVC Gateway
- ✅ **统一域名** - 通过反向代理实现单一入口
- ✅ **前端页面集成** - 暴露 React 原型页面用于测试
- ✅ **完整认证流程** - 本地登录 + 多 SSO 提供商支持
- ✅ **JWT Token** - 无状态认证，便于服务间通信

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                      Client                             │
└─────────────────┬───────────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────────────┐
│                Reverse Proxy                             │
│          (Nginx / Spring Gateway)                        │
└─────────────────┬────────────────────────────────────────┘
                  │
          ┌───────┴──────────────────┐
          │                          │
          ▼                          ▼
┌──────────────────────┐  ┌──────────────────────┐
│ Auth Microservice    │  │ Business Services    │
│ (google-oauth2-demo) │  │  (Multiple services) │
└──────────────────────┘  └──────────────────────┘
```

---

## 🚀 快速开始

### 前置条件

1. **Java 17+** - 运行认证微服务
2. **PostgreSQL 12+** - 认证服务的数据库
3. **反向代理** - Nginx 或 Spring MVC Gateway
4. **业务服务** - 你的后端业务服务

### 认证微服务配置

1. **启动认证微服务**

```bash
# 进入项目目录
cd /path/to/google-oauth2-demo

# 构建项目
mvn clean package

# 启动服务（默认端口 8081）
java -jar target/oauth2-demo.jar
```

2. **验证服务启动**

访问 `http://localhost:8081/api/auth/check-user?username=test` 确认服务正常运行。

---

## 🔧 反向代理配置

### 选项 A：使用 Nginx 作为反向代理

#### 1. Nginx 安装

- **Ubuntu/Debian**:
  ```bash
  sudo apt update && sudo apt install nginx
  ```

- **CentOS/RHEL**:
  ```bash
  sudo yum install epel-release && sudo yum install nginx
  ```

- **macOS**:
  ```bash
  brew install nginx
  ```

#### 2. Nginx 配置文件

创建或修改 Nginx 配置文件（例如：`/etc/nginx/conf.d/auth-gateway.conf`）：

```nginx
# Nginx 反向代理配置
server {
    listen 80;
    server_name example.com;  # 你的域名

    # 访问日志
    access_log /var/log/nginx/auth-gateway.access.log;
    error_log /var/log/nginx/auth-gateway.error.log;

    # 认证服务 API 路由
    location /api/auth/ {
        proxy_pass http://localhost:8081/api/auth/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # 认证服务用户相关 API
    location /api/user/ {
        proxy_pass http://localhost:8081/api/user/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # OAuth2 相关路由
    location /oauth2/ {
        proxy_pass http://localhost:8081/oauth2/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # 静态资源（前端页面）
    location /static/ {
        proxy_pass http://localhost:8081/static/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_cache_valid 200 30m;
        add_header Cache-Control "public, max-age=1800";
    }

    # 前端特定路由（对应 SpaController）
    # 注意：如果项目想要实现自己的页面，那么下面的配置可能需要调整来适应
    location /login {
        proxy_pass http://localhost:8081/login;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    location /test {
        proxy_pass http://localhost:8081/test;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    location /oauth2/callback {
        proxy_pass http://localhost:8081/oauth2/callback;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # 前端入口页面和其他 SPA 路由
    location / {
        proxy_pass http://localhost:8081/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # SPA 客户端路由（捕获所有非 API、非静态资源的路径）
    location ~ ^/(?!api/|oauth2/|static/|h2-console/|favicon.ico) {
        proxy_pass http://localhost:8081/$1;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # 业务服务 API 路由
    location /api/business/ {
        proxy_pass http://localhost:8080/api/;  # 业务服务地址
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # 传递认证信息
        proxy_set_header Authorization $http_authorization;
    }

    # 业务服务其他路由
    location /business/ {
        proxy_pass http://localhost:8080/;  # 业务服务地址
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # 传递认证信息
        proxy_set_header Authorization $http_authorization;
    }
}
```

#### 3. 配置说明

- **认证服务路由**：
  - `/api/auth/` - 认证相关 API
  - `/api/user/` - 用户管理 API
  - `/oauth2/` - OAuth2 登录和回调
  - `/static/` - 前端静态资源
  - `/` - 前端入口页面

- **业务服务路由**：
  - `/api/business/` - 业务服务 API
  - `/business/` - 业务服务其他路径

- **重要配置**：
  - `proxy_set_header Authorization $http_authorization;` - 传递认证 Token
  - `proxy_set_header X-Forwarded-Proto $scheme;` - 保留原始协议（HTTP/HTTPS）
  - `proxy_cache_valid` - 静态资源缓存配置

#### 4. 启动 Nginx

```bash
# 测试配置
nginx -t

# 重启 Nginx
sudo systemctl restart nginx
# 或
sudo service nginx restart
```

### 选项 B：使用 Spring Cloud Gateway 作为反向代理

Spring Cloud Gateway 提供两种实现方式，**这两种方式相互冲突，不能同时使用**：

#### 方式 1：基于 WebFlux 的 Gateway（传统版本）

**依赖配置**：

```xml
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-webflux</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.cloud</groupId>
        <artifactId>spring-cloud-starter-gateway</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
</dependencies>

<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-dependencies</artifactId>
            <version>2023.0.0</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>
```

**特点**：
- 基于响应式编程模型
- 高性能，适合高并发场景
- 不能与 `spring-boot-starter-web` 共存
- 学习曲线较陡峭

#### 方式 2：基于 MVC 的 Gateway（新版本）

**依赖配置**：

```xml
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.cloud</groupId>
        <artifactId>spring-cloud-starter-gateway-server-webmvc</artifactId>
        <version>5.0.0</version>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
</dependencies>

<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-dependencies</artifactId>
            <version>2023.0.0</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>
```

**特点**：
- 基于传统 MVC 编程模型
- 与现有 Spring MVC 项目无缝集成
- 不能与 `spring-boot-starter-webflux` 共存
- 学习曲线平缓，配置简单

**注意**：选择其中一种方式即可，根据您的项目技术栈和需求选择合适的版本。

#### 2. Gateway 配置文件

**注意**：以下配置文件对两种版本的 Gateway 都适用，只是依赖不同。

创建 `application.yml` 配置文件：

```yaml
server:
  port: 8080

spring:
  application:
    name: api-gateway
  
  cloud:
    gateway:
      routes:
        # 认证服务路由
        - id: auth-service-api
          uri: http://localhost:8081
          predicates:
            - Path=/api/auth/**
          filters:
            - PreserveHostHeader
            - AddRequestHeader=X-Forwarded-Proto, ${spring.profiles.active:http}
        
        - id: auth-service-user
          uri: http://localhost:8081
          predicates:
            - Path=/api/user/**
          filters:
            - PreserveHostHeader
            - AddRequestHeader=X-Forwarded-Proto, ${spring.profiles.active:http}
        
        - id: auth-service-oauth2
          uri: http://localhost:8081
          predicates:
            - Path=/oauth2/**
          filters:
            - PreserveHostHeader
            - AddRequestHeader=X-Forwarded-Proto, ${spring.profiles.active:http}
        
        - id: auth-service-static
          uri: http://localhost:8081
          predicates:
            - Path=/static/**
          filters:
            - PreserveHostHeader
            - AddRequestHeader=X-Forwarded-Proto, ${spring.profiles.active:http}
        
        # 前端特定路由（对应 SpaController）
        # 注意：如果项目想要实现自己的页面，那么下面的配置可能需要调整来适应
        - id: auth-service-login
          uri: http://localhost:8081
          predicates:
            - Path=/login
          filters:
            - PreserveHostHeader
            - AddRequestHeader=X-Forwarded-Proto, ${spring.profiles.active:http}
        
        - id: auth-service-test
          uri: http://localhost:8081
          predicates:
            - Path=/test
          filters:
            - PreserveHostHeader
            - AddRequestHeader=X-Forwarded-Proto, ${spring.profiles.active:http}
        
        - id: auth-service-oauth2-callback
          uri: http://localhost:8081
          predicates:
            - Path=/oauth2/callback
          filters:
            - PreserveHostHeader
            - AddRequestHeader=X-Forwarded-Proto, ${spring.profiles.active:http}
        
        # 前端入口页面
        - id: auth-service-root
          uri: http://localhost:8081
          predicates:
            - Path=/
          filters:
            - PreserveHostHeader
            - AddRequestHeader=X-Forwarded-Proto, ${spring.profiles.active:http}
        
        # SPA 客户端路由（对应 SpaController 的 spaRoutes 方法）
        - id: auth-service-spa-routes
          uri: http://localhost:8081
          predicates:
            - Path=/**
            - Path!=/api/**
            - Path!=/oauth2/**
            - Path!=/static/**
            - Path!=/h2-console/**
            - Path!=/favicon.ico
          filters:
            - PreserveHostHeader
            - AddRequestHeader=X-Forwarded-Proto, ${spring.profiles.active:http}
        
        # 业务服务路由
        - id: business-service-api
          uri: http://localhost:8082  # 业务服务地址
          predicates:
            - Path=/api/business/**
          filters:
            - PreserveHostHeader
            - AddRequestHeader=X-Forwarded-Proto, ${spring.profiles.active:http}
            - RewritePath=/api/business/(?<path>.*), /api/$
        
        - id: business-service
          uri: http://localhost:8082  # 业务服务地址
          predicates:
            - Path=/business/**
          filters:
            - PreserveHostHeader
            - AddRequestHeader=X-Forwarded-Proto, ${spring.profiles.active:http}
            - RewritePath=/business/(?<path>.*), /$

#  actuator 配置
management:
  endpoints:
    web:
      exposure:
        include: health,info,routes
  endpoint:
    health:
      show-details: always
```

#### 3. 配置说明

**通用配置说明**（两种版本都适用）：

- **认证服务路由**：
  - `/api/auth/**` - 认证相关 API
  - `/api/user/**` - 用户管理 API
  - `/oauth2/**` - OAuth2 登录和回调
  - `/static/**` - 前端静态资源
  - `/` - 前端入口页面

- **业务服务路由**：
  - `/api/business/**` - 业务服务 API（重写路径）
  - `/business/**` - 业务服务其他路径（重写路径）

- **重要配置**：
  - `PreserveHostHeader` - 保留原始 Host 头
  - `AddRequestHeader=X-Forwarded-Proto` - 传递原始协议
  - `RewritePath` - 路径重写，移除业务服务前缀

**版本特定配置**：

- **WebFlux 版本**：支持更多高级配置，如连接池、响应式过滤器等
- **MVC 版本**：配置更简单，与传统 Spring Boot 应用配置一致

### 前端路由配置说明

**重要**：如果项目想要实现自己的页面，那么下面的前端路由配置可能需要调整来适应。

对于前后端分离架构，`SpaController.java` 是处理前端 React 应用客户端路由的关键组件。当使用认证服务的前端时，反向代理配置必须确保以下前端路由能正确转发到认证微服务：

1. **核心前端路由**：
   - `/login` - 登录页面
   - `/test` - 测试页面
   - `/oauth2/callback` - OAuth2 回调页面
   - 所有其他非 API、非静态资源的路径

2. **工作原理**：
   - 反向代理将前端路由请求转发到认证微服务
   - `SpaController` 接收到请求后，转发到 `index.html`
   - 前端 React 应用接管客户端路由，根据 URL 显示相应页面

3. **配置要点**：
   - 前端路由需要单独配置，确保正确转发
   - SPA 客户端路由需要捕获所有非 API 路径
   - 路由顺序很重要，更具体的路径应该放在前面

#### 4. 启动 Gateway

```bash
# 构建并启动 Gateway
mvn clean package
java -jar target/api-gateway.jar
```

---

## 📦 认证微服务配置

### 1. 配置文件修改

修改 `google-oauth2-demo` 项目的 `application.yml` 文件：

```yaml
server:
  port: 8081

app:
  frontend:
    type: react
  jwt:
    secret: "your-secret-key"
  cors:
    allowed-origins:
      - "*"  # 生产环境应设置具体域名
    allowed-methods:
      - GET
      - POST
      - PUT
      - DELETE
      - OPTIONS
    allowed-headers:
      - "*"
    exposed-headers:
      - Authorization
    allow-credentials: true
    max-age: 3600

# OAuth2 配置
spring:
  security:
    oauth2:
      client:
        registration:
          google:
            client-id: ${GOOGLE_CLIENT_ID}
            client-secret: ${GOOGLE_CLIENT_SECRET}
            redirect-uri: "{baseUrl}/oauth2/callback/google"
        provider:
          google:
            authorization-uri: https://accounts.google.com/o/oauth2/v2/auth?prompt=select_account
            token-uri: https://oauth2.googleapis.com/token
            user-info-uri: https://openidconnect.googleapis.com/v1/userinfo
            user-name-attribute: sub

# 数据库配置
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/auth_db
    username: postgres
    password: your_password

# 其他配置保持不变...
```

### 2. 构建前端资源

```bash
# 进入前端目录
cd /path/to/google-oauth2-demo/frontend

# 安装依赖
npm install

# 构建前端（输出到 Spring Boot 静态资源目录）
npm run build
```

### 3. 启动认证微服务

```bash
# 进入项目目录
cd /path/to/google-oauth2-demo

# 构建并启动
mvn clean package
java -jar target/oauth2-demo.jar
```

---

## 🧪 测试验证

### 1. 验证服务启动

- **认证微服务**：`http://localhost:8081/api/auth/check-user?username=test`
- **反向代理**：`http://localhost/api/auth/check-user?username=test` （Nginx 或 Gateway）

### 2. 测试认证流程

#### 本地登录测试

```bash
# 1. 注册新用户
curl -X POST http://localhost/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123",
    "displayName": "Test User"
  }'

# 2. 登录
curl -X POST http://localhost/api/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=testuser&password=password123"

# 3. 使用 Token 访问受保护资源
curl -X GET http://localhost/api/auth/user \
  -H "Authorization: Bearer <your-access-token>"

# 4. 测试业务服务访问
curl -X GET http://localhost/api/business/protected \
  -H "Authorization: Bearer <your-access-token>"
```

### 3. 前端页面测试

访问 `http://localhost` 查看并测试 React 原型页面：

- **登录页面** - 测试本地登录
- **SSO 登录** - 测试 Google/GitHub/Twitter 登录
- **用户信息页面** - 查看当前用户信息
- **登录方式管理** - 测试多登录方式管理

---

## 🔧 业务服务集成

### 1. JWT Token 验证

业务服务需要验证从认证服务获取的 JWT Token。

#### Maven 依赖

```xml
<dependencies>
    <!-- JWT 验证依赖 -->
    <dependency>
        <groupId>io.jsonwebtoken</groupId>
        <artifactId>jjwt-api</artifactId>
        <version>0.11.5</version>
    </dependency>
    <dependency>
        <groupId>io.jsonwebtoken</groupId>
        <artifactId>jjwt-impl</artifactId>
        <version>0.11.5</version>
        <scope>runtime</scope>
    </dependency>
    <dependency>
        <groupId>io.jsonwebtoken</groupId>
        <artifactId>jjwt-jackson</artifactId>
        <version>0.11.5</version>
        <scope>runtime</scope>
    </dependency>
</dependencies>
```

#### Token 验证示例

```java
@Component
public class JwtTokenValidator {
    
    private final String jwtSecret = "your-secret-key"; // 与认证服务相同
    
    public boolean validateToken(String token) {
        try {
            Jwts.parserBuilder()
                .setSigningKey(jwtSecret.getBytes())
                .build()
                .parseClaimsJws(token);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
    
    public Claims getClaimsFromToken(String token) {
        return Jwts.parserBuilder()
            .setSigningKey(jwtSecret.getBytes())
            .build()
            .parseClaimsJws(token)
            .getBody();
    }
}
```

### 2. 拦截器配置

```java
@Configuration
public class SecurityConfig {
    
    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .authorizeRequests(authorize -> authorize
                .antMatchers("/api/public/**").permitAll()
                .anyRequest().authenticated()
            )
            .addFilterBefore(new JwtAuthenticationFilter(), UsernamePasswordAuthenticationFilter.class);
        
        return http.build();
    }
}

public class JwtAuthenticationFilter extends OncePerRequestFilter {
    
    private final JwtTokenValidator tokenValidator;
    
    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain) throws ServletException, IOException {
        String token = extractTokenFromHeader(request);
        
        if (token != null && tokenValidator.validateToken(token)) {
            Claims claims = tokenValidator.getClaimsFromToken(token);
            String username = claims.getSubject();
            
            // 创建认证对象
            UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(
                username, null, Collections.emptyList()
            );
            
            // 设置认证上下文
            SecurityContextHolder.getContext().setAuthentication(authentication);
        }
        
        chain.doFilter(request, response);
    }
    
    private String extractTokenFromHeader(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        if (bearerToken != null && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }
}
```

---

## 🛠️ 常见问题排查

### 问题 1：OAuth2 回调失败

**原因**：回调 URL 配置不正确

**解决**：
- 确保反向代理正确转发 `/oauth2/` 路径
- 在 OAuth2 提供商控制台设置正确的回调 URL（使用反向代理地址）
- 例如：`http://example.com/oauth2/callback/google`

### 问题 2：CORS 错误

**原因**：跨域配置不正确

**解决**：
- 确保认证服务的 CORS 配置包含反向代理地址
- 生产环境应设置具体域名，而非使用 `*`

### 问题 3：Token 验证失败

**原因**：JWT 密钥不匹配

**解决**：
- 确保认证服务和业务服务使用相同的 JWT 密钥
- 检查 Token 格式和签名算法

### 问题 4：前端页面无法访问

**原因**：静态资源配置不正确

**解决**：
- 确保反向代理正确转发 `/static/` 路径
- 验证前端构建是否成功输出到 `src/main/resources/static` 目录

---

## 🎯 生产环境部署

### 1. HTTPS 配置

#### Nginx HTTPS 配置

```nginx
server {
    listen 443 ssl;
    server_name example.com;

    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH';

    # 其他配置与 HTTP 版本相同...
}

# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name example.com;
    return 301 https://$host$request_uri;
}
```

#### Gateway HTTPS 配置

```yaml
server:
  port: 443
  ssl:
    key-store: classpath:keystore.p12
    key-store-password: your-password
    key-store-type: PKCS12
    key-alias: tomcat

# 其他配置保持不变...
```

### 2. 环境变量管理

使用环境变量管理敏感信息：

```bash
# 认证服务环境变量
export GOOGLE_CLIENT_ID="your-client-id"
export GOOGLE_CLIENT_SECRET="your-client-secret"
export JWT_SECRET="your-secret-key"
export DATABASE_URL="jdbc:postgresql://localhost:5432/auth_db"
export DATABASE_USERNAME="postgres"
export DATABASE_PASSWORD="your-password"

# 启动认证服务
java -jar target/oauth2-demo.jar
```

### 3. 高可用配置

#### Nginx 负载均衡

```nginx
upstream auth_servers {
    server localhost:8081;
    server localhost:8082;  # 第二个认证服务实例
}

upstream business_servers {
    server localhost:9001;
    server localhost:9002;
    server localhost:9003;
}

server {
    # ...
    
    location /api/auth/ {
        proxy_pass http://auth_servers;
        # 其他配置...
    }
    
    location /api/business/ {
        proxy_pass http://business_servers;
        # 其他配置...
    }
    
    # ...
}
```

---

## 📊 性能优化

### 1. Nginx 优化

```nginx
http {
    # 连接池配置
    keepalive_timeout 65;
    keepalive_requests 10000;
    
    # 缓冲区配置
    client_body_buffer_size 16k;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 8k;
    
    # 压缩配置
    gzip on;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    # 其他配置...
}
```

### 2. Gateway 优化

```yaml
spring:
  cloud:
    gateway:
      httpclient:
        pool:
          max-idle-time: 10s
          max-life-time: 1m
          max-connections: 1000
        connect-timeout: 1000ms
        response-timeout: 5s
```

### 3. 认证服务优化

- **数据库连接池**：配置 HikariCP 连接池
- **缓存**：使用 Redis 缓存热点数据
- **异步处理**：使用 CompletableFuture 处理异步操作
- **Token 优化**：合理设置 Token 过期时间

---

## 📚 相关文件参考

- **核心配置**：`src/main/resources/application.yml`
- **安全配置**：`src/main/java/com/example/oauth2demo/config/SecurityConfig.java`
- **API 文档**：`docs/` 目录
- **前端代码**：`frontend/` 目录

---

## ❓ 获取帮助

如有问题，请参考以下资源：

- [Spring Cloud Gateway 文档](https://docs.spring.io/spring-cloud-gateway/docs/current/reference/html/)
- [Nginx 官方文档](https://nginx.org/en/docs/)
- [Spring Security OAuth2 文档](https://docs.spring.io/spring-security/reference/servlet/oauth2/index.html)
- [JWT 官方文档](https://github.com/jwtk/jjwt)

---

## 🎯 下一步

1. **集成更多业务服务**
   - 添加更多业务服务路由到反向代理
   - 实现服务间的 JWT Token 传递

2. **监控与告警**
   - 集成 Prometheus + Grafana 监控
   - 设置服务健康检查和告警

3. **部署到生产环境**
   - 使用容器化部署（Docker + Kubernetes）
   - 配置自动扩缩容

4. **安全加固**
   - 实现 Token 黑名单
   - 添加速率限制防止暴力攻击
   - 定期轮换 JWT 密钥

---

## 📄 版本历史

| 版本 | 日期 | 更新内容 |
|-----|------|---------|
| 1.0 | 2026-01-27 | 初始版本，包含 Nginx 和 Spring Gateway 配置 |
| 1.1 | 2026-01-27 | 添加前端页面集成和业务服务示例 |
