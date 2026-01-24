package com.example.oauth2demo.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import java.time.LocalDateTime;

/**
 * 用户登录方式实体
 * 用于支持一个用户绑定多种登录方式
 */
@Entity
@Table(name = "user_login_methods")
@Getter
@Setter
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
