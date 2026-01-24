-- PostgreSQL数据库表结构定义

-- 用户表
-- 注意：id 改为 UUID 字符串，由应用层（Java代码）生成，而不是数据库自己生成
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY,  -- UUID 字符串格式：xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    email_verified BOOLEAN DEFAULT FALSE,
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP
);

-- 用户登录方式表
CREATE TABLE IF NOT EXISTS user_login_methods (
    id VARCHAR(36) PRIMARY KEY,  -- 此表的主键也使用 UUID
    user_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,  -- 引用 users 表的 UUID
    auth_provider TEXT NOT NULL,
    provider_user_id TEXT,
    provider_email TEXT,
    provider_username TEXT,
    local_username TEXT,
    local_password_hash TEXT,
    is_primary BOOLEAN DEFAULT FALSE,
    is_verified BOOLEAN DEFAULT FALSE,
    linked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP
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
    user_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,  -- 使用 UUID 字符串
    authority TEXT NOT NULL,
    PRIMARY KEY (user_id, authority)
);

-- Token黑名单表
CREATE TABLE IF NOT EXISTS token_blacklist (
    id VARCHAR(36) PRIMARY KEY,  -- 使用 UUID 字符串
    jti TEXT UNIQUE NOT NULL,
    token_type TEXT,
    user_id VARCHAR(36),  -- 使用 UUID 字符串，允许 NULL（非认证用户的 token）
    expires_at TIMESTAMP NOT NULL,
    blacklisted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reason TEXT
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_token_blacklist_jti ON token_blacklist(jti);
CREATE INDEX IF NOT EXISTS idx_token_blacklist_expires_at ON token_blacklist(expires_at);
