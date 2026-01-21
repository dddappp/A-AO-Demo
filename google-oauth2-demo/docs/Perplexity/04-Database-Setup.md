# 📊 数据库设置与迁移指南

**版本:** 3.0.0  
**数据库:** SQLite (开发) + PostgreSQL (生产)

---

## 目录

1. [SQLite 开发环境](#sqlite-开发环境)
2. [PostgreSQL 生产环境](#postgresql-生产环境)
3. [数据库初始化](#数据库初始化)
4. [备份和恢复](#备份和恢复)

---

## SQLite 开发环境

### 特点

```
✅ 零配置
✅ 文件存储 (auth-dev.db)
✅ 无需启动单独服务
✅ 完全支持 Spring Data JPA
✅ 适合本地开发和测试
```

### 依赖配置 (pom.xml)

```xml
<!-- SQLite 驱动 -->
<dependency>
    <groupId>org.xerial</groupId>
    <artifactId>sqlite-jdbc</artifactId>
    <version>3.44.0.0</version>
    <scope>runtime</scope>
</dependency>

<!-- Hibernate Community Dialect (SQLite) -->
<dependency>
    <groupId>org.hibernate.orm</groupId>
    <artifactId>hibernate-community-dialect</artifactId>
    <version>6.4.0.Final</version>
</dependency>
```

### application-dev.yml

```yaml
spring:
  datasource:
    url: jdbc:sqlite:file:./auth-dev.db?mode=rwc
    driver-class-name: org.sqlite.JDBC
    username: ""
    password: ""

  jpa:
    database-platform: org.hibernate.community.dialect.SQLiteDialect
    hibernate:
      ddl-auto: create-drop  # 开发: 每次启动重建
    properties:
      hibernate.dialect: org.hibernate.community.dialect.SQLiteDialect
```

### 启动应用

```bash
# 设置活跃配置为 dev
export SPRING_PROFILES_ACTIVE=dev

# 启动应用
mvn spring-boot:run

# 应用启动时会自动创建 auth-dev.db 文件
```

### 清理数据库

```bash
# 删除 SQLite 数据库文件，下次启动会重建
rm auth-dev.db
```

---

## PostgreSQL 生产环境

### 安装 PostgreSQL

#### Linux (Ubuntu/Debian)

```bash
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib

# 启动服务
sudo service postgresql start

# 检查状态
sudo service postgresql status
```

#### macOS (Homebrew)

```bash
brew install postgresql

# 启动服务
brew services start postgresql

# 检查版本
postgres --version
```

#### Docker

```bash
# 运行 PostgreSQL 容器
docker run -d \
  --name postgres \
  -e POSTGRES_DB=auth_db \
  -e POSTGRES_USER=auth_user \
  -e POSTGRES_PASSWORD=auth_password \
  -p 5432:5432 \
  postgres:15-alpine
```

### 创建数据库和用户

```bash
# 连接 PostgreSQL
psql -U postgres

# 在 psql 中执行:
CREATE USER auth_user WITH PASSWORD 'auth_password';
CREATE DATABASE auth_db OWNER auth_user;
GRANT ALL PRIVILEGES ON DATABASE auth_db TO auth_user;

# 退出
\q
```

### application-prod.yml

```yaml
spring:
  profiles:
    active: prod

  datasource:
    url: jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:auth_db}
    driver-class-name: org.postgresql.Driver
    username: ${DB_USERNAME:auth_user}
    password: ${DB_PASSWORD:auth_password}
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
      connection-timeout: 30000
      idle-timeout: 600000
      max-lifetime: 1800000

  jpa:
    database-platform: org.hibernate.dialect.PostgreSQLDialect
    hibernate:
      ddl-auto: validate  # 生产: 仅验证
    properties:
      hibernate.dialect: org.hibernate.dialect.PostgreSQLDialect
```

### 启动应用 (PostgreSQL)

```bash
# 设置环境变量
export SPRING_PROFILES_ACTIVE=prod
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=auth_db
export DB_USERNAME=auth_user
export DB_PASSWORD=auth_password
export GOOGLE_CLIENT_ID=your-client-id
export GOOGLE_CLIENT_SECRET=your-client-secret

# 启动应用
java -jar target/user-auth-system.jar
```

---

## 数据库初始化

### schema-postgresql.sql (完整)

```sql
-- 用户表
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255),
    display_name VARCHAR(255),
    avatar_url TEXT,
    email_verified BOOLEAN DEFAULT false,
    auth_provider VARCHAR(50) DEFAULT 'LOCAL',
    provider_user_id VARCHAR(255),
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP,
    CONSTRAINT unique_provider_id UNIQUE (auth_provider, provider_user_id)
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);

-- 用户权限表
CREATE TABLE IF NOT EXISTS user_authorities (
    user_id BIGINT NOT NULL,
    authority VARCHAR(50) NOT NULL,
    PRIMARY KEY (user_id, authority),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_user_authorities ON user_authorities(user_id);

-- OAuth2 注册客户端表
CREATE TABLE IF NOT EXISTS oauth2_registered_client (
    id VARCHAR(100) PRIMARY KEY,
    client_id VARCHAR(255) UNIQUE NOT NULL,
    client_id_issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    client_secret VARCHAR(255),
    client_secret_expires_at TIMESTAMP,
    client_name VARCHAR(255),
    client_authentication_methods VARCHAR(1000),
    authorization_grant_types VARCHAR(1000),
    redirect_uris VARCHAR(1000),
    post_logout_redirect_uris VARCHAR(1000),
    scopes VARCHAR(1000),
    client_settings TEXT,
    token_settings TEXT
);

-- OAuth2 授权表
CREATE TABLE IF NOT EXISTS oauth2_authorization (
    id VARCHAR(100) PRIMARY KEY,
    registered_client_id VARCHAR(100) NOT NULL,
    principal_name VARCHAR(255) NOT NULL,
    authorization_grant_type VARCHAR(100),
    authorized_scopes VARCHAR(1000),
    attributes TEXT,
    
    access_token_value BYTEA,
    access_token_issued_at TIMESTAMP,
    access_token_expires_at TIMESTAMP,
    access_token_type VARCHAR(100),
    access_token_scopes VARCHAR(1000),
    
    refresh_token_value BYTEA,
    refresh_token_issued_at TIMESTAMP,
    refresh_token_expires_at TIMESTAMP,
    
    oidc_id_token_value BYTEA,
    oidc_id_token_issued_at TIMESTAMP,
    oidc_id_token_expires_at TIMESTAMP,
    
    FOREIGN KEY (registered_client_id) REFERENCES oauth2_registered_client(id)
);

CREATE INDEX idx_oauth2_authorization_registered_client_id 
  ON oauth2_authorization(registered_client_id);
CREATE INDEX idx_oauth2_authorization_principal_name 
  ON oauth2_authorization(principal_name);

-- Token 黑名单表
CREATE TABLE IF NOT EXISTS token_blacklist (
    id BIGSERIAL PRIMARY KEY,
    jti VARCHAR(255) UNIQUE NOT NULL,
    token_type VARCHAR(50),
    user_id BIGINT,
    expires_at TIMESTAMP NOT NULL,
    blacklisted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reason VARCHAR(255),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX idx_token_blacklist_jti ON token_blacklist(jti);
CREATE INDEX idx_token_blacklist_expires_at ON token_blacklist(expires_at);
```

### data-postgresql.sql (初始化数据)

```sql
-- 创建测试用户
-- 密码: password123
INSERT INTO users (
    username, email, password_hash, display_name, 
    auth_provider, enabled, email_verified
) VALUES (
    'test@example.com',
    'test@example.com',
    '$2a$10$slYQmyNdGzin7olVN3p5Be7DlH.PKZbv5H8KnzzVgXXbVxzy8QKOT',
    'Test User',
    'LOCAL',
    true,
    true
) ON CONFLICT (username) DO NOTHING;

-- 给测试用户添加权限
INSERT INTO user_authorities (user_id, authority)
SELECT id, 'ROLE_USER' FROM users WHERE username = 'test@example.com'
ON CONFLICT DO NOTHING;

-- 创建管理员用户
INSERT INTO users (
    username, email, password_hash, display_name,
    auth_provider, enabled, email_verified
) VALUES (
    'admin@example.com',
    'admin@example.com',
    '$2a$10$slYQmyNdGzin7olVN3p5Be7DlH.PKZbv5H8KnzzVgXXbVxzy8QKOT',
    'Admin User',
    'LOCAL',
    true,
    true
) ON CONFLICT (username) DO NOTHING;

-- 给管理员添加权限
INSERT INTO user_authorities (user_id, authority)
SELECT id, 'ROLE_USER' FROM users WHERE username = 'admin@example.com'
ON CONFLICT DO NOTHING;

INSERT INTO user_authorities (user_id, authority)
SELECT id, 'ROLE_ADMIN' FROM users WHERE username = 'admin@example.com'
ON CONFLICT DO NOTHING;
```

### 加载初始化脚本

```bash
# 使用 psql 加载脚本
psql -U auth_user -d auth_db -f schema-postgresql.sql
psql -U auth_user -d auth_db -f data-postgresql.sql

# 验证表创建
psql -U auth_user -d auth_db -c "\dt"

# 验证数据
psql -U auth_user -d auth_db -c "SELECT * FROM users;"
```

---

## 备份和恢复

### PostgreSQL 备份

```bash
# 完整数据库备份
pg_dump -U auth_user -d auth_db > auth_db_backup.sql

# 自定义格式备份
pg_dump -U auth_user -d auth_db -Fc > auth_db_backup.dump

# 只备份数据
pg_dump -U auth_user -d auth_db --data-only > auth_db_data_only.sql
```

### 恢复

```bash
# 从 SQL 文件恢复
psql -U auth_user -d auth_db < auth_db_backup.sql

# 从自定义格式恢复
pg_restore -U auth_user -d auth_db auth_db_backup.dump
```

### 定期备份脚本

```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/var/backups/auth-db"
DB_NAME="auth_db"
DB_USER="auth_user"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

mkdir -p $BACKUP_DIR

pg_dump -U $DB_USER -d $DB_NAME | gzip > $BACKUP_DIR/auth_db_${TIMESTAMP}.sql.gz

# 保留最近 30 天的备份
find $BACKUP_DIR -name "auth_db_*.sql.gz" -mtime +30 -delete

echo "Backup completed: $BACKUP_DIR/auth_db_${TIMESTAMP}.sql.gz"
```

使用 crontab 定期运行：

```bash
# 每天凌晨 2 点执行备份
0 2 * * * /path/to/backup.sh
```

---

**下一步:** 查看 [05-Deployment-Guide.md] 获取完整的部署指南
