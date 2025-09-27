package com.example.javetaodemo;

import com.caoccao.javet.enums.JSRuntimeType;
import com.caoccao.javet.exceptions.JavetException;
import com.caoccao.javet.interop.V8Host;
import com.caoccao.javet.interop.V8Runtime;
import com.caoccao.javet.interop.engine.IJavetEngine;
import com.caoccao.javet.interop.engine.IJavetEnginePool;
import com.caoccao.javet.interop.engine.JavetEnginePool;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;

/**
 * Javet + aoconnect 集成演示
 *
 * 本演示展示了如何在Javet中集成aoconnect SDK来与AO网络交互
 *
 * 演示功能：
 * 1. V8模式 + 浏览器版本aoconnect（推荐）
 * 2. Node.js模式 + ESM版本aoconnect
 * 3. 引擎池管理
 * 4. 外部JavaScript文件加载
 * 5. 错误处理和资源管理
 */
public class JavetAOConnectDemo {
    private static final Logger logger = LoggerFactory.getLogger(JavetAOConnectDemo.class);

    public static void main(String[] args) {
        logger.info("🚀 开始Javet + aoconnect集成演示");

        try {
            // 演示1: V8模式 + 浏览器版本（推荐方案）
            demonstrateV8ModeWithBrowserBundle();

            // 演示2: Node.js模式 + ESM版本
            demonstrateNodeModeWithESM();

            // 演示3: 引擎池管理
            demonstrateEnginePool();

        } catch (Exception e) {
            logger.error("❌ 演示执行失败", e);
        }

        logger.info("✅ 演示完成");
    }

    /**
     * 演示1: V8模式 + 浏览器版本aoconnect（推荐）
     */
    private static void demonstrateV8ModeWithBrowserBundle() {
        logger.info("🎯 演示1: V8模式 + 浏览器版本aoconnect");

        try (IJavetEnginePool<V8Runtime> enginePool = new JavetEnginePool<>()) {
            enginePool.getConfig().setJSRuntimeType(JSRuntimeType.V8);

            try (IJavetEngine<V8Runtime> engine = enginePool.getEngine()) {
                V8Runtime runtime = engine.getV8Runtime();

                // 加载浏览器版本aoconnect（包含所有polyfill）
                String browserBundlePath = "src/main/resources/js/aoconnect.browser.js";
                File browserBundle = new File(browserBundlePath);

                if (browserBundle.exists()) {
                    logger.info("📦 加载浏览器版本aoconnect: {}", browserBundle.getAbsolutePath());
                    runtime.getExecutor(browserBundle).executeVoid();

                    // 测试基本功能
                    String result = runtime.getExecutor(
                        "const { spawn } = globalThis.aoconnect;" +
                        "return 'aoconnect加载成功，spawn函数可用: ' + typeof spawn;"
                    ).executeString();

                    logger.info("✅ {}", result);
                } else {
                    logger.warn("⚠️ 浏览器版本文件不存在: {}", browserBundle.getAbsolutePath());
                    logger.info("💡 请运行预处理脚本来准备aoconnect文件");
                }
            }
        } catch (JavetException e) {
            logger.error("❌ V8模式演示失败", e);
        }
    }

    /**
     * 演示2: Node.js模式 + ESM版本aoconnect
     */
    private static void demonstrateNodeModeWithESM() {
        logger.info("🎯 演示2: Node.js模式 + ESM版本aoconnect");

        try (IJavetEnginePool<V8Runtime> enginePool = new JavetEnginePool<>()) {
            enginePool.getConfig().setJSRuntimeType(JSRuntimeType.Node);

            try (IJavetEngine<V8Runtime> engine = enginePool.getEngine()) {
                V8Runtime runtime = engine.getV8Runtime();

                // 配置模块路径
                String projectRoot = System.getProperty("user.dir");
                String nodeModulesPath = projectRoot + "/node_modules";
                runtime.getExecutor(
                    "require('module').globalPaths.push('" + nodeModulesPath + "');"
                ).execute();

                // 加载ESM版本aoconnect
                runtime.getExecutor(
                    "global.aoconnect = require('@permaweb/aoconnect');"
                ).execute();

                // 测试基本功能
                String result = runtime.getExecutor(
                    "return 'aoconnect加载成功，版本: ' + (global.aoconnect ? '可用' : '不可用');"
                ).executeString();

                logger.info("✅ {}", result);
            }
        } catch (JavetException e) {
            logger.error("❌ Node.js模式演示失败", e);
        }
    }

    /**
     * 演示3: 引擎池管理
     */
    private static void demonstrateEnginePool() {
        logger.info("🎯 演示3: 引擎池管理");

        try (IJavetEnginePool<V8Runtime> enginePool = new JavetEnginePool<>()) {
            enginePool.getConfig().setJSRuntimeType(JSRuntimeType.V8);
            // 引擎池配置 (通过环境变量或配置文件)
            logger.info("🏊 引擎池创建成功");

            // 并发执行多个任务
            for (int i = 0; i < 5; i++) {
                final int taskId = i;
                new Thread(() -> {
                    try (IJavetEngine<V8Runtime> engine = enginePool.getEngine()) {
                        V8Runtime runtime = engine.getV8Runtime();
                        String result = runtime.getExecutor(
                            "return '任务" + taskId + "执行完成';"
                        ).executeString();
                        logger.info("✅ {}", result);
                    } catch (JavetException e) {
                        logger.error("❌ 任务{}执行失败", taskId, e);
                    }
                }).start();
            }

            // 等待所有任务完成
            Thread.sleep(2000);

        } catch (Exception e) {
            logger.error("❌ 引擎池演示失败", e);
        }
    }
}
