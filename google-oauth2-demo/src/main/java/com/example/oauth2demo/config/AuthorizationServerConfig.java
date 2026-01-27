package com.example.oauth2demo.config;

import com.example.oauth2demo.service.JwtTokenService;
import com.nimbusds.jose.jwk.JWKSet;
import com.nimbusds.jose.jwk.RSAKey;
import com.nimbusds.jose.jwk.source.ImmutableJWKSet;
import com.nimbusds.jose.jwk.source.JWKSource;
import com.nimbusds.jose.proc.SecurityContext;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.security.oauth2.core.AuthorizationGrantType;
import org.springframework.security.oauth2.core.ClientAuthenticationMethod;
import org.springframework.security.oauth2.server.authorization.client.InMemoryRegisteredClientRepository;
import org.springframework.security.oauth2.server.authorization.client.RegisteredClient;
import org.springframework.security.oauth2.server.authorization.config.annotation.web.configuration.OAuth2AuthorizationServerConfiguration;
import org.springframework.security.oauth2.server.authorization.settings.ClientSettings;
import org.springframework.security.oauth2.server.authorization.settings.TokenSettings;
import org.springframework.security.web.SecurityFilterChain;

import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.NoSuchAlgorithmException;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.time.Duration;
import java.util.UUID;

/**
 * Spring Authorization Server 配置
 * 负责生成和管理JWT Token
 */
@Configuration
public class AuthorizationServerConfig {

    /**
     * Authorization Server 安全过滤器链
     */
    @Bean
    @Order(1)
    public SecurityFilterChain authorizationServerSecurityFilterChain(org.springframework.security.config.annotation.web.builders.HttpSecurity http) throws Exception {
        // 只处理OAuth2授权服务器相关的路径
        http
            .securityMatcher("/oauth2/authorize", "/oauth2/token", "/oauth2/jwks", "/oauth2/revoke", "/oauth2/introspect")
            .authorizeHttpRequests(authz -> authz
                .anyRequest().permitAll()
            )
            .csrf(csrf -> csrf.disable());
        
        return http.build();
    }

    /**
     * OAuth2 客户端配置
     * 在内存中配置客户端，用于本地认证
     */
    @Bean
    public InMemoryRegisteredClientRepository registeredClientRepository() {
        RegisteredClient registeredClient = RegisteredClient.withId(UUID.randomUUID().toString())
            .clientId("auth-client")
            .clientSecret("{noop}auth-secret")  // 开发环境，生产环境应加密
            .clientAuthenticationMethod(ClientAuthenticationMethod.CLIENT_SECRET_BASIC)
            .authorizationGrantType(AuthorizationGrantType.PASSWORD)  // 本地登录
            .authorizationGrantType(AuthorizationGrantType.REFRESH_TOKEN)  // Token 刷新
            .redirectUri("http://localhost:5173/callback")  // 前端回调地址
            .scope("openid")
            .scope("profile")
            .scope("email")
            .tokenSettings(TokenSettings.builder()
                .accessTokenTimeToLive(Duration.ofHours(1))  // accessToken 1小时
                .refreshTokenTimeToLive(Duration.ofDays(7))  // refreshToken 7天
                .build())
            .clientSettings(ClientSettings.builder()
                .requireProofKey(false)  // 不需要PKCE
                .build())
            .build();

        return new InMemoryRegisteredClientRepository(registeredClient);
    }

    /**
     * JWT 密钥源
     * 使用JwtTokenService中的RSA密钥对进行JWT签名
     */
    @Bean
    public JWKSource<SecurityContext> jwkSource(JwtTokenService jwtTokenService) throws NoSuchAlgorithmException {
        PublicKey publicKey = jwtTokenService.getPublicKey();
        PrivateKey privateKey = jwtTokenService.getPrivateKey();

        RSAKey rsaKey = new RSAKey.Builder((java.security.interfaces.RSAPublicKey) publicKey)
            .privateKey((java.security.interfaces.RSAPrivateKey) privateKey)
            .keyID("key-1")  // 使用固定的keyID，与JwtTokenService中的kid保持一致
            .build();

        JWKSet jwkSet = new JWKSet(rsaKey);
        return new ImmutableJWKSet<>(jwkSet);
    }
}
