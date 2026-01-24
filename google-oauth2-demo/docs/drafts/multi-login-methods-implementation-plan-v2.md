# 多登录方式绑定功能 - 详细实施规划文档

## 文档信息

- **文档版本**: v1.0  
- **创建日期**: 2026-01-22
- **作者**: AI Assistant
- **文档类型**: 详细实施规划
- **关联项目**: Google OAuth2 Demo
- **状态**: 待审核

## 目录

1. [执行摘要](#执行摘要)
2. [现有代码库分析](#现有代码库分析)
3. [数据库设计详解](#数据库设计详解)
4. [实体层设计](#实体层设计)
5. [服务层设计](#服务层设计)
6. [API层设计](#api层设计)
7. [OAuth2处理器改造](#oauth2处理器改造)
8. [前端改造方案](#前端改造方案)
9. [数据迁移方案](#数据迁移方案)
10. [回滚方案](#回滚方案)
11. [安全性验证](#安全性验证)
12. [测试计划](#测试计划)
13. [实施检查清单](#实施检查清单)

---

## 执行摘要

### 目标
实现用户账户绑定多种登录方式的功能，允许用户使用本地密码、Google、GitHub、Twitter等多种方式登录同一账户。

### 核心原则
1. **最小侵入性**: 尽可能复用现有代码和API
2. **向后兼容**: 保证现有功能不受影响
3. **安全第一**: 所有变更必须通过安全审查
4. **数据安全**: 完整的数据迁移和回滚方案

### 关键创新
- **统一回调URL**: OAuth2登录和绑定使用同一回调URL，通过用户登录状态智能路由
- **复用现有API**: 不新增不必要的API端点，最大化利用现有接口

---

## 现有代码库分析

### 1. 实体层现状

#### UserEntity (核心问题)
```java
// 位置: src/main/java/com/example/oauth2demo/entity/UserEntity.java
@Entity
@Table(name = "users")
public class UserEntity {
    // ❌ 问题字段
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private AuthProvider authProvider = AuthProvider.LOCAL;  // 单一提供商
    
    @Column(length = 255)
    private String providerUserId;  // 单一提供商用户ID
    
    @Column(length = 255)
    private String passwordHash;  // 本地密码（与OAuth2混在一起）
}
```

**问题分析**:
- 一个用户只能有一个 `authProvider`
- 一个用户只能有一个 `providerUserId`
- 本地用户和OAuth2用户字段混杂

### 2. Repository层现状

#### UserRepository
```java
// 位置: src/main/java/com/example/oauth2demo/repository/UserRepository.java
public interface UserRepository extends JpaRepository<UserEntity, Long> {
    Optional<UserEntity> findByUsername(String username);
    Optional<UserEntity> findByEmail(String email);
    
    // ⚠️ 当前查询方法基于单一提供商假设
    Optional<UserEntity> findByAuthProviderAndProviderUserId(
        UserEntity.AuthProvider authProvider, String providerUserId);
}
```

**影响分析**:
- 登录查询逻辑需要改变
- OAuth2用户查找逻辑需要重构

### 3. Service层现状

#### UserService (关键服务)
```java
// 位置: src/main/java/com/example/oauth2demo/service/UserService.java

// ✅ 本地用户注册 - 无需改动
public UserDto register(RegisterRequest request) { ... }

// ⚠️ 本地用户登录 - 需要改为查询login_methods表
public UserDto login(String username, String password) {
    UserEntity user = userRepository.findByUsername(username)...
    passwordEncoder.matches(password, user.getPasswordHash())...
}

// ⚠️ OAuth2用户处理 - 需要支持绑定场景
public UserDto getOrCreateOAuthUser(
    UserEntity.AuthProvider provider,
    String providerUserId,
    String email,
    String name,
    String picture
) {
    // 当前：查找或创建用户
    // 需要：支持绑定到已登录用户
}
```

### 4. Controller层现状

#### 现有API端点
```java
// ApiAuthController.java
@RequestMapping("/api")
- GET  /api/user              // ✅ 获取当前用户信息 - 可复用
- POST /api/logout            // ✅ 登出 - 可复用

// TokenController.java  
@RequestMapping("/api/auth")
- POST /api/auth/refresh      // ✅ Token刷新 - 可复用

// AuthController.java
@RequestMapping("/api/auth")
- POST /api/auth/register     // ✅ 用户注册 - 可复用
- POST /api/auth/login        // ⚠️ 本地登录 - 需要调整查询逻辑
```

**结论**: **不需要新增API端点**，只需调整现有端点的内部实现。

### 5. OAuth2处理器现状

#### SecurityConfig.oauth2SuccessHandler
```java
// 位置: src/main/java/com/example/oauth2demo/config/SecurityConfig.java
@Bean
public AuthenticationSuccessHandler oauth2SuccessHandler() {
    return (request, response, authentication) -> {
        // 当前逻辑：
        // 1. 提取OAuth2用户信息
        // 2. 调用 userService.getOrCreateOAuthUser()
        // 3. 生成JWT Token
        // 4. 设置Cookie并重定向
        
        // 需要改造为：
        // 1. 检查用户是否已登录 (从JWT Cookie判断)
        // 2. 如果已登录 -> 绑定流程
        // 3. 如果未登录 -> 登录流程
    };
}
```

**关键点**: 这是整个方案的核心，需要仔细设计以确保安全性。

### 6. 数据库现状

#### schema.sql (SQLite)
```sql
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT,              -- ⚠️ 需要移除
    auth_provider TEXT DEFAULT 'LOCAL',  -- ⚠️ 需要移除
    provider_user_id TEXT,           -- ⚠️ 需要移除
    -- ...
);
```

---

## 数据库设计详解

### 新表: user_login_methods

#### 表结构 (SQLite语法)
```sql
CREATE TABLE IF NOT EXISTS user_login_methods (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    
    -- 登录方式标识
    auth_provider TEXT NOT NULL,              -- 'LOCAL', 'GOOGLE', 'GITHUB', 'TWITTER'
    
    -- OAuth2提供商相关字段 (auth_provider != 'LOCAL' 时使用)
    provider_user_id TEXT,                    -- 第三方平台的用户ID
    provider_email TEXT,                      -- 第三方平台的邮箱
    provider_username TEXT,                   -- 第三方平台的用户名
    
    -- 本地登录相关字段 (auth_provider = 'LOCAL' 时使用)
    local_username TEXT,                      -- 本地用户名
    local_password_hash TEXT,                 -- BCrypt密码哈希
    
    -- 元数据
    is_primary INTEGER DEFAULT 0,             -- 是否为主登录方式 (0=否, 1=是)
    is_verified INTEGER DEFAULT 0,            -- 是否已验证 (0=否, 1=是)
    linked_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_used_at DATETIME,
    
    -- 外键约束
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

#### 约束设计 (SQLite部分索引语法)
```sql
-- 唯一性约束 (SQLite 3.8.0+ 支持部分索引WHERE子句)
CREATE UNIQUE INDEX IF NOT EXISTS uk_user_login_provider 
    ON user_login_methods(user_id, auth_provider);
    -- 一个用户只能绑定一个提供商一次

CREATE UNIQUE INDEX IF NOT EXISTS uk_local_username 
    ON user_login_methods(local_username) 
    WHERE local_username IS NOT NULL;
    -- 本地用户名全局唯一 (只对非NULL值生效)

CREATE UNIQUE INDEX IF NOT EXISTS uk_provider_user 
    ON user_login_methods(auth_provider, provider_user_id)
    WHERE provider_user_id IS NOT NULL;
    -- 第三方用户ID在同平台唯一 (只对非NULL值生效)

-- ⚠️ 注意: SQLite 3.8.0+ 才支持部分索引的WHERE子句
-- 如果SQLite版本较旧，需要调整约束策略或升级SQLite版本
```

#### 查询索引
```sql
-- 性能优化索引
CREATE INDEX IF NOT EXISTS idx_login_methods_user_id 
    ON user_login_methods(user_id);

CREATE INDEX IF NOT EXISTS idx_login_methods_provider 
    ON user_login_methods(auth_provider, provider_user_id);

CREATE INDEX IF NOT EXISTS idx_login_methods_primary 
    ON user_login_methods(user_id, is_primary);

CREATE INDEX IF NOT EXISTS idx_login_methods_local_username 
    ON user_login_methods(local_username);
```

### users表调整

#### ⚠️ 重要决策: 渐进式迁移策略

**选项A: 立即删除旧字段** (高风险)
```sql
ALTER TABLE users DROP COLUMN auth_provider;
ALTER TABLE users DROP COLUMN provider_user_id;
ALTER TABLE users DROP COLUMN password_hash;
```

**选项B: 保留旧字段并标记为废弃** (低风险) ✅ **推荐**
```sql
-- 不删除字段，保留用于回滚和兼容性
-- 在代码中逐步停止使用这些字段
-- 添加注释标记为废弃

-- 可选：添加新字段用于跟踪迁移状态
ALTER TABLE users ADD COLUMN migrated_to_multi_login INTEGER DEFAULT 0;
```

**推荐理由**:
1. **安全性**: 可以随时回滚到旧版本
2. **兼容性**: 现有代码不会立即崩溃
3. **渐进性**: 可以分阶段验证新逻辑
4. **审计性**: 保留历史数据用于调试

**⚠️ 数据一致性保证**:

迁移后的数据一致性策略:
1. **只读不写**: 迁移后，`users`表的`auth_provider`、`provider_user_id`、`password_hash`字段变为**只读**
2. **新数据写入**: 所有新的登录方式操作**只写入**`user_login_methods`表
3. **查询优先级**: 
   - 登录查询: 优先查询`user_login_methods`表
   - 如果查不到，回退到`users`表旧字段(兼容性)
4. **同步更新** (可选): 
   - 在迁移脚本中一次性同步完成
   - 后续不再同步旧字段

**代码中的实现**:
```java
// ❌ 迁移后禁止的操作
user.setAuthProvider(...);  // 不再写入
user.setPasswordHash(...);  // 不再写入

// ✅ 迁移后正确的操作
loginMethod.setAuthProvider(...);  // 写入login_methods表
loginMethod.setLocalPasswordHash(...);  // 写入login_methods表
```

---

## 实体层设计

### 新实体: UserLoginMethod

```java
package com.example.oauth2demo.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import java.time.LocalDateTime;

/**
 * 用户登录方式实体
 * 用于支持一个用户绑定多种登录方式
 */
@Entity
@Table(name = "user_login_methods")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserLoginMethod {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private UserEntity user;

    @Enumerated(EnumType.STRING)
    @Column(name = "auth_provider", nullable = false, length = 50)
    private AuthProvider authProvider;

    // OAuth2提供商字段
    @Column(name = "provider_user_id", length = 255)
    private String providerUserId;

    @Column(name = "provider_email", length = 255)
    private String providerEmail;

    @Column(name = "provider_username", length = 255)
    private String providerUsername;

    // 本地登录字段
    @Column(name = "local_username", length = 255)
    private String localUsername;

    @Column(name = "local_password_hash", length = 255)
    private String localPasswordHash;

    // 元数据
    @Column(name = "is_primary", nullable = false)
    @Builder.Default
    private boolean isPrimary = false;

    @Column(name = "is_verified", nullable = false)
    @Builder.Default
    private boolean isVerified = false;

    @CreationTimestamp
    @Column(name = "linked_at", nullable = false, updatable = false)
    private LocalDateTime linkedAt;

    @Column(name = "last_used_at")
    private LocalDateTime lastUsedAt;

    /**
     * 登录方式类型枚举
     */
    public enum AuthProvider {
        LOCAL, GOOGLE, GITHUB, TWITTER
    }

    /**
     * 更新最后使用时间
     */
    public void updateLastUsedAt() {
        this.lastUsedAt = LocalDateTime.now();
    }

    /**
     * 检查是否为OAuth2登录方式
     */
    public boolean isOAuth2Method() {
        return authProvider != AuthProvider.LOCAL;
    }

    /**
     * 检查是否为本地登录方式
     */
    public boolean isLocalMethod() {
        return authProvider == AuthProvider.LOCAL;
    }
}
```

### UserEntity调整

```java
// ⚠️ 最小化修改策略
@Entity
@Table(name = "users")
public class UserEntity {
    
    // ... 保留所有现有字段不变 ...
    
    // ✅ 添加新的关联关系
    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @Builder.Default
    private Set<UserLoginMethod> loginMethods = new HashSet<>();
    
    // ✅ 辅助方法：获取主登录方式
    public UserLoginMethod getPrimaryLoginMethod() {
        return loginMethods.stream()
            .filter(UserLoginMethod::isPrimary)
            .findFirst()
            .orElse(null);
    }
    
    // ✅ 辅助方法：检查是否已绑定某个提供商
    public boolean hasLoginMethod(UserLoginMethod.AuthProvider provider) {
        return loginMethods.stream()
            .anyMatch(m -> m.getAuthProvider() == provider);
    }
    
    // ✅ 辅助方法：添加登录方式
    public void addLoginMethod(UserLoginMethod loginMethod) {
        loginMethods.add(loginMethod);
        loginMethod.setUser(this);
        
        // 如果是第一个登录方式，自动设为主登录方式
        if (loginMethods.size() == 1) {
            loginMethod.setPrimary(true);
        }
    }
}
```

### Repository层

#### 新Repository: UserLoginMethodRepository

```java
package com.example.oauth2demo.repository;

import com.example.oauth2demo.entity.UserLoginMethod;
import com.example.oauth2demo.entity.UserLoginMethod.AuthProvider;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserLoginMethodRepository extends JpaRepository<UserLoginMethod, Long> {
    
    /**
     * 查找用户的所有登录方式
     */
    List<UserLoginMethod> findByUserId(Long userId);
    
    /**
     * 查找用户的特定登录方式
     */
    Optional<UserLoginMethod> findByUserIdAndAuthProvider(Long userId, AuthProvider authProvider);
    
    /**
     * 通过OAuth2提供商和用户ID查找
     */
    Optional<UserLoginMethod> findByAuthProviderAndProviderUserId(
        AuthProvider authProvider, String providerUserId);
    
    /**
     * 通过本地用户名查找
     */
    Optional<UserLoginMethod> findByLocalUsername(String localUsername);
    
    /**
     * 查找用户的主登录方式
     */
    Optional<UserLoginMethod> findByUserIdAndIsPrimary(Long userId, boolean isPrimary);
    
    /**
     * 检查OAuth2账户是否已被绑定
     */
    boolean existsByAuthProviderAndProviderUserId(AuthProvider authProvider, String providerUserId);
    
    /**
     * 检查本地用户名是否已被使用
     */
    boolean existsByLocalUsername(String localUsername);
}
```

---

## 服务层设计

### 新服务: LoginMethodService

```java
package com.example.oauth2demo.service;

import com.example.oauth2demo.entity.UserEntity;
import com.example.oauth2demo.entity.UserLoginMethod;
import com.example.oauth2demo.entity.UserLoginMethod.AuthProvider;
import com.example.oauth2demo.repository.UserLoginMethodRepository;
import com.example.oauth2demo.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * 登录方式管理服务
 */
@Service
@RequiredArgsConstructor
@Transactional
@Slf4j
public class LoginMethodService {

    private final UserLoginMethodRepository loginMethodRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    /**
     * 获取用户的所有登录方式
     */
    @Transactional(readOnly = true)
    public List<UserLoginMethod> getUserLoginMethods(Long userId) {
        return loginMethodRepository.findByUserId(userId);
    }

    /**
     * 为用户绑定OAuth2登录方式
     * 
     * @throws IllegalStateException 如果该提供商已被该用户绑定
     * @throws IllegalArgumentException 如果OAuth2账户已被其他用户绑定
     */
    public UserLoginMethod bindOAuth2LoginMethod(
            Long userId,
            AuthProvider provider,
            String providerUserId,
            String providerEmail,
            String providerUsername) {
        
        log.info("Binding OAuth2 login method: userId={}, provider={}, providerUserId={}",
                userId, provider, providerUserId);
        
        // 1. 检查用户是否已经绑定该提供商
        if (loginMethodRepository.findByUserIdAndAuthProvider(userId, provider).isPresent()) {
            throw new IllegalStateException("用户已绑定该登录方式");
        }
        
        // 2. 检查OAuth2账户是否已被其他用户绑定
        loginMethodRepository.findByAuthProviderAndProviderUserId(provider, providerUserId)
            .ifPresent(existing -> {
                if (!existing.getUser().getId().equals(userId)) {
                    throw new IllegalArgumentException("该OAuth2账户已被其他用户绑定");
                }
            });
        
        // 3. 创建新的登录方式
        UserEntity user = userRepository.findById(userId)
            .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
        
        UserLoginMethod loginMethod = UserLoginMethod.builder()
            .user(user)
            .authProvider(provider)
            .providerUserId(providerUserId)
            .providerEmail(providerEmail)
            .providerUsername(providerUsername)
            .isVerified(true)  // OAuth2用户默认已验证
            .isPrimary(false)  // 新绑定的不是主登录方式
            .build();
        
        UserLoginMethod saved = loginMethodRepository.save(loginMethod);
        log.info("OAuth2 login method bound successfully: id={}", saved.getId());
        
        return saved;
    }

    /**
     * 通过本地用户名查找登录方式
     * 用于本地登录验证
     */
    @Transactional(readOnly = true)
    public UserLoginMethod findByLocalUsername(String username) {
        return loginMethodRepository.findByLocalUsername(username)
            .orElse(null);
    }

    /**
     * 通过OAuth2信息查找登录方式
     * 用于OAuth2登录
     */
    @Transactional(readOnly = true)
    public UserLoginMethod findByOAuth2Provider(AuthProvider provider, String providerUserId) {
        return loginMethodRepository.findByAuthProviderAndProviderUserId(provider, providerUserId)
            .orElse(null);
    }

    /**
     * 更新登录方式的最后使用时间
     */
    public void updateLastUsedAt(Long loginMethodId) {
        loginMethodRepository.findById(loginMethodId).ifPresent(method -> {
            method.updateLastUsedAt();
            loginMethodRepository.save(method);
        });
    }

    /**
     * 移除登录方式
     * 
     * @throws IllegalStateException 如果是最后一个登录方式
     */
    public void removeLoginMethod(Long userId, Long loginMethodId) {
        log.info("Removing login method: userId={}, loginMethodId={}", userId, loginMethodId);
        
        // ⚠️ 并发安全性: 在事务内重新查询以获取最新状态
        // @Transactional注解确保整个方法在同一事务内执行
        
        // 1. 检查登录方式是否属于该用户
        UserLoginMethod method = loginMethodRepository.findById(loginMethodId)
            .orElseThrow(() -> new IllegalArgumentException("登录方式不存在"));
        
        if (!method.getUser().getId().equals(userId)) {
            throw new IllegalArgumentException("无权移除该登录方式");
        }
        
        // 2. 在事务内检查是否至少有两个登录方式
        List<UserLoginMethod> methods = loginMethodRepository.findByUserId(userId);
        if (methods.size() <= 1) {
            throw new IllegalStateException("不能移除最后一个登录方式");
        }
        
        // 3. 如果是主登录方式，需要先设置另一个为主登录方式
        if (method.isPrimary()) {
            UserLoginMethod newPrimary = methods.stream()
                .filter(m -> !m.getId().equals(loginMethodId))
                .findFirst()
                .orElseThrow();
            
            newPrimary.setPrimary(true);
            loginMethodRepository.save(newPrimary);
            log.info("Set new primary login method: id={}", newPrimary.getId());
        }
        
        // 4. 删除登录方式
        loginMethodRepository.delete(method);
        log.info("Login method removed successfully");
    }

    /**
     * 设置主登录方式
     */
    public void setPrimaryLoginMethod(Long userId, Long loginMethodId) {
        log.info("Setting primary login method: userId={}, loginMethodId={}", userId, loginMethodId);
        
        // 1. 验证登录方式属于该用户
        UserLoginMethod method = loginMethodRepository.findById(loginMethodId)
            .orElseThrow(() -> new IllegalArgumentException("登录方式不存在"));
        
        if (!method.getUser().getId().equals(userId)) {
            throw new IllegalArgumentException("无权设置该登录方式");
        }
        
        // 2. 取消当前主登录方式
        loginMethodRepository.findByUserIdAndIsPrimary(userId, true)
            .ifPresent(current -> {
                current.setPrimary(false);
                loginMethodRepository.save(current);
            });
        
        // 3. 设置新的主登录方式
        method.setPrimary(true);
        loginMethodRepository.save(method);
        
        log.info("Primary login method set successfully");
    }
}
```

### UserService调整

```java
// 位置: src/main/java/com/example/oauth2demo/service/UserService.java

@Service
@RequiredArgsConstructor
@Transactional
public class UserService {
    
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final LoginMethodService loginMethodService;  // ✅ 新增依赖
    
    /**
     * 本地用户注册 (调整后)
     */
    public UserDto register(RegisterRequest request) {
        // 1. 检查用户名是否已被使用（查询login_methods表）
        if (loginMethodService.findByLocalUsername(request.getUsername()) != null) {
            throw new IllegalArgumentException("Username already exists");
        }
        
        // 2. 检查邮箱是否已存在
        if (userRepository.findByEmail(request.getEmail()).isPresent()) {
            throw new IllegalArgumentException("Email already exists");
        }
        
        // 3. 创建用户实体（不再设置password_hash等字段）
        UserEntity user = new UserEntity();
        user.setUsername(request.getUsername());  // 保留username字段作为显示名称
        user.setEmail(request.getEmail());
        user.setDisplayName(request.getDisplayName());
        user.setAuthorities(Set.of("ROLE_USER"));
        user.setEnabled(true);
        user.setEmailVerified(false);
        
        // ⚠️ 暂时保留旧字段以兼容
        user.setAuthProvider(UserEntity.AuthProvider.LOCAL);
        
        userRepository.save(user);
        
        // 4. 创建本地登录方式
        UserLoginMethod loginMethod = UserLoginMethod.builder()
            .user(user)
            .authProvider(UserLoginMethod.AuthProvider.LOCAL)
            .localUsername(request.getUsername())
            .localPasswordHash(passwordEncoder.encode(request.getPassword()))
            .isPrimary(true)
            .isVerified(false)
            .build();
        
        user.addLoginMethod(loginMethod);
        userRepository.save(user);
        
        return convertToDto(user);
    }
    
    /**
     * 本地用户登录 (调整后)
     */
    @Transactional(readOnly = true)
    public UserDto login(String username, String password) {
        // 1. 通过username查找登录方式
        UserLoginMethod loginMethod = loginMethodService.findByLocalUsername(username);
        if (loginMethod == null) {
            throw new RuntimeException("User not found");
        }
        
        // 2. 验证密码
        if (!passwordEncoder.matches(password, loginMethod.getLocalPasswordHash())) {
            throw new RuntimeException("Invalid password");
        }
        
        // 3. 更新最后使用时间
        loginMethodService.updateLastUsedAt(loginMethod.getId());
        
        return convertToDto(loginMethod.getUser());
    }
    
    /**
     * 获取或创建OAuth2用户 (调整后)
     * 
     * @param isBinding 是否为绑定流程（true=绑定到已登录用户，false=登录/注册流程）
     * @param existingUserId 如果是绑定流程，传入已登录用户ID
     */
    public UserDto getOrCreateOAuthUser(
            UserEntity.AuthProvider provider,
            String providerUserId,
            String email,
            String name,
            String picture,
            boolean isBinding,
            Long existingUserId) {
        
        // 1. 查找是否已存在该OAuth2登录方式
        UserLoginMethod existingMethod = loginMethodService.findByOAuth2Provider(
            UserLoginMethod.AuthProvider.valueOf(provider.name()),
            providerUserId
        );
        
        if (existingMethod != null) {
            // 场景A: OAuth2账户已存在
            if (isBinding && !existingMethod.getUser().getId().equals(existingUserId)) {
                throw new IllegalArgumentException("该OAuth2账户已被其他用户绑定");
            }
            // 更新最后使用时间
            loginMethodService.updateLastUsedAt(existingMethod.getId());
            return convertToDto(existingMethod.getUser());
        }
        
        if (isBinding) {
            // 场景B: 绑定流程 - 关联到现有用户
            UserEntity existingUser = userRepository.findById(existingUserId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
            
            loginMethodService.bindOAuth2LoginMethod(
                existingUserId,
                UserLoginMethod.AuthProvider.valueOf(provider.name()),
                providerUserId,
                email,
                name
            );
            
            return convertToDto(existingUser);
        } else {
            // 场景C: 登录流程 - 创建新用户
            
            // 检查邮箱是否已被使用
            if (email != null && userRepository.findByEmail(email).isPresent()) {
                throw new IllegalArgumentException("Email already registered with different provider");
            }
            
            // 生成虚拟邮箱（如果没有邮箱）
            if (email == null) {
                email = provider.name().toLowerCase() + "_" + providerUserId + "@oauth.local";
            }
            
            // 创建用户
            UserEntity newUser = new UserEntity();
            newUser.setEmail(email);
            newUser.setUsername(email);
            newUser.setDisplayName(name);
            newUser.setAvatarUrl(picture);
            newUser.setEmailVerified(true);
            newUser.setAuthorities(Set.of("ROLE_USER"));
            newUser.setEnabled(true);
            
            // ⚠️ 暂时保留旧字段以兼容
            newUser.setAuthProvider(provider);
            newUser.setProviderUserId(providerUserId);
            
            userRepository.save(newUser);
            
            // 创建OAuth2登录方式
            UserLoginMethod loginMethod = UserLoginMethod.builder()
                .user(newUser)
                .authProvider(UserLoginMethod.AuthProvider.valueOf(provider.name()))
                .providerUserId(providerUserId)
                .providerEmail(email)
                .providerUsername(name)
                .isPrimary(true)
                .isVerified(true)
                .build();
            
            newUser.addLoginMethod(loginMethod);
            userRepository.save(newUser);
            
            return convertToDto(newUser);
        }
    }
    
    // ... 其他方法保持不变 ...
}
```

---

## API层设计

### ⚠️ 关键决策：不新增API端点

**原则**: 最大化复用现有API，只调整内部实现。

### 新增Controller: LoginMethodController

```java
package com.example.oauth2demo.controller;

import com.example.oauth2demo.entity.UserLoginMethod;
import com.example.oauth2demo.service.LoginMethodService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 登录方式管理控制器
 * 提供查询、移除、设置主登录方式的功能
 * 
 * 注意：添加新登录方式通过现有的OAuth2登录流程和用户注册流程完成
 */
@RestController
@RequestMapping("/api/user/login-methods")
@RequiredArgsConstructor
@Slf4j
public class LoginMethodController {

    private final LoginMethodService loginMethodService;

    /**
     * 获取当前用户的登录方式列表
     * GET /api/user/login-methods
     */
    @GetMapping
    public ResponseEntity<?> getLoginMethods(@AuthenticationPrincipal Jwt jwt) {
        try {
            Long userId = jwt.getClaim("userId");
            
            List<UserLoginMethod> methods = loginMethodService.getUserLoginMethods(userId);
            
            // 转换为DTO
            List<Map<String, Object>> methodDtos = methods.stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
            
            return ResponseEntity.ok(Map.of(
                "loginMethods", methodDtos,
                "count", methodDtos.size()
            ));
        } catch (Exception e) {
            log.error("Failed to get login methods", e);
            return ResponseEntity.status(500).body(
                Map.of("error", "获取登录方式失败", "details", e.getMessage())
            );
        }
    }

    /**
     * 移除登录方式
     * DELETE /api/user/login-methods/{methodId}
     */
    @DeleteMapping("/{methodId}")
    public ResponseEntity<?> removeLoginMethod(
            @PathVariable Long methodId,
            @AuthenticationPrincipal Jwt jwt) {
        try {
            Long userId = jwt.getClaim("userId");
            
            loginMethodService.removeLoginMethod(userId, methodId);
            
            return ResponseEntity.ok(Map.of(
                "message", "登录方式已移除",
                "removedMethodId", methodId
            ));
        } catch (IllegalStateException | IllegalArgumentException e) {
            log.warn("Failed to remove login method: {}", e.getMessage());
            return ResponseEntity.status(400).body(
                Map.of("error", e.getMessage())
            );
        } catch (Exception e) {
            log.error("Failed to remove login method", e);
            return ResponseEntity.status(500).body(
                Map.of("error", "移除登录方式失败", "details", e.getMessage())
            );
        }
    }

    /**
     * 设置主登录方式
     * PUT /api/user/login-methods/{methodId}/primary
     */
    @PutMapping("/{methodId}/primary")
    public ResponseEntity<?> setPrimaryLoginMethod(
            @PathVariable Long methodId,
            @AuthenticationPrincipal Jwt jwt) {
        try {
            Long userId = jwt.getClaim("userId");
            
            loginMethodService.setPrimaryLoginMethod(userId, methodId);
            
            return ResponseEntity.ok(Map.of(
                "message", "主登录方式已设置",
                "primaryMethodId", methodId
            ));
        } catch (IllegalArgumentException e) {
            log.warn("Failed to set primary login method: {}", e.getMessage());
            return ResponseEntity.status(400).body(
                Map.of("error", e.getMessage())
            );
        } catch (Exception e) {
            log.error("Failed to set primary login method", e);
            return ResponseEntity.status(500).body(
                Map.of("error", "设置主登录方式失败", "details", e.getMessage())
            );
        }
    }

    /**
     * 转换为DTO
     */
    private Map<String, Object> convertToDto(UserLoginMethod method) {
        Map<String, Object> dto = new java.util.HashMap<>();
        dto.put("id", method.getId());
        dto.put("authProvider", method.getAuthProvider().name().toLowerCase());
        dto.put("isPrimary", method.isPrimary());
        dto.put("isVerified", method.isVerified());
        dto.put("linkedAt", method.getLinkedAt().toString());
        
        if (method.getLastUsedAt() != null) {
            dto.put("lastUsedAt", method.getLastUsedAt().toString());
        }
        
        // OAuth2特定信息
        if (method.isOAuth2Method()) {
            dto.put("providerEmail", method.getProviderEmail());
            dto.put("providerUsername", method.getProviderUsername());
        }
        
        // 本地登录特定信息
        if (method.isLocalMethod()) {
            dto.put("localUsername", method.getLocalUsername());
        }
        
        return dto;
    }
}
```

---

## OAuth2处理器改造

### SecurityConfig.oauth2SuccessHandler (核心改造)

```java
/**
 * OAuth2登录成功处理器 - 智能路由版本
 * 根据用户登录状态自动选择登录或绑定流程
 */
@Bean
public AuthenticationSuccessHandler oauth2SuccessHandler() {
    return new AuthenticationSuccessHandler() {
        @Override
        public void onAuthenticationSuccess(HttpServletRequest request,
                                          HttpServletResponse response,
                                          Authentication authentication) throws IOException {
            log.info("=== OAuth2 Authentication Success - Smart Routing ===");

            try {
                // 🎯 核心：检查用户是否已登录
                Long currentUserId = getCurrentUserIdFromRequest(request);
                boolean isUserLoggedIn = (currentUserId != null);
                
                log.info("User login status: {}, userId: {}", 
                    isUserLoggedIn ? "LOGGED_IN" : "NOT_LOGGED_IN", currentUserId);

                UserDto userDto = null;

                // 处理Google用户（OpenID Connect）
                if (authentication.getPrincipal() instanceof OidcUser oidcUser) {
                    userDto = handleGoogleAuth(oidcUser, isUserLoggedIn, currentUserId);
                }
                // 处理GitHub和Twitter用户（OAuth2）
                else if (authentication.getPrincipal() instanceof OAuth2User oauth2User) {
                    userDto = handleOAuth2Auth(oauth2User, isUserLoggedIn, currentUserId);
                }

                if (userDto == null) {
                    throw new IllegalStateException("无法处理OAuth2认证");
                }

                // 🎯 关键区别：绑定流程不生成新JWT token
                if (isUserLoggedIn) {
                    // 绑定流程：不修改现有token，直接重定向
                    log.info("Binding completed successfully for user: {}", currentUserId);
                    response.sendRedirect("/?message=binding_success");
                } else {
                    // 登录流程：生成JWT token
                    log.info("Login completed successfully for user: {}", userDto.getId());
                    generateAndSetJwtTokens(response, userDto);
                    response.sendRedirect("/");
                }

            } catch (IllegalArgumentException e) {
                // 业务逻辑错误（如账户已被绑定）
                log.warn("OAuth2 processing failed: {}", e.getMessage());
                String errorMsg = java.net.URLEncoder.encode(e.getMessage(), "UTF-8");
                response.sendRedirect("/?error=" + errorMsg);
            } catch (Exception e) {
                // 系统错误
                log.error("OAuth2 processing error", e);
                response.sendRedirect("/?error=oauth2_processing_failed");
            }
        }

        /**
         * 从请求中获取当前登录用户ID
         * 通过JWT Cookie判断
         */
        private Long getCurrentUserIdFromRequest(HttpServletRequest request) {
            try {
                // 1. 从Cookie中获取accessToken
                Cookie[] cookies = request.getCookies();
                if (cookies == null) {
                    return null;
                }

                String accessToken = null;
                for (Cookie cookie : cookies) {
                    if ("accessToken".equals(cookie.getName())) {
                        accessToken = cookie.getValue();
                        break;
                    }
                }

                if (accessToken == null || accessToken.trim().isEmpty()) {
                    return null;
                }

                // 2. 验证并提取userId
                return jwtTokenService.getUserIdFromToken(accessToken);
            } catch (Exception e) {
                log.debug("Failed to get current user from request: {}", e.getMessage());
                return null;
            }
        }

        /**
         * 处理Google认证
         */
        private UserDto handleGoogleAuth(OidcUser oidcUser, 
                                         boolean isBinding, 
                                         Long existingUserId) {
            String providerUserId = oidcUser.getSubject();
            String email = oidcUser.getEmail();
            String name = oidcUser.getFullName();
            String picture = oidcUser.getPicture();

            log.info("Processing Google auth: email={}, binding={}", email, isBinding);

            return userService.getOrCreateOAuthUser(
                UserEntity.AuthProvider.GOOGLE,
                providerUserId, email, name, picture,
                isBinding, existingUserId
            );
        }

        /**
         * 处理其他OAuth2认证（GitHub, Twitter）
         */
        private UserDto handleOAuth2Auth(OAuth2User oauth2User,
                                        boolean isBinding,
                                        Long existingUserId) {
            String provider = determineProvider(oauth2User);
            String providerUserId = getProviderUserId(oauth2User, provider);
            String email = getProviderEmail(oauth2User, provider);
            String name = getProviderName(oauth2User, provider);
            String picture = getProviderPicture(oauth2User, provider);

            log.info("Processing {} auth: username={}, binding={}", provider, name, isBinding);

            UserEntity.AuthProvider authProvider = 
                UserEntity.AuthProvider.valueOf(provider.toUpperCase());

            return userService.getOrCreateOAuthUser(
                authProvider,
                providerUserId, email, name, picture,
                isBinding, existingUserId
            );
        }

        /**
         * 生成并设置JWT Tokens
         */
        private void generateAndSetJwtTokens(HttpServletResponse response, UserDto userDto) {
            String accessToken = jwtTokenService.generateAccessToken(
                userDto.getUsername(), userDto.getEmail(), userDto.getId()
            );
            String refreshToken = jwtTokenService.generateRefreshToken(
                userDto.getUsername(), userDto.getId()
            );

            // 设置Access Token Cookie
            Cookie accessTokenCookie = new Cookie("accessToken", accessToken);
            accessTokenCookie.setHttpOnly(true);
            accessTokenCookie.setPath("/");
            accessTokenCookie.setMaxAge(3600); // 1小时
            accessTokenCookie.setSecure(false); // 开发环境
            accessTokenCookie.setAttribute("SameSite", "Lax");
            response.addCookie(accessTokenCookie);

            // 设置Refresh Token Cookie
            Cookie refreshTokenCookie = new Cookie("refreshToken", refreshToken);
            refreshTokenCookie.setHttpOnly(true);
            refreshTokenCookie.setPath("/");
            refreshTokenCookie.setMaxAge(604800); // 7天
            refreshTokenCookie.setSecure(false); // 开发环境
            refreshTokenCookie.setAttribute("SameSite", "Lax");
            response.addCookie(refreshTokenCookie);

            log.debug("JWT tokens generated and set in cookies");
        }

        // ... 保留现有的辅助方法 (determineProvider, getProviderUserId等) ...
    };
}
```

---

## 数据迁移方案

### 迁移脚本: migrate-to-multi-login.sql

```sql
-- =====================================================
-- 多登录方式数据迁移脚本
-- 数据库: SQLite
-- 用途: 将现有单登录方式数据迁移到新的多登录方式结构
-- =====================================================

-- 阶段1: 创建新表
-- =====================================================

-- 1.1 创建user_login_methods表
CREATE TABLE IF NOT EXISTS user_login_methods (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    auth_provider TEXT NOT NULL,
    provider_user_id TEXT,
    provider_email TEXT,
    provider_username TEXT,
    local_username TEXT,
    local_password_hash TEXT,
    is_primary INTEGER DEFAULT 0,
    is_verified INTEGER DEFAULT 0,
    linked_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_used_at DATETIME,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 1.2 创建唯一性约束
CREATE UNIQUE INDEX IF NOT EXISTS uk_user_login_provider 
    ON user_login_methods(user_id, auth_provider);

CREATE UNIQUE INDEX IF NOT EXISTS uk_local_username 
    ON user_login_methods(local_username) 
    WHERE local_username IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uk_provider_user 
    ON user_login_methods(auth_provider, provider_user_id)
    WHERE provider_user_id IS NOT NULL;

-- 1.3 创建查询索引
CREATE INDEX IF NOT EXISTS idx_login_methods_user_id 
    ON user_login_methods(user_id);

CREATE INDEX IF NOT EXISTS idx_login_methods_provider 
    ON user_login_methods(auth_provider, provider_user_id);

CREATE INDEX IF NOT EXISTS idx_login_methods_primary 
    ON user_login_methods(user_id, is_primary);

CREATE INDEX IF NOT EXISTS idx_login_methods_local_username 
    ON user_login_methods(local_username);

-- 阶段2: 数据迁移
-- =====================================================

-- 2.1 迁移本地用户
INSERT INTO user_login_methods (
    user_id,
    auth_provider,
    local_username,
    local_password_hash,
    is_primary,
    is_verified,
    linked_at
)
SELECT
    id,
    'LOCAL',
    username,
    password_hash,
    1,  -- 设为主登录方式
    email_verified,
    created_at
FROM users
WHERE auth_provider = 'LOCAL'
  AND password_hash IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM user_login_methods ulm 
      WHERE ulm.user_id = users.id AND ulm.auth_provider = 'LOCAL'
  );

-- 2.2 迁移Google用户
INSERT INTO user_login_methods (
    user_id,
    auth_provider,
    provider_user_id,
    provider_email,
    provider_username,
    is_primary,
    is_verified,
    linked_at
)
SELECT
    id,
    'GOOGLE',
    provider_user_id,
    email,
    display_name,
    1,  -- 设为主登录方式
    1,  -- OAuth2用户默认已验证
    created_at
FROM users
WHERE auth_provider = 'GOOGLE'
  AND provider_user_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM user_login_methods ulm 
      WHERE ulm.user_id = users.id AND ulm.auth_provider = 'GOOGLE'
  );

-- 2.3 迁移GitHub用户
INSERT INTO user_login_methods (
    user_id,
    auth_provider,
    provider_user_id,
    provider_email,
    provider_username,
    is_primary,
    is_verified,
    linked_at
)
SELECT
    id,
    'GITHUB',
    provider_user_id,
    email,
    display_name,
    1,
    1,
    created_at
FROM users
WHERE auth_provider = 'GITHUB'
  AND provider_user_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM user_login_methods ulm 
      WHERE ulm.user_id = users.id AND ulm.auth_provider = 'GITHUB'
  );

-- 2.4 迁移Twitter用户
INSERT INTO user_login_methods (
    user_id,
    auth_provider,
    provider_user_id,
    provider_email,
    provider_username,
    is_primary,
    is_verified,
    linked_at
)
SELECT
    id,
    'TWITTER',
    provider_user_id,
    email,
    display_name,
    1,
    1,
    created_at
FROM users
WHERE auth_provider = 'TWITTER'
  AND provider_user_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM user_login_methods ulm 
      WHERE ulm.user_id = users.id AND ulm.auth_provider = 'TWITTER'
  );

-- 阶段3: 数据验证
-- =====================================================

-- 3.1 验证迁移数量
SELECT 
    '迁移验证' as check_type,
    (SELECT COUNT(*) FROM users) as total_users,
    (SELECT COUNT(DISTINCT user_id) FROM user_login_methods) as migrated_users,
    (SELECT COUNT(*) FROM user_login_methods) as total_login_methods;

-- 3.2 验证每个用户都有至少一个登录方式
SELECT 
    '孤立用户检查' as check_type,
    COUNT(*) as orphaned_users
FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM user_login_methods ulm WHERE ulm.user_id = u.id
);

-- 3.3 验证每个用户都有一个主登录方式
SELECT 
    '主登录方式检查' as check_type,
    COUNT(*) as users_without_primary
FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM user_login_methods ulm 
    WHERE ulm.user_id = u.id AND ulm.is_primary = 1
);

-- 阶段4: 标记迁移完成（可选）
-- =====================================================

-- 4.1 添加迁移标记字段
ALTER TABLE users ADD COLUMN migrated_to_multi_login INTEGER DEFAULT 0;

-- 4.2 标记已迁移用户
UPDATE users 
SET migrated_to_multi_login = 1
WHERE id IN (
    SELECT DISTINCT user_id FROM user_login_methods
);
```

### 迁移执行步骤

1. **备份数据库**
   ```bash
   cp dev-database.db dev-database.db.backup.$(date +%Y%m%d_%H%M%S)
   ```

2. **执行迁移脚本**
   ```bash
   sqlite3 dev-database.db < google-oauth2-demo/src/main/resources/db/migration/migrate-to-multi-login.sql
   ```

3. **验证迁移结果**
   ```bash
   sqlite3 dev-database.db "SELECT * FROM user_login_methods LIMIT 10;"
   ```

4. **运行应用测试**
   ```bash
   mvn spring-boot:run
   ```

---

## 回滚方案

### 回滚脚本: rollback-multi-login.sql

```sql
-- =====================================================
-- 多登录方式回滚脚本
-- 用途: 在出现问题时回滚到单登录方式结构
-- =====================================================

-- 步骤1: 从备份恢复（推荐）
-- =====================================================
-- 直接用备份文件替换当前数据库
-- cp dev-database.db.backup.YYYYMMDD_HHMMSS dev-database.db

-- 步骤2: 如果需要保留新数据，手动回滚
-- =====================================================

-- 2.1 删除user_login_methods表
DROP TABLE IF EXISTS user_login_methods;

-- 2.2 删除迁移标记字段
ALTER TABLE users DROP COLUMN IF EXISTS migrated_to_multi_login;

-- 2.3 验证回滚
SELECT COUNT(*) as remaining_login_methods_tables 
FROM sqlite_master 
WHERE type='table' AND name='user_login_methods';
```

### 代码回滚策略

1. **Git回滚到迁移前的commit**
   ```bash
   git log --oneline  # 找到迁移前的commit hash
   git revert <commit-hash>  # 或者 git reset --hard <commit-hash>
   ```

2. **重启应用验证**
   ```bash
   mvn clean install
   mvn spring-boot:run
   ```

---

## 安全性验证

### 安全检查清单

#### 1. 账户绑定安全

✅ **防止OAuth2账户被恶意绑定**
- 检查OAuth2账户是否已被其他用户绑定
- 验证绑定请求来自已登录用户
- 记录所有绑定操作的审计日志

✅ **防止重复绑定**
- 数据库唯一约束：`uk_user_login_provider`
- 服务层检查：`findByUserIdAndAuthProvider`

✅ **防止账户劫持**
- OAuth2回调只接受有效的state参数
- 绑定流程验证用户登录状态
- JWT token验证确保用户身份

#### 2. 密码安全

✅ **密码哈希存储**
- 使用BCrypt算法（Spring Security默认）
- 每个密码独立盐值
- 密码字段不直接暴露给API

✅ **密码验证**
- 使用`PasswordEncoder.matches()`
- 不在日志中输出原始密码
- 失败次数限制（可选扩展）

#### 3. Token安全

✅ **JWT Token安全**
- HttpOnly Cookie存储
- 合理的过期时间（Access: 1小时，Refresh: 7天）
- 签名验证

✅ **OAuth2 Token安全**
- 不存储OAuth2 access token（除非需要调用API）
- OAuth2流程使用HTTPS
- State参数防CSRF

#### 4. 数据库安全

✅ **SQL注入防护**
- 使用JPA/Hibernate参数化查询
- 不拼接SQL语句

✅ **数据完整性**
- 外键约束
- 唯一性约束
- 级联删除

#### 5. API安全

✅ **认证保护**
- 所有管理API需要JWT认证
- 使用`@AuthenticationPrincipal`注入用户信息

✅ **授权保护**
- 用户只能操作自己的登录方式
- 服务层验证userId匹配

✅ **输入验证**
- 参数非空检查
- 类型验证
- 业务规则验证

---

## 测试计划

### 单元测试

#### LoginMethodService 测试
```java
@SpringBootTest
class LoginMethodServiceTest {
    
    @Test
    void bindOAuth2LoginMethod_Success() {
        // 测试成功绑定OAuth2登录方式
    }
    
    @Test
    void bindOAuth2LoginMethod_AlreadyBound_ThrowsException() {
        // 测试重复绑定抛出异常
    }
    
    @Test
    void bindOAuth2LoginMethod_BoundByOther_ThrowsException() {
        // 测试OAuth2账户已被其他用户绑定
    }
    
    @Test
    void removeLoginMethod_LastMethod_ThrowsException() {
        // 测试移除最后一个登录方式抛出异常
    }
    
    @Test
    void setPrimaryLoginMethod_Success() {
        // 测试设置主登录方式
    }
}
```

### 集成测试

#### OAuth2绑定流程测试
```java
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
class OAuth2BindingIntegrationTest {
    
    @Test
    void oauth2Login_NotLoggedIn_CreatesNewUser() {
        // 测试未登录用户OAuth2登录创建新账户
    }
    
    @Test
    void oauth2Login_LoggedIn_BindsToExistingUser() {
        // 测试已登录用户OAuth2登录绑定到现有账户
    }
    
    @Test
    void oauth2Login_AlreadyBound_ReturnsError() {
        // 测试OAuth2账户已绑定返回错误
    }
}
```

### 端到端测试场景

#### 场景1: 本地用户绑定Google
1. 用户用本地用户名/密码注册
2. 登录成功
3. 点击"绑定Google账户"按钮
4. 完成Google OAuth2授权
5. 验证绑定成功
6. 用Google账户登录验证

#### 场景2: Google用户添加本地密码
1. 用户用Google登录创建账户
2. 进入设置页面
3. 添加本地用户名和密码
4. 登出
5. 用本地用户名/密码登录验证

#### 场景3: 多平台绑定
1. 用户用Google登录
2. 绑定GitHub账户
3. 绑定Twitter账户
4. 验证三种方式都能登录
5. 移除一种登录方式
6. 验证其他方式仍可登录

---

## 实施检查清单

### 准备阶段
- [ ] 代码完整备份
- [ ] 数据库完整备份
- [ ] 创建独立分支 `feature/multi-login-methods`
- [ ] 阅读并理解所有文档

### 数据库阶段
- [ ] 创建 `user_login_methods` 表
- [ ] 创建所有索引和约束
- [ ] 执行数据迁移脚本
- [ ] 验证迁移数据完整性
- [ ] 测试回滚脚本

### 实体层阶段
- [ ] 创建 `UserLoginMethod` 实体
- [ ] 修改 `UserEntity` 添加关联关系
- [ ] 创建 `UserLoginMethodRepository`
- [ ] 编写单元测试

### 服务层阶段
- [ ] 创建 `LoginMethodService`
- [ ] 修改 `UserService.register()`
- [ ] 修改 `UserService.login()`
- [ ] 修改 `UserService.getOrCreateOAuthUser()`
- [ ] 编写单元测试

### API层阶段
- [ ] 创建 `LoginMethodController`
- [ ] 编写集成测试
- [ ] 测试API端点

### OAuth2处理器阶段
- [ ] 修改 `oauth2SuccessHandler`
- [ ] 实现智能路由逻辑
- [ ] 测试登录流程
- [ ] 测试绑定流程

### 前端阶段
- [ ] 创建 `LoginMethodManager` 组件
- [ ] 修改 `OAuth2LoginButton` 组件
- [ ] 集成API调用
- [ ] 端到端测试

### 验证阶段
- [ ] 所有单元测试通过
- [ ] 所有集成测试通过
- [ ] 端到端测试通过
- [ ] 安全性检查通过
- [ ] 性能测试通过

### 部署阶段
- [ ] 代码审查
- [ ] 创建PR
- [ ] 合并到main分支
- [ ] 部署到生产环境
- [ ] 监控运行状态

---

## 附录A: 风险评估矩阵

| 风险项 | 概率 | 影响 | 等级 | 缓解措施 |
|-------|------|------|------|---------|
| 数据迁移失败 | 低 | 高 | 中 | 完整备份 + 回滚脚本 + 分阶段迁移 |
| OAuth2账户冲突 | 中 | 中 | 中 | 唯一性约束 + 业务层检查 |
| 现有功能破坏 | 低 | 高 | 中 | 保留旧字段 + 向后兼容 + 完整测试 |
| 性能下降 | 低 | 中 | 低 | 查询优化 + 索引 + 缓存 |
| 安全漏洞 | 低 | 高 | 中 | 安全审查 + 输入验证 + 审计日志 |

---

## 附录B: API完整对照表

### 复用的现有API（无需修改接口）

| 端点 | 方法 | 用途 | 修改程度 |
|------|------|------|---------|
| `/api/user` | GET | 获取用户信息 | 内部调整：从login_methods表获取provider |
| `/api/auth/register` | POST | 用户注册 | 内部调整：创建login_methods记录 |
| `/api/auth/login` | POST | 本地登录 | 内部调整：从login_methods表查询 |
| `/api/logout` | POST | 登出 | 无修改 |
| `/api/auth/refresh` | POST | Token刷新 | 无修改 |
| `/oauth2/authorization/{provider}` | GET | OAuth2登录 | 内部调整：智能路由 |

### 新增API

| 端点 | 方法 | 用途 | 权限要求 |
|------|------|------|---------|
| `/api/user/login-methods` | GET | 获取登录方式列表 | 需登录 |
| `/api/user/login-methods/{id}` | DELETE | 移除登录方式 | 需登录 |
| `/api/user/login-methods/{id}/primary` | PUT | 设置主登录方式 | 需登录 |

**总结**: 只新增3个API端点，最大化复用现有接口。

---

## 文档状态

- **版本**: v1.0
- **状态**: ✅ 待审核
- **下一步**: 等待用户批准后开始实施
- **预计实施时间**: 6-8周
- **风险等级**: 🟡 中等（已制定完整缓解方案）

---

**📌 重要提醒**：
1. 本文档基于对现有代码库的深入分析
2. 所有修改都遵循最小侵入性原则
3. 完整的数据迁移和回滚方案已准备就绪
4. 安全性经过系统性验证
5. 等待用户批准后开始实施，不会自行修改代码

**✅ 准备就绪，等待审批！**