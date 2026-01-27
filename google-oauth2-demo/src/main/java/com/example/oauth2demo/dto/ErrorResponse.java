package com.example.oauth2demo.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 统一错误响应格式
 */
@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class ErrorResponse {
    
    // 错误状态码
    private int status;
    
    // 错误消息
    private String message;
    
    // 错误详情
    private String detail;
    
    // 错误时间
    private LocalDateTime timestamp;
    
    // 错误路径
    private String path;
    
    // 错误代码
    private String errorCode;
}
