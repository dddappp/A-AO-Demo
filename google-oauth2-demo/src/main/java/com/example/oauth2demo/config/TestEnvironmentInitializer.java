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
import java.util.HashSet;
import java.util.Set;

/**
 * Test环境初始化器 - PostgreSQL环境的测试设置
 * 
 * Test环境使用PostgreSQL数据库，但初始化逻辑与dev环境相似
 * 注意：SQL初始化脚本（data-postgresql.sql）会在应用启动时自动执行
 * 这个类主要用于额外的代码级初始化（如果需要的话）
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
     * 注意：SQL脚本已通过application-test.yml的spring.sql.init配置自动执行
     * 这个方法主要用于输出环境信息和验证数据库连接
     */
    private void setupTestEnvironment() {
        try {
            log.info("========================================");
            log.info("🧪 Test环境初始化开始 (PostgreSQL)");
            log.info("========================================");

            // 验证数据库连接和数据
            long userCount = userRepository.count();
            long loginMethodCount = loginMethodRepository.count();

            log.info("✅ Test环境初始化完成");
            log.info("========================================");
            log.info("");
            log.info("📊 数据库状态:");
            log.info("  用户总数: {}", userCount);
            log.info("  登录方式总数: {}", loginMethodCount);
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
}
