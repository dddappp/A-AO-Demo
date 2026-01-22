-- 初始化测试数据 (SQLite数据库)
-- 注意：密码使用BCrypt加密，密码都是 'password123'

-- 插入测试用户 (使用INSERT OR IGNORE避免重复插入)
INSERT OR IGNORE INTO users (username, email, password_hash, display_name, auth_provider, enabled, email_verified)
VALUES ('testuser', 'test@example.com',
        '$2a$10$slYQmyNdGzin7olVN3p5Be7DlH.PKZbv5H8KnzzVgXXbVxzy8QKOT',
        'Test User', 'LOCAL', 1, 1);

-- 给测试用户添加权限 (使用INSERT OR IGNORE避免重复插入)
INSERT OR IGNORE INTO user_authorities (user_id, authority)
SELECT id, 'ROLE_USER' FROM users WHERE username = 'testuser';

-- 插入管理员用户 (使用INSERT OR IGNORE避免重复插入)
INSERT OR IGNORE INTO users (username, email, password_hash, display_name, auth_provider, enabled, email_verified)
VALUES ('admin', 'admin@example.com',
        '$2a$10$slYQmyNdGzin7olVN3p5Be7DlH.PKZbv5H8KnzzVgXXbVxzy8QKOT',
        'Admin User', 'LOCAL', 1, 1);

-- 给管理员添加权限 (使用INSERT OR IGNORE避免重复插入)
INSERT OR IGNORE INTO user_authorities (user_id, authority)
SELECT id, 'ROLE_USER' FROM users WHERE username = 'admin';

INSERT OR IGNORE INTO user_authorities (user_id, authority)
SELECT id, 'ROLE_ADMIN' FROM users WHERE username = 'admin';

-- 插入前端测试用户 (与前端代码匹配，使用INSERT OR IGNORE避免重复插入)
INSERT OR IGNORE INTO users (username, email, password_hash, display_name, auth_provider, enabled, email_verified)
VALUES ('frontenduser', 'frontend@example.com',
        '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
        'Frontend User', 'LOCAL', 1, 1);

-- 给前端测试用户添加权限 (使用INSERT OR IGNORE避免重复插入)
INSERT OR IGNORE INTO user_authorities (user_id, authority)
SELECT id, 'ROLE_USER' FROM users WHERE username = 'frontenduser';