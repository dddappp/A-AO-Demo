package com.example.oauth2demo.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.ViewControllerRegistry;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.support.AbstractAnnotationConfigDispatcherServletInitializer;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Value("${app.frontend.type:thymeleaf}")
    private String frontendType;

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        // 处理静态资源
        registry.addResourceHandler("/**")
                .addResourceLocations("classpath:/static/", "classpath:/public/", "classpath:/resources/")
                .setCachePeriod(0);
    }

    @Override
    public void addViewControllers(ViewControllerRegistry registry) {
        // 只有在Thymeleaf模式下才使用视图控制器
        // React模式下由静态资源处理器处理
        if ("thymeleaf".equals(frontendType)) {
            registry.addViewController("/login").setViewName("login");
            registry.addViewController("/").setViewName("home");
        }
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        // 配置CORS，允许前端访问API
        registry.addMapping("/api/**")
                .allowedOrigins(
                    "http://localhost:5173",
                    "http://localhost:3000",
                    "https://api.u2511175.nyat.app:55139"  // 外部隧道域
                ) // 允许的前端域名
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                .allowedHeaders("*")
                .allowCredentials(true) // 允许发送Cookie
                .maxAge(3600);
        
        // 配置CORS，允许资源服务器访问Token验证端点
        registry.addMapping("/oauth2/**")
                .allowedOrigins(
                    "http://localhost:5001",  // 本地Python资源服务器
                    "http://localhost:5002",  // 备用端口
                    "http://localhost:5000",  // 备用端口
                    "https://api.u2511175.nyat.app:55139"  // 外部隧道域
                )
                .allowedMethods("GET", "POST", "OPTIONS")
                .allowedHeaders("*")
                .allowCredentials(true)
                .maxAge(3600);
    }
}