package com.example.oauth2demo.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;

/**
 * SPA路由控制器
 * 处理React应用的客户端路由
 */
@Controller
public class SpaController {

    @Value("${app.frontend.type:react}")
    private String frontendType;

    /**
     * SPA路由处理 - 对于React应用，返回index.html
     * 这确保所有前端路由都能正确加载React应用
     */
    @GetMapping("/login")
    public String loginPage() {
        if ("react".equals(frontendType)) {
            return "forward:/index.html";
        }
        return "redirect:/";
    }

    @GetMapping("/test")
    public String testPage() {
        if ("react".equals(frontendType)) {
            return "forward:/index.html";
        }
        return "redirect:/";
    }

    @GetMapping("/{path:[^\\.]*}")
    public String spaRoutes(@PathVariable String path) {
        // 排除API路径、静态资源等
        if (path.startsWith("api/") || path.startsWith("h2-console/") || path.equals("favicon.ico")) {
            return null; // 不处理这些路径
        }

        if ("react".equals(frontendType)) {
            return "forward:/index.html";
        }
        return "redirect:/";
    }

    /**
     * OAuth2回调路由 - 转发到前端处理
     */
    @GetMapping("/oauth2/callback")
    public String oauth2Callback() {
        if ("react".equals(frontendType)) {
            return "forward:/index.html";
        }
        return "redirect:/";
    }
}