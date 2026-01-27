package com.example.oauth2demo.config;

import com.example.oauth2demo.service.JwtTokenService;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.web.BearerTokenResolver;
import org.springframework.security.web.SecurityFilterChain;

import java.util.*;

/**
 * 资源服务器配置
 * 保护业务API端点，从HttpOnly Cookie中验证JWT Token
 */
@Configuration
@RequiredArgsConstructor
public class ResourceServerConfig {

    private final JwtTokenService jwtTokenService;

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
     * 使用 RSA 公钥进行验证
     */
    @Bean
    public JwtDecoder jwtDecoder() {
        return jwtTokenService.jwtDecoder();
    }

    /**
     * JWT认证转换器，从token中提取权限信息
     */
    @Bean
    public JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(jwt -> {
            Collection<GrantedAuthority> authorities = new ArrayList<>();
            // 从token中提取权限信息
            List<String> auths = jwt.getClaimAsStringList("authorities");
            if (auths != null) {
                for (String auth : auths) {
                    authorities.add(new SimpleGrantedAuthority(auth));
                }
            }
            return authorities;
        });
        return converter;
    }

    /**
     * 资源服务器安全过滤器链
     * 配置受保护的API端点
     */
    @Bean
    @Order(2)
    public SecurityFilterChain resourceServerSecurityFilterChain(HttpSecurity http,
                                                                 BearerTokenResolver bearerTokenResolver,
                                                                 JwtDecoder jwtDecoder,
                                                                 JwtAuthenticationConverter jwtAuthenticationConverter) throws Exception {
        http
            .securityMatcher("/api/**")  // 只匹配API请求（排除认证API，因为AuthApiConfig优先级更高）
            .authorizeHttpRequests(authz -> authz
                .requestMatchers("/api/auth/**").permitAll()  // 认证API公开
                .requestMatchers("/api/user").authenticated()  // 所有认证用户都可以访问
                .requestMatchers("/api/admin/**").hasAuthority("ROLE_ADMIN")  // 只有ROLE_ADMIN权限可以访问
                .requestMatchers("/api/manager/**").hasAnyAuthority("ROLE_ADMIN", "ROLE_MANAGER")  // ROLE_ADMIN或ROLE_MANAGER权限可以访问
                .anyRequest().authenticated()  // 所有API请求都需要认证
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .bearerTokenResolver(bearerTokenResolver)
                .jwt(jwt -> jwt
                    .decoder(jwtDecoder)
                    .jwtAuthenticationConverter(jwtAuthenticationConverter)
                )
            );

        return http.build();
    }
}
