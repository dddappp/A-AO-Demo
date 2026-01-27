package com.example.oauth2demo.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.web.SecurityFilterChain;

/**
 * 认证API配置
 * 处理公开的认证相关API端点
 */
@Configuration
public class AuthApiConfig {

    /**
     * 认证API安全过滤器链
     * 只处理认证相关的API端点，不应用JWT验证
     */
    @Bean
    @Order(0)
    public SecurityFilterChain authApiSecurityFilterChain(HttpSecurity http) throws Exception {
        http
            .securityMatcher("/api/auth/**")  // 只匹配认证API
            .authorizeHttpRequests(authz -> authz
                .anyRequest().permitAll()  // 所有认证API都公开
            )
            .csrf(csrf -> csrf.disable());  // 认证API通常需要禁用CSRF

        return http.build();
    }
}