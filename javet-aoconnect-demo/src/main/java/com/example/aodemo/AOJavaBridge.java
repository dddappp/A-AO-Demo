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
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Properties;

/**
 * AO Java Bridge
 *
 * 将成功的纯 Node.js `aoconnect` 流程迁移到 Javet，直接在 Java 中调用 Node 运行时完成真实的
 * Legacy 网络 `spawn -> message` 操作。
 */
public class AOJavaBridge implements AutoCloseable {
    private static final Logger logger = LoggerFactory.getLogger(AOJavaBridge.class);

    private static final long ASYNC_TIMEOUT_MS = 60_000;

    private final IJavetEnginePool<V8Runtime> enginePool;
    private volatile boolean initialized = false;

    // AO 网络配置
    private String gatewayUrl;
    private String muUrl;
    private String cuUrl;
    private String aoUrl;
    private String schedulerId;
    private String moduleId;

    // 钱包管理
    private String walletPath;
    private String walletJson;

    /**
     * 构造函数 - 初始化 Node.js 运行时的 Javet 引擎池，并加载网络配置与 AOS 钱包。
     */
    public AOJavaBridge() throws JavetException {
        // 与纯 JS 测试保持完全一致的代理设置
        System.setProperty("HTTPS_PROXY", "http://127.0.0.1:1235");
        System.setProperty("HTTP_PROXY", "http://127.0.0.1:1235");
        System.setProperty("ALL_PROXY", "http://127.0.0.1:1235");
        System.setProperty("NODE_TLS_REJECT_UNAUTHORIZED", "0");

        this.enginePool = new JavetEnginePool<>();
        this.enginePool.getConfig().setJSRuntimeType(JSRuntimeType.Node);

        loadConfiguration();
        initializeWallet();

        logger.info("AO Java Bridge initialized with Node.js runtime pool");
        logger.info("AO Network Config - Gateway: {}, MU: {}, CU: {}, Scheduler: {}",
                   gatewayUrl, muUrl, cuUrl, schedulerId);
        logger.info("Wallet Path: {}", walletPath);
    }

    /**
     * 加载 AO 网络配置
     */
    private void loadConfiguration() {
        Properties props = new Properties();

        try (InputStream input = getClass().getClassLoader().getResourceAsStream("application.properties")) {
            if (input != null) {
                props.load(input);

                // 加载 AO 网络配置
                this.gatewayUrl = props.getProperty("ao.gateway.url", "https://arweave.net");
                this.muUrl = props.getProperty("ao.mu.url", "https://mu.ao-testnet.xyz");
                this.cuUrl = props.getProperty("ao.cu.url", "https://cu.ao-testnet.xyz");
                this.aoUrl = props.getProperty("ao.url", "https://forward.computer");
                this.schedulerId = props.getProperty("ao.scheduler.id", "_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA");
                this.moduleId = props.getProperty("ao.module.id", "ISShJH1ij-hPPt9St5UFFr_8Ys3Kj5cyg7zrMGt7H9s");

                logger.debug("Loaded AO network configuration successfully");
            } else {
                logger.warn("application.properties not found, using default configuration");
                // 使用默认配置
                this.gatewayUrl = "https://arweave.net";
                this.muUrl = "https://mu.ao-testnet.xyz";
                this.cuUrl = "https://cu.ao-testnet.xyz";
                this.aoUrl = "https://forward.computer";
                this.schedulerId = "_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA";
                this.moduleId = "ISShJH1ij-hPPt9St5UFFr_8Ys3Kj5cyg7zrMGt7H9s";
            }
        } catch (IOException e) {
            logger.error("Failed to load configuration", e);
            // 使用默认配置
            this.gatewayUrl = "https://arweave.net";
            this.muUrl = "https://mu.ao-testnet.xyz";
            this.cuUrl = "https://cu.ao-testnet.xyz";
            this.aoUrl = "https://forward.computer";
            this.schedulerId = "_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA";
            this.moduleId = "ISShJH1ij-hPPt9St5UFFr_8Ys3Kj5cyg7zrMGt7H9s";
        }
    }

