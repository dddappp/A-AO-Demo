package com.example.aodemo;

import com.caoccao.javet.exceptions.JavetException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * 入口应用：在 Java 中跑通 "spawn -> message" 的真实 Legacy AO 流程。
 */
public class AODemoApplication {
    private static final Logger logger = LoggerFactory.getLogger(AODemoApplication.class);

    public static void main(String[] args) {
        logger.info("Starting AO Demo Application...");

        // 设置Javet系统属性以帮助原生库加载
        System.setProperty("javet.logger.level", "INFO");

        try (AOJavaBridge bridge = new AOJavaBridge()) {
            logger.info("Initializing AO Java Bridge...");
            bridge.initialize();

            logger.info("✅ AO Java Bridge initialized successfully!");

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

            // 运行真实AO网络演示
            demonstrateRealAONetwork(bridge);

        } catch (JavetException e) {
            logger.error("Javet exception occurred", e);
        } catch (Exception e) {
            logger.error("Unexpected error occurred", e);
        }

        logger.info("AO Demo Application completed");
    }

    /**
     * 演示真实 AO 网络交互
     */
    private static void demonstrateRealAONetwork(AOJavaBridge bridge) {
        try {
            logger.info("=== Real AO Network Interaction Demo ===");
            logger.info("🚀 Demonstrating actual AO network operations...");

            // 显示钱包信息
            logger.info("\n💰 Wallet Information:");
            logger.info("   Wallet Path: {}", bridge.getWalletPath());
            logger.info("   Network: AO Legacy (arweave.net)");
            logger.info("   Status: Wallet initialized and ready for signing");

            // 显示网络配置
            logger.info("\n🌐 AO Network Configuration:");
            logger.info("   Gateway: {}", bridge.getGatewayUrl());
            logger.info("   AO URL: {}", bridge.getAoUrl());
            logger.info("   MU URL: {}", bridge.getMuUrl());
            logger.info("   CU URL: {}", bridge.getCuUrl());
            logger.info("   Scheduler: {}", bridge.getSchedulerId());
            logger.info("   Module: {}", bridge.getModuleId());

            // 尝试创建真实AO进程
            logger.info("\n⚙️ Phase 1: Real AO Process Creation");
            logger.info("   Attempting to create AO process with wallet signing...");

            try {
                String processId = bridge.spawnProcess();
                logger.info("✅ Real AO Process created: {}", processId);

                logger.info("\n📤 Phase 2: Real Message Sending");
                String messageData = "Hello from Java + Javet + aoconnect + Real AO Network!";
                String messageId = bridge.sendMessage(processId, "Echo", messageData);
                logger.info("✅ Real message sent: {}", messageId);

                logger.info("\n🎉 AO Network Demo Completed Successfully!");
                logger.info("   • Process ID: {}", processId);
                logger.info("   • Message ID: {}", messageId);
            } catch (Exception e) {
                logger.error("❌ Real AO network operation failed: {}", e.getMessage());
                logger.info("💡 Network connection failed - stopping demonstration as requested");
            }

        } catch (Exception e) {
            logger.error("Real AO network demonstration failed", e);
        }
    }
}
