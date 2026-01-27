package com.example.oauth2demo.service;

import com.example.oauth2demo.entity.UserEntity;
import com.example.oauth2demo.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * JWT Token刷新服务
 * 处理refresh token验证和新的access token生成
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class TokenRefreshService {

    private final UserRepository userRepository;
    private final JwtTokenService jwtTokenService;

    /**
     * 刷新用户的JWT Token
     *
     * @param refreshTokenValue refresh token字符串
     * @return 新的TokenPair
     */
    public TokenPair refreshUserTokens(String refreshTokenValue) {
        try {
            // 1. 验证refresh token
            if (!jwtTokenService.validateRefreshToken(refreshTokenValue)) {
                throw new RuntimeException("无效的refresh token");
            }

            // 2. 从refresh token中提取用户信息
            String username = jwtTokenService.extractUsername(refreshTokenValue);
            String userId = jwtTokenService.getUserIdFromToken(refreshTokenValue);

            // 3. 验证提取的信息不为空
            if (userId == null || userId.trim().isEmpty()) {
                throw new RuntimeException("无法从token中提取用户ID");
            }
            if (username == null || username.trim().isEmpty()) {
                throw new RuntimeException("无法从token中提取用户名");
            }

            // 4. 验证用户存在
            UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("用户不存在"));

            // 5. 验证用户名匹配
            if (user.getUsername() == null || !username.equals(user.getUsername())) {
                throw new RuntimeException("Token用户名不匹配");
            }

            // 6. 生成新的Token对
            String newAccessToken = jwtTokenService.generateAccessToken(
                user.getUsername(), user.getEmail(), user.getId(), user.getAuthorities()
            );
            String newRefreshToken = jwtTokenService.generateRefreshToken(
                user.getUsername(), user.getId()
            );

            log.info("成功刷新token for user: {}", username);
            return new TokenPair(newAccessToken, newRefreshToken);

        } catch (Exception e) {
            log.error("Token refresh failed: {}", e.getMessage());
            throw new RuntimeException("Token刷新失败: " + e.getMessage(), e);
        }
    }

    /**
     * Token对数据传输对象
     */
    public static class TokenPair {
        private final String accessToken;
        private final String refreshToken;

        public TokenPair(String accessToken, String refreshToken) {
            this.accessToken = accessToken;
            this.refreshToken = refreshToken;
        }

        public String getAccessToken() {
            return accessToken;
        }

        public String getRefreshToken() {
            return refreshToken;
        }
    }
}