    /**
     * 初始化钱包 - 检查是否存在钱包文件，如果不存在则创建
     */
    private void initializeWallet() {
        String userHome = System.getProperty("user.home");
        this.walletPath = userHome + "/.aos.json";
        Path walletFile = Paths.get(walletPath);
        if (!Files.exists(walletFile)) {
            throw new RuntimeException("Wallet not found. Please run AOS CLI once to create ~/.aos.json");
        }
        try {
            walletJson = Files.readString(walletFile);
            logger.info("✅ Wallet loaded from {}", walletPath);
        } catch (IOException e) {
            throw new RuntimeException("Failed to read wallet file", e);
        }
    }

    /**
     * 初始化桥接：配置 Node 运行时环境、加载 `@permaweb/aoconnect`，并完全复刻 AOS CLI 的 Legacy 流程。
     */
    public synchronized void initialize() throws JavetException {
        if (initialized) {
            return;
        }

        try (IJavetEngine<V8Runtime> engine = enginePool.getEngine()) {
            V8Runtime runtime = engine.getV8Runtime();

            logger.info("Node runtime info: version={}, napi={}",
                    runtime.getExecutor("process.version").executeString(),
                    runtime.getExecutor("process.versions.napi").executeString());

            logger.info("=== AO Legacy Network Connection (AOS Style) ===");
            logger.info("Connecting to AO Legacy network using AOS configuration...");

            String httpsProxy = System.getenv("HTTPS_PROXY");
            if (httpsProxy == null || httpsProxy.isEmpty()) {
                httpsProxy = System.getProperty("HTTPS_PROXY", "http://127.0.0.1:1235");
            }
            String httpProxy = System.getenv("HTTP_PROXY");
            if (httpProxy == null || httpProxy.isEmpty()) {
                httpProxy = System.getProperty("HTTP_PROXY", "http://127.0.0.1:1235");
            }
            String allProxy = System.getenv("ALL_PROXY");
            if (allProxy == null || allProxy.isEmpty()) {
                allProxy = System.getProperty("ALL_PROXY", httpProxy);
            }

            String envScript = String.format(
                "process.env.HTTPS_PROXY = `%s`;\n" +
                "process.env.HTTP_PROXY = `%s`;\n" +
                "process.env.ALL_PROXY = `%s`;\n" +
                "process.env.GATEWAY_URL = `%s`;\n" +
                "process.env.CU_URL = `%s`;\n" +
                "process.env.MU_URL = `%s`;\n" +
                "process.env.SCHEDULER = `%s`;\n" +
                "process.env.AO_URL = `%s`;\n" +
                "process.env.ARWEAVE_GRAPHQL = 'https://arweave.net/graphql';\n" +
                "process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';\n" +
                "const { ProxyAgent } = require('undici');\n" +
                "const proxyUrl = process.env.HTTPS_PROXY || process.env.HTTP_PROXY || process.env.ALL_PROXY;\n" +
                "const proxyAgent = proxyUrl ? new ProxyAgent(proxyUrl) : null;\n" +
                "const originalFetch = globalThis.fetch;\n" +
                "globalThis.fetch = function(url, options = {}) {\n" +
                "  const finalOptions = { ...options };\n" +
                "  if (proxyAgent && typeof url === 'string' && url.startsWith('http')) {\n" +
                "    finalOptions.dispatcher = proxyAgent;\n" +
                "  }\n" +
                "  console.log('🌐 FETCH via ProxyAgent:', url);\n" +
                "  return originalFetch(url, finalOptions)\n" +
                "    .then(res => {\n" +
                "      console.log('✅ FETCH response:', url, res.status, res.statusText);\n" +
                "      return res;\n" +
                "    })\n" +
                "    .catch(err => {\n" +
                "      console.log('❌ FETCH error:', url, err.message);\n" +
                "      throw err;\n" +
                "    });\n" +
                "};\n" +
                "console.log('🔧 Node.js proxy environment configured (AOS style)');",
                escapeForTemplate(httpsProxy),
                escapeForTemplate(httpProxy),
                escapeForTemplate(allProxy),
                escapeForTemplate(gatewayUrl),
                escapeForTemplate(cuUrl),
                escapeForTemplate(muUrl),
                escapeForTemplate(schedulerId),
                escapeForTemplate(aoUrl)
            );

            logger.info("1. Setting Node.js environment and proxy (AOS style)...");
            runtime.getExecutor(envScript).executeVoid();

            logger.info("2. Loading aoconnect SDK...");
            runtime.getExecutor("globalThis.aoconnectModule = require('@permaweb/aoconnect');").executeVoid();

            logger.info("3. Preparing spawn/message helpers...");
            String setupScript =
                "const { spawn, createDataItemSigner } = globalThis.aoconnectModule;\n" +
                "globalThis.spawnProcess = async function({ wallet, src, tags, data }) {\n" +
                "  console.log('🚀 Using AOS-style spawn process (Javet version)...');\n" +
                "  const signer = createDataItemSigner(wallet);\n" +
                "  const aosTags = tags.concat([{ name: 'aos-Version', value: '2.0.7' }]);\n" +
                "  const spawnParams = {\n" +
                "    module: src,\n" +
                "    scheduler: globalThis.SCHEDULER,\n" +
                "    signer: signer,\n" +
                "    tags: aosTags,\n" +
                "    data: data || ''\n" +
                "  };\n" +
                "  console.log('📦 Module:', spawnParams.module);\n" +
                "  console.log('🎯 Scheduler:', spawnParams.scheduler);\n" +
                "  console.log('🏷️ Tags:', spawnParams.tags.map(t => `${t.name}=${t.value}`).join(', '));\n" +
                "  try {\n" +
                "    const result = await spawn(spawnParams);\n" +
                "    console.log('📥 Spawn result:', result);\n" +
                "    if (typeof result === 'object' && result.id) { return result.id; }\n" +
                "    if (typeof result === 'string') { return result; }\n" +
                "    return result;\n" +
                "  } catch (error) {\n" +
                "    console.error('❌ Spawn error in Node.js runtime:', error.message);\n" +
                "    throw error;\n" +
                "  }\n" +
                "};\n" +
                "globalThis.aoconnect = globalThis.aoconnectModule;\n";
            runtime.getExecutor(setupScript).executeVoid();

            logger.info("4. Configuring AO Legacy network connection (AOS style)...");
            configureAONetworkConnection(runtime);

            logger.info("5. Verifying aoconnect SDK...");
            runtime.getExecutor("if (typeof aoconnect === 'undefined') { throw new Error('aoconnect SDK not loaded'); }").executeVoid();

            logger.info("6. Testing AO Legacy network connection...");
            testAONetworkConnection(runtime);

            logger.info("✅ AO Legacy network connection established successfully!");
            logger.info("@permaweb/aoconnect ready inside Node runtime (AOS style)");
            initialized = true;

        } catch (Exception e) {
            if (e instanceof JavetException) {
                throw (JavetException) e;
            }
            throw new RuntimeException("Failed to initialize AO bridge", e);
        }
    }

