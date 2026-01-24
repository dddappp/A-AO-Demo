package com.example.oauth2demo.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Token黑名单实体类
 * 用于撤销access token和refresh token
 * 
 * 注意：ID 和 userId 均改为 UUID String，由应用层（Java代码）生成
 */
@Entity
@Table(name = "token_blacklist", indexes = {
    @Index(name = "idx_jti", columnList = "jti"),
    @Index(name = "idx_expires_at", columnList = "expires_at")
})
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TokenBlacklistEntity {

    @Id
    @Column(length = 36)  // UUID 字符串长度为 36
    private String id;  // UUID 字符串格式

    @Column(nullable = false, unique = true, length = 255)
    private String jti;  // JWT ID

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TokenType tokenType;

    @Column(length = 36)  // UUID 字符串
    private String userId;  // 关联用户的 UUID，允许 NULL（非认证用户的 token）

    @Column(nullable = false)
    private LocalDateTime expiresAt;

    @CreationTimestamp
    @Column(nullable = false, updatable = false)
    private LocalDateTime blacklistedAt;

    @Column(length = 255)
    private String reason;

    public enum TokenType {
        ACCESS, REFRESH, ID
    }

    /**
     * 在持久化前生成UUID（后备机制，正常情况下应该由应用层设置）
     */
    @PrePersist
    protected void onCreate() {
        if (id == null || id.trim().isEmpty()) {
            id = UUID.randomUUID().toString();
        }
    }
}