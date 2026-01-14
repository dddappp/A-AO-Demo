package com.example.oauth2demo.controller;

import com.example.oauth2demo.service.JwtValidationService;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.core.user.OAuth2User;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

import java.util.HashMap;
import java.util.Map;

@Controller
public class AuthController {

    @Value("${app.frontend.type:thymeleaf}")
    private String frontendType;

    /**
     * 前端路由处理 - 将所有非API请求重定向到index.html
     * 支持React Router的客户端路由（仅在React模式下启用）
     */
    @GetMapping(value = "/{path:[^\\.]*}")
    public String forwardToIndex(@PathVariable String path) {
        // 如果不是React模式，不启用前端路由
        if (!"react".equals(frontendType)) {
            return null;
        }

        // 如果是API请求、OAuth2请求或静态资源，让Spring Boot正常处理
        if (path.startsWith("api") || path.startsWith("oauth2") || path.startsWith("static") ||
            path.startsWith("css") || path.startsWith("js") || path.startsWith("images") ||
            path.equals("favicon.ico") || path.matches(".*\\.(css|js|png|jpg|jpeg|gif|ico|svg)$")) {
            return null; // 返回null让Spring Boot继续处理
        }
        // 其他所有请求都返回index.html，让React Router处理
        return "forward:/index.html";
    }

    @Autowired
    private JwtValidationService jwtValidationService;

    @GetMapping("/")
    public String home() {
        // 在React模式下，让前端路由处理所有路径
        if ("react".equals(frontendType)) {
            return "forward:/index.html";
        }
        return "home";
    }

    @GetMapping("/login")
    public String login() {
        // 在React模式下，让前端路由处理所有路径
        if ("react".equals(frontendType)) {
            return "forward:/index.html";
        }
        /*
        forward: 是 Spring 的特殊关键字，表示服务器端转发（不是重定向）。
        转发意味着：请求直接转到服务器内部的另一个资源，浏览器地址栏不变，用户看不到跳转。
        具体行为：用户访问 http://yourapp.com/login，但实际上加载的是 http://yourapp.com/index.html 的内容。
        为什么这样做？
        React 是单页应用（SPA - Single Page Application）框架。它的工作原理是：
        浏览器加载一个 HTML 主文件（index.html）；
        JavaScript 代码在浏览器中运行，根据 URL 路径动态渲染不同的页面；
        React Router 库负责处理所有 URL 路由（包括 /login、/dashboard 等）。
         */
        return "login";
    }

    @GetMapping("/test")
    public String test(Model model, @AuthenticationPrincipal OAuth2User oauth2User) {
        // 在React模式下，让前端路由处理所有路径
        if ("react".equals(frontendType)) {
            return "forward:/index.html";
        }

        // 为Thymeleaf模板设置用户信息
        if (oauth2User != null) {
            String provider = getProviderFromUser(oauth2User);
            model.addAttribute("provider", provider);
            model.addAttribute("userName", getUserName(oauth2User, provider));
            model.addAttribute("userEmail", getUserEmail(oauth2User, provider));
            model.addAttribute("userId", getUserId(oauth2User, provider));
            model.addAttribute("userAvatar", getUserAvatar(oauth2User, provider));

            // GitHub特定信息
            if ("github".equals(provider)) {
                model.addAttribute("userHtmlUrl", getUserHtmlUrl(oauth2User, provider));
                model.addAttribute("userPublicRepos", getUserPublicRepos(oauth2User, provider));
                model.addAttribute("userFollowers", getUserFollowers(oauth2User, provider));
            }

            // Twitter特定信息
            if ("twitter".equals(provider)) {
                model.addAttribute("userLocation", getUserLocation(oauth2User, provider));
                model.addAttribute("userVerified", getUserVerified(oauth2User, provider));
                model.addAttribute("userDescription", getUserDescription(oauth2User, provider));
            }
        }

        return "test";
    }

    // 移除自定义OAuth2回调处理器 - 让Spring Security处理默认的OAuth2流程
    // Spring Security会自动处理/login/oauth2/code/{registrationId}路径的回调

    // 调试端点 - 检查当前认证状态
    @GetMapping("/debug")
    public String debug(Model model) {
        System.out.println("=== DEBUG ENDPOINT CALLED ===");
        model.addAttribute("message", "Debug endpoint reached");
        return "debug";
    }

    @PostMapping("/api/test-validate-token")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> testValidateToken(@RequestParam String token) {
        Map<String, Object> response = new HashMap<>();

        try {
            System.out.println("=== MANUAL TOKEN VALIDATION REQUEST ===");
            System.out.println("Token length: " + (token != null ? token.length() : 0));

            // 验证 ID Token
            Map<String, Object> validationResult = jwtValidationService.validateIdToken(token);

            response.put("success", true);
            response.put("validation", validationResult);
            response.put("message", "手动 ID Token 验证成功");

            System.out.println("Manual token validation successful");

        } catch (Exception e) {
            System.err.println("Manual token validation failed: " + e.getMessage());
            e.printStackTrace();

            response.put("success", false);
            response.put("message", "手动 ID Token 验证失败: " + e.getMessage());
            return ResponseEntity.badRequest().body(response);
        }

        return ResponseEntity.ok(response);
    }