    /**
     * 配置 AO Legacy 网络的全局变量，供 JS 侧使用。
     */
    private void configureAONetworkConnection(V8Runtime runtime) throws JavetException {
        // 在 V8 模式下，直接设置全局变量
        String configScript = String.format(
            "// AOS-style AO Legacy network configuration (V8 mode)\n" +
            "globalThis.GATEWAY_URL = '%s';\n" +
            "globalThis.MU_URL = '%s';\n" +
            "globalThis.CU_URL = '%s';\n" +
            "globalThis.SCHEDULER = '%s';\n" +
            "globalThis.MODULE_ID = '%s';\n" +
            "console.log('✅ AO Environment configured (V8 mode):', {GATEWAY_URL, MU_URL, CU_URL, SCHEDULER, MODULE_ID});",
            gatewayUrl, muUrl, cuUrl, schedulerId, moduleId
        );

        runtime.getExecutor(configScript).executeVoid();
    }

    /**
     * 简单检查 `aoconnect.connect` 是否可用，用于确认 SDK 安装成功。
     */
    private void testAONetworkConnection(V8Runtime runtime) throws JavetException {
        try {
            // 简单的连接测试
            Boolean connected = runtime.getExecutor(
                "try {\n" +
                "  return typeof globalThis.aoconnect !== 'undefined' && typeof globalThis.aoconnect.connect === 'function';\n" +
                "} catch (e) {\n" +
                "  console.log('Connection test error:', e.message);\n" +
                "  return false;\n" +
                "}"
            ).executeBoolean();

            if (connected) {
                logger.info("✅ AO Legacy network connection verified");
            } else {
                logger.warn("⚠️ AO Legacy network connection test failed (this is normal without wallet signer)");
            }
        } catch (Exception e) {
            logger.warn("⚠️ AO Legacy network connection test failed: {}", e.getMessage());
        }
    }

