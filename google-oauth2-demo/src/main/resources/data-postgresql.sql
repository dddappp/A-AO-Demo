-- PostgreSQL初始化测试数据
-- 注意：密码使用BCrypt加密，密码都是 'password123'

-- 插入测试用户
INSERT INTO users (username, email, display_name, enabled, email_verified)
VALUES ('testuser', 'test@example.com', 'Test User', true, true)
ON CONFLICT (username) DO NOTHING;

-- 为测试用户添加本地登录方式
INSERT INTO user_login_methods (user_id, auth_provider, local_username, local_password_hash, is_primary, is_verified)
SELECT id, 'LOCAL', 'testuser', '$2a$10$slYQmyNdGzin7olVN3p5Be7DlH.PKZbv5H8KnzzVgXXbVxzy8QKOT', true, true
FROM users WHERE username = 'testuser'
ON CONFLICT (user_id, auth_provider) DO NOTHING;

-- 给测试用户添加权限
INSERT INTO user_authorities (user_id, authority)
SELECT id, 'ROLE_USER' FROM users WHERE username = 'testuser'
ON CONFLICT (user_id, authority) DO NOTHING;

-- 插入管理员用户
INSERT INTO users (username, email, display_name, enabled, email_verified)
VALUES ('admin', 'admin@example.com', 'Admin User', true, true)
ON CONFLICT (username) DO NOTHING;

-- 为管理员添加本地登录方式
INSERT INTO user_login_methods (user_id, auth_provider, local_username, local_password_hash, is_primary, is_verified)
SELECT id, 'LOCAL', 'admin', '$2a$10$slYQmyNdGzin7olVN3p5Be7DlH.PKZbv5H8KnzzVgXXbVxzy8QKOT', true, true
FROM users WHERE username = 'admin'
ON CONFLICT (user_id, auth_provider) DO NOTHING;

-- 给管理员添加权限
INSERT INTO user_authorities (user_id, authority)
SELECT id, 'ROLE_USER' FROM users WHERE username = 'admin'
ON CONFLICT (user_id, authority) DO NOTHING;

INSERT INTO user_authorities (user_id, authority)
SELECT id, 'ROLE_ADMIN' FROM users WHERE username = 'admin'
ON CONFLICT (user_id, authority) DO NOTHING;

-- 插入前端测试用户 (与前端代码匹配)
INSERT INTO users (username, email, display_name, enabled, email_verified)
VALUES ('frontenduser', 'frontend@example.com', 'Frontend User', true, true)
ON CONFLICT (username) DO NOTHING;

-- 为前端测试用户添加本地登录方式
INSERT INTO user_login_methods (user_id, auth_provider, local_username, local_password_hash, is_primary, is_verified)
SELECT id, 'LOCAL', 'frontenduser', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', true, true
FROM users WHERE username = 'frontenduser'
ON CONFLICT (user_id, auth_provider) DO NOTHING;

-- 给前端测试用户添加权限
INSERT INTO user_authorities (user_id, authority)
SELECT id, 'ROLE_USER' FROM users WHERE username = 'frontenduser'
ON CONFLICT (user_id, authority) DO NOTHING;

-- 为test环境创建额外的测试账户
-- testlocal: 本地登录用户（场景1）
INSERT INTO users (username, email, display_name, enabled, email_verified)
VALUES ('testlocal', 'testlocal@example.com', 'Test Local User', true, true)
ON CONFLICT (username) DO NOTHING;

INSERT INTO user_login_methods (user_id, auth_provider, local_username, local_password_hash, is_primary, is_verified)
SELECT id, 'LOCAL', 'testlocal', '$2a$10$slYQmyNdGzin7olVN3p5Be7DlH.PKZbv5H8KnzzVgXXbVxzy8QKOT', true, true
FROM users WHERE username = 'testlocal'
ON CONFLICT (user_id, auth_provider) DO NOTHING;

INSERT INTO user_authorities (user_id, authority)
SELECT id, 'ROLE_USER' FROM users WHERE username = 'testlocal'
ON CONFLICT (user_id, authority) DO NOTHING;

-- testsso: SSO登录用户（场景2）
INSERT INTO users (username, email, display_name, enabled, email_verified)
VALUES ('testsso', 'testsso@example.com', 'Test SSO User', true, true)
ON CONFLICT (username) DO NOTHING;

INSERT INTO user_login_methods (user_id, auth_provider, provider_user_id, provider_email, provider_username, is_primary, is_verified)
SELECT id, 'GOOGLE', 'mock_google_testsso', 'testsso@gmail.com', 'Test SSO User', true, true
FROM users WHERE username = 'testsso'
ON CONFLICT (user_id, auth_provider) DO NOTHING;

INSERT INTO user_authorities (user_id, authority)
SELECT id, 'ROLE_USER' FROM users WHERE username = 'testsso'
ON CONFLICT (user_id, authority) DO NOTHING;

-- testboth: 本地+SSO双方式用户（场景3）
INSERT INTO users (username, email, display_name, enabled, email_verified)
VALUES ('testboth', 'testboth@example.com', 'Test Both User', true, true)
ON CONFLICT (username) DO NOTHING;

INSERT INTO user_login_methods (user_id, auth_provider, local_username, local_password_hash, is_primary, is_verified)
SELECT id, 'LOCAL', 'testboth', '$2a$10$slYQmyNdGzin7olVN3p5Be7DlH.PKZbv5H8KnzzVgXXbVxzy8QKOT', true, true
FROM users WHERE username = 'testboth'
ON CONFLICT (user_id, auth_provider) DO NOTHING;

INSERT INTO user_login_methods (user_id, auth_provider, provider_user_id, provider_email, provider_username, is_primary, is_verified)
SELECT id, 'GOOGLE', 'mock_google_testboth', 'testboth@gmail.com', 'Test Both User', false, true
FROM users WHERE username = 'testboth'
ON CONFLICT (user_id, auth_provider) DO NOTHING;

INSERT INTO user_authorities (user_id, authority)
SELECT id, 'ROLE_USER' FROM users WHERE username = 'testboth'
ON CONFLICT (user_id, authority) DO NOTHING;
