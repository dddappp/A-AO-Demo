package com.example.oauth2demo.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import java.time.LocalDateTime;

/**
 * Token黑名单实体类
 * 用于撤销access token和refresh token
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
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 255)
    private String jti;  // JWT ID

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TokenType tokenType;

    @Column
    private Long userId;

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
}