package com.example.oauth2demo.service;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

/**
 * JWT Token生成和管理服务
 */
@Service
public class JwtTokenService {

    private final SecretKey secretKey = Keys.secretKeyFor(SignatureAlgorithm.HS256);

    /**
     * 获取用于验证的密钥
     */
    public SecretKey getSecretKey() {
        return secretKey;
    }

    /**
     * 生成Access Token
     */
    public String generateAccessToken(String username, String email, Long userId) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("userId", userId);
        claims.put("email", email);
        claims.put("type", "access");

        return Jwts.builder()
                .setClaims(claims)
                .setSubject(username)
                .setIssuedAt(new Date())
                .setExpiration(new Date(System.currentTimeMillis() + 3600000)) // 1小时
                .signWith(secretKey)
                .compact();
    }

    /**
     * 生成Refresh Token
     */
    public String generateRefreshToken(String username, Long userId) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("userId", userId);
        claims.put("type", "refresh");

        return Jwts.builder()
                .setClaims(claims)
                .setSubject(username)
                .setIssuedAt(new Date())
                .setExpiration(new Date(System.currentTimeMillis() + 604800000)) // 7天
                .signWith(secretKey)
                .compact();
    }

    /**
     * 从Token中提取用户名
     */
    public String extractUsername(String token) {
        return Jwts.parserBuilder()
                .setSigningKey(secretKey)
                .build()
                .parseClaimsJws(token)
                .getBody()
                .getSubject();
    }

    /**
     * 验证Token
     */
    public boolean validateToken(String token, String username) {
        try {
            String extractedUsername = extractUsername(token);
            return username.equals(extractedUsername);
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * 验证Refresh Token（检查类型和过期时间）
     */
    public boolean validateRefreshToken(String token) {
        try {
            var claims = Jwts.parserBuilder()
                .setSigningKey(secretKey)
                .build()
                .parseClaimsJws(token)
                .getBody();

            // 检查token类型
            String tokenType = claims.get("type", String.class);
            if (!"refresh".equals(tokenType)) {
                return false;
            }

            // 检查是否过期
            return !claims.getExpiration().before(new Date());
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * 从Token中提取用户ID
     */
    public Long getUserIdFromToken(String token) {
        try {
            var claims = Jwts.parserBuilder()
                .setSigningKey(secretKey)
                .build()
                .parseClaimsJws(token)
                .getBody();

            Integer userId = claims.get("userId", Integer.class);
            return userId != null ? userId.longValue() : null;
        } catch (Exception e) {
            throw new RuntimeException("无法从token中提取用户ID", e);
        }
    }
}