package com.example.oauth2demo.service;

import com.example.oauth2demo.entity.UserEntity;
import com.example.oauth2demo.entity.UserLoginMethod;
import com.example.oauth2demo.entity.UserLoginMethod.AuthProvider;
import com.example.oauth2demo.repository.UserLoginMethodRepository;
import com.example.oauth2demo.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/**
 * 登录方式管理服务
 */
@Service
@RequiredArgsConstructor
@Transactional
@Slf4j
public class LoginMethodService {

    private final UserLoginMethodRepository loginMethodRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    /**
     * 获取用户的所有登录方式
     */
    @Transactional(readOnly = true)
    public List<UserLoginMethod> getUserLoginMethods(String userId) {
        return loginMethodRepository.findByUserId(userId);
    }

    /**
     * 为用户绑定OAuth2登录方式
     * 
     * @throws IllegalStateException 如果该提供商已被该用户绑定
     * @throws IllegalArgumentException 如果OAuth2账户已被其他用户绑定
     */
    public UserLoginMethod bindOAuth2LoginMethod(
            String userId,
            AuthProvider provider,
            String providerUserId,
            String providerEmail,
            String providerUsername) {
        
        log.info("Binding OAuth2 login method: userId={}, provider={}, providerUserId={}",
                userId, provider, providerUserId);
        
        // 1. 检查用户是否已经绑定该提供商
        if (loginMethodRepository.findByUserIdAndAuthProvider(userId, provider).isPresent()) {
            throw new IllegalStateException("用户已绑定该登录方式");
        }
        
        // 2. 检查OAuth2账户是否已被其他用户绑定
        loginMethodRepository.findByAuthProviderAndProviderUserId(provider, providerUserId)
            .ifPresent(existing -> {
                if (!existing.getUser().getId().equals(userId)) {
                    throw new IllegalArgumentException("该OAuth2账户已被其他用户绑定");
                }
            });
        
        // 3. 创建新的登录方式
        UserEntity user = userRepository.findById(userId)
            .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
        
        UserLoginMethod loginMethod = UserLoginMethod.builder()
            .id(UUID.randomUUID().toString())  // 生成 UUID
            .user(user)
            .authProvider(provider)
            .providerUserId(providerUserId)
            .providerEmail(providerEmail)
            .providerUsername(providerUsername)
            .isVerified(true)  // OAuth2用户默认已验证
            .isPrimary(false)  // 新绑定的不是主登录方式
            .build();
        
        UserLoginMethod saved = loginMethodRepository.save(loginMethod);
        log.info("OAuth2 login method bound successfully: id={}", saved.getId());
        
        return saved;
    }

    /**
     * 通过本地用户名查找登录方式
     * 用于本地登录验证
     */
    @Transactional(readOnly = true)
    public UserLoginMethod findByLocalUsername(String username) {
        return loginMethodRepository.findByLocalUsername(username)
            .orElse(null);
    }

    /**
     * 通过OAuth2信息查找登录方式
     * 用于OAuth2登录
     */
    @Transactional(readOnly = true)
    public UserLoginMethod findByOAuth2Provider(AuthProvider provider, String providerUserId) {
        return loginMethodRepository.findByAuthProviderAndProviderUserId(provider, providerUserId)
            .orElse(null);
    }

    /**
     * 更新登录方式的最后使用时间
     */
    public void updateLastUsedAt(String loginMethodId) {
        loginMethodRepository.findById(loginMethodId).ifPresent(method -> {
            method.updateLastUsedAt();
            loginMethodRepository.save(method);
        });
    }

    /**
     * 移除登录方式
     * 
     * @throws IllegalStateException 如果是最后一个登录方式
     */
    public void removeLoginMethod(String userId, String loginMethodId) {
        log.info("Removing login method: userId={}, loginMethodId={}", userId, loginMethodId);
        
        // 1. 检查登录方式是否属于该用户
        UserLoginMethod method = loginMethodRepository.findById(loginMethodId)
            .orElseThrow(() -> new IllegalArgumentException("登录方式不存在"));
        
        if (!method.getUser().getId().equals(userId)) {
            throw new IllegalArgumentException("无权移除该登录方式");
        }
        
        // 2. 在事务内检查是否至少有两个登录方式
        List<UserLoginMethod> methods = loginMethodRepository.findByUserId(userId);
        if (methods.size() <= 1) {
            throw new IllegalStateException("不能移除最后一个登录方式");
        }
        
        // 3. 如果是主登录方式，需要先设置另一个为主登录方式
        if (method.isPrimary()) {
            UserLoginMethod newPrimary = methods.stream()
                .filter(m -> !m.getId().equals(loginMethodId))
                .findFirst()
                .orElseThrow();
            
            newPrimary.setPrimary(true);
            loginMethodRepository.save(newPrimary);
            log.info("Set new primary login method: id={}", newPrimary.getId());
        }
        
        // 4. 删除登录方式
        loginMethodRepository.delete(method);
        log.info("Login method removed successfully");
    }

    /**
     * 设置主登录方式
     */
    public void setPrimaryLoginMethod(String userId, String loginMethodId) {
        log.info("Setting primary login method: userId={}, loginMethodId={}", userId, loginMethodId);
        
        // 1. 验证登录方式属于该用户
        UserLoginMethod method = loginMethodRepository.findById(loginMethodId)
            .orElseThrow(() -> new IllegalArgumentException("登录方式不存在"));
        
        if (!method.getUser().getId().equals(userId)) {
            throw new IllegalArgumentException("无权设置该登录方式");
        }
        
        // 2. 取消当前主登录方式
        loginMethodRepository.findByUserIdAndIsPrimary(userId, true)
            .ifPresent(current -> {
                current.setPrimary(false);
                loginMethodRepository.save(current);
            });
        
        // 3. 设置新的主登录方式
        method.setPrimary(true);
        loginMethodRepository.save(method);
        
        log.info("Primary login method set successfully");
    }

    /**
     * 为已登录用户添加本地登录方式（用于SSO用户添加本地密码）
     * 
     * 场景：用户通过SSO登录后，想添加本地用户名/密码登录方式
     * 
     * @throws IllegalStateException 如果用户已有本地登录方式
     * @throws IllegalArgumentException 如果用户名已被使用
     */
    public UserLoginMethod addLocalLoginMethod(
            String userId,
            String username,
            String password) {
        
        log.info("Adding local login method for SSO user: userId={}, username={}", userId, username);
        
        // 1. 检查用户是否已有本地登录方式
        if (loginMethodRepository.findByUserIdAndAuthProvider(userId, AuthProvider.LOCAL).isPresent()) {
            throw new IllegalStateException("该用户已有本地登录方式，无法重复添加");
        }
        
        // 2. 检查用户名是否已被使用
        if (loginMethodRepository.existsByLocalUsername(username)) {
            throw new IllegalArgumentException("用户名已被使用，请选择其他用户名");
        }
        
        // 3. 获取用户
        UserEntity user = userRepository.findById(userId)
            .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
        
        // 4. 创建新的本地登录方式
        UserLoginMethod loginMethod = UserLoginMethod.builder()
            .id(UUID.randomUUID().toString())  // 生成 UUID
            .user(user)
            .authProvider(AuthProvider.LOCAL)
            .localUsername(username)
            .localPasswordHash(passwordEncoder.encode(password))
            .isPrimary(false)  // 新添加的不是主登录方式
            .isVerified(false)  // 未验证（可选：可以改为true如果不需要验证）
            .build();
        
        UserLoginMethod saved = loginMethodRepository.save(loginMethod);
        log.info("Local login method added successfully: id={}", saved.getId());
        
        return saved;
    }
}
