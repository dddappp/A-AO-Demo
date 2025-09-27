package com.example.aodemo;

import com.caoccao.javet.exceptions.JavetException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * AO Demo 应用程序 - 展示 Javet 和 aoconnect 集成的演示应用
 *
 * 本应用演示了如何：
 * 1. 初始化 AO Java Bridge
 * 2. 连接到 AO 网络
 * 3. 创建 AO 进程
 * 4. 发送消息并获取结果
 *
 * 运行方式：
 * - 使用 Maven: mvn compile exec:java
 * - 使用 IDE: 直接运行 main 方法
 *
 * 注意：需要确保 AO 网络配置正确，特别是 scheduler ID
 */
public class AODemoApplication {
    private static final Logger logger = LoggerFactory.getLogger(AODemoApplication.class);

    // AO 网络配置 - 这些应该从配置文件中读取
    private static final String MODULE_ID = "S9ydoEDkzP_bSFI-Lm-vzBcBK4hZxPqVrtMNyO6zq-W4"; // 示例模块ID
    private static final String SCHEDULER_ID = "GNcuO-pnva8hcIAn2rGTp0sNqGx-v9V8GqVh_K8JFhSc"; // 示例调度器ID

    public static void main(String[] args) {
        logger.info("Starting AO Demo Application...");

        // 设置Javet系统属性以帮助原生库加载
        System.setProperty("javet.logger.level", "INFO");

        try (AOJavaBridge bridge = new AOJavaBridge()) {
            // 初始化桥接
            logger.info("Initializing AO Java Bridge...");
            bridge.initialize();

            logger.info("✅ AO Java Bridge initialized successfully!");

            // 测试连接
            logger.info("Testing AO network connection...");
            try {
                boolean connected = bridge.testConnection();
                logger.info("Connection test result: {}", connected);
            } catch (Exception e) {
                logger.error("Connection test failed: {}", e.getMessage());
                logger.info("This is expected if AO network is not configured");
            }

            // 显示桥接信息
            logger.info("Bridge info: {}", bridge.getPoolInfo());
            logger.info("Bridge initialized: {}", bridge.isInitialized());

        } catch (JavetException e) {
            logger.error("Javet exception occurred", e);
        } catch (Exception e) {
            logger.error("Unexpected error occurred", e);
        }

        logger.info("AO Demo Application completed");
    }

    /**
     * 演示 AO 网络的各种功能
     */
    private static void demonstrateAOCapabilities(AOJavaBridge bridge) {
        try {
            logger.info("=== AO Network Capabilities Demo ===");

            // 1. 创建 AO 进程
            logger.info("1. Creating AO process...");
            String processId = bridge.spawnProcess(MODULE_ID, SCHEDULER_ID);
            logger.info("✅ Process created: {}", processId);

            // 2. 发送消息
            logger.info("2. Sending message to process...");
            String messageData = "Hello from Java via Javet!";
            String messageId = bridge.sendMessage(processId, "Echo", messageData);
            logger.info("✅ Message sent: {}", messageId);

            // 3. 获取结果
            logger.info("3. Retrieving result...");
            String result = bridge.getResult(messageId);
            logger.info("✅ Result received: {}", result);

            // 4. 显示引擎池信息
            logger.info("4. Engine pool info:");
            logger.info("   - Pool info: {}", bridge.getPoolInfo());
            logger.info("   - Initialized: {}", bridge.isInitialized());

            logger.info("=== Demo completed successfully ===");

        } catch (JavetException e) {
            logger.error("Error during AO capabilities demonstration", e);
        }
    }
}
