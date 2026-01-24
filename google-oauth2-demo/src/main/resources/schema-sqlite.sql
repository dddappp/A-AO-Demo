-- SQLite数据库表结构定义 (开发环境)
-- 此文件用于 dev 环境
-- 生产环境请使用 schema-postgresql.sql
-- 
-- 注意：所有 ID 均改为 UUID 字符串，由应用层（Java代码）生成

-- 用户表
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,  -- UUID 字符串格式：xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    email_verified INTEGER DEFAULT 0,
    enabled INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_login_at DATETIME
);

-- 用户登录方式表
CREATE TABLE IF NOT EXISTS user_login_methods (
    id TEXT PRIMARY KEY,  -- UUID 字符串
    user_id TEXT NOT NULL,  -- UUID 字符串
    auth_provider TEXT NOT NULL,
    provider_user_id TEXT,
    provider_email TEXT,
    provider_username TEXT,
    local_username TEXT,
    local_password_hash TEXT,
    is_primary INTEGER DEFAULT 0,
    is_verified INTEGER DEFAULT 0,
    linked_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_used_at DATETIME,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 用户登录方式的唯一性约束
CREATE UNIQUE INDEX IF NOT EXISTS uk_user_login_provider 
    ON user_login_methods(user_id, auth_provider);

CREATE UNIQUE INDEX IF NOT EXISTS uk_local_username 
    ON user_login_methods(local_username) 
    WHERE local_username IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uk_provider_user 
    ON user_login_methods(auth_provider, provider_user_id)
    WHERE provider_user_id IS NOT NULL;

-- 用户登录方式的查询索引
CREATE INDEX IF NOT EXISTS idx_login_methods_user_id 
    ON user_login_methods(user_id);

CREATE INDEX IF NOT EXISTS idx_login_methods_provider 
    ON user_login_methods(auth_provider, provider_user_id);

CREATE INDEX IF NOT EXISTS idx_login_methods_primary 
    ON user_login_methods(user_id, is_primary);

-- 用户权限关联表
CREATE TABLE IF NOT EXISTS user_authorities (
    user_id TEXT NOT NULL,  -- UUID 字符串
    authority TEXT NOT NULL,
    PRIMARY KEY (user_id, authority),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Token黑名单表
CREATE TABLE IF NOT EXISTS token_blacklist (
    id TEXT PRIMARY KEY,  -- UUID 字符串
    jti TEXT UNIQUE NOT NULL,
    token_type TEXT,
    user_id TEXT,  -- UUID 字符串，允许 NULL（非认证用户的 token）
    expires_at DATETIME NOT NULL,
    blacklisted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    reason TEXT
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_token_blacklist_jti ON token_blacklist(jti);
CREATE INDEX IF NOT EXISTS idx_token_blacklist_expires_at ON token_blacklist(expires_at);