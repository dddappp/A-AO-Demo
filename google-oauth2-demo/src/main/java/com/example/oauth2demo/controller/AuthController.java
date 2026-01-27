package com.example.oauth2demo.controller;

import com.example.oauth2demo.dto.RegisterRequest;
import com.example.oauth2demo.dto.UserDto;
import com.example.oauth2demo.entity.UserLoginMethod;
import com.example.oauth2demo.repository.UserRepository;
import com.example.oauth2demo.repository.UserLoginMethodRepository;
import com.example.oauth2demo.service.UserService;
import com.example.oauth2demo.service.JwtTokenService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.core.user.OAuth2User;
import org.springframework.security.oauth2.jwt.Jwt;
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
@Tag(name = "Authentication", description = "用户认证相关API")
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
    @Operation(
        summary = "用户注册",
        description = "创建新的本地用户账号",
        tags = { "Authentication" }
    )
    @ApiResponses({
        @ApiResponse(
            responseCode = "200",
            description = "注册成功",
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(implementation = UserDto.class)
            )
        ),
        @ApiResponse(
            responseCode = "400",
            description = "注册失败",
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(
                    example = "{\"error\": \"Username already exists\"}"
                )
            )
        )
    })
    public ResponseEntity<UserDto> register(
            @Parameter(
                name = "request",
                description = "注册信息",
                required = true
            )
            @RequestBody RegisterRequest request) {
        UserDto user = userService.register(request);
        return ResponseEntity.ok(user);
    }

    /**
     * 本地用户登录
     * 使用Spring Security进行认证并建立会话
     */
    @PostMapping("/login")
    @Operation(
        summary = "本地用户登录",
        description = "使用用户名和密码登录，支持Token双重传递（cookie + JSON响应体）",
        tags = { "Authentication" }
    )
    @ApiResponses({
        @ApiResponse(
            responseCode = "200",
            description = "登录成功",
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(
                    example = "{\"message\": \"Login successful\", \"authenticated\": true, \"user\": {...}, \"accessToken\": \"...\", \"refreshToken\": \"...\", \"accessTokenExpiresIn\": 3600, \"refreshTokenExpiresIn\": 604800, \"tokenType\": \"Bearer\"}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "401",
            description = "登录失败",
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(
                    example = "{\"error\": \"Invalid credentials\"}"
                )
            )
        )
    })
    public ResponseEntity<?> login(
            @Parameter(
                name = "username",
                description = "用户名",
                required = true
            )
            @RequestParam String username,
            @Parameter(
                name = "password",
                description = "密码",
                required = true
            )
            @RequestParam String password,
            HttpServletRequest request, HttpServletResponse response) {
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

            // 返回成功响应（包含Token用于跨域场景）
            Map<String, Object> responseData = new java.util.LinkedHashMap<>();
            responseData.put("user", user);
            responseData.put("message", "Login successful");
            responseData.put("authenticated", true);
            responseData.put("accessToken", accessToken);
            responseData.put("refreshToken", refreshToken);
            responseData.put("accessTokenExpiresIn", 3600);  // 1小时
            responseData.put("refreshTokenExpiresIn", 604800);  // 7天
            responseData.put("tokenType", "Bearer");

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
    @Operation(
        summary = "获取当前用户信息",
        description = "获取当前登录用户的详细信息",
        tags = { "Authentication" }
    )
    @ApiResponses({
        @ApiResponse(
            responseCode = "200",
            description = "获取成功",
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(
                    example = "{\"authenticated\": true, \"name\": \"John Doe\", \"email\": \"john@example.com\"}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "401",
            description = "未认证",
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(
                    example = "{\"error\": \"User not authenticated\"}"
                )
            )
        )
    })
    public ResponseEntity<?> getCurrentUser() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        
        if (authentication == null || !authentication.isAuthenticated()) {
            return ResponseEntity.status(401).body(Map.of("error", "User not authenticated"));
        }

        Map<String, Object> userInfo = new java.util.LinkedHashMap<>();
        userInfo.put("authenticated", true);

        // 处理不同类型的认证主体
        if (authentication.getPrincipal() instanceof OAuth2User) {
            // OAuth2登录
            OAuth2User oauth2User = (OAuth2User) authentication.getPrincipal();
            userInfo.put("name", oauth2User.getName());
            userInfo.put("email", oauth2User.getAttribute("email"));
            userInfo.put("provider", "oauth2");
        } else if (authentication.getPrincipal() instanceof Jwt) {
            // JWT token登录
            Jwt jwt = (Jwt) authentication.getPrincipal();
            userInfo.put("name", jwt.getSubject());
            userInfo.put("email", jwt.getClaim("email"));
            userInfo.put("userId", jwt.getClaim("userId"));
            userInfo.put("authorities", jwt.getClaim("authorities"));
            userInfo.put("provider", "local");
        } else {
            // 其他类型的认证
            userInfo.put("name", authentication.getName());
            userInfo.put("provider", "unknown");
        }

        return ResponseEntity.ok(userInfo);
    }

    /**
     * 检查用户是否存在（测试用）
     */
    @GetMapping("/check-user")
    @Operation(
        summary = "检查用户是否存在",
        description = "检查指定用户名是否已存在（测试用）",
        tags = { "Authentication" }
    )
    @ApiResponses({
        @ApiResponse(
            responseCode = "200",
            description = "检查成功",
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(
                    example = "{\"exists\": true, \"user\": {...}}"
                )
            )
        )
    })
    public ResponseEntity<?> checkUser(
            @Parameter(
                name = "username",
                description = "用户名",
                required = true
            )
            @RequestParam String username) {
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
    @Operation(
        summary = "生成BCrypt密码哈希",
        description = "生成指定密码的BCrypt哈希值（测试用）",
        tags = { "Authentication" }
    )
    @ApiResponses({
        @ApiResponse(
            responseCode = "200",
            description = "生成成功",
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(
                    example = "{\"password\": \"test123\", \"hash\": \"$2a$10$...\"}"
                )
            )
        )
    })
    public ResponseEntity<?> generateHash(
            @Parameter(
                name = "password",
                description = "密码",
                required = true
            )
            @RequestParam String password) {
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
    @Operation(
        summary = "创建测试用户",
        description = "创建测试用的本地用户账号（临时用）",
        tags = { "Authentication" }
    )
    @ApiResponses({
        @ApiResponse(
            responseCode = "200",
            description = "创建成功",
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(
                    example = "{\"message\": \"User created successfully\", \"user\": {...}}"
                )
            )
        )
    })
    public ResponseEntity<?> createTestUser(
            @Parameter(
                name = "username",
                description = "用户名",
                required = true
            )
            @RequestParam String username,
            @Parameter(
                name = "password",
                description = "密码",
                required = true
            )
            @RequestParam String password) {
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
    @Operation(
        summary = "重置用户密码",
        description = "重置指定用户的密码（仅开发环境可用）",
        tags = { "Authentication" }
    )
    @ApiResponses({
        @ApiResponse(
            responseCode = "200",
            description = "重置成功",
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(
                    example = "{\"message\": \"Password reset successfully\", \"username\": \"testuser\"}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "400",
            description = "重置失败",
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(
                    example = "{\"error\": \"User not found\"}"
                )
            )
        )
    })
    public ResponseEntity<?> resetPassword(
            @Parameter(
                name = "username",
                description = "用户名",
                required = true
            )
            @RequestParam String username,
            @Parameter(
                name = "newPassword",
                description = "新密码",
                required = true
            )
            @RequestParam String newPassword) {
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
    @Operation(
        summary = "用户登出",
        description = "清除用户认证状态和所有认证相关的Cookies",
        tags = { "Authentication" }
    )
    @ApiResponses({
        @ApiResponse(
            responseCode = "200",
            description = "登出成功",
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(
                    example = "{\"message\": \"Logged out successfully\"}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "500",
            description = "登出失败",
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(
                    example = "{\"error\": \"Logout failed\"}"
                )
            )
        )
    })
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