    /**
     * 创建真实 AO 进程，返回 43 字符的 Arweave/AO 交易 ID。
     */
    public String spawnProcess() throws JavetException {
        ensureInitialized();

        logger.info("=== Real AO Process Creation (AOS Style) ===");
        logger.info("Creating real AO process using aoconnect.connect().spawn()...");

        try (IJavetEngine<V8Runtime> engine = enginePool.getEngine()) {
            V8Runtime runtime = engine.getV8Runtime();

            runtime.getExecutor("globalThis.__javetSpawnResult=undefined;globalThis.__javetSpawnError=undefined;").executeVoid();

            String asyncScript = String.format(
                "(async () => {\n" +
                "  try {\n" +
                "    const wallet = JSON.parse(`%s`);\n" +
                "    const processName = 'javet-demo-' + Date.now();\n" +
                "    const result = await globalThis.spawnProcess({\n" +
                "      wallet,\n" +
                "      src: '%s',\n" +
                "      tags: [\n" +
                "        { name: 'App-Name', value: 'javet-aoconnect-demo' },\n" +
                "        { name: 'Name', value: processName },\n" +
                "        { name: 'Authority', value: 'fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY' }\n" +
                "      ],\n" +
                "      data: ''\n" +
                "    });\n" +
                "    globalThis.__javetSpawnResult = result;\n" +
                "  } catch (error) {\n" +
                "    globalThis.__javetSpawnError = error ? (error.message || String(error)) : 'Unknown error';\n" +
                "  }\n" +
                "})();",
                escapeForTemplate(walletJson),
                moduleId
            );

            runtime.getExecutor(asyncScript).executeVoid();
            String result = awaitJsResult(runtime, "__javetSpawnResult", "__javetSpawnError");

            logger.info("🔄 Executed spawn script, result: {}", result);
            if (result == null || result.length() != 43 || !result.matches("^[A-Za-z0-9_-]+$")) {
                throw new RuntimeException("Invalid process ID format returned: " + result);
            }
            logger.info("✅ Real AO Process created: {}", result);
            return result;
        }
    }

