package com.example.oauth2demo.service;

import com.example.oauth2demo.dto.RegisterRequest;
import com.example.oauth2demo.dto.UserDto;
import com.example.oauth2demo.entity.UserEntity;
import com.example.oauth2demo.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Set;

/**
 * 用户业务逻辑服务
 */
@Service
@RequiredArgsConstructor
@Transactional
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    /**
     * 本地用户注册
     */
    public UserDto register(RegisterRequest request) {
        // 检查用户名和邮箱是否已存在
        if (userRepository.findByUsername(request.getUsername()).isPresent()) {
            throw new IllegalArgumentException("Username already exists");
        }

        if (userRepository.findByEmail(request.getEmail()).isPresent()) {
            throw new IllegalArgumentException("Email already exists");
        }

        // 创建新用户
        UserEntity user = new UserEntity();
        user.setUsername(request.getUsername());
        user.setEmail(request.getEmail());
        user.setPasswordHash(passwordEncoder.encode(request.getPassword()));
        user.setDisplayName(request.getDisplayName());
        user.setAuthProvider(UserEntity.AuthProvider.LOCAL);
        user.setAuthorities(Set.of("ROLE_USER"));  // 默认权限
        user.setEnabled(true);
        user.setEmailVerified(false);

        userRepository.save(user);
        return convertToDto(user);
    }

    /**
     * 本地用户登录 - 验证用户名和密码
     */
    @Transactional(readOnly = true)
    public UserDto login(String username, String password) {
        UserEntity user = userRepository.findByUsername(username)
            .orElseThrow(() -> new RuntimeException("User not found"));

        // 验证密码
        if (!passwordEncoder.matches(password, user.getPasswordHash())) {
            throw new RuntimeException("Invalid password");
        }

        return convertToDto(user);
    }

    /**
     * 获取或创建OAuth2用户
     */
    public UserDto getOrCreateOAuthUser(UserEntity.AuthProvider provider,
                                        String providerUserId,
                                        String email,
                                        String name,
                                        String picture) {
        // 尝试查找已存在的用户
        var existingUser = userRepository
            .findByAuthProviderAndProviderUserId(provider, providerUserId);

        if (existingUser.isPresent()) {
            return convertToDto(existingUser.get());
        }

        // 检查邮箱是否已被其他用户使用
        if (email != null && userRepository.findByEmail(email).isPresent()) {
            throw new IllegalArgumentException("Email already registered with different provider");
        }

        // 为没有邮箱的OAuth用户生成虚拟邮箱
        if (email == null) {
            email = provider.name().toLowerCase() + "_" + providerUserId + "@oauth.local";
        }

        // 创建新OAuth用户
        UserEntity newUser = new UserEntity();
        newUser.setEmail(email);
        newUser.setUsername(email);
        newUser.setDisplayName(name);
        newUser.setAvatarUrl(picture);
        newUser.setAuthProvider(provider);
        newUser.setProviderUserId(providerUserId);
        newUser.setEmailVerified(email != null);  // OAuth用户邮箱通常已验证
        newUser.setAuthorities(Set.of("ROLE_USER"));
        newUser.setEnabled(true);

        userRepository.save(newUser);
        return convertToDto(newUser);
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

    private UserDto convertToDto(UserEntity user) {
        UserDto dto = new UserDto();
        dto.setId(user.getId());
        dto.setUsername(user.getUsername());
        dto.setEmail(user.getEmail());
        dto.setDisplayName(user.getDisplayName());
        dto.setAvatarUrl(user.getAvatarUrl());
        return dto;
    }
}