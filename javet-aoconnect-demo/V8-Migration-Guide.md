# Javet + aoconnect（Browser Build）在 V8 模式下的集成与迁移指南

本指南说明如何从 Javet 的 Node 模式迁移到 V8 模式，并使用 `@permaweb/aoconnect` 的浏览器构建，实现无需 Node/N-API 的 AO 网络交互（spawn + message）。

---

## 目标
- 不依赖 Node 原生扩展（secp256k1/keccak 等），避免 Linux 下 N-API 加载问题。
- 在 V8 模式下运行 aoconnect（browser 构建），通过自定义 polyfill 提供浏览器 API（fetch、TextEncoder、atob/btoa、crypto 等）。
- 复刻既有流程：先 spawn 新进程，再向该进程发送消息。

## 总体思路
- 使用 Javet V8 模式（`JSRuntimeType.V8`）。
- 以 UMD/浏览器版 aoconnect 为入口，避免 `require`、原生模块依赖。
- Java 侧注入 polyfill：
  - fetch：桥接到 Java HTTP 客户端，支持代理、TLS。
  - TextEncoder/TextDecoder、atob/btoa：JS 纯实现或精简 polyfill。
  - crypto：使用纯 JS/wasm 签名/哈希库（替代 `keccak`、`secp256k1` 原生扩展）。
- 以 DataItemSigner（legacy）路径优先，尽量选用 JS 实现的签名方案。

## 关键技术点
1) V8 环境与模块加载
- 无 `require`、无 `process`，只能通过全局注入或 `eval`/`Executor` 加载。
- 建议使用 aoconnect 的浏览器打包文件（UMD），在 Java 中以字符串注入，或从资源文件读取注入。
- aoconnect 期望的全局对象通常是 `window`/`globalThis`，在 V8 中使用 `globalThis`。

2) fetch 与代理
- 实现 `globalThis.fetch = (url, opts) => JavaBridge.fetch(url, opts)`。
- Java 侧用 `HttpClient`（或 OkHttp）执行请求：
  - 代理：读取 `HTTPS_PROXY`/`HTTP_PROXY` 环境变量，支持 CONNECT。
  - TLS：允许自定义证书策略（可配置跳过验证用于内网测试）。
  - 超时：按需设置（例如 60s）。

3) 编解码与工具 API
- `TextEncoder/TextDecoder`：提供轻量 JS polyfill（用 `Buffer` 替代不可行，V8 模式没有）。
- `atob/btoa`：JS 版本实现（Base64 编解码）。
- `URL`、`URLSearchParams`：V8 通常带有基本实现，若缺失可用 JS 实现。

4) 加密哈希与签名
- 替代方案：
  - 哈希（Keccak）：`@noble/hashes/sha3`、`js-sha3` 或 `keccak-wasm`。
  - 椭圆曲线（Secp256k1）：`@noble/secp256k1`。
- 接线点：aoconnect 使用 `arbundles` 进行签名与打包；可 fork/patch 其依赖，将原生 `keccak`/`secp256k1` 替换为上述 JS/wasm 实现。
- 方案 A（推荐）：在 V8 中优先加载一个“已替换原生扩展”的 browser 版 aoconnect（或我们维护的 UMD 产物）。

5) 钱包
- 继续复用 `~/.aos.json`，Java 读取并注入到 V8，全局作为 `wallet` 对象供 aoconnect 使用。

6) API 调用路径
- 使用 `connect(getInfo()).spawn(...)` + `createDataItemSigner(wallet)`（legacy 流程）。
- spawn 成功后，使用 `connect(getInfo()).message(...)` 向新进程发送消息。

---

## 实施步骤

### 1. 切换 Javet 到 V8 模式
- `AOJavaBridge` 中：
  - 引擎池配置改为 `JSRuntimeType.V8`。
  - 移除 Node 专属逻辑（`require`、`process.env`、undici ProxyAgent 等）。

### 2. 注入浏览器版 aoconnect
- 将 UMD 构建文件加入资源目录（例如 `src/main/resources/js/aoconnect.browser.umd.js`）。
- Java 加载为字符串，`runtime.getExecutor(umdScript).executeVoid()`，使其在 `globalThis.aoconnect` 下可用。

