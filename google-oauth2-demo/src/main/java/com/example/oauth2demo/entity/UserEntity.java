package com.example.oauth2demo.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

/**
 * 用户实体类
 * 支持本地用户和OAuth2用户
 * 
 * 注意：ID 改为 UUID String，由应用层（Java代码）生成，而不是数据库自动生成
 */
@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
public class UserEntity {

    @Id
    @Column(length = 36)  // UUID 字符串长度为 36（包括连字符）
    private String id;  // UUID 字符串格式：xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

    @Column(unique = true, nullable = false, length = 255)
    private String username;

    @Column(unique = true, nullable = false, length = 255)
    private String email;

    @Column(length = 255)
    private String displayName;

    @Column(columnDefinition = "TEXT")
    private String avatarUrl;

    @Column(nullable = false)
    private boolean emailVerified = false;

    @Column(nullable = false)
    private boolean enabled = true;

    // Spring Security GrantedAuthority
    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "user_authorities", joinColumns = @JoinColumn(name = "user_id"))
    @Column(name = "authority")
    private Set<String> authorities = new HashSet<>();

    @CreationTimestamp
    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(nullable = false)
    private LocalDateTime updatedAt;

    @Column
    private LocalDateTime lastLoginAt;

    // ✅ 多登录方式关联
    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private Set<UserLoginMethod> loginMethods = new HashSet<>();

    // 自定义 Builder
    public static UserEntityBuilder builder() {
        return new UserEntityBuilder();
    }

    public static class UserEntityBuilder {
        private String id;
        private String username;
        private String email;
        private String displayName;
        private String avatarUrl;
        private boolean emailVerified = false;
        private boolean enabled = true;
        private Set<String> authorities = new HashSet<>();
        private LocalDateTime createdAt;
        private LocalDateTime updatedAt;
        private LocalDateTime lastLoginAt;
        private Set<UserLoginMethod> loginMethods = new HashSet<>();

        public UserEntityBuilder id(String id) { this.id = id; return this; }
        public UserEntityBuilder username(String username) { this.username = username; return this; }
        public UserEntityBuilder email(String email) { this.email = email; return this; }
        public UserEntityBuilder displayName(String displayName) { this.displayName = displayName; return this; }
        public UserEntityBuilder avatarUrl(String avatarUrl) { this.avatarUrl = avatarUrl; return this; }
        public UserEntityBuilder emailVerified(boolean emailVerified) { this.emailVerified = emailVerified; return this; }
        public UserEntityBuilder enabled(boolean enabled) { this.enabled = enabled; return this; }
        public UserEntityBuilder authorities(Set<String> authorities) { this.authorities = authorities; return this; }
        public UserEntityBuilder createdAt(LocalDateTime createdAt) { this.createdAt = createdAt; return this; }
        public UserEntityBuilder updatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; return this; }
        public UserEntityBuilder lastLoginAt(LocalDateTime lastLoginAt) { this.lastLoginAt = lastLoginAt; return this; }
        public UserEntityBuilder loginMethods(Set<UserLoginMethod> loginMethods) { this.loginMethods = loginMethods; return this; }

        public UserEntity build() {
            UserEntity user = new UserEntity();
            user.id = this.id;
            user.username = this.username;
            user.email = this.email;
            user.displayName = this.displayName;
            user.avatarUrl = this.avatarUrl;
            user.emailVerified = this.emailVerified;
            user.enabled = this.enabled;
            user.authorities = this.authorities != null ? this.authorities : new HashSet<>();
            user.createdAt = this.createdAt;
            user.updatedAt = this.updatedAt;
            user.lastLoginAt = this.lastLoginAt;
            user.loginMethods = this.loginMethods != null ? this.loginMethods : new HashSet<>();
            return user;
        }
    }

    @PrePersist
    protected void onCreate() {
        // 如果ID未设置，生成UUID（后备机制，正常情况下应该由应用层设置）
        if (id == null || id.trim().isEmpty()) {
            id = UUID.randomUUID().toString();
        }
        if (authorities.isEmpty()) {
            authorities.add("ROLE_USER");
        }
    }

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
        // 如果集合为null或不可变，创建新的HashSet
        if (this.loginMethods == null) {
            this.loginMethods = new HashSet<>();
        }
        
        this.loginMethods.add(loginMethod);
        loginMethod.setUser(this);
        
        // 如果是第一个登录方式，自动设为主登录方式
        if (this.loginMethods.size() == 1) {
            loginMethod.setPrimary(true);
        }
    }
}