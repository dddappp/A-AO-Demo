package com.example.oauth2demo.service;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Base64;

/**
 * JWT Token生成和管理服务
 */
@Service
public class JwtTokenService {

    private final SecretKey secretKey;
    private static final String KEY_FILE_PATH = "jwt-secret.key";

    public JwtTokenService(
            @Value("${app.jwt.secret:}") String jwtSecret,
            @Value("${app.jwt.secret-file:}") String jwtSecretFile
    ) {
        this.secretKey = loadOrGenerateKey(jwtSecret, jwtSecretFile);
    }

    /**
     * 加载或生成JWT密钥
     */
    private SecretKey loadOrGenerateKey(String jwtSecret, String jwtSecretFile) {
        // 1. 优先使用配置的密钥
        if (!jwtSecret.isEmpty()) {
            System.out.println("Using JWT secret from configuration");
            return createSecretKeyFromInput(jwtSecret, "configuration");
        }
        
        // 2. 检查环境变量
        String envSecret = System.getenv("JWT_SECRET");
        if (envSecret != null && !envSecret.isEmpty()) {
            System.out.println("Using JWT secret from environment variable");
            return createSecretKeyFromInput(envSecret, "environment variable");
        }
        
        // 3. 使用配置的密钥文件
        if (!jwtSecretFile.isEmpty()) {
            try {
                Path keyPath = Paths.get(jwtSecretFile);
                if (Files.exists(keyPath)) {
                    System.out.println("Using JWT secret from configured file: " + jwtSecretFile);
                    byte[] keyBytes = Base64.getDecoder().decode(Files.readString(keyPath).trim());
                    return Keys.hmacShaKeyFor(keyBytes);
                }
            } catch (IOException e) {
                System.err.println("Failed to load JWT key from configured file: " + e.getMessage());
            }
        }
        
        // 4. 尝试从默认文件加载密钥
        try {
            Path keyPath = Paths.get(KEY_FILE_PATH);
            if (Files.exists(keyPath)) {
                System.out.println("Using JWT secret from default file: " + KEY_FILE_PATH);
                byte[] keyBytes = Base64.getDecoder().decode(Files.readString(keyPath).trim());
                return Keys.hmacShaKeyFor(keyBytes);
            } else {
                // 生成新密钥并存储
                SecretKey newKey = Keys.secretKeyFor(SignatureAlgorithm.HS256);
                String keyBase64 = Base64.getEncoder().encodeToString(newKey.getEncoded());
                Files.writeString(keyPath, keyBase64);
                System.out.println("Generated new JWT secret and stored in default file: " + KEY_FILE_PATH);
                return newKey;
            }
        } catch (IOException e) {
            // 如果文件操作失败，使用默认密钥（仅用于开发环境）
            System.err.println("Failed to load or generate JWT key from file: " + e.getMessage());
            System.err.println("Using default key for development only");
            return Keys.hmacShaKeyFor("default-secret-key-for-development-only-change-in-production".getBytes());
        }
    }
    
    /**
     * 从输入字符串创建SecretKey，支持Base64编码
     */
    private SecretKey createSecretKeyFromInput(String input, String source) {
        try {
            byte[] keyBytes;
            
            // 尝试解析Base64编码的密钥
            try {
                keyBytes = Base64.getDecoder().decode(input.trim());
                System.out.println("Using Base64 encoded JWT secret from " + source);
            } catch (IllegalArgumentException e) {
                // 如果不是Base64编码，直接使用字符串的字节数组
                System.out.println("Using plain text JWT secret from " + source);
                keyBytes = input.getBytes();
            }
            
            // 检查密钥长度
            if (keyBytes.length < 32) {
                System.err.println("Warning: JWT secret from " + source + " is too short (" + keyBytes.length + " bytes).");
                System.err.println("Minimum recommended length is 32 bytes for HMAC-SHA256.");
                System.err.println("Using SHA-256 hash to generate a secure key.");
                
                // 使用SHA-256哈希生成足够长度的密钥
                java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
                byte[] hashedKey = digest.digest(keyBytes);
                return Keys.hmacShaKeyFor(hashedKey);
            }
            return Keys.hmacShaKeyFor(keyBytes);
        } catch (Exception e) {
            System.err.println("Error creating secret key from " + source + ": " + e.getMessage());
            System.err.println("Using default key for development only");
            return Keys.hmacShaKeyFor("default-secret-key-for-development-only-change-in-production".getBytes());
        }
    }

    /**
     * 获取用于验证的密钥
     */
    public SecretKey getSecretKey() {
        return secretKey;
    }

    /**
     * 生成Access Token
     */
    public String generateAccessToken(String username, String email, String userId, java.util.Set<String> authorities) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("userId", userId);
        claims.put("email", email);
        claims.put("authorities", authorities);
        claims.put("type", "access");

        return Jwts.builder()
                .setClaims(claims)
                .setSubject(username)
                .setIssuedAt(new Date())
                .setExpiration(new Date(System.currentTimeMillis() + 3600000)) // 1小时
                .setHeaderParam("kid", "key-1")  // 添加kid用于JWKS匹配
                .signWith(secretKey)
                .compact();
    }

    /**
     * 生成Refresh Token
     */
    public String generateRefreshToken(String username, String userId) {
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
    public String getUserIdFromToken(String token) {
        try {
            var claims = Jwts.parserBuilder()
                .setSigningKey(secretKey)
                .build()
                .parseClaimsJws(token)
                .getBody();

            return claims.get("userId", String.class);
        } catch (Exception e) {
            throw new RuntimeException("无法从token中提取用户ID", e);
        }
    }
}