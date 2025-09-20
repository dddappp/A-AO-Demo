package com.example.oauth2demo.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.jsonwebtoken.*;
import io.jsonwebtoken.security.SignatureException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.math.BigInteger;
import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.spec.RSAPublicKeySpec;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;

@Service
public class JwtValidationService {

    private static final String GOOGLE_JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs";
    private static final String GOOGLE_ISSUER = "https://accounts.google.com";

    @Value("${spring.security.oauth2.client.registration.google.client-id}")
    private String expectedClientId;

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;

    public JwtValidationService() {
        this.restTemplate = new RestTemplate();
        this.objectMapper = new ObjectMapper();
    }

    public Map<String, Object> validateIdToken(String idToken) throws Exception {
        Map<String, Object> result = new HashMap<>();

        try {
            // 解析 JWT 头部获取 key ID
            String[] tokenParts = idToken.split("\\.");
            if (tokenParts.length != 3) {
                throw new IllegalArgumentException("Invalid JWT format");
            }

            String headerJson = new String(Base64.getUrlDecoder().decode(tokenParts[0]));
            JsonNode headerNode = objectMapper.readTree(headerJson);
            String keyId = headerNode.get("kid").asText();

            System.out.println("JWT Key ID: " + keyId);

            // 从 Google JWKS 获取公钥
            PublicKey publicKey = getGooglePublicKey(keyId);
            System.out.println("Retrieved Google public key for validation");

            // 验证 JWT
            Jws<Claims> jws = Jwts.parserBuilder()
                    .setSigningKey(publicKey)
                    .build()
                    .parseClaimsJws(idToken);

            Claims claims = jws.getBody();

            // 验证声明
            validateClaims(claims);

            // 构建验证结果
            result.put("valid", true);
            result.put("issuer", claims.getIssuer());
            result.put("subject", claims.getSubject());
            result.put("audience", claims.getAudience());
            result.put("issuedAt", claims.getIssuedAt());
            result.put("expiresAt", claims.getExpiration());
            result.put("email", claims.get("email"));
            result.put("name", claims.get("name"));
            result.put("emailVerified", claims.get("email_verified"));

            System.out.println("JWT validation successful");
            System.out.println("Subject: " + claims.getSubject());
            System.out.println("Email: " + claims.get("email"));

        } catch (ExpiredJwtException e) {
            result.put("valid", false);
            result.put("error", "Token has expired");
            result.put("expiredAt", e.getClaims().getExpiration());
            throw new Exception("Token has expired");
        } catch (SignatureException e) {
            result.put("valid", false);
            result.put("error", "Invalid token signature");
            throw new Exception("Invalid token signature");
        } catch (Exception e) {
            result.put("valid", false);
            result.put("error", e.getMessage());
            throw e;
        }

        return result;
    }

    private PublicKey getGooglePublicKey(String keyId) throws Exception {
        System.out.println("Fetching Google JWKS from: " + GOOGLE_JWKS_URL);

        String jwksResponse = restTemplate.getForObject(GOOGLE_JWKS_URL, String.class);
        JsonNode jwksNode = objectMapper.readTree(jwksResponse);

        // 查找匹配的 key
        for (JsonNode keyNode : jwksNode.get("keys")) {
            if (keyId.equals(keyNode.get("kid").asText())) {
                System.out.println("Found matching key in JWKS");

                // 提取 RSA 公钥参数
                String n = keyNode.get("n").asText();
                String e = keyNode.get("e").asText();

                // 解码 Base64URL
                byte[] modulusBytes = Base64.getUrlDecoder().decode(n);
                byte[] exponentBytes = Base64.getUrlDecoder().decode(e);

                // 转换为 BigInteger
                BigInteger modulus = new BigInteger(1, modulusBytes);
                BigInteger exponent = new BigInteger(1, exponentBytes);

                // 创建公钥
                RSAPublicKeySpec spec = new RSAPublicKeySpec(modulus, exponent);
                KeyFactory keyFactory = KeyFactory.getInstance("RSA");
                return keyFactory.generatePublic(spec);
            }
        }

        throw new Exception("Unable to find matching key in Google JWKS");
    }

    private void validateClaims(Claims claims) throws Exception {
        // 验证发行者
        if (!GOOGLE_ISSUER.equals(claims.getIssuer())) {
            throw new Exception("Invalid issuer: " + claims.getIssuer());
        }

        // 验证受众
        String audience = claims.getAudience();
        if (!expectedClientId.equals(audience)) {
            throw new Exception("Invalid audience: " + audience);
        }

        // 验证过期时间
        if (claims.getExpiration().before(new java.util.Date())) {
            throw new Exception("Token has expired");
        }

        System.out.println("Claims validation successful");
        System.out.println("Issuer: " + claims.getIssuer());
        System.out.println("Audience: " + claims.getAudience());
        System.out.println("Expires: " + claims.getExpiration());
    }
}
