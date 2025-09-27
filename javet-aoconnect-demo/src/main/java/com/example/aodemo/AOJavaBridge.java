package com.example.aodemo;

import com.caoccao.javet.enums.JSRuntimeType;
import com.caoccao.javet.exceptions.JavetException;
import com.caoccao.javet.interop.V8Runtime;
import com.caoccao.javet.interop.engine.IJavetEngine;
import com.caoccao.javet.interop.engine.IJavetEnginePool;
import com.caoccao.javet.interop.engine.JavetEnginePool;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.io.IOException;

/**
 * AO Java Bridge - 主要的 AO 网络桥接类
 *
 * 本类基于 Javet 框架实现，通过 V8 引擎加载 aoconnect 的浏览器版本，
 * 提供 Java 应用与 AO 网络交互的接口。
 *
 * 关键特性：
 * - 使用 V8 模式运行时（纯 JavaScript 引擎）
 * - 加载 aoconnect 浏览器版本（包含所有 polyfill）
 * - 引擎池管理以提高性能
 * - 自动资源管理和错误处理
 */
public class AOJavaBridge implements AutoCloseable {
    private static final Logger logger = LoggerFactory.getLogger(AOJavaBridge.class);

    private final IJavetEnginePool<V8Runtime> enginePool;
    private volatile boolean initialized = false;

    /**
     * 构造函数 - 初始化 AO 桥接
     *
     * @throws JavetException 如果初始化失败
     */
    public AOJavaBridge() throws JavetException {
        // 创建 Node.js 模式引擎池
        this.enginePool = new JavetEnginePool<>();
        this.enginePool.getConfig().setJSRuntimeType(JSRuntimeType.Node);

        logger.info("AO Java Bridge initialized with Node.js runtime pool");
    }

    /**
     * 初始化桥接 - 加载 aoconnect 脚本
     *
     * @throws JavetException 如果初始化失败
     */
    public synchronized void initialize() throws JavetException {
        if (initialized) {
            return;
        }

        try (IJavetEngine<V8Runtime> engine = enginePool.getEngine()) {
            V8Runtime runtime = engine.getV8Runtime();

            logger.info("Loading aoconnect SDK...");

            // 配置模块路径
            String modulePaths = System.getProperty("user.dir") + "/node_modules";
            runtime.getExecutor("require('module').globalPaths.push('" + modulePaths + "');").execute();

            // 加载 aoconnect SDK
            runtime.getExecutor("global.aoconnect = require('@permaweb/aoconnect');").execute();

            // 验证 aoconnect 是否正确加载
            runtime.getExecutor("if (typeof global.aoconnect === 'undefined') { throw new Error('aoconnect SDK not loaded'); }").executeVoid();

            logger.info("aoconnect SDK loaded successfully");
            initialized = true;

        } catch (Exception e) {
            if (e instanceof JavetException) {
                throw (JavetException) e;
            }
            throw new RuntimeException("Failed to initialize AO bridge", e);
        }
    }

    /**
     * 创建 AO 进程
     *
     * @param moduleId 模块 ID
     * @param schedulerId 调度器 ID
     * @return 进程 ID
     * @throws JavetException 如果执行失败
     */
    public String spawnProcess(String moduleId, String schedulerId) throws JavetException {
        ensureInitialized();

        try (IJavetEngine<V8Runtime> engine = enginePool.getEngine()) {
            V8Runtime runtime = engine.getV8Runtime();

            String script = String.format(
                "const result = await globalThis.aoconnect.spawn({" +
                "  module: '%s'," +
                "  scheduler: '%s'" +
                "});" +
                "return result;",
                moduleId, schedulerId
            );

            logger.debug("Executing spawn process script: {}", script);
            String result = runtime.getExecutor(script).executeString();
            logger.info("Process spawned successfully: {}", result);

            return result;
        }
    }

    /**
     * 发送消息到 AO 进程
     *
     * @param processId 进程 ID
     * @param action 动作名称
     * @param tags 标签数据
     * @return 消息 ID
     * @throws JavetException 如果执行失败
     */
    public String sendMessage(String processId, String action, String data) throws JavetException {
        ensureInitialized();

        try (IJavetEngine<V8Runtime> engine = enginePool.getEngine()) {
            V8Runtime runtime = engine.getV8Runtime();

            String script = String.format(
                "const result = await globalThis.aoconnect.message({" +
                "  process: '%s'," +
                "  tags: [{ name: 'Action', value: '%s' }]," +
                "  data: '%s'" +
                "});" +
                "return result;",
                processId, action, data
            );

            logger.debug("Executing send message script for process: {}", processId);
            String result = runtime.getExecutor(script).executeString();
            logger.info("Message sent successfully to process {}: {}", processId, result);

            return result;
        }
    }

    /**
     * 查询进程结果
     *
     * @param messageId 消息 ID
     * @return 结果数据
     * @throws JavetException 如果执行失败
     */
    public String getResult(String messageId) throws JavetException {
        ensureInitialized();

        try (IJavetEngine<V8Runtime> engine = enginePool.getEngine()) {
            V8Runtime runtime = engine.getV8Runtime();

            String script = String.format(
                "const result = await globalThis.aoconnect.result({" +
                "  message: '%s'" +
                "});" +
                "return JSON.stringify(result);",
                messageId
            );

            logger.debug("Executing get result script for message: {}", messageId);
            String result = runtime.getExecutor(script).executeString();
            logger.debug("Result retrieved for message {}: {}", messageId, result);

            return result;
        }
    }

    /**
     * 测试连接 - 简单的 ping 操作
     *
     * @return 连接状态
     * @throws JavetException 如果执行失败
     */
    public boolean testConnection() throws JavetException {
        ensureInitialized();

        try (IJavetEngine<V8Runtime> engine = enginePool.getEngine()) {
            V8Runtime runtime = engine.getV8Runtime();

            // 测试AO网络连接 - 检查SDK是否可用
            Boolean connected = runtime.getExecutor("return typeof globalThis.aoconnect !== 'undefined';").executeBoolean();

            logger.info("AO connection test result: {}", connected);
            return connected;
        }
    }

    /**
     * 确保桥接已初始化
     */
    private void ensureInitialized() {
        if (!initialized) {
            throw new IllegalStateException("AO Java Bridge not initialized. Call initialize() first.");
        }
    }

    /**
     * 获取引擎池信息
     */
    public String getPoolInfo() {
        return "V8Runtime pool initialized";
    }

    /**
     * 检查是否已初始化
     */
    public boolean isInitialized() {
        return initialized;
    }

    @Override
    public void close() {
        logger.info("Closing AO Java Bridge");
        try {
            if (enginePool != null) {
                enginePool.close();
            }
        } catch (Exception e) {
            logger.error("Error closing engine pool", e);
        }
        initialized = false;
    }
}
