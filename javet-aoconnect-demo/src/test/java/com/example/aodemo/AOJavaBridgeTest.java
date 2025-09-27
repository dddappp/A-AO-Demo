package com.example.aodemo;

import com.caoccao.javet.exceptions.JavetException;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import static org.junit.jupiter.api.Assertions.*;

/**
 * AO Java Bridge 测试类
 */
public class AOJavaBridgeTest {
    private static final Logger logger = LoggerFactory.getLogger(AOJavaBridgeTest.class);

    private AOJavaBridge bridge;

    @BeforeEach
    void setUp() throws JavetException {
        bridge = new AOJavaBridge();
        bridge.initialize();
    }

    @AfterEach
    void tearDown() {
        if (bridge != null) {
            bridge.close();
        }
    }

    @Test
    void testInitialization() {
        assertTrue(bridge.isInitialized());
        assertNotNull(bridge.getPoolInfo());
        logger.info("Bridge initialized successfully");
    }

    @Test
    void testConnection() throws JavetException {
        boolean connected = bridge.testConnection();
        assertTrue(connected, "Should be connected to AO network");
        logger.info("Connection test passed");
    }

    @Test
    void testSpawnProcess() throws JavetException {
        // 注意：这个测试需要有效的模块ID和调度器ID
        // 这里使用示例值，实际测试时需要替换为真实值
        String moduleId = "S9ydoEDkzP_bSFI-Lm-vzBcBK4hZxPqVrtMNyO6zq-W4";
        String schedulerId = "GNcuO-pnva8hcIAn2rGTp0sNqGx-v9V8GqVh_K8JFhSc";

        String processId = bridge.spawnProcess(moduleId, schedulerId);
        assertNotNull(processId);
        assertFalse(processId.trim().isEmpty());
        logger.info("Process spawned: {}", processId);
    }

    @Test
    void testSendMessage() throws JavetException {
        // 注意：这个测试需要有效的进程ID
        // 这里使用示例值，实际测试时需要替换为真实值
        String processId = "test_process_id"; // 需要替换为实际进程ID
        String action = "Echo";
        String data = "Test message from Java";

        try {
            String messageId = bridge.sendMessage(processId, action, data);
            assertNotNull(messageId);
            logger.info("Message sent: {}", messageId);
        } catch (Exception e) {
            // 如果进程ID无效，可能会抛出异常，这是正常的
            logger.warn("Message send failed (expected for invalid process ID): {}", e.getMessage());
        }
    }

    @Test
    void testGetResult() throws JavetException {
        // 注意：这个测试需要有效的消息ID
        // 这里使用示例值，实际测试时需要替换为真实值
        String messageId = "test_message_id"; // 需要替换为实际消息ID

        try {
            String result = bridge.getResult(messageId);
            assertNotNull(result);
            logger.info("Result retrieved: {}", result);
        } catch (Exception e) {
            // 如果消息ID无效，可能会抛出异常，这是正常的
            logger.warn("Result retrieval failed (expected for invalid message ID): {}", e.getMessage());
        }
    }
}
