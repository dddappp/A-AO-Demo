package com.example.oauth2demo.config;

import com.example.oauth2demo.entity.UserEntity;
import com.example.oauth2demo.entity.UserLoginMethod;
import com.example.oauth2demo.repository.UserRepository;
import com.example.oauth2demo.repository.UserLoginMethodRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import java.time.LocalDateTime;
import java.util.UUID;
import java.util.HashSet;
import java.util.Set;

/**
 * Test环境初始化器 - PostgreSQL环境的测试设置
 * 
 * Test环境使用PostgreSQL数据库，初始化逻辑与dev环境相同
 * 在每次应用启动时创建三个预定义的测试账户
 * 
 * 这样可以快速进行各种测试场景：
 * - 本地登录 → 绑定SSO
 * - SSO登录 → 绑定本地密码
 * - 多方式登录验证
 */
@Component
@Profile("test")
@RequiredArgsConstructor
@Slf4j
public class TestEnvironmentInitializer implements CommandLineRunner {

    private final UserRepository userRepository;
    private final UserLoginMethodRepository loginMethodRepository;
    private final PasswordEncoder passwordEncoder;

    private static final String PASSWORD = "password123";

    @Override
    public void run(String... args) throws Exception {
        setupTestEnvironment();
    }

    /**
     * Test环境设置
     * 
     * 与Dev环境类似，创建三个测试账户，确保密码哈希正确匹配
     */
    private void setupTestEnvironment() {
        try {
            log.info("========================================");
            log.info("🧪 Test环境初始化开始 (PostgreSQL)");
            log.info("========================================");

            // 1. 清空数据库（确保干净的测试环境）
            clearDatabase();

            // 2. 创建测试账户
            createTestAccounts();

            log.info("✅ Test环境初始化完成");
            log.info("========================================");
            log.info("");
            log.info("📋 可用的测试账户：");
            log.info("");
            log.info("  场景1: 本地登录 → 绑定SSO");
            log.info("    用户名: testlocal");
            log.info("    密码: " + PASSWORD);
            log.info("    状态: 仅有本地登录方式，无SSO绑定");
            log.info("");
            log.info("  场景2: SSO登录 → 绑定本地密码");
            log.info("    用户名: testsso");
            log.info("    模拟: 已通过Google登录");
            log.info("    状态: 仅有Google登录方式，无本地密码");
            log.info("");
            log.info("  场景3: 多方式登录");
            log.info("    用户名: testboth");
            log.info("    密码: " + PASSWORD);
            log.info("    Google: 已绑定");
            log.info("    状态: 同时有本地密码和Google登录方式");
            log.info("");
            log.info("🔐 数据库: PostgreSQL (localhost:5432)");
            log.info("💾 数据库名: google_oauth2_demo");
            log.info("");

        } catch (Exception e) {
            log.error("❌ Test环境初始化失败", e);
            throw new RuntimeException("Failed to initialize test environment", e);
        }
    }

    /**
     * 清空数据库中的所有用户和登录方式
     */
    private void clearDatabase() {
        log.info("清空数据库...");
        loginMethodRepository.deleteAll();
        userRepository.deleteAll();
        log.info("✅ 数据库已清空");
    }

    /**
     * 创建测试账户
     */
    private void createTestAccounts() {
        log.info("创建测试账户...");

        // 账户1: testlocal - 仅本地登录（用于测试本地 → SSO绑定）
        createLocalOnlyUser(
            "testlocal",
            "testlocal@example.com",
            "Test Local User"
        );

        // 账户2: testsso - 仅SSO登录（用于测试SSO → 本地绑定）
        createSSOOnlyUser(
            "testsso",
            "testsso@example.com",
            "Test SSO User"
        );

        // 账户3: testboth - 本地和SSO都有（用于测试多方式登录）
        createMixedUser(
            "testboth",
            "testboth@example.com",
            "Test Both User"
        );

        log.info("✅ 测试账户创建完成");
    }