    /**
     * 给刚创建的 AO 进程发送消息，返回真实消息 ID。
     */
    public String sendMessage(String processId, String action, String data) throws JavetException {
        ensureInitialized();

        logger.info("=== AO Message Sending Demo ===");
        logger.info("Demonstrating message sending to AO process...");

        try (IJavetEngine<V8Runtime> engine = enginePool.getEngine()) {
            V8Runtime runtime = engine.getV8Runtime();

            runtime.getExecutor("globalThis.__javetMessageResult=undefined;globalThis.__javetMessageError=undefined;").executeVoid();
            runtime.getExecutor(String.format(
                    "(async () => {\n" +
                    "  try {\n" +
                    "    const wallet = JSON.parse(`%s`);\n" +
                    "    const signer = aoconnect.createDataItemSigner(wallet);\n" +
                    "    const messageResult = await aoconnect.connect({\n" +
                    "      MODE: 'legacy',\n" +
                    "      GATEWAY_URL: globalThis.GATEWAY_URL,\n" +
                    "      MU_URL: globalThis.MU_URL,\n" +
                    "      CU_URL: globalThis.CU_URL\n" +
                    "    }).message({\n" +
                    "      process: '%s',\n" +
                    "      signer,\n" +
                    "      tags: [{ name: 'Action', value: '%s' }],\n" +
                    "      data: '%s'\n" +
                    "    });\n" +
                    "    globalThis.__javetMessageResult = messageResult;\n" +
                    "  } catch (error) {\n" +
                    "    globalThis.__javetMessageError = error ? (error.message || String(error)) : 'Unknown error';\n" +
                    "  }\n" +
                    "})();",
                    escapeForTemplate(walletJson),
                    processId,
                    action,
                    escapeForTemplate(data)
            )).executeVoid();

            String result = awaitJsResult(runtime, "__javetMessageResult", "__javetMessageError");
            logger.info("🎯 Message dispatch completed!");
            logger.info("📨 Message Details:");
            logger.info("   - Message ID: {}", result);
            logger.info("   - Target Process: {}", processId);
            logger.info("   - Action: {}", action);
            logger.info("   - Data Length: {} characters", data.length());
            return result;
        }
    }

    /**
     * 检查 Node 运行时中是否存在 `aoconnect.connect`。
     */
    public boolean testConnection() throws JavetException {
        ensureInitialized();

        try (IJavetEngine<V8Runtime> engine = enginePool.getEngine()) {
            V8Runtime runtime = engine.getV8Runtime();

            // 测试AO网络连接 - 检查SDK是否可用
            Boolean connected = runtime.getExecutor(
                "try {\n" +
                "  return typeof aoconnect !== 'undefined' && typeof aoconnect.connect === 'function';\n" +
                "} catch (e) {\n" +
                "  console.log('Connection test error:', e.message);\n" +
                "  return false;\n" +
                "}"
            ).executeBoolean();

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

    /**
     * 获取网关URL
     */
    public String getGatewayUrl() {
        return gatewayUrl;
    }

    /**
     * 获取MU URL
     */
    public String getMuUrl() {
        return muUrl;
    }

    /**
     * 获取CU URL
     */
    public String getCuUrl() {
        return cuUrl;
    }

    /**
     * 获取AO URL
     */
    public String getAoUrl() {
        return aoUrl;
    }

    /**
     * 获取调度器ID
     */
    public String getSchedulerId() {
        return schedulerId;
    }

    /**
     * 获取模块ID
     */
    public String getModuleId() {
        return moduleId;
    }

    /**
     * 获取钱包路径
     */
    public String getWalletPath() {
        return walletPath;
    }

    private String escapeForTemplate(String input) {
        return input
                .replace("\\", "\\\\")
                .replace("`", "\\`")
                .replace("${", "\\${");
    }

    /**
     * 轮询 JS 全局变量获取异步结果，并驱动 Node 事件循环。
     */
    private String awaitJsResult(V8Runtime runtime, String resultVar, String errorVar) throws JavetException {
        long startTime = System.currentTimeMillis();
        long timeout = ASYNC_TIMEOUT_MS;
        while (System.currentTimeMillis() - startTime < timeout) {
            runtime.await();
            String error = runtime.getExecutor("globalThis." + errorVar).executeString();
            if (error != null && !error.isEmpty() && !"undefined".equals(error)) {
                throw new RuntimeException("JavaScript error: " + error);
            }
            String result = runtime.getExecutor("globalThis." + resultVar).executeString();
            if (result != null && !result.isEmpty() && !"undefined".equals(result)) {
                return result;
            }
            try {
                Thread.sleep(50);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new RuntimeException("Interrupted while waiting for JS result", e);
            }
        }
        throw new RuntimeException("Timeout waiting for JavaScript operation to complete");
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