### 3. 提供 Polyfills
- 在 V8 初始化脚本中注入：
  - `TextEncoder/TextDecoder` 的 JS 实现。
  - `atob/btoa`。
  - `fetch`：调用 Java 的 `HttpClient`，支持代理与 TLS 选项。
- 可按需提供 `crypto.getRandomValues` 等最小子集（许多 JS 库用于生成随机数）。

### 4. 替换加密依赖（若 aoconnect UMD 构建仍依赖原生扩展）
- 方案 A：使用已替换原生依赖的 aoconnect UMD（推荐）。
- 方案 B：在 V8 注入 `@noble/hashes/sha3` 与 `@noble/secp256k1` 的浏览器构建，覆写全局对象映射，让 aoconnect/arbundles 调用时导向纯 JS 实现。

### 5. 运行时参数与钱包
- Java 读取 `~/.aos.json`，注入为 `globalThis.wallet`。
- 设置 `globalThis.GATEWAY_URL`、`globalThis.MU_URL`、`globalThis.CU_URL`、`globalThis.SCHEDULER`、`globalThis.AO_URL`。

### 6. 运行流程
- 初始化：加载 polyfills、加载 aoconnect UMD、注入网络与钱包配置。
- 调用：
  - `const { connect, createDataItemSigner } = globalThis.aoconnect;`
  - `const signer = createDataItemSigner(globalThis.wallet);`
  - `const ao = connect(getInfo());`
  - `const pid = await ao.spawn({ module, scheduler, signer, tags, data });`
  - `const mid = await ao.message({ process: pid, signer, tags, data });`
- Java 侧轮询 Promise 结果（`runtime.await()` + 全局变量收集）与现有 Node 模式一致。

---

## 兼容性与性能
- 性能：V8 模式无 Node/N-API，减少原生模块动态装载开销；纯 JS/wasm 的哈希/签名较原生略慢但可控。
- 兼容性：browser 构建的 aoconnect 对 Web API 期望更高，polyfill 的完备性决定稳定性。

## Docker 适配
- V8 模式镜像不需要 Node 预编译模块：
  - 不需要 `npm rebuild` 或指定 `linux/amd64`。
  - 仅需 Java JRE + 我们的资源文件（UMD + polyfill）。
- 代理：沿用环境变量，Java `HttpClient` 读取并转发到 `fetch`。

---

## 风险与回退
- 如果某些子库在 browser 构建中仍隐含 Node API，可需微调（fork/patch）。
- 若短期内不想维护 UMD 产物，可先在本机验证流程再决定是否投入容器。

## 验收标准
- 在 V8 模式下：
  - `spawn` 返回真实 43 字符 Process ID。
  - `message` 返回真实消息 ID，指向刚创建的进程。
  - 代理可控、超时合理、失败即停。

---

## 附录：最小 Polyfill 草案（示意）
```js
// TextEncoder / TextDecoder（可采用更完整实现）
if (typeof TextEncoder === 'undefined') {
  globalThis.TextEncoder = class { encode(s) { return Uint8Array.from(Array.from(s).map(c => c.charCodeAt(0))); } };
}
if (typeof TextDecoder === 'undefined') {
  globalThis.TextDecoder = class { decode(u8) { return String.fromCharCode.apply(null, Array.from(u8)); } };
}
// atob / btoa
if (typeof atob === 'undefined') {
  globalThis.atob = (b64) => JavaBridge.base64Decode(b64);
}
if (typeof btoa === 'undefined') {
  globalThis.btoa = (s) => JavaBridge.base64Encode(s);
}
// fetch -> Java
if (typeof fetch === 'undefined') {
  globalThis.fetch = (url, opts) => JavaBridge.fetch(url, opts);
}
```

> 以上仅示例，实际实现需处理 UTF-8、流、错误与超时，并与 Java 侧桥接。

---

## 利用 Javenode 加速 V8 集成

