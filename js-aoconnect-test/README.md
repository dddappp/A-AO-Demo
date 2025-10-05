# JS AOS Connect Spawn Test

这个测试项目演示了如何使用纯JavaScript代码成功调用 `@permaweb/aoconnect` 库来在AO网络上创建（spawn）进程，完全模仿AOS（AO Operating System）的行为。

## 🎯 测试目标

验证纯JavaScript环境能否：
1. ✅ 加载AOS兼容的钱包
2. ✅ 配置AO Legacy网络连接
3. ✅ 使用正确的aoconnect API spawn进程
4. ✅ 成功创建真实的AO进程并返回43字符的进程ID

## 🔍 AO 生态系统核心概念

在深入了解这个测试项目之前，让我们先了解 AO 生态系统的几个核心概念：钱包文件、进程名和进程ID。这些概念对于理解 AO 应用的开发至关重要。

### 钱包文件 (Wallet File)
- **位置**: 默认位于 `~/.aos.json`
- **作用**: 存储用户的密钥对，用于在 AO 网络上签署交易和验证身份
- **格式**: JSON 格式，包含私钥和公钥信息
- **创建**: 首次运行 AOS CLI 时自动创建，或通过 Wander 钱包等工具生成

钱包文件是用户在 AO 网络上的身份凭证，用于签署所有的交易和消息。

### 进程名 (Process Name)
- **本质**: 用户定义的可读标识符，不是技术上的唯一标识
- **用途**: 帮助人类识别和管理 AO 进程
- **格式**: 字符串，如 `"js-aoconnect-test"` 或 `"blog-app"`
- **存储**: 作为标签 (tag) 存储在进程元数据中，标签名通常为 `"Name"`

进程名主要用于提高可读性，方便开发者管理多个进程。

### 进程 ID (Process ID)
- **格式**: 43 字符的 Base64URL 编码字符串
- **唯一性**: AO 网络保证全局唯一
- **作用**: AO 网络上进程的唯一技术标识符
- **生成**: 由 AO 网络的 spawn 操作动态返回

进程ID 是 AO 网络分配的唯一标识符，用于在网络上精确定位和通信。

### 三者之间的关系

**进程 ID 不是由钱包文件和进程名直接"派生"的**，而是通过以下流程生成的：

```
钱包文件 + 进程名 + 其他参数 → AO 网络 spawn 操作 → 进程 ID
```

#### 详细流程
1. **准备阶段**: 加载钱包文件获取签名密钥，指定进程名，配置模块等参数
2. **签名和提交**: 使用钱包对 spawn 交易进行数字签名，将进程名作为标签提交给 AO 网络
3. **网络分配**: AO 网络验证签名和参数，分配全局唯一的进程ID，返回给客户端

#### 映射关系存储
- **进程名 → 进程ID 的映射**: 存储在 **Arweave 区块链网络**上
- **AOS 不维护本地映射文件**: 每次需要查找进程时，都通过 GraphQL 查询 Arweave 网络
- **钱包文件**: 只存储密钥对，与进程映射无关

#### 实际应用中的查找流程
```bash
# 用户输入进程名
aos my-process

# AOS 执行流程：
1. 获取钱包地址
2. 构造 GraphQL 查询：查找 Name="my-process" 的进程
3. 从查询结果中提取进程ID
4. 连接到该进程ID对应的 AO 进程
```

#### 设计理念
这种设计符合 AO 的去中心化理念：
- **数据持久性**: 存储在 Arweave 永久保存
- **去中心化**: 无需中心化数据库
- **透明性**: 所有映射关系都可公开查询
- **一致性**: 网络保证数据一致性

**理解这些概念对于 AO 应用开发至关重要**：钱包提供身份验证，进程名提供可读性标识，而进程ID 是网络分配的唯一技术标识符。三者协同工作，但进程ID 不是前两者的简单组合，而是 AO 网络动态生成的唯一标识。

## 🏆 测试结果

**✅ 技术验证成功！纯JS + ProxyAgent即可spawn真实AO进程**

### 🎯 核心结论

| 测试项目      | 状态       | 说明                                                     |
| ------------- | ---------- | -------------------------------------------------------- |
| **代理配置**  | ✅ **成功** | 关键在于`undici.ProxyAgent`替换全局`fetch`               |
| **消息发送**  | ✅ **成功** | `connect(getInfo()).message()`可正常发送并返回真实消息ID |
| **进程创建**  | ✅ **成功** | `connect(getInfo()).spawn()`返回43字符真实AO进程ID       |
| **钱包处理**  | ✅ **成功** | 直接复用`~/.aos.json`钱包实现真实签名                    |
| **AOS兼容性** | ✅ **成功** | 所有环境变量、标签、模块ID与AOS一致                      |

