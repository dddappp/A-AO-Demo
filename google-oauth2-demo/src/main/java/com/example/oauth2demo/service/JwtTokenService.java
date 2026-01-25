package com.example.oauth2demo.service;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import lombok.Getter;
import org.springframework.stereotype.Service;

import java.security.*;
import java.security.spec.X509EncodedKeySpec;
import java.security.spec.PKCS8EncodedKeySpec;
import java.util.*;
import java.io.IOException;
import java.io.ByteArrayInputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Base64;

/**
 * JWT Token生成和管理服务
 * 使用 RSA-2048 密钥对进行签名和验证
 * 支持 JWKS 和异构资源服务器集成
 */
@Service
@Getter
public class JwtTokenService {

    private final PrivateKey privateKey;
    private final PublicKey publicKey;
    private static final String RSA_KEY_FILE_PATH = "rsa-keys.ser";
    private static final int RSA_KEY_SIZE = 2048;

    public JwtTokenService() {
        KeyPair keyPair = loadOrGenerateKeyPair();
        this.privateKey = keyPair.getPrivate();
        this.publicKey = keyPair.getPublic();
        
        System.out.println("✅ JwtTokenService initialized with RSA-2048 keys");
        System.out.println("   Public Key Algorithm: " + publicKey.getAlgorithm());
        System.out.println("   Key Size: " + RSA_KEY_SIZE);
    }

    /**
     * 加载或生成 RSA 密钥对
     */
    private KeyPair loadOrGenerateKeyPair() {
        try {
            // 尝试从文件加载密钥对
            Path keyFile = Paths.get(RSA_KEY_FILE_PATH);
            if (Files.exists(keyFile)) {
                System.out.println("🔑 Loading RSA key pair from file: " + RSA_KEY_FILE_PATH);
                return loadKeyPairFromFile(keyFile);
            }
        } catch (Exception e) {
            System.out.println("⚠️ Failed to load key pair from file: " + e.getMessage());
        }

        // 生成新的密钥对
        System.out.println("🔄 Generating new RSA-2048 key pair...");
        try {
            KeyPairGenerator keyGen = KeyPairGenerator.getInstance("RSA");
            keyGen.initialize(RSA_KEY_SIZE);
            KeyPair keyPair = keyGen.generateKeyPair();
            
            // 尝试保存到文件
            try {
                saveKeyPairToFile(keyPair, Paths.get(RSA_KEY_FILE_PATH));
                System.out.println("💾 Key pair saved to: " + RSA_KEY_FILE_PATH);
            } catch (Exception e) {
                System.out.println("⚠️ Failed to save key pair to file: " + e.getMessage());
            }
            
            return keyPair;
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("Failed to generate RSA key pair", e);
        }
    }

    /**
     * 从文件加载密钥对
     */
    private KeyPair loadKeyPairFromFile(Path keyFile) throws Exception {
        byte[] keyData = Files.readAllBytes(keyFile);
        
        // 简单的格式：privateKey长度(4字节) + privateKeyData + publicKeyData
        int privateKeyLength = ((keyData[0] & 0xFF) << 24) |
                              ((keyData[1] & 0xFF) << 16) |
                              ((keyData[2] & 0xFF) << 8) |
                              (keyData[3] & 0xFF);
        
        byte[] privateKeyData = new byte[privateKeyLength];
        byte[] publicKeyData = new byte[keyData.length - 4 - privateKeyLength];
        
        System.arraycopy(keyData, 4, privateKeyData, 0, privateKeyLength);
        System.arraycopy(keyData, 4 + privateKeyLength, publicKeyData, 0, publicKeyData.length);
        
        KeyFactory keyFactory = KeyFactory.getInstance("RSA");
        
        PKCS8EncodedKeySpec privateKeySpec = new PKCS8EncodedKeySpec(privateKeyData);
        PrivateKey privateKey = keyFactory.generatePrivate(privateKeySpec);
        
        X509EncodedKeySpec publicKeySpec = new X509EncodedKeySpec(publicKeyData);
        PublicKey publicKey = keyFactory.generatePublic(publicKeySpec);
        
        KeyPair loadedKeyPair = new KeyPair(publicKey, privateKey);
        System.out.println("✅ RSA key pair loaded from file");
        return loadedKeyPair;
    }