    /**
     * 创建仅有本地登录方式的用户
     */
    private void createLocalOnlyUser(String username, String email, String displayName) {
        UserEntity user = new UserEntity();
        user.setId(UUID.randomUUID().toString());  // 生成 UUID
        user.setUsername(username);
        user.setEmail(email);
        user.setDisplayName(displayName);
        Set<String> authorities = new HashSet<>();
        authorities.add("ROLE_USER");
        user.setAuthorities(authorities);
        user.setEnabled(true);
        user.setEmailVerified(true);

        userRepository.save(user);

        // 创建本地登录方式
        UserLoginMethod loginMethod = UserLoginMethod.builder()
            .id(UUID.randomUUID().toString())  // 生成 UUID
            .user(user)
            .authProvider(UserLoginMethod.AuthProvider.LOCAL)
            .localUsername(username)
            .localPasswordHash(passwordEncoder.encode(PASSWORD))
            .isPrimary(true)
            .isVerified(true)
            .build();

        user.addLoginMethod(loginMethod);
        userRepository.save(user);

        log.info("  ✅ 创建用户: {} (仅本地登录)", username);
    }

    /**
     * 创建仅有SSO登录方式的用户
     */
    private void createSSOOnlyUser(String username, String email, String displayName) {
        UserEntity user = new UserEntity();
        user.setId(UUID.randomUUID().toString());  // 生成 UUID
        user.setUsername(email); // SSO用户使用邮箱作为用户名
        user.setEmail(email);
        user.setDisplayName(displayName);
        Set<String> authorities = new HashSet<>();
        authorities.add("ROLE_USER");
        user.setAuthorities(authorities);
        user.setEnabled(true);
        user.setEmailVerified(true);

        userRepository.save(user);

        // 创建Google登录方式（模拟Google OAuth2登录）
        UserLoginMethod googleMethod = UserLoginMethod.builder()
            .id(UUID.randomUUID().toString())  // 生成 UUID
            .user(user)
            .authProvider(UserLoginMethod.AuthProvider.GOOGLE)
            .providerUserId("mock_google_" + username)
            .providerEmail(email)
            .providerUsername(displayName)
            .isPrimary(true)
            .isVerified(true)
            .linkedAt(LocalDateTime.now())
            .build();

        user.addLoginMethod(googleMethod);
        userRepository.save(user);

        log.info("  ✅ 创建用户: {} (仅SSO登录 - Google)", username);
    }

    /**
     * 创建既有本地登录又有SSO登录的用户
     */
    private void createMixedUser(String username, String email, String displayName) {
        UserEntity user = new UserEntity();
        user.setId(UUID.randomUUID().toString());  // 生成 UUID
        user.setUsername(username);
        user.setEmail(email);
        user.setDisplayName(displayName);
        Set<String> authorities = new HashSet<>();
        authorities.add("ROLE_USER");
        user.setAuthorities(authorities);
        user.setEnabled(true);
        user.setEmailVerified(true);

        userRepository.save(user);

        // 1. 创建本地登录方式（主登录方式）
        UserLoginMethod localMethod = UserLoginMethod.builder()
            .id(UUID.randomUUID().toString())  // 生成 UUID
            .user(user)
            .authProvider(UserLoginMethod.AuthProvider.LOCAL)
            .localUsername(username)
            .localPasswordHash(passwordEncoder.encode(PASSWORD))
            .isPrimary(true)
            .isVerified(true)
            .build();

        user.addLoginMethod(localMethod);

        // 2. 创建Google登录方式
        UserLoginMethod googleMethod = UserLoginMethod.builder()
            .id(UUID.randomUUID().toString())  // 生成 UUID
            .user(user)
            .authProvider(UserLoginMethod.AuthProvider.GOOGLE)
            .providerUserId("mock_google_" + username)
            .providerEmail(email)
            .providerUsername(displayName)
            .isPrimary(false)
            .isVerified(true)
            .linkedAt(LocalDateTime.now())
            .build();

        user.addLoginMethod(googleMethod);
        userRepository.save(user);

        log.info("  ✅ 创建用户: {} (本地 + Google登录)", username);
    }
}
