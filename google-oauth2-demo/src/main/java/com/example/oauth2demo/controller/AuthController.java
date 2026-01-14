package com.example.oauth2demo.controller;

import com.example.oauth2demo.service.JwtValidationService;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;
import org.springframework.security.oauth2.core.user.OAuth2User;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

import java.util.HashMap;
import java.util.Map;

@Controller
public class AuthController {

    @Autowired
    private JwtValidationService jwtValidationService;

    @GetMapping("/")
    public String home() {
        return "home";
    }

    @GetMapping("/login")
    public String login() {
        return "login";
    }

    @GetMapping("/test")
    public String test(@AuthenticationPrincipal OAuth2User oauth2User, Model model) {
        if (oauth2User != null) {
            // 增强用户信息显示，支持多提供商
            String provider = getProviderFromUser(oauth2User);
            model.addAttribute("provider", provider);
            model.addAttribute("userName", getUserName(oauth2User, provider));
            model.addAttribute("userEmail", getUserEmail(oauth2User, provider));
            model.addAttribute("userId", getUserId(oauth2User, provider));
            model.addAttribute("userAvatar", getUserAvatar(oauth2User, provider));

            // GitHub特定属性
            if ("github".equals(provider)) {
                model.addAttribute("userHtmlUrl", getUserHtmlUrl(oauth2User, provider));
                model.addAttribute("userPublicRepos", getUserPublicRepos(oauth2User, provider));
                model.addAttribute("userFollowers", getUserFollowers(oauth2User, provider));
            }

            // Twitter特定属性
            if ("twitter".equals(provider)) {
                model.addAttribute("userLocation", getUserLocation(oauth2User, provider));
                model.addAttribute("userVerified", getUserVerified(oauth2User, provider));
                model.addAttribute("userDescription", getUserDescription(oauth2User, provider));
            }

            model.addAttribute("isLoggedIn", true);
        } else {
            model.addAttribute("isLoggedIn", false);
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

    // 新增：GitHub令牌验证端点
    @PostMapping("/api/validate-github-token")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> validateGitHubToken(HttpServletRequest request) {
        Map<String, Object> response = new HashMap<>();

        try {
            // 从Cookie中获取GitHub访问令牌（自动获取，不需要用户输入）
            String accessToken = null;
            if (request.getCookies() != null) {
                for (jakarta.servlet.http.Cookie cookie : request.getCookies()) {
                    if ("github_access_token".equals(cookie.getName())) {
                        accessToken = cookie.getValue();
                        break;
                    }
                }
            }

            if (accessToken == null || accessToken.trim().isEmpty()) {
                response.put("success", false);
                response.put("message", "未找到GitHub访问令牌，请重新登录");
                return ResponseEntity.badRequest().body(response);
            }

            System.out.println("=== GitHub Token Validation Request ===");
            System.out.println("Access Token found in cookie: " + accessToken.substring(0, Math.min(20, accessToken.length())) + "...");

            // 验证GitHub访问令牌
            Map<String, Object> validationResult = jwtValidationService.validateGitHubToken(accessToken);

            response.put("success", true);
            response.put("validation", validationResult);
            response.put("message", "GitHub 访问令牌验证成功");

            System.out.println("GitHub token validation successful");

        } catch (Exception e) {
            System.err.println("GitHub token validation failed: " + e.getMessage());
            e.printStackTrace();

            response.put("success", false);
            response.put("message", "GitHub 访问令牌验证失败: " + e.getMessage());
            return ResponseEntity.badRequest().body(response);
        }

        return ResponseEntity.ok(response);
    }

    // 新增：Twitter令牌验证端点
    @PostMapping("/api/validate-twitter-token")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> validateTwitterToken(HttpServletRequest request) {
        Map<String, Object> response = new HashMap<>();

        try {
            // 从Cookie中获取Twitter访问令牌（自动获取，不需要用户输入）
            String accessToken = null;
            if (request.getCookies() != null) {
                for (jakarta.servlet.http.Cookie cookie : request.getCookies()) {
                    if ("twitter_access_token".equals(cookie.getName())) {
                        accessToken = cookie.getValue();
                        break;
                    }
                }
            }

            if (accessToken == null || accessToken.trim().isEmpty()) {
                response.put("success", false);
                response.put("message", "未找到Twitter访问令牌，请重新登录");
                return ResponseEntity.badRequest().body(response);
            }

            System.out.println("=== Twitter Token Validation Request ===");
            System.out.println("Access Token found in cookie: " + accessToken.substring(0, Math.min(20, accessToken.length())) + "...");

            // 验证Twitter访问令牌
            Map<String, Object> validationResult = jwtValidationService.validateTwitterToken(accessToken);

            response.put("success", true);
            response.put("validation", validationResult);
            response.put("message", "Twitter 访问令牌验证成功");

            System.out.println("Twitter token validation successful");

        } catch (Exception e) {
            System.err.println("Twitter token validation failed: " + e.getMessage());
            e.printStackTrace();

            response.put("success", false);
            response.put("message", "Twitter 访问令牌验证失败: " + e.getMessage());
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