    /**
     * 将密钥对保存到文件
     */
    private void saveKeyPairToFile(KeyPair keyPair, Path keyFile) throws Exception {
        byte[] privateKeyData = keyPair.getPrivate().getEncoded();
        byte[] publicKeyData = keyPair.getPublic().getEncoded();
        
        byte[] keyFileData = new byte[4 + privateKeyData.length + publicKeyData.length];
        
        // 写入 privateKey 长度
        keyFileData[0] = (byte) ((privateKeyData.length >> 24) & 0xFF);
        keyFileData[1] = (byte) ((privateKeyData.length >> 16) & 0xFF);
        keyFileData[2] = (byte) ((privateKeyData.length >> 8) & 0xFF);
        keyFileData[3] = (byte) (privateKeyData.length & 0xFF);
        
        System.arraycopy(privateKeyData, 0, keyFileData, 4, privateKeyData.length);
        System.arraycopy(publicKeyData, 0, keyFileData, 4 + privateKeyData.length, publicKeyData.length);
        
        Files.write(keyFile, keyFileData);
    }

    /**
     * 生成访问 Token
     */
    public String generateAccessToken(
            String username,
            String email,
            String userId,
            java.util.Set<String> authorities) {
        
        Map<String, Object> claims = new HashMap<>();
        claims.put("userId", userId);
        claims.put("email", email);
        claims.put("authorities", authorities);
        claims.put("type", "access");
        
        // OAuth2 标准声明
        long issuedAtMs = System.currentTimeMillis();
        long expiresInMs = 3600000; // 1小时
        
        claims.put("iss", "https://auth.example.com");
        claims.put("aud", "resource-server");
        claims.put("jti", UUID.randomUUID().toString());

        return Jwts.builder()
                .setClaims(claims)
                .setSubject(username)
                .setIssuedAt(new Date(issuedAtMs))
                .setExpiration(new Date(issuedAtMs + expiresInMs))
                .setHeaderParam("kid", "key-1")  // 用于 JWKS 匹配
                .signWith(privateKey, SignatureAlgorithm.RS256)
                .compact();
    }

    /**
     * 生成刷新 Token
     */
    public String generateRefreshToken(String username, String userId) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("userId", userId);
        claims.put("type", "refresh");
        claims.put("jti", UUID.randomUUID().toString());
        
        long issuedAtMs = System.currentTimeMillis();
        long expiresInMs = 604800000; // 7天
        
        claims.put("iss", "https://auth.example.com");

        return Jwts.builder()
                .setClaims(claims)
                .setSubject(username)
                .setIssuedAt(new Date(issuedAtMs))
                .setExpiration(new Date(issuedAtMs + expiresInMs))
                .setHeaderParam("kid", "key-1")
                .signWith(privateKey, SignatureAlgorithm.RS256)
                .compact();
    }

    /**
     * 生成测试 Token（用于测试场景）
     */
    public String generateTestToken(String username) {
        return generateAccessToken(username, username + "@example.com", UUID.randomUUID().toString(),
                new HashSet<>(Arrays.asList("ROLE_USER")));
    }

    /**
     * 验证 Refresh Token
     */
    public boolean validateRefreshToken(String token) {
        try {
            Jwts.parserBuilder()
                    .setSigningKey(publicKey)
                    .build()
                    .parseClaimsJws(token);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * 从 Token 中提取用户名
     */
    public String extractUsername(String token) {
        try {
            return Jwts.parserBuilder()
                    .setSigningKey(publicKey)
                    .build()
                    .parseClaimsJws(token)
                    .getBody()
                    .getSubject();
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * 从 Token 中提取用户 ID
     */
    public String getUserIdFromToken(String token) {
        try {
            return Jwts.parserBuilder()
                    .setSigningKey(publicKey)
                    .build()
                    .parseClaimsJws(token)
                    .getBody()
                    .get("userId", String.class);
        } catch (Exception e) {
            return null;
        }
    }
}
