package com.example.oauth2demo.service;

import com.example.oauth2demo.dto.RegisterRequest;
import com.example.oauth2demo.dto.UserDto;
import com.example.oauth2demo.entity.UserEntity;
import com.example.oauth2demo.entity.UserLoginMethod;
import com.example.oauth2demo.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

/**
 * 用户业务逻辑服务
 */
@Service
@RequiredArgsConstructor
@Transactional
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final LoginMethodService loginMethodService;

    /**
     * 本地用户注册
     */
    public UserDto register(RegisterRequest request) {
        // 检查本地用户名是否已被使用
        if (loginMethodService.findByLocalUsername(request.getUsername()) != null) {
            throw new IllegalArgumentException("Username already exists");
        }

        if (userRepository.findByEmail(request.getEmail()).isPresent()) {
            throw new IllegalArgumentException("Email already exists");
        }

        // 创建新用户实体
        UserEntity user = new UserEntity();
        user.setId(UUID.randomUUID().toString());  // 生成 UUID
        user.setUsername(request.getUsername());
        user.setEmail(request.getEmail());
        user.setDisplayName(request.getDisplayName());
        Set<String> authorities = new HashSet<>();
        authorities.add("ROLE_USER");
        user.setAuthorities(authorities);  // 默认权限
        user.setEnabled(true);
        user.setEmailVerified(false);

        userRepository.save(user);

        // 创建本地登录方式
        UserLoginMethod loginMethod = UserLoginMethod.builder()
            .id(UUID.randomUUID().toString())  // 生成 UUID
            .user(user)
            .authProvider(UserLoginMethod.AuthProvider.LOCAL)
            .localUsername(request.getUsername())
            .localPasswordHash(passwordEncoder.encode(request.getPassword()))
            .isPrimary(true)
            .isVerified(false)
            .build();

        user.addLoginMethod(loginMethod);
        userRepository.save(user);

        return convertToDto(user);
    }

    /**
     * 本地用户登录 - 验证用户名和密码
     */
    @Transactional(readOnly = true)
    public UserDto login(String username, String password) {
        // 从登录方式表查找本地登录方式
        UserLoginMethod loginMethod = loginMethodService.findByLocalUsername(username);
        if (loginMethod == null) {
            throw new RuntimeException("User not found");
        }

        // 验证密码
        if (!passwordEncoder.matches(password, loginMethod.getLocalPasswordHash())) {
            throw new RuntimeException("Invalid password");
        }

        // 更新最后使用时间
        loginMethodService.updateLastUsedAt(loginMethod.getId());

        return convertToDto(loginMethod.getUser());
    }

    /**
     * 获取或创建OAuth2用户
     * 
     * @param isBinding 是否为绑定流程（true=绑定到已登录用户，false=登录/注册流程）
     * @param existingUserId 如果是绑定流程，传入已登录用户ID
     */
    public UserDto getOrCreateOAuthUser(
            String provider,
            String providerUserId,
            String email,
            String name,
            String picture,
            boolean isBinding,
            String existingUserId) {
        
        // 1. 查找是否已存在该OAuth2登录方式
        UserLoginMethod existingMethod = loginMethodService.findByOAuth2Provider(
            UserLoginMethod.AuthProvider.valueOf(provider.toUpperCase()),
            providerUserId
        );
        
        if (existingMethod != null) {
            // 场景A: OAuth2账户已存在
            if (isBinding && !existingMethod.getUser().getId().equals(existingUserId)) {
                throw new IllegalArgumentException("该OAuth2账户已被其他用户绑定");
            }
            // 更新最后使用时间
            loginMethodService.updateLastUsedAt(existingMethod.getId());
            return convertToDto(existingMethod.getUser());
        }
        
        if (isBinding) {
            // 场景B: 绑定流程 - 关联到现有用户
            UserEntity existingUser = userRepository.findById(existingUserId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
            
            loginMethodService.bindOAuth2LoginMethod(
                existingUserId,
                UserLoginMethod.AuthProvider.valueOf(provider.toUpperCase()),
                providerUserId,
                email,
                name
            );
            
            return convertToDto(existingUser);
        } else {
            // 场景C: 登录流程 - 创建新用户
            
            // 检查邮箱是否已被使用
            if (email != null && userRepository.findByEmail(email).isPresent()) {
                throw new IllegalArgumentException("Email already registered with different provider");
            }
            
            // 生成虚拟邮箱（如果没有邮箱）
            if (email == null) {
                email = provider.toLowerCase() + "_" + providerUserId + "@oauth.local";
            }
            
            // 创建用户
            UserEntity newUser = new UserEntity();
            newUser.setId(UUID.randomUUID().toString());  // 生成 UUID
            newUser.setEmail(email);
            newUser.setUsername(email);
            newUser.setDisplayName(name);
            newUser.setAvatarUrl(picture);
            newUser.setEmailVerified(true);
            Set<String> authorities = new HashSet<>();
            authorities.add("ROLE_USER");
            newUser.setAuthorities(authorities);
            newUser.setEnabled(true);
            
            userRepository.save(newUser);
            
            // 创建OAuth2登录方式
            UserLoginMethod loginMethod = UserLoginMethod.builder()
                .id(UUID.randomUUID().toString())  // 生成 UUID
                .user(newUser)
                .authProvider(UserLoginMethod.AuthProvider.valueOf(provider.toUpperCase()))
                .providerUserId(providerUserId)
                .providerEmail(email)
                .providerUsername(name)
                .isPrimary(true)
                .isVerified(true)
                .build();
            
            newUser.addLoginMethod(loginMethod);
            userRepository.save(newUser);
            
            return convertToDto(newUser);
        }
    }

    /**
     * 获取当前用户信息
     */
    @Transactional(readOnly = true)
    public UserDto getCurrentUser(String username) {
        UserEntity user = userRepository.findByUsername(username)
            .orElseThrow(() -> new RuntimeException("User not found"));
        return convertToDto(user);
    }

    /**
     * 根据用户ID获取用户信息
     */
    @Transactional(readOnly = true)
    public UserDto getUserById(String userId) {
        UserEntity user = userRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("User not found"));
        return convertToDto(user);
    }

    /**
     * 获取或创建OAuth2用户（重载方法，用于向后兼容现有调用）
     */
    public UserDto getOrCreateOAuthUser(String provider,
                                        String providerUserId,
                                        String email,
                                        String name,
                                        String picture) {
        // 调用新的方法，isBinding=false（登录流程）
        return getOrCreateOAuthUser(provider, providerUserId, email, name, picture, false, null);
    }

    private UserDto convertToDto(UserEntity user) {
        UserDto dto = new UserDto();
        dto.setId(user.getId());
        dto.setUsername(user.getUsername());
        dto.setEmail(user.getEmail());
        dto.setDisplayName(user.getDisplayName());
        dto.setAvatarUrl(user.getAvatarUrl());
        dto.setAuthorities(user.getAuthorities());
        
        // 获取主要登录方式的provider信息
        if (!user.getLoginMethods().isEmpty()) {
            // 找到主要登录方式
            UserLoginMethod primaryMethod = user.getLoginMethods().stream()
                .filter(UserLoginMethod::isPrimary)
                .findFirst()
                .orElse(user.getLoginMethods().iterator().next());
            
            dto.setProvider(primaryMethod.getAuthProvider().name().toLowerCase());
        }
        
        return dto;
    }
}