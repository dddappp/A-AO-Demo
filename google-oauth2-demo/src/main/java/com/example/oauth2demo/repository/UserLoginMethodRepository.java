package com.example.oauth2demo.repository;

import com.example.oauth2demo.entity.UserLoginMethod;
import com.example.oauth2demo.entity.UserLoginMethod.AuthProvider;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserLoginMethodRepository extends JpaRepository<UserLoginMethod, String> {
    
    /**
     * 查找用户的所有登录方式
     */
    List<UserLoginMethod> findByUserId(String userId);
    
    /**
     * 查找用户的特定登录方式
     */
    Optional<UserLoginMethod> findByUserIdAndAuthProvider(String userId, AuthProvider authProvider);
    
    /**
     * 通过OAuth2提供商和用户ID查找
     */
    Optional<UserLoginMethod> findByAuthProviderAndProviderUserId(
        AuthProvider authProvider, String providerUserId);
    
    /**
     * 通过本地用户名查找
     */
    Optional<UserLoginMethod> findByLocalUsername(String localUsername);
    
    /**
     * 查找用户的主登录方式
     */
    Optional<UserLoginMethod> findByUserIdAndIsPrimary(String userId, boolean isPrimary);
    
    /**
     * 检查OAuth2账户是否已被绑定
     */
    boolean existsByAuthProviderAndProviderUserId(AuthProvider authProvider, String providerUserId);
    
    /**
     * 检查本地用户名是否已被使用
     */
    boolean existsByLocalUsername(String localUsername);
}
