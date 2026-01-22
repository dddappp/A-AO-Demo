package com.example.oauth2demo.config;

import com.example.oauth2demo.entity.UserEntity;
import com.example.oauth2demo.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * 开发环境初始化器
 * 在应用启动时自动设置测试用户
 */
@Component
@Profile("dev")
@RequiredArgsConstructor
@Slf4j
public class DevEnvironmentInitializer implements CommandLineRunner {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) throws Exception {
        setupTestUser();
    }

    /**
     * 设置测试用户
     * 确保开发环境下有可用的测试账号
     */
    private void setupTestUser() {
        String testUsername = "frontenduser";
        String testEmail = "frontend@example.com";
        String testPassword = "password123";

        try {
            var existingUser = userRepository.findByUsername(testUsername);

            if (existingUser.isPresent()) {
                // 重置现有用户的密码
                var user = existingUser.get();
                user.setPasswordHash(passwordEncoder.encode(testPassword));
                userRepository.save(user);
                log.info("✅ 开发环境：重置测试用户密码 - {}", testUsername);
            } else {
                // 创建新的测试用户
                var testUser = UserEntity.builder()
                    .username(testUsername)
                    .email(testEmail)
                    .passwordHash(passwordEncoder.encode(testPassword))
                    .displayName("Frontend User")
                    .authProvider(UserEntity.AuthProvider.LOCAL)
                    .enabled(true)
                    .emailVerified(true)
                    .build();

                userRepository.save(testUser);
                log.info("✅ 开发环境：创建测试用户 - {}", testUsername);
            }

            log.info("🔐 开发环境测试账号：{} / {}", testUsername, testPassword);
            log.info("📡 密码重置端点：POST /api/auth/reset-password (仅dev环境)");

        } catch (Exception e) {
            log.error("❌ 开发环境初始化失败", e);
        }
    }
}