-- 迁移本地用户
INSERT INTO user_login_methods (
    user_id,
    auth_provider,
    local_username,
    local_password_hash,
    is_primary,
    is_verified,
    linked_at
)
SELECT
    id,
    'LOCAL',
    username,
    password_hash,
    1,
    CASE WHEN email_verified = 1 THEN 1 ELSE 0 END,
    created_at
FROM users
WHERE auth_provider = 'LOCAL'
  AND password_hash IS NOT NULL
  AND username IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM user_login_methods ulm 
      WHERE ulm.user_id = users.id AND ulm.auth_provider = 'LOCAL'
  );

-- 迁移Google用户
INSERT INTO user_login_methods (
    user_id,
    auth_provider,
    provider_user_id,
    provider_email,
    provider_username,
    is_primary,
    is_verified,
    linked_at
)
SELECT
    id,
    'GOOGLE',
    provider_user_id,
    email,
    display_name,
    1,
    1,
    created_at
FROM users
WHERE auth_provider = 'GOOGLE'
  AND provider_user_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM user_login_methods ulm 
      WHERE ulm.user_id = users.id AND ulm.auth_provider = 'GOOGLE'
  );

-- 迁移GitHub用户
INSERT INTO user_login_methods (
    user_id,
    auth_provider,
    provider_user_id,
    provider_email,
    provider_username,
    is_primary,
    is_verified,
    linked_at
)
SELECT
    id,
    'GITHUB',
    provider_user_id,
    email,
    display_name,
    1,
    1,
    created_at
FROM users
WHERE auth_provider = 'GITHUB'
  AND provider_user_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM user_login_methods ulm 
      WHERE ulm.user_id = users.id AND ulm.auth_provider = 'GITHUB'
  );

-- 迁移Twitter用户
INSERT INTO user_login_methods (
    user_id,
    auth_provider,
    provider_user_id,
    provider_email,
    provider_username,
    is_primary,
    is_verified,
    linked_at
)
SELECT
    id,
    'TWITTER',
    provider_user_id,
    email,
    display_name,
    1,
    1,
    created_at
FROM users
WHERE auth_provider = 'TWITTER'
  AND provider_user_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM user_login_methods ulm 
      WHERE ulm.user_id = users.id AND ulm.auth_provider = 'TWITTER'
  );
