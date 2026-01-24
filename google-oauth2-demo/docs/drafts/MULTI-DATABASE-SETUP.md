# 多数据库支持 - SQLite (Dev) & PostgreSQL (Test/Prod)

> 📌 **项目架构**: 支持SQLite（开发）和PostgreSQL（测试/生产）双数据库

## 🎯 概述

本项目现已支持多数据库配置，通过Spring Profiles实现环境隔离：

| 环境 | 数据库 | 用途 | 配置文件 | SQL脚本 |
|------|--------|------|---------|--------|
| **dev** | SQLite | 快速开发和验证 | `application-dev.yml` | `schema.sql` / `data.sql` |
| **test** | PostgreSQL | 集成测试 | `application-test.yml` | `schema-postgresql.sql` / `data-postgresql.sql` |
| **prod** | PostgreSQL | 生产环境 | `application-prod.yml` | 由DBA管理 |

---

## 🚀 启动指南

### 方式1：默认启动（dev环境 - SQLite）

```bash
cd google-oauth2-demo
export $(cat .env | xargs)
mvn spring-boot:run
```

**说明**:
- 使用SQLite数据库（文件：`dev-database.db`）
- 自动初始化3个测试账户（testlocal, testsso, testboth）
- 适合快速开发和功能验证

### 方式2：显式启动dev环境

```bash
mvn spring-boot:run -Dspring-boot.run.arguments="--spring.profiles.active=dev"
```

### 方式3：启动test环境（PostgreSQL）

**前提条件**：
1. PostgreSQL数据库已启动
2. 数据库已创建：`google_oauth2_demo`
3. 环境变量已设置

```bash
# 设置PostgreSQL连接信息
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
export POSTGRES_DATABASE=google_oauth2_demo
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=123456

# 启动应用
mvn spring-boot:run -Dspring-boot.run.arguments="--spring.profiles.active=test"
```

### 方式4：启动prod环境（生产配置）

```bash
# 生产环境必须设置所有环境变量（无默认值）
export POSTGRES_HOST=<prod-host>
export POSTGRES_PORT=<prod-port>
export POSTGRES_DATABASE=<prod-db>
export POSTGRES_USER=<prod-user>
export POSTGRES_PASSWORD=<prod-password>
export GOOGLE_CLIENT_ID=<google-id>
export GOOGLE_CLIENT_SECRET=<google-secret>
export GITHUB_CLIENT_ID=<github-id>
export GITHUB_CLIENT_SECRET=<github-secret>
export TWITTER_CLIENT_ID=<twitter-id>
export TWITTER_CLIENT_SECRET=<twitter-secret>

# 启动应用
mvn spring-boot:run -Dspring-boot.run.arguments="--spring.profiles.active=prod"
```

---

## 📊 数据库配置详解

### Dev环境配置 (application-dev.yml)

```yaml
spring:
  datasource:
    url: jdbc:sqlite:./dev-database.db
    driver-class-name: org.sqlite.JDBC
  
  jpa:
    database-platform: org.hibernate.community.dialect.SQLiteDialect
    hibernate:
      ddl-auto: none
  
  sql:
    init:
      mode: always
      data-locations: classpath:data.sql
      schema-locations: classpath:schema.sql
```

**特点**:
- SQLite数据库存储在文件系统（便于版本控制和备份）
- 每次启动都执行SQL初始化脚本
- 调试日志级别为DEBUG

### Test环境配置 (application-test.yml)

```yaml
spring:
  datasource:
    url: jdbc:postgresql://${POSTGRES_HOST:localhost}:${POSTGRES_PORT:5432}/${POSTGRES_DATABASE:google_oauth2_demo}
    driver-class-name: org.postgresql.Driver
    username: ${POSTGRES_USER:postgres}
    password: ${POSTGRES_PASSWORD:password}
    hikari:
      maximum-pool-size: 10
      minimum-idle: 2
  
  jpa:
    database-platform: org.hibernate.dialect.PostgreSQLDialect
    hibernate:
      ddl-auto: none
  
  sql:
    init:
      mode: always
      data-locations: classpath:data-postgresql.sql
      schema-locations: classpath:schema-postgresql.sql
```

**特点**:
- 使用PostgreSQL数据库
- 支持连接池优化
- 每次启动都执行PostgreSQL SQL脚本

### Prod环境配置 (application-prod.yml)

```yaml
spring:
  datasource:
    url: jdbc:postgresql://${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DATABASE}
    driver-class-name: org.postgresql.Driver
    username: ${POSTGRES_USER}
    password: ${POSTGRES_PASSWORD}
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
  
  jpa:
    hibernate:
      ddl-auto: validate  # 不自动修改表
  
  sql:
    init:
      mode: never  # 不自动执行初始化脚本
```

