package com.example.oauth2demo.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Set;

/**
 * 用户DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserDto {
    private String id;  // 改为 String (UUID)
    private String username;
    private String email;
    private String displayName;
    private String avatarUrl;
    private Set<String> authorities;
    private String provider;
}