### 📊 最新测试输出（真实运行日志节选）

```
🚀 Phase 1: Spawning new AO process...
🎉 SUCCESS! AO Process spawned with AOS-style hyper-async!
📋 Process ID: 5iKkEiso0tEoNm7QJZlDGfDVVGBSF8hTSnPypOg0jO0

📨 Phase 2: Sending message to the new process...
✅ Message dispatched!
   Message Result: y15Aew8KP4OMTeERxcZJGf-wf5ibQiyWq9xRoPXM0Cc

🎯 TEST SUMMARY:
✅ Process spawning: WORKS (real AO process spawned via aoconnect)
✅ Message sending: WORKS (message delivered to newly spawned process)
🎉 RESULT: Pure JS aoconnect test fully succeeds!
```

### 🔑 问题真正的根源 & 最终突破

1. **AOS会强制覆盖 `globalThis.fetch`，并绑定 `undici.ProxyAgent`**（`src/services/proxy.js`）。
   - 我们的JS脚本最初依赖 Node 的环境变量代理，这对 `connect().spawn()` 不足以处理 MU 的 TLS + 长连接请求。
   - 恢复与AOS一致的 ProxyAgent 逻辑后，`fetch` 请求才能稳定通过代理到达 `https://mu.ao-testnet.xyz`。

2. **必须在 `require('@permaweb/aoconnect')` 之前设置好代理和环境变量**。
   - AOS CLI 在启动时先设置环境/代理，再加载 aoconnect。
   - 我们调整导入顺序后，代理配置立刻生效，spawn 成功。

3. **Legacy 模式仍然依赖 scheduler/module/tag 与 AOS 完全一致**。
   - 使用 AOS `package.json` 中的 `moduleId`、默认 `scheduler`、以及 `Authority` 标签。

### ✅ 经过验证的关键修复

- [x] 在脚本最前面设置所有与 AOS 相同的环境变量
- [x] 使用 `undici.ProxyAgent` 将 `globalThis.fetch` 定向到本地代理
- [x] 完全复用 AOS 的 `getInfo()`、 `createDataItemSigner()`、 tags、 moduleId
- [x] 先设置环境变量和代理，再 `require('@permaweb/aoconnect')`
- [x] 使用成功运行的 `js-test` 实例反复验证 spawn 成功

### 现状总结

- **纯 JS 环境** 可以在本机网络代理下成功 spawn AO 进程。
- **无需额外代币/手续费**，Legacy 模式与 AOS CLI 行为一致。
- **消息发送 + 进程创建** 全流程可用，为后续 Javet 集成提供稳定基础。

下文更新了整个脚本说明，帮助任何人复现这一结果。

## 🔧 技术实现

### 核心技术点

1. **正确的aoconnect API使用**
   ```javascript
   const { spawn, createDataItemSigner } = require('@permaweb/aoconnect');
   ```

2. **代理配置**
   - 使用`https-proxy-agent`处理HTTP代理
   - 手动覆盖`global.fetch`函数以支持代理

3. **AOS兼容的spawn参数**
   ```javascript
   const spawnParams = {
     module: MODULE_ID,
     scheduler: SCHEDULER_ID,
     signer: createDataItemSigner(wallet),
     tags: [
       { name: 'App-Name', value: 'js-aoconnect-test' },
       { name: 'Authority', value: 'fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY' },
       { name: 'aos-Version', value: '1.0.0' }
     ],
     data: ''
   };
   ```

4. **网络配置**
   - Gateway: `https://arweave.net`
   - CU: `https://cu.ao-testnet.xyz`
   - MU: `https://mu.ao-testnet.xyz`
   - Scheduler: `_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA`

### 关键代码片段

#### 代理设置
```javascript
// Override global fetch to use proxy
const { HttpsProxyAgent } = require('https-proxy-agent');
global.fetch = function(url, options = {}) {
  const proxyUrl = process.env.HTTPS_PROXY || process.env.HTTP_PROXY;
  if (proxyUrl) {
    options.agent = new HttpsProxyAgent(proxyUrl);
  }
  return originalFetch(url, options);
};
```

