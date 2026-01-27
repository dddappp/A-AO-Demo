package com.example.oauth2demo.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * 全局 CORS 配置
 * 支持来自异构资源服务器的跨域请求
 */
@Configuration
public class CorsConfig {

    @Bean
    public WebMvcConfigurer corsConfigurer() {
        return new WebMvcConfigurer() {
            @Override
            public void addCorsMappings(CorsRegistry registry) {
                // 允许所有跨域请求
                registry.addMapping("/**")
                        // 允许的源（使用allowedOriginPatterns替代allowedOrigins以支持通配符和凭证）
                        .allowedOriginPatterns("*")
                        // 允许的HTTP方法
                        .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                        // 允许的请求头
                        .allowedHeaders("*")
                        // 允许暴露的响应头
                        .exposedHeaders("Authorization", "Content-Type")
                        // 允许携带凭证
                        .allowCredentials(true)
                        // 预检请求的有效期（秒）
                        .maxAge(3600);
            }
        };
    }
}
