package com.example.oauth2demo.repository;

import com.example.oauth2demo.entity.TokenBlacklistEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;

/**
 * Token黑名单Repository接口
 */
@Repository
public interface TokenBlacklistRepository extends JpaRepository<TokenBlacklistEntity, String> {
    boolean existsByJti(String jti);
    Optional<TokenBlacklistEntity> findByJti(String jti);
}