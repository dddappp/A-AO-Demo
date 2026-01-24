package com.example.oauth2demo.service;

import com.example.oauth2demo.entity.UserEntity;
import com.example.oauth2demo.entity.UserLoginMethod;
import com.example.oauth2demo.repository.UserLoginMethodRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

/**
 * 自定义用户详情服务
 * Spring Authorization Server会调用此服务进行本地用户认证
 */
@Service
@RequiredArgsConstructor
public class CustomUserDetailsService implements UserDetailsService {

    private final UserLoginMethodRepository loginMethodRepository;

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        // 从user_login_methods表查询本地登录方式
        UserLoginMethod loginMethod = loginMethodRepository.findByLocalUsername(username)
            .orElseThrow(() -> new UsernameNotFoundException("User not found: " + username));

        UserEntity user = loginMethod.getUser();
        
        if (!user.isEnabled()) {
            throw new UsernameNotFoundException("User is disabled: " + username);
        }

        // 将UserEntity的authorities转换为Spring Security的GrantedAuthority
        var grantedAuthorities = user.getAuthorities().stream()
            .map(SimpleGrantedAuthority::new)
            .toList();

        return User.builder()
            .username(username)
            .password(loginMethod.getLocalPasswordHash())  // BCrypt hash from user_login_methods
            .authorities(grantedAuthorities)   // 从数据库读取权限
            .accountExpired(false)
            .accountLocked(false)
            .credentialsExpired(false)
            .disabled(!user.isEnabled())
            .build();
    }
}