    @PostMapping("/api/validate-token")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> validateToken(HttpServletRequest request) {
        Map<String, Object> response = new HashMap<>();

        try {
            // 从 Cookie 中获取 ID Token
            String idToken = getIdTokenFromCookie(request);

            if (idToken == null) {
                response.put("success", false);
                response.put("message", "未找到 ID Token Cookie");
                return ResponseEntity.badRequest().body(response);
            }

            System.out.println("=== Token Validation Request ===");
            System.out.println("ID Token: " + idToken.substring(0, Math.min(50, idToken.length())) + "...");

            // 验证 ID Token
            Map<String, Object> validationResult = jwtValidationService.validateIdToken(idToken);

            response.put("success", true);
            response.put("validation", validationResult);
            response.put("message", "ID Token 验证成功");

            System.out.println("Token validation successful");
            System.out.println("Validation result: " + validationResult);

        } catch (Exception e) {
            System.err.println("Token validation failed: " + e.getMessage());
            e.printStackTrace();

            response.put("success", false);
            response.put("message", "ID Token 验证失败: " + e.getMessage());
            return ResponseEntity.badRequest().body(response);
        }

        return ResponseEntity.ok(response);
    }



    // 新增：从用户对象中提取提供商信息
    private String getProviderFromUser(OAuth2User user) {
        // 由于Spring Security的实现，我们无法直接从OAuth2User获取registrationId
        // 这里通过用户属性特征来判断提供商
        if (user.getAttribute("sub") != null) {
            // Google用户有sub字段
            return "google";
        } else if (user.getAttribute("login") != null) {
            // GitHub用户有login字段
            return "github";
        } else if (user.getAttribute("username") != null) {
            // Twitter用户有username字段
            return "twitter";
        }
        return "unknown";
    }

    // 新增：根据提供商获取用户名
    private String getUserName(OAuth2User user, String provider) {
        if ("github".equals(provider)) {
            return user.getAttribute("name"); // GitHub的name字段
        } else if ("google".equals(provider)) {
            return user.getAttribute("name"); // Google的name字段
        } else if ("twitter".equals(provider)) {
            return user.getAttribute("name"); // Twitter的name字段
        }
        return user.getAttribute("name");
    }

    // 新增：根据提供商获取邮箱
    private String getUserEmail(OAuth2User user, String provider) {
        if ("github".equals(provider)) {
            return user.getAttribute("email"); // GitHub的email字段
        } else if ("google".equals(provider)) {
            return user.getAttribute("email"); // Google的email字段
        }
        return user.getAttribute("email");
    }

    // 新增：根据提供商获取用户ID
    private String getUserId(OAuth2User user, String provider) {
        if ("github".equals(provider)) {
            return user.getAttribute("login"); // GitHub的用户ID是login字段
        } else if ("google".equals(provider)) {
            return user.getAttribute("sub"); // Google的用户ID是sub字段
        } else if ("twitter".equals(provider)) {
            return user.getAttribute("username"); // Twitter的用户ID是username字段
        }
        return user.getAttribute("sub");
    }

    // 新增：根据提供商获取头像
    private String getUserAvatar(OAuth2User user, String provider) {
        if ("github".equals(provider)) {
            return user.getAttribute("avatar_url"); // GitHub的头像字段
        } else if ("google".equals(provider)) {
            return user.getAttribute("picture"); // Google的头像字段
        } else if ("twitter".equals(provider)) {
            return user.getAttribute("profile_image_url"); // Twitter的头像字段
        }
        return null;
    }

    // 新增：获取GitHub主页URL
    private String getUserHtmlUrl(OAuth2User user, String provider) {
        if ("github".equals(provider)) {
            return user.getAttribute("html_url");
        }
        return null;
    }

    // 新增：获取GitHub公开仓库数
    private Integer getUserPublicRepos(OAuth2User user, String provider) {
        if ("github".equals(provider)) {
            return (Integer) user.getAttribute("public_repos");
        }
        return null;
    }

    // 新增：获取GitHub粉丝数
    private Integer getUserFollowers(OAuth2User user, String provider) {
        if ("github".equals(provider)) {
            return (Integer) user.getAttribute("followers");
        }
        return null;
    }

    // 新增：获取Twitter位置信息
    private String getUserLocation(OAuth2User user, String provider) {
        if ("twitter".equals(provider)) {
            return user.getAttribute("location");
        }
        return null;
    }

    // 新增：获取Twitter是否已验证
    private Boolean getUserVerified(OAuth2User user, String provider) {
        if ("twitter".equals(provider)) {
            return (Boolean) user.getAttribute("verified");
        }
        return null;
    }

    // 新增：获取Twitter个人简介
    private String getUserDescription(OAuth2User user, String provider) {
        if ("twitter".equals(provider)) {
            return user.getAttribute("description");
        }
        return null;
    }

    private String getIdTokenFromCookie(HttpServletRequest request) {
        Cookie[] cookies = request.getCookies();
        if (cookies != null) {
            for (Cookie cookie : cookies) {
                if ("id_token".equals(cookie.getName())) {
                    return cookie.getValue();
                }
            }
        }
        return null;
    }
}
