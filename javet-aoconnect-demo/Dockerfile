FROM --platform=linux/amd64 node:22-bookworm AS node-deps
# 说明：Javet 提供的 Node 原生库仅含 x86_64 版本，
# 因此镜像统一使用 linux/amd64 架构。macOS + OrbStack 会通过仿真
# 运行该镜像，但编译出的 N-API 扩展在仿真环境下仍可能与运行时 ABI 不符。
# 在真实的 Linux x86_64 主机上构建/运行可避免此差异。
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends python3 make g++ && rm -rf /var/lib/apt/lists/*
COPY package.json package-lock.json* ./
RUN npm install --production \
    # 尝试在镜像内针对 x86_64 ABI 重新编译 aoconnect 依赖的原生模块
    && npm rebuild --build-from-source keccak secp256k1 \
    && npm cache clean --force

FROM --platform=linux/amd64 maven:3.9.6-eclipse-temurin-17 AS builder
WORKDIR /app
COPY . .
COPY --from=node-deps /app/node_modules ./node_modules
RUN mvn -q package

FROM --platform=linux/amd64 eclipse-temurin:17-jre
WORKDIR /app
COPY --from=builder /app/target/javet-aoconnect-demo.jar app.jar
COPY --from=builder /app/node_modules ./node_modules
ENTRYPOINT ["java","-jar","app.jar"]
