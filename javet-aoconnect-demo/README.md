# Javet AOConnect Demo

## 目标

在 Java 中直接调用 Node.js 运行时，复刻 `js-aoconnect-test` 的 `spawn -> message` 成功流程，证明 **Javet 集成 @permaweb/aoconnect 可行且可靠**。

## 成果

- ✅ JVM 内部启动 Node runtime（Javet Node 模式）
- ✅ 直接复用 `js-aoconnect-test` 的环境设置、代理和 API 调用方式
- ✅ 使用 AOS CLI 同款钱包 `~/.aos.json`
- ✅ Javet 依赖使用官方 4.x 架构后缀命名：macOS `javet-node-macos-*` + Linux `javet-node-linux-x86_64`
- ✅ Docker 镜像默认走 `linux/amd64`，并强制本地编译 `keccak`、`secp256k1` 确保 N-API 与 Node 22 兼容
- ✅ `spawn` 返回真实 43 字符 AO 进程 ID
- ✅ `message` 返回真实消息 ID，指向上一步新建的进程

最新跑通记录（2025-09-29）：
- Process ID: `hd34HJGjgX3tw8tJY7psHiEGDBIJTxWova77BGWGXWM`
- Message ID: `XsP-ZH9OqEhtYwq23tlv5O5r5k_x3KS-UYCIFF57O9c`

## 关键经验

1. **Node 运行时**：Javet 默认是 V8；必须显式设置 `JSRuntimeType.Node` 才能使用 `require`、`process`。
2. **代理处理**：AOS CLI 会覆写 `global.fetch` 使用 `undici.ProxyAgent`，直接抄一样的逻辑；光设环境变量会失败。
3. **初始化顺序**：一定要先设置环境和代理，再 `require('@permaweb/aoconnect')`，否则内部请求不会走代理。
4. **异步结果**：JS 返回 Promise，Java 通过 `runtime.await()` + 轮询全局变量收集结果，不能凭空 `sleep`。
5. **不要返还假数据**：任何网络错误直接抛出异常并停止演示，避免“成功但是假 ID”。

## 目录结构

```
javet-aoconnect-demo/
├── src/main/java/com/example/aodemo/
│   ├── AOJavaBridge.java      # Node runtime + aoconnect 桥接
│   └── AODemoApplication.java # 演示入口，打印真实 ID
├── src/main/resources/
│   ├── application.properties # Legacy 网络端点配置
│   └── logback.xml            # 日志配置
├── package.json / node_modules/undici
├── pom.xml
└── start.sh                   # 可选启动脚本，预设代理环境变量
```

## 运行方式

```
cd javet-aoconnect-demo
npm install
mvn -q exec:java
```

> 若 `undici` 缺失，会报 `Cannot find module 'undici'`，执行 `npm install undici --no-save` 即可。

## 输出示例

```
✅ AO Java Bridge initialized with Node.js runtime pool
…
📥 Spawn result: hd34HJGjgX3tw8tJY7psHiEGDBIJTxWova77BGWGXWM
✅ Real AO Process created: hd34HJGjgX3tw8tJY7psHiEGDBIJTxWova77BGWGXWM
…
📨 Message Details:
   - Message ID: XsP-ZH9OqEhtYwq23tlv5O5r5k_x3KS-UYCIFF57O9c
   - Target Process: hd34HJGjgX3tw8tJY7psHiEGDBIJTxWova77BGWGXWM
```

## 常见报错速记

| 报错                                                   | 解决方式                                                                    |
| ------------------------------------------------------ | --------------------------------------------------------------------------- |
| `Cannot find module 'undici'`                          | `npm install undici --no-save`                                              |
| `fetch failed`                                         | 检查代理覆写脚本是否执行；确认 `HTTPS_PROXY` 指向代理；代理需要支持 CONNECT |
| `Timeout waiting for JavaScript operation to complete` | 确认 `runtime.await()` 每轮被调用；不要用 `Thread.sleep` 替代事件循环       |
| `Invalid process ID format`                            | 进程创建失败，日志会包含实际错误；不要返回假 ID                             |

## 与 `js-aoconnect-test` 的对照

| 项目                   | 运行时     | 核心脚本            | 结果                    |
| ---------------------- | ---------- | ------------------- | ----------------------- |
| `js-aoconnect-test`    | Node CLI   | `spawn-test.js`     | Spawn 真实进程 + 消息   |
| `javet-aoconnect-demo` | Javet Node | `AOJavaBridge.java` | 同样流程，运行在 JVM 内 |

## Docker 打包示例

`Dockerfile` 默认使用 `linux/amd64` 基础镜像，并在 Node 阶段安装 `python3`, `make`, `g++` 后执行 `npm rebuild --build-from-source keccak secp256k1`。原因如下：
- `@permaweb/aoconnect` 依赖的 `keccak` / `secp256k1` 只有 `linux-x64` 预编译包，而 OrbStack/Docker Desktop 在 macOS 上默认构建 `arm64` 镜像会导致 `napi_module_register` 等符号缺失。
- 统一以 `amd64` 构建可以与 Javet 提供的 `javet-node-linux-x86_64` 原生库匹配，避免运行时加载失败。
- 如果宿主机是 arm64（例如 M 系列 Mac），Docker 会在运行时通过仿真执行 `amd64` 镜像，只需启动命令加上 `--platform linux/amd64` 即可消除警告。

构建与运行步骤：
```
cd javet-aoconnect-demo
# 1. 构建镜像（始终输出 linux/amd64）
docker build -t javet-aoconnect-demo .

# 2. 运行容器，指向宿主机代理与钱包
# macOS/Windows: 使用 host.docker.internal
# Linux: 替换为宿主机实际 IP
docker run --rm \
  --platform linux/amd64 \
  -e HTTPS_PROXY=http://host.docker.internal:1235 \
  -e HTTP_PROXY=http://host.docker.internal:1235 \
  -e ALL_PROXY=http://host.docker.internal:1235 \
  -e NODE_TLS_REJECT_UNAUTHORIZED=0 \
  -v $HOME/.aos.json:/root/.aos.json \
  javet-aoconnect-demo
```

容器内输出应与本地运行一致：先 `spawn` 新进程，再向该进程发送消息并返回真实 ID。

> 注意：在 OrbStack 的 macOS 环境中，即使强制 `linux/amd64` 并重新编译原生模块，仍可能出现 `secp256k1: undefined symbol napi_define_class`。推测是仿真层的 Node ABI 与编译结果不一致，建议在真实 x86_64 主机上执行 Docker 流程或进一步排查。

两者的环境变量、代理处理、tag 处理完全一致；Javet 只是把 Node 封装进了 Java。如此可验证 Java 集成 aoconnect 不需要 Mock，不需要“改协议”，关键是 Node 环境与代理配置必须和 AOS CLI 一模一样。
