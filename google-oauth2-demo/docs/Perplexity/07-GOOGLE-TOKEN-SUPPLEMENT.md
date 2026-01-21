# 📌 补充文档：Google SSO Token 管理完整方案

**版本:** 3.0.0  
**日期:** 2026年1月21日  
**主题:** Google SSO 返回的 Tokens（Access Token & Refresh Token）如何管理

---

## 📋 目录

1. [问题回顾](#问题回顾)
2. [核心答案](#核心答案)
3. [三类 Token 的区别](#三类-token-的区别)
4. [完整流程](#完整流程)
5. [数据库设计](#数据库设计)
6. [代码实现](#代码实现)
7. [使用场景](#使用场景)

---

## 问题回顾

### 你的疑问

> Google SSO 返回的 Access Token 和 Refresh Token 不保存在后端吗？当我们需要从 Google 的资源服务获取资源的时候，不是需要 Access Token 或者 Refresh Token 吗？

### ✅ 答案

**完全正确！应该保存！** 后端必须保存这两个 Token，用来访问 Google 的资源服务。

---

## 核心答案

### 📊 三类 Token 的关系

```
Google 返回的 Token (4个)
│
├─ 1. google_access_token (用来访问 Google API)
│  └─ 有效期: ~1 小时
│  └─ 用来: GET https://www.googleapis.com/calendar/v3/...
│
├─ 2. google_refresh_token (用来获取新 access_token)
│  └─ 有效期: ~6 个月
│  └─ 用来: 当 access_token 过期时刷新
│
├─ 3. google_id_token (JWT，包含用户信息)
│  └─ 用来: 提取用户信息 (sub, email, name, picture)
│
└─ 4. expires_in (多少秒后过期)
   └─ 通常: 3599 秒 (约 1 小时)


我们系统生成的 Token (3个)
│
├─ 1. accessToken (我们系统的认证 Token)
│  └─ 用来访问我们的 API
│
├─ 2. refreshToken (我们系统的刷新 Token)
│  └─ 用来刷新我们的 accessToken
│
└─ 3. idToken (我们系统的用户信息 Token)
   └─ 展示给前端
```

### 🎯 关键要点

```
✅ Google Token 的两个用途：

用途 1: 登录认证（第一次）
  ├─ 从 google_id_token 中提取用户信息
  ├─ 创建/更新本地 users 表记录
  └─ 不需要 access_token/refresh_token

用途 2: 调用 Google API（后续）
  ├─ 使用 google_access_token 调用 Google API
  ├─ 当 access_token 过期时，用 refresh_token 刷新
  └─ ✅ 必须保存这两个 Token！
```

---

## 三类 Token 的区别

### Token 来源和用途对比表

| 方面 | Google access_token | Google refresh_token | 我们的 accessToken |
|------|-------------------|-------------------|------------------|
| **来源** | Google 颁发 | Google 颁发 | 我们颁发 |
| **用途** | 访问 Google API | 刷新 access_token | 访问我们的 API |
| **有效期** | ~1 小时 (3599秒) | ~6 个月 | ~1 小时 |
| **存储位置** | ✅ google_tokens 表 (加密) | ✅ google_tokens 表 (加密) | HttpOnly Cookie |
| **前端可见** | ❌ 不可见 | ❌ 不可见 | ❌ 不可见 |
| **刷新方式** | 用 refresh_token 获取新的 | N/A | 用我们的 refreshToken 刷新 |
| **使用场景** | 后端调用 Google Calendar/Drive/Gmail API | access_token 过期时调用 | 前端请求我们的 API |

---

## 完整流程

### Google SSO 首次登录的完整流程

```
┌──────────────────────────────────────────────────────────────┐
│ 第一步：用户点击"使用 Google 登录"                          │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│ 第二步：重定向到 Google 授权页面                             │
│ https://accounts.google.com/o/oauth2/v2/auth?               │
│   client_id=YOUR_CLIENT_ID&                                 │
│   redirect_uri=http://localhost:8080/login/oauth2/code/...  │
│   scope=openid+email+profile                                │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│ 第三步：用户输入 Google 账密 + 同意授权                     │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│ 第四步：Google 重定向回我们的后端                            │
│ GET /login/oauth2/code/google?code=AUTH_CODE&state=...      │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│ 第五步：后端用 authorization_code 交换 Token               │
│ POST https://oauth.googleapis.com/token                      │
│ {                                                            │
│   "code": "AUTH_CODE",                                       │
│   "client_id": "YOUR_CLIENT_ID",                             │
│   "client_secret": "YOUR_CLIENT_SECRET",                     │
│   "redirect_uri": "http://localhost:8080/login/oauth2/code/",
│   "grant_type": "authorization_code"                         │
│ }                                                            │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│ 第六步：Google 返回四个 Token（⭐ 关键！）                 │
│ {                                                            │
│   "access_token": "ya29.a0AfH6SMBx...",                     │
│   "refresh_token": "1//0gF7l...",                           │
│   "expires_in": 3599,                                        │
│   "token_type": "Bearer",                                    │
│   "scope": "openid email profile",                           │
│   "id_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6I..."           │
│ }                                                            │
│                                                              │
│ ✅ access_token: 用来访问 Google API                       │
│ ✅ refresh_token: 用来刷新 access_token                    │
│ ✅ id_token: JWT，包含用户信息                             │
│ ✅ expires_in: 多少秒后 access_token 过期                  │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│ 第七步：后端处理（⭐ 这是你关心的部分！）                  │
│                                                              │
│ 7.1 解析 google_id_token (JWT)                              │
│     ├─ sub: 1234567890 (Google 用户 ID)                    │
│     ├─ email: jane@gmail.com                                │
│     ├─ name: Jane Smith                                     │
│     ├─ picture: https://lh3.googleusercontent.com/...       │
│     └─ email_verified: true                                 │
│                                                              │
│ 7.2 创建/更新本地 users 表                                  │
│     INSERT INTO users (                                     │
│         username, email, display_name, avatar_url,         │
│         auth_provider, provider_user_id, email_verified    │
│     ) VALUES (                                              │
│         'jane@gmail.com',                                   │
│         'jane@gmail.com',                                   │
│         'Jane Smith',                                       │
│         'https://lh3.googleusercontent.com/...',           │
│         'GOOGLE',                                           │
│         '1234567890',                                       │
│         true                                                │
│     )                                                       │
│                                                              │
│ 7.3 ✅ 保存 Google Token 到 google_tokens 表（关键！）    │
│     INSERT INTO google_tokens (                             │
│         user_id,                                            │
│         access_token,                                       │
│         refresh_token,                                      │
│         expires_at                                          │
│     ) VALUES (                                              │
│         2,                                                  │
│         ENCRYPT('ya29.a0AfH6SMBx...'),   ← 加密存储!      │
│         ENCRYPT('1//0gF7l...'),          ← 加密存储!      │
│         NOW() + INTERVAL '1 hour'                           │
│     )                                                       │
│                                                              │
│ 7.4 生成我们的 Token                                        │
│     └─ accessToken, refreshToken, idToken                  │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│ 第八步：返回给前端                                          │
│ Set-Cookie: accessToken=...  (HttpOnly, SameSite=Strict)   │
│ Set-Cookie: refreshToken=... (HttpOnly, SameSite=Strict)   │
│ {                                                           │
│   "idToken": "...",                                         │
│   "user": {                                                 │
│     "id": 2,                                                │
│     "username": "jane@gmail.com",                           │
│     "displayName": "Jane Smith",                            │
│     "avatarUrl": "https://..."                              │
│   }                                                         │
│ }                                                           │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│ 第九步：前端保存和跳转                                      │
│ 1. localStorage.setItem('idToken', idToken)                 │
│ 2. 浏览器自动保存 Cookie                                    │
│ 3. 跳转到 Dashboard ✅                                       │
└──────────────────────────────────────────────────────────────┘
```

### 后续：调用 Google API 的流程

```
用户请求: "显示我的 Google Calendar 日历事件"
    │
    ▼
前端: POST /api/google/calendar/events
     Authorization: Bearer <我们的 accessToken>
    │
    ▼
后端验证我们的 accessToken ✅
    │
    ▼
从 google_tokens 表获取用户的 google_access_token ✅
    │
    ▼
检查是否过期?
├─ 未过期: 直接使用
└─ 已过期: 
   ├─ 调用 Google token 端点
   ├─ 用 google_refresh_token 获取新的 google_access_token
   ├─ 更新 google_tokens 表
   └─ 使用新的 token
    │
    ▼
调用 Google Calendar API ✅
GET https://www.googleapis.com/calendar/v3/calendars/primary/events
Authorization: Bearer <google_access_token>
    │
    ▼
Google 返回日历事件
    │
    ▼
后端处理并返回给前端
    │
    ▼
前端展示日历事件 ✅
```

---

## 数据库设计

### 修改后的 users 表

```sql
-- 修改现有的 users 表，添加一个关系字段
ALTER TABLE users ADD COLUMN google_token_id BIGINT;
ALTER TABLE users ADD FOREIGN KEY (google_token_id) REFERENCES google_tokens(id);

-- 或者更简单的方式：在 users 表中直接添加字段
ALTER TABLE users ADD COLUMN google_access_token TEXT;
ALTER TABLE users ADD COLUMN google_refresh_token TEXT;
ALTER TABLE users ADD COLUMN google_token_expires_at TIMESTAMP;
```

### 推荐方案：创建单独的 google_tokens 表

```sql
CREATE TABLE google_tokens (
    -- 主键
    id BIGSERIAL PRIMARY KEY,
    
    -- 关联用户（一对一关系）
    user_id BIGINT NOT NULL UNIQUE,
    
    -- ✅ Google 返回的 Token（必须加密存储！）
    access_token TEXT NOT NULL,           -- ya29.a0AfH6SMBx...
    refresh_token TEXT,                   -- 1//0gF7l...
    
    -- Token 元数据
    token_type VARCHAR(50) DEFAULT 'Bearer',
    scope TEXT,                           -- openid email profile
    
    -- ✅ 过期时间（自动刷新的关键！）
    expires_at TIMESTAMP NOT NULL,        -- 何时过期
    
    -- 审计字段
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- 外键约束
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT unique_user_google_token UNIQUE(user_id)
);

-- 创建索引以提高查询性能
CREATE INDEX idx_google_tokens_user_id ON google_tokens(user_id);
CREATE INDEX idx_google_tokens_expires_at ON google_tokens(expires_at);
```

### 实体类定义

```java
// UserEntity.java（修改）
@Entity
@Table(name = "users")
public class UserEntity {
    // ... 现有字段 ...
    
    // ✅ 新增：一对一关系到 Google Token
    @OneToOne(mappedBy = "user", cascade = CascadeType.ALL, orphanRemoval = true)
    private GoogleToken googleToken;
}

// GoogleToken.java（新增）
@Entity
@Table(name = "google_tokens")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GoogleToken {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    // 关联用户
    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", unique = true, nullable = false)
    private UserEntity user;
    
    // ✅ Google 返回的 Token（加密存储）
    @Column(columnDefinition = "TEXT", nullable = false)
    private String accessToken;           // 加密后存储
    
    @Column(columnDefinition = "TEXT")
    private String refreshToken;          // 加密后存储
    
    // Token 元数据
    @Column(nullable = false)
    private String tokenType = "Bearer";
    
    @Column(columnDefinition = "TEXT")
    private String scope;
    
    // ✅ 过期时间
    @Column(nullable = false)
    private LocalDateTime expiresAt;
    
    // 审计字段
    @CreationTimestamp
    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;
    
    @UpdateTimestamp
    @Column(nullable = false)
    private LocalDateTime updatedAt;
    
    // 便利方法
    public boolean isExpired() {
        return LocalDateTime.now().isAfter(expiresAt);
    }
    
    public boolean isAboutToExpire() {
        // 提前 5 分钟刷新
        return LocalDateTime.now().isAfter(expiresAt.minusMinutes(5));
    }
}
```

---

## 代码实现

### 1. GoogleTokenRepository

```java
@Repository
public interface GoogleTokenRepository extends JpaRepository<GoogleToken, Long> {
    Optional<GoogleToken> findByUserId(Long userId);
    
    // 查询所有即将过期的 Token
    @Query("SELECT gt FROM GoogleToken gt WHERE gt.expiresAt < NOW()")
    List<GoogleToken> findExpiredTokens();
}
```

### 2. GoogleOAuth2SuccessHandler（修改）

```java
@Component
@RequiredArgsConstructor
public class GoogleOAuth2SuccessHandler implements AuthenticationSuccessHandler {

    private final UserService userService;
    private final GoogleTokenService googleTokenService;
    private final OAuth2TokenGenerator tokenGenerator;

    @Override
    public void onAuthenticationSuccess(
        HttpServletRequest request,
        HttpServletResponse response,
        Authentication authentication) throws IOException {

        try {
            // 1. 提取 Google 用户信息
            OAuth2User googleUser = (OAuth2User) authentication.getPrincipal();
            
            String providerUserId = googleUser.getName();
            String email = googleUser.getAttribute("email");
            String name = googleUser.getAttribute("name");
            String picture = googleUser.getAttribute("picture");
            
            // 2. ✅ 从 OAuth2 Authentication 提取 Google Token
            String googleAccessToken = extractAccessToken(authentication);
            String googleRefreshToken = extractRefreshToken(authentication);
            Integer expiresIn = (Integer) ((Map) authentication.getDetails())
                .getOrDefault("expires_in", 3599);
            
            // 3. 获取或创建本地用户
            UserEntity user = userService.getOrCreateGoogleUser(
                providerUserId, 
                email, 
                name, 
                picture
            );
            
            // 4. ✅ 保存 Google Token 到数据库（关键！）
            googleTokenService.saveGoogleToken(
                user.getId(),
                googleAccessToken,
                googleRefreshToken,
                LocalDateTime.now().plusSeconds(expiresIn)
            );
            
            // 5. 生成我们的 Token
            String accessToken = tokenGenerator.generateAccessToken(user);
            String refreshToken = tokenGenerator.generateRefreshToken(user);
            String idToken = tokenGenerator.generateIdToken(user);
            
            // 6. 设置 HttpOnly Cookie
            addCookie(response, "accessToken", accessToken, 3600);
            addCookie(response, "refreshToken", refreshToken, 604800);
            
            // 7. 返回响应
            response.setContentType("application/json");
            response.getWriter().write(new ObjectMapper().writeValueAsString(
                Map.of(
                    "idToken", idToken,
                    "user", convertToDto(user)
                )
            ));
            
        } catch (Exception e) {
            response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            response.getWriter().write("Authentication failed: " + e.getMessage());
        }
    }

    // ✅ 从 OAuth2 Authentication 中提取 Google access_token
    private String extractAccessToken(Authentication authentication) {
        try {
            OAuth2AuthenticationToken oauth2Token = (OAuth2AuthenticationToken) authentication;
            // 具体的提取方式取决于 Spring Security 的配置
            // 通常在 attributes 或 credentials 中
            Map<String, Object> attributes = oauth2Token.getPrincipal().getAttributes();
            
            // 根据 Spring 的 OAuth2 配置，access_token 可能在不同地方
            if (attributes.containsKey("access_token")) {
                return (String) attributes.get("access_token");
            }
            
            // 备选方式：从 details 中获取
            Object credentials = oauth2Token.getCredentials();
            if (credentials instanceof OAuth2AccessToken) {
                return ((OAuth2AccessToken) credentials).getTokenValue();
            }
            
            throw new RuntimeException("无法提取 Google access_token");
        } catch (Exception e) {
            throw new RuntimeException("提取 access_token 失败: " + e.getMessage());
        }
    }

    // ✅ 从 OAuth2 Authentication 中提取 Google refresh_token
    private String extractRefreshToken(Authentication authentication) {
        try {
            OAuth2AuthenticationToken oauth2Token = (OAuth2AuthenticationToken) authentication;
            Map<String, Object> attributes = oauth2Token.getPrincipal().getAttributes();
            
            // refresh_token 在首次登录时返回，但后续可能不返回
            if (attributes.containsKey("refresh_token")) {
                return (String) attributes.get("refresh_token");
            }
            
            return null; // refresh_token 可能为 null（后续登录）
        } catch (Exception e) {
            return null;
        }
    }

    private void addCookie(HttpServletResponse response, String name, String value, int maxAge) {
        ResponseCookie cookie = ResponseCookie
            .from(name, value)
            .httpOnly(true)
            .secure(true)
            .sameSite("Strict")
            .path("/api")
            .maxAge(maxAge)
            .build();
        
        response.addHeader("Set-Cookie", cookie.toString());
    }

    private UserDto convertToDto(UserEntity user) {
        return UserDto.builder()
            .id(user.getId())
            .username(user.getUsername())
            .email(user.getEmail())
            .displayName(user.getDisplayName())
            .avatarUrl(user.getAvatarUrl())
            .build();
    }
}
```

### 3. GoogleTokenService（新增）

```java
@Service
@RequiredArgsConstructor
public class GoogleTokenService {
    
    private final GoogleTokenRepository googleTokenRepository;
    private final UserRepository userRepository;
    private final TokenEncryption encryption;
    
    @Value("${google.client-id}")
    private String googleClientId;
    
    @Value("${google.client-secret}")
    private String googleClientSecret;
    
    private final RestTemplate restTemplate = new RestTemplate();

    /**
     * ✅ 保存 Google Token 到数据库
     */
    public void saveGoogleToken(
        Long userId,
        String googleAccessToken,
        String googleRefreshToken,
        LocalDateTime expiresAt) {
        
        UserEntity user = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("用户不存在"));
        
        GoogleToken googleToken = googleTokenRepository
            .findByUserId(userId)
            .orElse(new GoogleToken());
        
        googleToken.setUser(user);
        googleToken.setAccessToken(encryption.encrypt(googleAccessToken));  // ✅ 加密
        googleToken.setRefreshToken(
            googleRefreshToken != null ? encryption.encrypt(googleRefreshToken) : null
        );
        googleToken.setExpiresAt(expiresAt);
        
        googleTokenRepository.save(googleToken);
    }

    /**
     * ✅ 获取有效的 Google access_token（自动刷新）
     */
    public String getValidAccessToken(Long userId) {
        GoogleToken googleToken = googleTokenRepository.findByUserId(userId)
            .orElseThrow(() -> new RuntimeException("用户未授权 Google"));
        
        // 如果即将过期，自动刷新
        if (googleToken.isAboutToExpire()) {
            refreshGoogleToken(googleToken);
        }
        
        return encryption.decrypt(googleToken.getAccessToken());
    }

    /**
     * ✅ 刷新过期的 Google Token
     */
    public void refreshGoogleToken(GoogleToken googleToken) {
        if (googleToken.getRefreshToken() == null) {
            throw new RuntimeException("Google refresh_token 为空，无法刷新");
        }
        
        try {
            // 1. 准备请求体
            Map<String, String> body = new HashMap<>();
            body.put("client_id", googleClientId);
            body.put("client_secret", googleClientSecret);
            body.put("refresh_token", encryption.decrypt(googleToken.getRefreshToken()));
            body.put("grant_type", "refresh_token");
            
            // 2. 调用 Google token 端点
            ResponseEntity<Map> response = restTemplate.postForEntity(
                "https://oauth.googleapis.com/token",
                body,
                Map.class
            );
            
            if (response.getStatusCode() != HttpStatus.OK) {
                throw new RuntimeException("Google token 刷新失败");
            }
            
            Map<String, Object> responseBody = response.getBody();
            
            // 3. 更新 Token
            String newAccessToken = (String) responseBody.get("access_token");
            Integer expiresIn = (Integer) responseBody.getOrDefault("expires_in", 3599);
            
            googleToken.setAccessToken(encryption.encrypt(newAccessToken));
            googleToken.setExpiresAt(LocalDateTime.now().plusSeconds(expiresIn));
            
            // 刷新的响应可能包含新的 refresh_token
            if (responseBody.containsKey("refresh_token")) {
                String newRefreshToken = (String) responseBody.get("refresh_token");
                googleToken.setRefreshToken(encryption.encrypt(newRefreshToken));
            }
            
            googleTokenRepository.save(googleToken);
            
        } catch (Exception e) {
            throw new RuntimeException("刷新 Google Token 失败: " + e.getMessage(), e);
        }
    }
}
```

### 4. Token 加密服务

```java
@Component
public class TokenEncryption {
    
    @Value("${encryption.key}")
    private String encryptionKey;

    /**
     * ✅ 加密 Token（存储到数据库）
     */
    public String encrypt(String token) {
        if (token == null) return null;
        
        try {
            Cipher cipher = Cipher.getInstance("AES");
            SecretKeySpec key = new SecretKeySpec(
                encryptionKey.getBytes(StandardCharsets.UTF_8),
                0,
                16,
                "AES"
            );
            cipher.init(Cipher.ENCRYPT_MODE, key);
            
            byte[] encryptedData = cipher.doFinal(token.getBytes());
            return Base64.getEncoder().encodeToString(encryptedData);
            
        } catch (Exception e) {
            throw new RuntimeException("Token 加密失败", e);
        }
    }

    /**
     * ✅ 解密 Token（从数据库读取）
     */
    public String decrypt(String encryptedToken) {
        if (encryptedToken == null) return null;
        
        try {
            Cipher cipher = Cipher.getInstance("AES");
            SecretKeySpec key = new SecretKeySpec(
                encryptionKey.getBytes(StandardCharsets.UTF_8),
                0,
                16,
                "AES"
            );
            cipher.init(Cipher.DECRYPT_MODE, key);
            
            byte[] decodedData = Base64.getDecoder().decode(encryptedToken);
            byte[] decryptedData = cipher.doFinal(decodedData);
            
            return new String(decryptedData);
            
        } catch (Exception e) {
            throw new RuntimeException("Token 解密失败", e);
        }
    }
}
```

### 5. 使用 Google API 示例

```java
@RestController
@RequestMapping("/api/google")
@RequiredArgsConstructor
public class GoogleIntegrationController {
    
    private final GoogleTokenService googleTokenService;
    private final RestTemplate restTemplate;

    /**
     * ✅ 获取用户的 Google Calendar 事件
     */
    @GetMapping("/calendar/events")
    public ResponseEntity<?> getCalendarEvents(
        @RequestHeader("Authorization") String bearerToken) {
        
        try {
            // 1. 验证我们的 accessToken，提取用户 ID
            Long userId = extractUserIdFromToken(bearerToken);
            
            // 2. 获取用户的 Google access_token（自动刷新）
            String googleAccessToken = googleTokenService.getValidAccessToken(userId);
            
            // 3. 调用 Google Calendar API
            HttpHeaders headers = new HttpHeaders();
            headers.set("Authorization", "Bearer " + googleAccessToken);
            headers.set("Accept", "application/json");
            
            HttpEntity<String> entity = new HttpEntity<>(headers);
            
            ResponseEntity<String> response = restTemplate.exchange(
                "https://www.googleapis.com/calendar/v3/calendars/primary/events",
                HttpMethod.GET,
                entity,
                String.class
            );
            
            // 4. 返回日历事件
            return ResponseEntity.ok(response.getBody());
            
        } catch (HttpClientErrorException.Unauthorized e) {
            return ResponseEntity.status(401).body("Google Token 已过期或无效");
        } catch (Exception e) {
            return ResponseEntity.status(500).body("获取日历事件失败: " + e.getMessage());
        }
    }

    /**
     * ✅ 获取用户的 Google Drive 文件列表
     */
    @GetMapping("/drive/files")
    public ResponseEntity<?> getGoogleDriveFiles(
        @RequestHeader("Authorization") String bearerToken) {
        
        try {
            Long userId = extractUserIdFromToken(bearerToken);
            String googleAccessToken = googleTokenService.getValidAccessToken(userId);
            
            HttpHeaders headers = new HttpHeaders();
            headers.set("Authorization", "Bearer " + googleAccessToken);
            
            HttpEntity<String> entity = new HttpEntity<>(headers);
            
            ResponseEntity<String> response = restTemplate.exchange(
                "https://www.googleapis.com/drive/v3/files",
                HttpMethod.GET,
                entity,
                String.class
            );
            
            return ResponseEntity.ok(response.getBody());
            
        } catch (Exception e) {
            return ResponseEntity.status(500).body("获取 Google Drive 文件失败");
        }
    }

    private Long extractUserIdFromToken(String bearerToken) {
        // 从 JWT Token 中提取用户 ID
        String token = bearerToken.replace("Bearer ", "");
        // 解析 JWT 并返回 userId
        // 这里使用你的 TokenProvider 工具类
        return tokenProvider.getUserIdFromToken(token);
    }
}
```

---

## 使用场景

### 场景 1：首次登录（只需要用户信息）

```
Google 返回四个 Token
    ↓
✅ 从 google_id_token 提取用户信息 (email, name, picture)
    ↓
✅ 保存到 users 表
    ↓
✅ 保存 google_access_token 和 google_refresh_token 到 google_tokens 表
    │  （即使不需要调用 Google API，也应该保存，以备后用）
    ↓
✅ 生成我们的 Token
    ↓
登录成功 ✅
```

### 场景 2：调用 Google Calendar API

```
用户请求: "显示我的日历"
    ↓
前端: GET /api/google/calendar/events
     Authorization: Bearer <我们的 accessToken>
    ↓
后端:
1. 验证我们的 accessToken ✅
2. 获取用户的 google_access_token ✅
3. 检查是否过期
   ├─ 未过期: 直接使用
   └─ 已过期: 自动用 refresh_token 刷新
4. 调用 Google Calendar API ✅
5. 返回日历数据
    ↓
前端显示日历 ✅
```

### 场景 3：Google Token 自动过期和刷新

```
用户上午登录，下午仍在使用应用
    ↓
google_access_token 有效期: 1 小时
    ↓
1 小时后，用户请求 Google API
    ↓
后端检查: isAboutToExpire() = true
    ↓
自动调用 Google token 端点刷新:
POST https://oauth.googleapis.com/token
{
  "refresh_token": <保存的 google_refresh_token>,
  ...
}
    ↓
Google 返回新的 google_access_token
    ↓
更新 google_tokens 表
    ↓
用新的 token 调用 Google API
    ↓
用户无感知，继续使用应用 ✅
```

---

## 配置示例

### application.yml

```yaml
spring:
  # Google OAuth2 配置
  security:
    oauth2:
      client:
        registration:
          google:
            client-id: ${GOOGLE_CLIENT_ID}
            client-secret: ${GOOGLE_CLIENT_SECRET}
            scope:
              - openid
              - email
              - profile
              - https://www.googleapis.com/auth/calendar
              - https://www.googleapis.com/auth/drive
        provider:
          google:
            authorization-uri: https://accounts.google.com/o/oauth2/v2/auth
            token-uri: https://oauth.googleapis.com/token
            user-info-uri: https://www.googleapis.com/oauth2/v1/userinfo
            user-name-attribute: sub

# Token 加密密钥（从环境变量读取）
encryption:
  key: ${ENCRYPTION_KEY}

# Google 客户端信息
google:
  client-id: ${GOOGLE_CLIENT_ID}
  client-secret: ${GOOGLE_CLIENT_SECRET}
```

### 环境变量设置

```bash
# .env 或环境变量
export GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com
export GOOGLE_CLIENT_SECRET=xxx
export ENCRYPTION_KEY=your-16-char-key   # 16 个字符的加密密钥
```

---

## 总结

### ✅ Google Token 管理的关键点

| 方面 | 处理方式 |
|------|--------|
| **access_token** | ✅ 保存到 google_tokens 表，加密存储 |
| **refresh_token** | ✅ 保存到 google_tokens 表，加密存储 |
| **expires_at** | ✅ 记录过期时间，自动刷新 |
| **前端访问** | ❌ 前端不需要知道，所有调用在后端进行 |
| **加密方式** | ✅ AES 加密，密钥存环境变量 |
| **刷新机制** | ✅ 提前 5 分钟自动刷新 |
| **使用场景** | ✅ 调用 Google Calendar/Drive/Gmail API |

### 📝 完整清单

```
✅ 创建 google_tokens 表
✅ 创建 GoogleToken 实体类
✅ 创建 GoogleTokenRepository
✅ 创建 GoogleTokenService（保存和刷新逻辑）
✅ 创建 TokenEncryption（加密解密）
✅ 修改 GoogleOAuth2SuccessHandler（保存 Token）
✅ 创建 GoogleIntegrationController（调用 API）
✅ 配置 application.yml
✅ 设置环境变量
```

---

**现在你拥有了完整的 Google Token 管理方案！** 🎉
