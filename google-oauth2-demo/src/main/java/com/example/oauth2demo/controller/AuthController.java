package com.example.oauth2demo.controller;

import com.example.oauth2demo.service.JwtValidationService;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;
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
    public String test(@AuthenticationPrincipal OidcUser oidcUser, Model model) {
        if (oidcUser != null) {
            model.addAttribute("userName", oidcUser.getFullName());
            model.addAttribute("userEmail", oidcUser.getEmail());
            model.addAttribute("userId", oidcUser.getSubject());
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