**特点**:
- 生产级别的数据库连接池配置
- 不自动修改表结构（安全第一）
- 不执行初始化脚本
- 日志级别为WARN

---

## 🗄️ SQL脚本设计

### SQLite脚本（dev环境）

- **schema.sql**: SQLite兼容的DDL
  - 使用 `INTEGER PRIMARY KEY AUTOINCREMENT`
  - 使用 `DATETIME` 类型
  - 使用 `INTEGER` 代表布尔值

- **data.sql**: SQLite兼容的DML
  - 使用 `INSERT OR IGNORE` 处理重复
  - 测试账户：testuser, admin, frontenduser, testlocal, testsso, testboth

### PostgreSQL脚本（test/prod环境）

- **schema-postgresql.sql**: PostgreSQL特定的DDL
  - 使用 `BIGSERIAL` 自增ID
  - 使用 `TIMESTAMP` 类型
  - 使用 `BOOLEAN` 类型
  - 完整的约束定义

- **data-postgresql.sql**: PostgreSQL特定的DML
  - 使用 `ON CONFLICT ... DO NOTHING` 处理重复
  - 相同的测试账户数据

---

## 📋 测试账户

所有环境都包含以下测试账户（密码都是 `password123`）：

### 基础账户
- **testuser** / **password123** - 标准测试用户
- **admin** / **password123** - 管理员用户
- **frontenduser** / **password123** - 前端测试用户

### 多登录方式测试账户
- **testlocal** / **password123** - 仅本地登录（场景1：本地→SSO）
- **testsso** - 仅Google SSO登录（场景2：SSO→本地）
- **testboth** / **password123** - 本地+Google双方式（场景3：多方式登录）

---

## 🔄 环境切换

### 快速切换示例

```bash
# 从dev切换到test
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
export POSTGRES_DATABASE=google_oauth2_demo
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=123456

mvn spring-boot:run -Dspring-boot.run.arguments="--spring.profiles.active=test"
```

### 查看当前环境配置

应用启动时会在日志中输出：
- 数据库类型（SQLite/PostgreSQL）
- 连接字符串
- 初始化状态
- 测试账户信息

---

## ⚠️ 常见问题

### Q1: 如何在dev和test环境之间快速切换？

A: 只需改变 `--spring.profiles.active` 参数即可。Dev环境会自动使用SQLite，Test环境会使用PostgreSQL。

### Q2: Test环境启动时报错"数据库连接失败"？

A: 检查以下几点：
1. PostgreSQL服务是否运行：`psql -h localhost -U postgres`
2. 数据库是否已创建：`CREATE DATABASE google_oauth2_demo;`
3. 环境变量是否正确设置：`echo $POSTGRES_HOST`
4. 防火墙是否允许连接

### Q3: 能否在同一台机器上同时运行dev和test环境？

A: 不能。应用会占用同一个端口（8081）。需要在不同的终端或改变端口。

### Q4: SQL脚本如何自动选择SQLite或PostgreSQL版本？

A: 通过Spring的 `sql.init` 配置在不同环境中指定不同的脚本文件：
- dev环境：`schema.sql` 和 `data.sql`（SQLite）
- test环境：`schema-postgresql.sql` 和 `data-postgresql.sql`（PostgreSQL）

### Q5: 生产环境需要创建表吗？

A: 不需要。生产环境的 `ddl-auto: validate` 和 `sql.init.mode: never` 确保：
- 不自动创建表
- 不执行初始化脚本
- 表结构由DBA预先创建和管理

---

## 📚 文件结构

```
src/main/resources/
├── application.yml                    # 基础配置 + OAuth2设置
├── application-dev.yml               # 📱 Dev环境：SQLite
├── application-test.yml              # 🧪 Test环境：PostgreSQL
├── application-prod.yml              # 🏢 Prod环境：PostgreSQL
├── schema-sqlite.sql                 # SQLite表结构
├── schema-postgresql.sql             # PostgreSQL表结构
├── data-sqlite.sql                   # SQLite测试数据
└── data-postgresql.sql               # PostgreSQL测试数据
```

---

## 🎯 最佳实践

1. **开发阶段**: 使用dev环境（SQLite）
   - 快速启动，无需数据库服务
   - 自动初始化测试数据
   - 适合快速迭代

2. **集成测试**: 使用test环境（PostgreSQL）
   - 与生产环境使用相同数据库
   - 验证生产环境兼容性
   - 完整的测试流程

3. **生产部署**: 使用prod环境（PostgreSQL）
   - 最大化性能和安全性
   - 由DBA管理表结构
   - 禁用自动初始化

---

## 📖 相关文档

- [Google OAuth2 Demo README](../README.md)
- [多登录方式实现计划](./multi-login-methods-implementation-plan-v3-improved.md)
- [项目进展](./project-progress.md)

