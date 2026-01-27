package com.example.oauth2demo.controller;

import com.example.oauth2demo.service.TokenRefreshService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * Token管理控制器
 * 处理JWT Token的刷新和其他token相关操作
 */
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
@Slf4j
@Tag(name = "Token Management", description = "JWT Token管理相关API")
public class TokenController {

    private final TokenRefreshService tokenRefreshService;

    /**
     * 刷新JWT Token
     * 使用refresh token获取新的access token和refresh token
     */
    @PostMapping("/refresh")
    @Operation(
        summary = "刷新JWT Token",
        description = "使用refresh token获取新的access token和refresh token，支持双重传递（cookie + JSON响应体）",
        tags = { "Token Management" }
    )
    @ApiResponses({
        @ApiResponse(
            responseCode = "200",
            description = "Token刷新成功",
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(
                    example = "{\"message\": \"Token refreshed successfully\", \"accessToken\": \"...\", \"refreshToken\": \"...\", \"accessTokenExpiresIn\": 3600, \"refreshTokenExpiresIn\": 604800, \"tokenType\": \"Bearer\"}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "401",
            description = "Token刷新失败",
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(
                    example = "{\"error\": \"Token refresh failed\", \"details\": \"Invalid refresh token\"}"
                )
            )
        )
    })
    public ResponseEntity<?> refreshToken(
            @Parameter(
                name = "refreshToken",
                description = "Refresh token（从cookie中获取）",
                required = true,
                in = io.swagger.v3.oas.annotations.enums.ParameterIn.COOKIE
            )
            @CookieValue(value = "refreshToken", required = false) String refreshTokenCookie,
            HttpServletResponse response) {

        try {
            log.info("Token refresh request received");

            if (refreshTokenCookie == null || refreshTokenCookie.trim().isEmpty()) {
                log.warn("No refresh token found in cookies");
                return ResponseEntity.status(401).body(
                    Map.of("error", "Refresh token not found")
                );
            }

            // 刷新token
            TokenRefreshService.TokenPair tokenPair = tokenRefreshService.refreshUserTokens(refreshTokenCookie);
            log.info("Tokens refreshed successfully");

            // 设置新的Cookies
            setTokenCookies(response, tokenPair.getAccessToken(), tokenPair.getRefreshToken());

            return ResponseEntity.ok(Map.of(
                "message", "Token refreshed successfully",
                "accessToken", tokenPair.getAccessToken(),
                "refreshToken", tokenPair.getRefreshToken(),
                "accessTokenExpiresIn", 3600,  // 1小时
                "refreshTokenExpiresIn", 604800, // 7天
                "tokenType", "Bearer"
            ));


        } catch (Exception e) {
            log.error("Token refresh failed", e);
            return ResponseEntity.status(401).body(
                Map.of("error", "Token refresh failed", "details", e.getMessage())
            );
        }
    }

    /**
     * 设置Token Cookies
     */
    private void setTokenCookies(HttpServletResponse response, String accessToken, String refreshToken) {
        // Access Token Cookie (1小时)
        Cookie accessTokenCookie = new Cookie("accessToken", accessToken);
        accessTokenCookie.setHttpOnly(true);
        accessTokenCookie.setPath("/");
        accessTokenCookie.setMaxAge(3600); // 1小时
        accessTokenCookie.setSecure(true); // 生产环境，HTTPS必须
        accessTokenCookie.setAttribute("SameSite", "Lax");
        response.addCookie(accessTokenCookie);

        // Refresh Token Cookie (7天)
        Cookie refreshTokenCookie = new Cookie("refreshToken", refreshToken);
        refreshTokenCookie.setHttpOnly(true);
        refreshTokenCookie.setPath("/");
        refreshTokenCookie.setMaxAge(604800); // 7天
        refreshTokenCookie.setSecure(true); // 生产环境，HTTPS必须
        refreshTokenCookie.setAttribute("SameSite", "Lax");
        response.addCookie(refreshTokenCookie);

        log.debug("Token cookies set successfully");
    }
}