#### Spawn进程
```javascript
async function spawnProcess({ wallet, src, tags, data }) {
  const signer = createDataItemSigner(wallet);
  const aosTags = tags.concat([{ name: 'aos-Version', value: '1.0.0' }]);

  const spawnParams = {
    module: src,
    scheduler: process.env.SCHEDULER,
    signer: signer,
    tags: aosTags,
    data: data || ''
  };

  const result = await spawn(spawnParams);
  return result; // 直接返回43字符的AO进程ID
}
```

## 🚀 运行测试

### 环境准备

1. **安装依赖**
   ```bash
   npm install
   ```

2. **设置代理** (如果需要)
   ```bash
   export HTTPS_PROXY=http://127.0.0.1:1235
   export HTTP_PROXY=http://127.0.0.1:1235
   ```

3. **准备钱包**
   - 确保 `~/.aos.json` 存在（AOS会自动创建）

### 运行测试

```bash
node spawn-test.js
```

### 预期输出

```
🚀 Starting pure JS aoconnect spawn test...
🌐 AO Network Configuration:
   Gateway: https://arweave.net
   CU: https://cu.ao-testnet.xyz
   MU: https://mu.ao-testnet.xyz
   Scheduler: _GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA
   Module: ISShJH1ij-hPPt9St5UFFr_8Ys3Kj5cyg7zrMGt7H9s

🔑 Loading wallet...
✅ Wallet loaded, address: 8h3JgLOkI7JZUrMH99yL...

📋 Spawn Parameters:
   Module: ISShJH1ij-hPPt9St5UFFr_8Ys3Kj5cyg7zrMGt7H9s
   Tags: 2

⚙️ Spawning AO process...
🚀 Using AOS legacy spawnProcess pattern...
📦 Module: ISShJH1ij-hPPt9St5UFFr_8Ys3Kj5cyg7zrMGt7H9s
🎯 Scheduler: _GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA
🏷️ Tags: App-Name=js-aoconnect-test, Authority=fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY, aos-Version=1.0.0

🎉 SUCCESS! AO Process spawned!
📋 Process Details:
   Process ID: Bb-9l2NIAbLVLU7ixYf0YJlX-Xr_NH8srf3tJTw0Ua0
   Length: 43
   Format check: ✅ Valid AOS format

✅ TEST PASSED: Real AOS Process ID created!
📝 Process ID: Bb-9l2NIAbLVLU7ixYf0YJlX-Xr_NH8srf3tJTw0Ua0
```

## 📊 进程验证

创建的进程ID `Bb-9l2NIAbLVLU7ixYf0YJlX-Xr_NH8srf3tJTw0Ua0` 具有以下特征：

- ✅ **长度**: 43字符
- ✅ **格式**: 仅包含字母、数字、连字符和下划线
- ✅ **类型**: 真实的Arweave/AO网络地址
- ✅ **兼容性**: 与AOS完全兼容

## 🔍 技术分析

### 为什么这个测试成功？

1. **正确的API使用**: 使用`aoconnect.spawn()`而不是复杂的HTTP请求
2. **代理支持**: 手动实现了fetch代理支持，与AOS的行为一致
3. **环境配置**: 使用与AOS Legacy网络相同的配置
4. **参数格式**: 完全按照AOS的spawnProcess函数的参数格式

### 与AOS的对比

| 特性   | AOS                 | JS测试      |
| ------ | ------------------- | ----------- |
| 网络   | Legacy              | Legacy ✅    |
| API    | `connect().spawn()` | `spawn()` ✅ |
| 代理   | 支持                | 支持 ✅      |
| 进程ID | 43字符              | 43字符 ✅    |
| 兼容性 | -                   | 完全兼容 ✅  |

## 🔄 下一步：集成到Javet

这个成功的JS测试为将aoconnect集成到Javet Java项目提供了完整的技术路径：

1. ✅ **API验证**: `aoconnect.spawn()` 可以直接使用
2. ✅ **代理方案**: 通过覆盖`global.fetch`实现代理支持
3. ✅ **参数格式**: spawn参数格式已确认
4. ✅ **网络配置**: Legacy网络配置已验证

现在可以将这些技术集成到Javet V8运行时中，实现Java环境下的AO进程创建。

## 📝 依赖项

```json
{
  "dependencies": {
    "@permaweb/aoconnect": "^0.0.55",
    "https-proxy-agent": "^7.0.4"
  }
}
```

## 🏷️ 标签说明

测试中使用的标签遵循AOS标准：

- `App-Name`: 应用名称标识
- `Authority`: AO网络权限标识
- `aos-Version`: AOS版本号

这些标签确保创建的进程与AOS生态系统完全兼容。