[Javenode](https://github.com/caoccao/Javenode) 是 Javet 作者提供的“在 V8 模式下模拟 Node 核心能力”的扩展库，已经补齐了事件循环与计时器等“必需 API”，可显著减少我们在 V8 方案中的适配工作。

- 已覆盖能力（可直接复用）
  - V8 内建事件循环（基于 vert.x）
  - `console`、`timers`、`timers/promises` 等模块（支持静态/动态加载）
- 尚未覆盖（仍需我们实现）
  - `fetch`（Javenode README 的 TODO 明确待实现）
  - `fs`（非本项目核心需求，可忽略）

参考：Javenode README 中的特性、示例与 TODO 说明见 [Javenode 仓库](https://github.com/caoccao/Javenode)。

### 引入依赖

Maven：

```xml
<dependency>
    <groupId>com.caoccao.javet</groupId>
    <artifactId>javenode</artifactId>
    <version>0.8.0</version>
</dependency>
```

Gradle（Kotlin DSL）：

```kotlin
implementation("com.caoccao.javet:javenode:0.8.0")
```

### 快速使用（示例）

以下演示在 V8 下加载计时器模块、运行并等待事件循环结束：

```java
try (V8Runtime v8Runtime = V8Host.getV8Instance().createV8Runtime();
     JNEventLoop eventLoop = new JNEventLoop(v8Runtime)) {
    eventLoop.loadStaticModules(JNModuleType.Console, JNModuleType.Timers);
    v8Runtime.getExecutor(
        "const a = [];\n" +
        "setTimeout(() => a.push('Hello Javenode'), 10);")
        .executeVoid();
    eventLoop.await();
    v8Runtime.getExecutor("console.log(a[0]);").executeVoid();
}
```

> 在本项目中，可将上述事件循环初始化整合到 `AOJavaBridge` 的 V8 初始化流程，随后加载 polyfill 和 aoconnect 浏览器构建。

### 与本项目 V8 方案的分工
- 交给 Javenode：计时器、事件循环、部分 Node 核心模块的模拟（无需我们重复造轮子）。
- 交给本项目：
  - 提供 `fetch`（Java HttpClient 桥接，含代理/TLS/超时）。
  - 注入浏览器 API 小件（`TextEncoder/Decoder`、`atob/btoa`、`crypto.getRandomValues`）。
  - 使用纯 JS/wasm 密码学（`@noble/secp256k1`、`@noble/hashes/sha3`）。
  - 加载 aoconnect 浏览器 UMD，执行 `spawn -> message` 流程。

### 评估影响
- 复杂度：事件循环与计时器由 Javenode 提供，V8 方案实现量显著下降。
- 兼容性：仍需我们完成网络与密码学的纯 JS/wasm 路径，但不再受 Linux N‑API/原生扩展约束。
- 安全性：V8 模式更可控，无 Node 原生层动态装载风险；Javenode 只引入必要模块。

> 参考来源：Javenode 官方 README 与特性说明（仓库地址同上）。

---

## FAQ（前端同学常见疑问）

- aoconnect 浏览器版是否依赖 ArbBundles？
  - 是。用于 DataItem 打包/签名。在浏览器目标下走纯 JS/wasm 路径（如 `@noble/secp256k1`、`@noble/hashes/sha3` 或同类），不使用原生 `.node` 扩展。
- 还需要 `undici` 吗？
  - 不需要。V8 模式下没有 Node 运行时，我们用 Java HttpClient 桥接实现 `fetch`，`undici` 仅用于 Node。
- 代理如何生效？
  - 继续使用 `HTTPS_PROXY` / `HTTP_PROXY` / `ALL_PROXY` 环境变量。Java 读取并在 `fetch` 实现中转发（CONNECT、超时、TLS 等）。
- 钱包从哪里加载？
  - 仍使用 `~/.aos.json`（可挂载/映射进容器）。Java 读取后注入到 `globalThis.wallet`。
- 为什么 Node 模式在 Linux 容器失败、V8 模式更稳？
  - Node 模式依赖 N‑API 原生扩展（secp256k1/keccak）。Linux 下 Javet 内嵌 Node 的符号可见性/装载方式与 macOS 不同，可能导致 `.node` 加载失败。V8 模式不需要原生扩展，天然规避。
- 最小落地清单？
  - 切 V8 模式 → 注入 aoconnect 浏览器 UMD → 提供 `fetch/TextEncoder/atob/btoa/crypto.getRandomValues` → 使用纯 JS/wasm 密码学 → `spawn -> message` 验证。
- 常见故障排查？
  - `fetch failed`：检查代理变量与 Java `HttpClient` 桥接；打印 URL、状态码、超时。
  - 编解码异常：完善 `TextEncoder/Decoder` UTF‑8 处理与 Base64 polyfill。
  - 签名/哈希不一致：确认 noble 库版本与数据编码路径一致（Uint8Array vs string）。
