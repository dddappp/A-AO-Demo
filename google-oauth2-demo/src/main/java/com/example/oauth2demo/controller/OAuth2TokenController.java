package com.example.oauth2demo.controller;

import com.example.oauth2demo.service.JwtTokenService;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.jwk.RSAKey;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.util.MultiValueMap;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;
import java.io.BufferedReader;
import java.net.URLDecoder;
import java.security.PublicKey;
import java.security.interfaces.RSAPublicKey;
import java.util.*;

/**
 * OAuth2 Token 管理控制器
 * 提供 JWKS 端点和 Token 验证端点
 * 用于支持异构资源服务器的 Token 验证
 */
@Slf4j
@RestController
@RequestMapping("/oauth2")
@RequiredArgsConstructor
public class OAuth2TokenController {

    private final JwtTokenService jwtTokenService;

    /**
     * JWKS 端点
     * 返回用于验证 JWT 签名的公钥集合
     * 符合 RFC 7517 (JSON Web Key) 和 RFC 7518 规范
     */
    @GetMapping("/jwks")
    public ResponseEntity<?> getJwks() {
        log.debug("JWKS endpoint requested");
        try {
            PublicKey publicKey = jwtTokenService.getPublicKey();
            String kid = jwtTokenService.getToken().getKid();  // 从配置文件读取 kid
            
            // 将公钥转换为 JWK 格式
            if (publicKey instanceof RSAPublicKey) {
                RSAPublicKey rsaKey = (RSAPublicKey) publicKey;
                RSAKey jwk = new RSAKey.Builder(rsaKey)
                        .keyID(kid)  // 使用与 Token 头中 kid 相同的值
                        .algorithm(JWSAlgorithm.RS256)
                        .build();
                
                // 使用RSAKey的toJSONObject()方法生成正确的JWK格式
                List<Map<String, Object>> keys = new ArrayList<>();
                keys.add(jwk.toJSONObject());
                
                log.debug("JWKS returned successfully with kid: " + kid);
                return ResponseEntity.ok(Map.of("keys", keys));
            } else {
                log.error("Public key is not RSA key");
                return ResponseEntity.status(500).body(Map.of(
                        "error", "Internal server error",
                        "message", "Public key type not supported"
                ));
            }
        } catch (Exception e) {
            log.error("Error generating JWKS", e);
            return ResponseEntity.status(500).body(Map.of(
                    "error", "Internal server error",
                    "message", e.getMessage()
            ));
        }
    }

    /**
     * Token 内省端点
     * 验证 Token 有效性并返回 Token 信息
     * 符合 RFC 7662 (Token Introspection) 规范
     * 支持两种路径：/oauth2/introspect 和 /oauth2/api/introspect
     * 支持两种请求格式：查询参数和表单提交
     */
    @PostMapping({"/introspect", "/api/introspect"})
    public ResponseEntity<?> introspect(
            @RequestParam(value = "token", required = false) String token,
            @RequestBody(required = false) MultiValueMap<String, String> formData,
            HttpServletRequest request) {
        log.info("Token introspection request received");
        
        // 尝试从多个来源获取token
        String tokenValue = token;
        
        // 如果查询参数中没有token，尝试从表单数据中获取
        if (tokenValue == null && formData != null) {
            tokenValue = formData.getFirst("token");
        }
        
        // 如果还是没有token，尝试从请求体中直接获取（处理原始POST请求）
        if (tokenValue == null) {
            try {
                StringBuilder sb = new StringBuilder();
                BufferedReader reader = request.getReader();
                String line;
                while ((line = reader.readLine()) != null) {
                    sb.append(line);
                }
                String body = sb.toString();
                if (body != null && body.contains("token=")) {
                    // 解析表单数据格式的请求体
                    String[] parts = body.split("&");
                    for (String part : parts) {
                        if (part.startsWith("token=")) {
                            tokenValue = part.substring("token=".length());
                            tokenValue = URLDecoder.decode(tokenValue, "UTF-8");
                            break;
                        }
                    }
                }
            } catch (Exception e) {
                log.debug("Error reading request body", e);
            }
        }
        
        if (tokenValue == null || tokenValue.trim().isEmpty()) {
            log.warn("Empty token provided for introspection");
            return ResponseEntity.ok(Map.of("active", false));
        }
        
        try {
            // 验证 Token 签名
            Claims claims = Jwts.parserBuilder()
                    .setSigningKey(jwtTokenService.getPublicKey())
                    .build()
                    .parseClaimsJws(tokenValue)
                    .getBody();
            
            log.debug("Token verified successfully, user: {}", claims.getSubject());
            
            // 构造内省响应
            Map<String, Object> response = new LinkedHashMap<>();
            response.put("active", true);
            response.put("sub", claims.getSubject());
            response.put("userId", claims.get("userId"));
            response.put("email", claims.get("email"));
            response.put("authorities", claims.get("authorities"));
            response.put("aud", claims.getAudience());
            response.put("iss", claims.getIssuer());
            response.put("iat", claims.getIssuedAt() != null ? claims.getIssuedAt().getTime() / 1000 : null);
            response.put("exp", claims.getExpiration() != null ? claims.getExpiration().getTime() / 1000 : null);
            response.put("jti", claims.get("jti"));
            response.put("token_type", "Bearer");
            
            return ResponseEntity.ok(response);
            
        } catch (io.jsonwebtoken.ExpiredJwtException e) {
            log.warn("Token expired");
            return ResponseEntity.ok(Map.of(
                    "active", false,
                    "error", "Token expired"
            ));
        } catch (io.jsonwebtoken.SignatureException e) {
            log.warn("Invalid token signature");
            return ResponseEntity.ok(Map.of(
                    "active", false,
                    "error", "Invalid signature"
            ));
        } catch (Exception e) {
            log.warn("Token introspection error", e);
            return ResponseEntity.ok(Map.of(
                    "active", false,
                    "error", "Invalid token"
            ));
        }
    }
    
    /**
     * Token 内省测试端点（GET方法）
     * 用于测试端点是否能够成功响应
     */
    @GetMapping("/introspect-test")
    public ResponseEntity<?> introspectTest() {
        log.debug("Token introspection test request received");
        
        // 直接返回 active: false，测试是否能够成功响应
        return ResponseEntity.ok(Map.of("active", false, "test", "success"));
    }

    /**
     * Token 验证测试端点
     * 用于前端测试 Token 是否有效
     */
    @PostMapping("/validate")
    public ResponseEntity<?> validateToken(@RequestParam String token) {
        log.debug("Token validation request received");
        
        try {
            Claims claims = Jwts.parserBuilder()
                    .setSigningKey(jwtTokenService.getPublicKey())
                    .build()
                    .parseClaimsJws(token)
                    .getBody();
            
            return ResponseEntity.ok(Map.of(
                    "valid", true,
                    "message", "Token is valid",
                    "user", claims.getSubject()
            ));
        } catch (Exception e) {
            return ResponseEntity.ok(Map.of(
                    "valid", false,
                    "message", "Token is invalid: " + e.getMessage()
            ));
        }
    }
}
