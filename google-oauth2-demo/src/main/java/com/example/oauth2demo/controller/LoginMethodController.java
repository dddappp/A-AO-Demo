package com.example.oauth2demo.controller;

import com.example.oauth2demo.entity.UserLoginMethod;
import com.example.oauth2demo.service.LoginMethodService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 登录方式管理控制器
 * 提供查询、移除、设置主登录方式的功能
 */
@RestController
@RequestMapping("/api/user/login-methods")
@RequiredArgsConstructor
@Slf4j
public class LoginMethodController {

    private final LoginMethodService loginMethodService;

    /**
     * 获取当前用户的登录方式列表
     * GET /api/user/login-methods
     */
    @GetMapping
    public ResponseEntity<?> getLoginMethods(@AuthenticationPrincipal Jwt jwt) {
        try {
            String userId = jwt.getClaim("userId");
            
            List<UserLoginMethod> methods = loginMethodService.getUserLoginMethods(userId);
            
            // 转换为DTO
            List<Map<String, Object>> methodDtos = methods.stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
            
            return ResponseEntity.ok(Map.of(
                "loginMethods", methodDtos,
                "count", methodDtos.size()
            ));
        } catch (Exception e) {
            log.error("Failed to get login methods", e);
            return ResponseEntity.status(500).body(
                Map.of("error", "获取登录方式失败", "details", e.getMessage())
            );
        }
    }

    /**
     * 移除登录方式
     * DELETE /api/user/login-methods/{methodId}
     */
    @DeleteMapping("/{methodId}")
    public ResponseEntity<?> removeLoginMethod(
            @PathVariable String methodId,
            @AuthenticationPrincipal Jwt jwt) {
        try {
            String userId = jwt.getClaim("userId");
            
            loginMethodService.removeLoginMethod(userId, methodId);
            
            return ResponseEntity.ok(Map.of(
                "message", "登录方式已移除",
                "removedMethodId", methodId
            ));
        } catch (IllegalStateException | IllegalArgumentException e) {
            log.warn("Failed to remove login method: {}", e.getMessage());
            return ResponseEntity.status(400).body(
                Map.of("error", e.getMessage())
            );
        } catch (Exception e) {
            log.error("Failed to remove login method", e);
            return ResponseEntity.status(500).body(
                Map.of("error", "移除登录方式失败", "details", e.getMessage())
            );
        }
    }

    /**
     * 设置主登录方式
     * PUT /api/user/login-methods/{methodId}/primary
     */
    @PutMapping("/{methodId}/primary")
    public ResponseEntity<?> setPrimaryLoginMethod(
            @PathVariable String methodId,
            @AuthenticationPrincipal Jwt jwt) {
        try {
            String userId = jwt.getClaim("userId");
            
            loginMethodService.setPrimaryLoginMethod(userId, methodId);
            
            return ResponseEntity.ok(Map.of(
                "message", "主登录方式已设置",
                "primaryMethodId", methodId
            ));
        } catch (IllegalArgumentException e) {
            log.warn("Failed to set primary login method: {}", e.getMessage());
            return ResponseEntity.status(400).body(
                Map.of("error", e.getMessage())
            );
        } catch (Exception e) {
            log.error("Failed to set primary login method", e);
            return ResponseEntity.status(500).body(
                Map.of("error", "设置主登录方式失败", "details", e.getMessage())
            );
        }
    }

    /**
     * 为SSO用户添加本地登录方式
     * POST /api/user/add-local-login
     * 
     * 请求体:
     * {
     *   "username": "myusername",
     *   "password": "mypassword",
     *   "passwordConfirm": "mypassword"
     * }
     */
    @PostMapping("/add-local-login")
    public ResponseEntity<?> addLocalLoginMethod(
            @RequestBody Map<String, String> request,
            @AuthenticationPrincipal Jwt jwt) {
        try {
            String userId = jwt.getClaim("userId");
            
            String username = request.get("username");
            String password = request.get("password");
            String passwordConfirm = request.get("passwordConfirm");
            
            // 验证输入
            if (username == null || username.trim().isEmpty()) {
                return ResponseEntity.status(400).body(
                    Map.of("error", "用户名不能为空")
                );
            }
            
            if (password == null || password.trim().isEmpty()) {
                return ResponseEntity.status(400).body(
                    Map.of("error", "密码不能为空")
                );
            }
            
            if (!password.equals(passwordConfirm)) {
                return ResponseEntity.status(400).body(
                    Map.of("error", "两次输入的密码不一致")
                );
            }
            
            if (password.length() < 6) {
                return ResponseEntity.status(400).body(
                    Map.of("error", "密码长度至少6个字符")
                );
            }
            
            // 调用服务添加本地登录方式
            var loginMethod = loginMethodService.addLocalLoginMethod(userId, username, password);
            
            return ResponseEntity.ok(Map.of(
                "message", "本地登录方式添加成功",
                "loginMethod", convertToDto(loginMethod)
            ));
            
        } catch (IllegalStateException e) {
            log.warn("Failed to add local login: {}", e.getMessage());
            return ResponseEntity.status(400).body(
                Map.of("error", e.getMessage())
            );
        } catch (IllegalArgumentException e) {
            log.warn("Invalid input: {}", e.getMessage());
            return ResponseEntity.status(400).body(
                Map.of("error", e.getMessage())
            );
        } catch (Exception e) {
            log.error("Failed to add local login method", e);
            return ResponseEntity.status(500).body(
                Map.of("error", "添加本地登录方式失败", "details", e.getMessage())
            );
        }
    }

    /**
     * 转换为DTO
     */
    private Map<String, Object> convertToDto(UserLoginMethod method) {
        Map<String, Object> dto = new java.util.HashMap<>();
        dto.put("id", method.getId());
        dto.put("authProvider", method.getAuthProvider().name().toLowerCase());
        dto.put("isPrimary", method.isPrimary());
        dto.put("isVerified", method.isVerified());
        dto.put("linkedAt", method.getLinkedAt().toString());
        
        if (method.getLastUsedAt() != null) {
            dto.put("lastUsedAt", method.getLastUsedAt().toString());
        }
        
        // OAuth2特定信息
        if (method.isOAuth2Method()) {
            dto.put("providerEmail", method.getProviderEmail());
            dto.put("providerUsername", method.getProviderUsername());
        }
        
        // 本地登录特定信息
        if (method.isLocalMethod()) {
            dto.put("localUsername", method.getLocalUsername());
        }
        
        return dto;
    }
}
