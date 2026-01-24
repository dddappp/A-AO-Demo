-- SQLite 不支持 DROP COLUMN 在某些版本，我们使用重建表的方式

-- 步骤1: 创建新表（不包含旧字段）
CREATE TABLE IF NOT EXISTS users_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
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

-- 步骤2: 复制数据到新表
INSERT INTO users_new 
SELECT id, username, email, display_name, avatar_url, email_verified, enabled, created_at, updated_at, last_login_at
FROM users;

-- 步骤3: 删除旧表
DROP TABLE users;

-- 步骤4: 重命名新表
ALTER TABLE users_new RENAME TO users;

-- 步骤5: 重新创建索引
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
