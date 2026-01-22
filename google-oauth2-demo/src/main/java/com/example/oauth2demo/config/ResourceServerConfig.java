package com.example.oauth2demo.config;

import com.example.oauth2demo.service.JwtTokenService;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.server.resource.web.BearerTokenResolver;
import org.springframework.security.web.SecurityFilterChain;

/**
 * 资源服务器配置
 * 保护业务API端点，从HttpOnly Cookie中验证JWT Token
 */
@Configuration
public class ResourceServerConfig {

    private final JwtTokenService jwtTokenService;

    public ResourceServerConfig(JwtTokenService jwtTokenService) {
        this.jwtTokenService = jwtTokenService;
    }

    /**
     * 自定义Bearer Token解析器，从Cookie中读取Token
     */
    @Bean
    public BearerTokenResolver bearerTokenResolver() {
        return new BearerTokenResolver() {
            @Override
            public String resolve(HttpServletRequest request) {
                // 首先尝试从Authorization头读取
                String authHeader = request.getHeader("Authorization");
                if (authHeader != null && authHeader.startsWith("Bearer ")) {
                    return authHeader.substring(7);
                }

                // 如果没有Authorization头，从Cookie中读取
                if (request.getCookies() != null) {
                    for (Cookie cookie : request.getCookies()) {
                        if ("accessToken".equals(cookie.getName())) {
                            return cookie.getValue();
                        }
                    }
                }

                return null;
            }
        };
    }

    /**
     * JWT解码器配置
     */
    @Bean
    public JwtDecoder jwtDecoder() {
        // 使用我们自己的JWT密钥验证
        return NimbusJwtDecoder.withSecretKey(jwtTokenService.getSecretKey()).build();
    }

    /**
     * 资源服务器安全过滤器链
     * 配置受保护的API端点
     */
    @Bean
    @Order(3)
    public SecurityFilterChain resourceServerSecurityFilterChain(HttpSecurity http,
                                                                 BearerTokenResolver bearerTokenResolver,
                                                                 JwtDecoder jwtDecoder) throws Exception {
        http
            .securityMatcher("/api/**")  // 只匹配API请求（排除认证API，因为AuthApiConfig优先级更高）
            .authorizeHttpRequests(authz -> authz
                .anyRequest().authenticated()  // 所有API请求都需要认证
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .bearerTokenResolver(bearerTokenResolver)
                .jwt(jwt -> jwt
                    .decoder(jwtDecoder)
                )
            );

        return http.build();
    }
}