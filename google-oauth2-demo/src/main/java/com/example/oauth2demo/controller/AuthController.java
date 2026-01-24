package com.example.oauth2demo.controller;

import com.example.oauth2demo.dto.RegisterRequest;
import com.example.oauth2demo.dto.UserDto;
import com.example.oauth2demo.entity.UserLoginMethod;
import com.example.oauth2demo.repository.UserRepository;
import com.example.oauth2demo.repository.UserLoginMethodRepository;
import com.example.oauth2demo.service.UserService;
import com.example.oauth2demo.service.JwtTokenService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.core.user.OAuth2User;
import org.springframework.security.web.authentication.logout.SecurityContextLogoutHandler;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.context.annotation.Profile;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.util.Map;

/**
 * 认证相关API控制器和SPA路由控制器
 */
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final UserService userService;
    private final AuthenticationManager authenticationManager;
    private final UserRepository userRepository;
    private final UserLoginMethodRepository loginMethodRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenService jwtTokenService;

    /**
     * 用户注册
     */
    @PostMapping("/register")
    public ResponseEntity<UserDto> register(@RequestBody RegisterRequest request) {
        UserDto user = userService.register(request);
        return ResponseEntity.ok(user);
    }

    /**
     * 本地用户登录
     * 使用Spring Security进行认证并建立会话
     */
    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestParam String username, @RequestParam String password, HttpServletRequest request, HttpServletResponse response) {
        try {
            // 使用AuthenticationManager进行认证
            Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(username, password)
            );

            // 认证成功，建立SecurityContext
            SecurityContextHolder.getContext().setAuthentication(authentication);

            // 获取用户信息
            UserDto user = userService.login(username, password);

            // 生成JWT Token
            String accessToken = jwtTokenService.generateAccessToken(
                user.getUsername(),
                user.getEmail(),
                user.getId(),
                userService.getCurrentUser(user.getUsername()).getAuthorities()
            );

            String refreshToken = jwtTokenService.generateRefreshToken(
                user.getUsername(),
                user.getId()
            );

            // 存储Token到HttpOnly Cookie
            Cookie accessTokenCookie = new Cookie("accessToken", accessToken);
            accessTokenCookie.setHttpOnly(true);
            accessTokenCookie.setPath("/");
            accessTokenCookie.setMaxAge(3600); // 1小时
            accessTokenCookie.setSecure(false); // 开发环境
            accessTokenCookie.setAttribute("SameSite", "Lax");
            response.addCookie(accessTokenCookie);

            Cookie refreshTokenCookie = new Cookie("refreshToken", refreshToken);
            refreshTokenCookie.setHttpOnly(true);
            refreshTokenCookie.setPath("/");
            refreshTokenCookie.setMaxAge(604800); // 7天
            refreshTokenCookie.setSecure(false); // 开发环境
            refreshTokenCookie.setAttribute("SameSite", "Lax");
            response.addCookie(refreshTokenCookie);

            // 返回成功响应
            Map<String, Object> responseData = Map.of(
                "user", user,
                "message", "Login successful",
                "authenticated", true
            );

            return ResponseEntity.ok(responseData);

        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(Map.of("error", "Invalid credentials"));
        }
    }

    /**
     * 获取当前用户信息
     * 这个端点会被Spring Security保护，需要有效的JWT Token
     */
    @GetMapping("/user")
    public ResponseEntity<?> getCurrentUser(@AuthenticationPrincipal OAuth2User oauth2User) {
        if (oauth2User == null) {
            return ResponseEntity.status(401).body(Map.of("error", "User not authenticated"));
        }

        // 这里可以返回用户信息
        // 注意：实际项目中，这里应该调用UserService来获取完整的用户信息
        Map<String, Object> userInfo = Map.of(
            "authenticated", true,
            "name", oauth2User.getName(),
            "email", oauth2User.getAttribute("email")
        );

        return ResponseEntity.ok(userInfo);
    }

    /**
     * 检查用户是否存在（测试用）
     */
    @GetMapping("/check-user")
    public ResponseEntity<?> checkUser(@RequestParam String username) {
        try {
            var user = userRepository.findByUsername(username);
            if (user.isPresent()) {
                return ResponseEntity.ok(Map.of(
                    "exists", true,
                    "user", Map.of(
                        "id", user.get().getId(),
                        "username", user.get().getUsername(),
                        "email", user.get().getEmail(),
                        "enabled", user.get().isEnabled()
                    )
                ));
            } else {
                return ResponseEntity.ok(Map.of("exists", false));
            }
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("error", e.getMessage()));
        }
    }

    /**
     * 生成BCrypt密码哈希（测试用）
     */
    @GetMapping("/generate-hash")
    public ResponseEntity<?> generateHash(@RequestParam String password) {
        try {
            String hash = passwordEncoder.encode(password);
            return ResponseEntity.ok(Map.of(
                "password", password,
                "hash", hash
            ));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("error", e.getMessage()));
        }
    }

    /**
     * 创建测试用户（临时用）
     */
    @PostMapping("/create-test-user")
    public ResponseEntity<?> createTestUser(@RequestParam String username, @RequestParam String password) {
        try {
            if (userRepository.findByUsername(username).isPresent()) {
                return ResponseEntity.ok(Map.of("message", "User already exists"));
            }

            UserDto user = userService.register(new RegisterRequest(
                username,
                username + "@example.com",
                password,
                "Test User"
            ));

            return ResponseEntity.ok(Map.of(
                "message", "User created successfully",
                "user", user
            ));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("error", e.getMessage()));
        }
    }

    /**
     * 重置用户密码（仅开发环境可用）
     */
    @PostMapping("/reset-password")
    @Profile("dev")
    public ResponseEntity<?> resetPassword(@RequestParam String username, @RequestParam String newPassword) {
        try {
            var loginMethodOptional = loginMethodRepository.findByLocalUsername(username);
            if (loginMethodOptional.isEmpty()) {
                return ResponseEntity.badRequest().body(Map.of("error", "User not found"));
            }

            var loginMethod = loginMethodOptional.get();
            loginMethod.setLocalPasswordHash(passwordEncoder.encode(newPassword));
            loginMethodRepository.save(loginMethod);

            return ResponseEntity.ok(Map.of(
                "message", "Password reset successfully",
                "username", username
            ));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("error", e.getMessage()));
        }
    }

    /**
     * 登出 - 统一认证方式的登出处理
     */
    @PostMapping("/logout")
    public ResponseEntity<?> logout(HttpServletRequest request, HttpServletResponse response) {
        try {
            System.out.println("=== AUTH CONTROLLER LOGOUT STARTED ===");

            // 1. 清除Spring Security上下文
            SecurityContextHolder.clearContext();
            System.out.println("SecurityContext cleared");

            // 2. 使用SecurityContextLogoutHandler处理OAuth2特定的清理
            new SecurityContextLogoutHandler().logout(request, response, null);
            System.out.println("SecurityContextLogoutHandler executed");

            // 3. 使Session无效（如果存在）
            if (request.getSession(false) != null) {
                request.getSession(false).invalidate();
                System.out.println("Session invalidated");
            }

            // 4. ✅ 关键：清除所有认证Cookies！
            clearAuthCookies(response);
            System.out.println("Auth cookies cleared");

            System.out.println("=== AUTH CONTROLLER LOGOUT COMPLETED ===");
            return ResponseEntity.ok(Map.of("message", "Logged out successfully"));
        } catch (Exception e) {
            System.err.println("AuthController logout error: " + e.getMessage());
            e.printStackTrace();
            return ResponseEntity.status(500).body(Map.of("error", "Logout failed"));
        }
    }

    /**
     * 清除所有认证相关的Cookies
     */
    private void clearAuthCookies(HttpServletResponse response) {
        String[] cookieNames = {
            "JSESSIONID",
            "accessToken",      // JWT access token
            "refreshToken",     // JWT refresh token
            "google_access_token",
            "github_access_token",
            "twitter_access_token"
        };

        for (String cookieName : cookieNames) {
            Cookie cookie = new Cookie(cookieName, null);
            cookie.setMaxAge(0);
            cookie.setPath("/");
            cookie.setHttpOnly(true);
            response.addCookie(cookie);
            System.out.println("Cleared cookie: " + cookieName);
        }
    }
}