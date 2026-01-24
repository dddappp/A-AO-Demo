-- 初始化测试数据 (SQLite数据库)
-- 注意：密码使用BCrypt加密，密码都是 'password123'

-- 插入测试用户
INSERT OR IGNORE INTO users (username, email, display_name, enabled, email_verified)
VALUES ('testuser', 'test@example.com', 'Test User', 1, 1);

-- 为测试用户添加本地登录方式
INSERT OR IGNORE INTO user_login_methods (user_id, auth_provider, local_username, local_password_hash, is_primary, is_verified)
SELECT id, 'LOCAL', 'testuser', '$2a$10$slYQmyNdGzin7olVN3p5Be7DlH.PKZbv5H8KnzzVgXXbVxzy8QKOT', 1, 1
FROM users WHERE username = 'testuser';

-- 给测试用户添加权限
INSERT OR IGNORE INTO user_authorities (user_id, authority)
SELECT id, 'ROLE_USER' FROM users WHERE username = 'testuser';

-- 插入管理员用户
INSERT OR IGNORE INTO users (username, email, display_name, enabled, email_verified)
VALUES ('admin', 'admin@example.com', 'Admin User', 1, 1);

-- 为管理员添加本地登录方式
INSERT OR IGNORE INTO user_login_methods (user_id, auth_provider, local_username, local_password_hash, is_primary, is_verified)
SELECT id, 'LOCAL', 'admin', '$2a$10$slYQmyNdGzin7olVN3p5Be7DlH.PKZbv5H8KnzzVgXXbVxzy8QKOT', 1, 1
FROM users WHERE username = 'admin';

-- 给管理员添加权限
INSERT OR IGNORE INTO user_authorities (user_id, authority)
SELECT id, 'ROLE_USER' FROM users WHERE username = 'admin';

INSERT OR IGNORE INTO user_authorities (user_id, authority)
SELECT id, 'ROLE_ADMIN' FROM users WHERE username = 'admin';

-- 插入前端测试用户 (与前端代码匹配)
INSERT OR IGNORE INTO users (username, email, display_name, enabled, email_verified)
VALUES ('frontenduser', 'frontend@example.com', 'Frontend User', 1, 1);

-- 为前端测试用户添加本地登录方式
INSERT OR IGNORE INTO user_login_methods (user_id, auth_provider, local_username, local_password_hash, is_primary, is_verified)
SELECT id, 'LOCAL', 'frontenduser', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 1, 1
FROM users WHERE username = 'frontenduser';

-- 给前端测试用户添加权限
INSERT OR IGNORE INTO user_authorities (user_id, authority)
SELECT id, 'ROLE_USER' FROM users WHERE username = 'frontenduser';