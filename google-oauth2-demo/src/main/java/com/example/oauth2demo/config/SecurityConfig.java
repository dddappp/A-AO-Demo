package com.example.oauth2demo.config;

import com.example.oauth2demo.entity.UserEntity;
import com.example.oauth2demo.service.UserService;
import com.example.oauth2demo.dto.UserDto;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.client.OAuth2AuthorizedClient;
import org.springframework.security.oauth2.client.OAuth2AuthorizedClientService;
import org.springframework.security.oauth2.client.userinfo.OAuth2UserRequest;
import org.springframework.security.oauth2.client.userinfo.OAuth2UserService;
import org.springframework.security.oauth2.client.userinfo.DefaultOAuth2UserService;
import org.springframework.security.oauth2.core.OAuth2AccessToken;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;
import org.springframework.security.oauth2.core.user.DefaultOAuth2User;
import org.springframework.security.oauth2.core.user.OAuth2User;
import org.springframework.security.oauth2.client.registration.ClientRegistrationRepository;
import org.springframework.security.oauth2.client.web.DefaultOAuth2AuthorizationRequestResolver;
import org.springframework.security.oauth2.client.web.OAuth2AuthorizationRequestResolver;
import org.springframework.security.oauth2.client.web.OAuth2AuthorizationRequestCustomizers;
import org.springframework.security.oauth2.core.endpoint.OAuth2AuthorizationRequest;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.AuthenticationSuccessHandler;
import org.springframework.security.web.csrf.CookieCsrfTokenRepository;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.ProviderManager;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.client.RestTemplate;
import com.example.oauth2demo.service.JwtTokenService;
import org.springframework.http.*;
import org.springframework.core.ParameterizedTypeReference;
import java.util.List;

import java.io.IOException;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import com.fasterxml.jackson.databind.ObjectMapper;

@Configuration
@EnableWebSecurity
public class SecurityConfig {



    @Autowired
    private UserService userService;

    @Bean
    public RestTemplate restTemplate() {
        return new RestTemplate();
    }

    @Autowired
    private OAuth2AuthorizedClientService authorizedClientService;

    @Autowired
    private ClientRegistrationRepository clientRegistrationRepository;

    @Autowired
    private UserDetailsService userDetailsService;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtTokenService jwtTokenService;

    @Autowired
    private com.example.oauth2demo.service.LoginMethodService loginMethodService;

    /**
     * 配置AuthenticationManager用于本地用户认证
     */
    @Bean
    public AuthenticationManager authenticationManager() {
        DaoAuthenticationProvider authProvider = new DaoAuthenticationProvider();
        authProvider.setUserDetailsService(userDetailsService);
        authProvider.setPasswordEncoder(passwordEncoder);
        return new ProviderManager(authProvider);
    }

    /**
     * OAuth2登录成功处理器 - 智能路由版本
     * 根据用户登录状态自动选择登录或绑定流程
     * 支持Token双重传递（cookie + JSON响应体）
     */
    @Bean
    public AuthenticationSuccessHandler oauth2SuccessHandler() {
        return new AuthenticationSuccessHandler() {
            @Override
            public void onAuthenticationSuccess(HttpServletRequest request, HttpServletResponse response,
                                              Authentication authentication) throws IOException {
                System.out.println("=== OAuth2 Authentication Success - Smart Routing ===");

                try {
                    // 🎯 核心：检查用户是否已登录
                    String currentUserId = getCurrentUserIdFromRequest(request);
                    boolean isUserLoggedIn = false;
                    
                    // 验证用户是否真正存在（防止无效token导致的绑定失败）
                    if (currentUserId != null) {
                        try {
                            if (userService.getUserById(currentUserId) != null) {
                                isUserLoggedIn = true;
                            } else {
                                System.out.println("User ID extracted from token does not exist: " + currentUserId);
                                currentUserId = null;
                            }
                        } catch (Exception e) {
                            System.out.println("Failed to verify user existence: " + e.getMessage());
                            currentUserId = null;
                        }
                    }
                    
                    System.out.println("User login status: " + (isUserLoggedIn ? "LOGGED_IN" : "NOT_LOGGED_IN") + 
                                     ", userId: " + currentUserId);

                    UserDto userDto = null;
                    String accessToken = null;
                    String refreshToken = null;

                    // 处理Google用户（OpenID Connect）
                    if (authentication.getPrincipal() instanceof OidcUser oidcUser) {
                        String providerUserId = oidcUser.getSubject();
                        String email = oidcUser.getEmail();
                        String name = oidcUser.getFullName();
                        String picture = oidcUser.getPicture();

                        // 调用新的方法，传入isBinding和currentUserId
                        userDto = userService.getOrCreateOAuthUser(
                            "GOOGLE",
                            providerUserId, email, name, picture,
                            isUserLoggedIn, currentUserId
                        );

                        System.out.println("Provider: Google");
                        System.out.println("User: " + name);
                        System.out.println("Email: " + email);
                    }
                    // 处理GitHub和Twitter用户（OAuth2）
                    else if (authentication.getPrincipal() instanceof OAuth2User oauth2User) {
                        String provider = determineProvider(oauth2User);
                        // ✅ 最小修复：registrationId 'x' 对应枚举值 'TWITTER'（UserService 需要枚举值）
                        if (authentication instanceof org.springframework.security.oauth2.client.authentication.OAuth2AuthenticationToken oauth2Token) {
                            String registrationId = oauth2Token.getAuthorizedClientRegistrationId();
                            System.out.println("=== OAuth2 Success Handler ===");
                            System.out.println("Registration ID: " + registrationId);
                            if ("x".equals(registrationId)) {
                                provider = "TWITTER";  // UserService 需要枚举值 "TWITTER"
                            } else if ("github".equals(registrationId)) {
                                provider = "GITHUB";  // UserService 需要枚举值 "GITHUB"
                            }
                        }
                        System.out.println("Final provider: " + provider);
                        String providerUserId = getProviderUserId(oauth2User, provider);
                        String email = getProviderEmail(oauth2User, provider);
                        String name = getProviderName(oauth2User, provider);
                        String picture = getProviderPicture(oauth2User, provider);

                        userDto = userService.getOrCreateOAuthUser(
                            provider, providerUserId, email, name, picture,
                            isUserLoggedIn, currentUserId
                        );

                        System.out.println("Provider: " + provider);
                        System.out.println("User: " + name);
                        System.out.println("Email: " + email);
                    }

                    if (userDto != null) {
                        // 🎯 统一处理：无论是登录还是绑定，都生成新的JWT token
                        accessToken = jwtTokenService.generateAccessToken(
                            userDto.getUsername(),
                            userDto.getEmail(),
                            userDto.getId(),
                            userService.getCurrentUser(userDto.getUsername()).getAuthorities()
                        );

                        refreshToken = jwtTokenService.generateRefreshToken(
                            userDto.getUsername(),
                            userDto.getId()
                        );

                        // 存储Access Token到HttpOnly Cookie
                        Cookie accessTokenCookie = new Cookie("accessToken", accessToken);
                        accessTokenCookie.setHttpOnly(true);
                        accessTokenCookie.setPath("/");
                        accessTokenCookie.setMaxAge(3600); // 1小时
                        accessTokenCookie.setSecure(true); // 生产环境设为true，HTTPS必须
                        accessTokenCookie.setAttribute("SameSite", "Lax");
                        response.addCookie(accessTokenCookie);

                        // 存储Refresh Token到HttpOnly Cookie
                        Cookie refreshTokenCookie = new Cookie("refreshToken", refreshToken);
                        refreshTokenCookie.setHttpOnly(true);
                        refreshTokenCookie.setPath("/");
                        refreshTokenCookie.setMaxAge(604800); // 7天
                        refreshTokenCookie.setSecure(true); // 生产环境设为true，HTTPS必须
                        refreshTokenCookie.setAttribute("SameSite", "Lax");
                        response.addCookie(refreshTokenCookie);

                        if (isUserLoggedIn) {
                            System.out.println("Binding completed successfully for user: " + currentUserId);
                        } else {
                            System.out.println("Login completed successfully for user: " + userDto.getId());
                        }
                        
                        // 检测回调模式：优先使用state参数中的response_type，其次使用Accept头
                        String callbackMode = "redirect";
                        String redirectUri = "/";
                        
                        // 解析state参数
                        String state = request.getParameter("state");
                        if (state != null) {
                            try {
                                // 解码state参数
                                String decodedState = java.net.URLDecoder.decode(state, "UTF-8");
                                // 尝试解析为JSON
                                ObjectMapper objectMapper = new ObjectMapper();
                                Map<String, Object> stateData = objectMapper.readValue(decodedState, Map.class);
                                
                                // 获取回调模式
                                if (stateData.containsKey("response_type")) {
                                    String responseType = stateData.get("response_type").toString();
                                    if ("json".equals(responseType)) {
                                        callbackMode = "json";
                                    }
                                }
                                
                                // 获取重定向URI
                                if (stateData.containsKey("redirect_uri")) {
                                    redirectUri = stateData.get("redirect_uri").toString();
                                }
                            } catch (Exception e) {
                                // 解析失败，使用默认值
                                System.out.println("Failed to parse state parameter: " + e.getMessage());
                            }
                        }
                        
                        // 如果没有指定回调模式，使用Accept头判断
                        if ("redirect".equals(callbackMode)) {
                            String acceptHeader = request.getHeader("Accept");
                            if (acceptHeader != null && acceptHeader.contains("application/json")) {
                                callbackMode = "json";
                            }
                        }
                        
                        if ("json".equals(callbackMode)) {
                            // 返回JSON响应 - 无头服务模式
                            response.setContentType("application/json");
                            response.setCharacterEncoding("UTF-8");
                            
                            // 构建响应数据
                            Map<String, Object> responseData = new HashMap<>();
                            responseData.put("message", isUserLoggedIn ? "Binding successful" : "Login successful");
                            responseData.put("authenticated", true);
                            responseData.put("user", userDto);
                            responseData.put("accessToken", accessToken);
                            responseData.put("refreshToken", refreshToken);
                            responseData.put("accessTokenExpiresIn", 3600); // 1小时
                            responseData.put("refreshTokenExpiresIn", 604800); // 7天
                            responseData.put("tokenType", "Bearer");
                            
                            // 序列化并写入响应
                            ObjectMapper objectMapper = new ObjectMapper();
                            objectMapper.writeValue(response.getWriter(), responseData);
                        } else {
                            // 重定向模式 - 完全由前端主导
                            // 使用state参数中指定的redirect_uri，或使用默认值
                            response.sendRedirect(redirectUri);
                        }
                    }

                } catch (IllegalArgumentException e) {
                    // 业务逻辑错误（如账户已被绑定）
                    System.out.println("OAuth2 processing failed: " + e.getMessage());
                    handleOAuth2Error(request, response, e.getMessage());
                } catch (Exception e) {
                    // 系统错误
                    System.err.println("OAuth2 processing error: " + e.getMessage());
                    e.printStackTrace();
                    handleOAuth2Error(request, response, "oauth2_processing_failed");
                }
            }

            /**
             * 从请求中获取当前登录用户ID
             * 通过JWT Cookie判断
             */
            private String getCurrentUserIdFromRequest(HttpServletRequest request) {
                try {
                    Cookie[] cookies = request.getCookies();
                    if (cookies == null) {
                        return null;
                    }

                    String accessToken = null;
                    for (Cookie cookie : cookies) {
                        if ("accessToken".equals(cookie.getName())) {
                            accessToken = cookie.getValue();
                            break;
                        }
                    }

                    if (accessToken == null || accessToken.trim().isEmpty()) {
                        return null;
                    }

                    // 尝试提取userId，异常则返回null（不是登录状态）
                    try {
                        return jwtTokenService.getUserIdFromToken(accessToken);
                    } catch (RuntimeException e) {
                        System.out.println("Invalid or expired access token: " + e.getMessage());
                        return null;
                    }
                } catch (Exception e) {
                    System.out.println("Failed to extract user ID from cookies: " + e.getMessage());
                    return null;
                }
            }

            /**
             * 处理OAuth2错误，支持JSON响应和重定向
             */
            private void handleOAuth2Error(HttpServletRequest request, HttpServletResponse response, String errorMessage) throws IOException {
                // 检测回调模式：优先使用state参数中的response_type，其次使用Accept头
                String callbackMode = "redirect";
                String redirectUri = "/";
                
                // 解析state参数
                String state = request.getParameter("state");
                if (state != null) {
                    try {
                        // 解码state参数
                        String decodedState = java.net.URLDecoder.decode(state, "UTF-8");
                        // 尝试解析为JSON
                        ObjectMapper objectMapper = new ObjectMapper();
                        Map<String, Object> stateData = objectMapper.readValue(decodedState, Map.class);
                        
                        // 获取回调模式
                        if (stateData.containsKey("response_type")) {
                            String responseType = stateData.get("response_type").toString();
                            if ("json".equals(responseType)) {
                                callbackMode = "json";
                            }
                        }
                        
                        // 获取重定向URI
                        if (stateData.containsKey("redirect_uri")) {
                            redirectUri = stateData.get("redirect_uri").toString();
                        }
                    } catch (Exception e) {
                        // 解析失败，使用默认值
                        System.out.println("Failed to parse state parameter: " + e.getMessage());
                    }
                }
                
                // 如果没有指定回调模式，使用Accept头判断
                if ("redirect".equals(callbackMode)) {
                    String acceptHeader = request.getHeader("Accept");
                    if (acceptHeader != null && acceptHeader.contains("application/json")) {
                        callbackMode = "json";
                    }
                }
                
                if ("json".equals(callbackMode)) {
                    // 返回JSON响应 - 无头服务模式
                    response.setContentType("application/json");
                    response.setCharacterEncoding("UTF-8");
                    
                    // 构建错误响应数据
                    Map<String, Object> responseData = new HashMap<>();
                    responseData.put("message", "OAuth2 processing failed");
                    responseData.put("authenticated", false);
                    responseData.put("error", errorMessage);
                    responseData.put("timestamp", System.currentTimeMillis());
                    responseData.put("path", request.getRequestURI());
                    
                    // 序列化并写入响应
                    ObjectMapper objectMapper = new ObjectMapper();
                    objectMapper.writeValue(response.getWriter(), responseData);
                } else {
                    // 重定向模式 - 完全由前端主导
                    try {
                        String encodedError = java.net.URLEncoder.encode(errorMessage, "UTF-8");
                        response.sendRedirect(redirectUri + (redirectUri.contains("?") ? "&" : "?") + "error=" + encodedError);
                    } catch (Exception ex) {
                        response.sendRedirect(redirectUri + (redirectUri.contains("?") ? "&" : "?") + "error=oauth2_processing_failed");
                    }
                }
            }
        };
    }

    /**
     * 主安全过滤器链
     * 处理Web页面和OAuth2登录
     */
    @Bean
    @Order(3)
    public SecurityFilterChain webSecurityFilterChain(HttpSecurity http,
                                                     ClientRegistrationRepository clientRegistrationRepository) throws Exception {
        http
            // CSRF保护
            .csrf(csrf -> csrf
                .csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
                .ignoringRequestMatchers("/oauth2/**", "/api/auth/**", "/api/logout")
            )
            // 授权规则
            .authorizeHttpRequests(authz -> authz
                .requestMatchers("/", "/login/**", "/oauth2/**", "/css/**", "/js/**",
                               "/images/**", "/static/**", "/index.html", "/assets/**",
                               "/favicon.ico", "/error").permitAll()
                .requestMatchers("/api/auth/**").permitAll()  // 认证API公开
                .requestMatchers("/api/user").authenticated()  // 所有认证用户都可以访问
                .requestMatchers("/api/admin/**").hasRole("ADMIN")  // 只有ADMIN角色可以访问
                .requestMatchers("/api/manager/**").hasAnyRole("ADMIN", "MANAGER")  // ADMIN或MANAGER角色可以访问
                .anyRequest().authenticated()
            )
            // OAuth2登录配置
            .oauth2Login(oauth2 -> oauth2
                .loginPage("/login")
                .successHandler(oauth2SuccessHandler())
                .failureHandler((request, response, exception) -> {
                    System.err.println("=== OAuth2 Login Failure ===");
                    System.err.println("Request URI: " + request.getRequestURI());
                    System.err.println("Query String: " + request.getQueryString());
                    System.err.println("Error: " + exception.getMessage());
                    System.err.println("Error Class: " + exception.getClass().getName());
                    exception.printStackTrace();
                    response.sendRedirect("/login?error=oauth2_failed");
                })
                .authorizationEndpoint(authz -> authz
                    .authorizationRequestResolver(authorizationRequestResolver(clientRegistrationRepository))
                )
                .userInfoEndpoint(userInfo -> userInfo
                    .userService(oauth2UserService())
                )
                .redirectionEndpoint(redirection -> redirection
                    .baseUri("/oauth2/callback")
                )
            )
            // 登出配置
            .logout(logout -> logout
                .logoutSuccessUrl("/login")
                .invalidateHttpSession(true)
                .clearAuthentication(true)
                .deleteCookies("id_token", "github_access_token", "twitter_access_token",
                             "JSESSIONID", "accessToken", "refreshToken")
                .permitAll()
            );

        return http.build();
    }

    // 新增：自定义OAuth2用户服务
    @Bean
    public OAuth2UserService<OAuth2UserRequest, OAuth2User> oauth2UserService() {
        return userRequest -> {
            String registrationId = userRequest.getClientRegistration().getRegistrationId();

            if ("x".equals(registrationId)) {  // ✅ X API v2：检查 'x' 而不是 'twitter'
                // 自定义Twitter用户信息获取
                try {
                    OAuth2User xUser = loadXUser(userRequest);  // ✅ X API v2：变量名和方法名更新

                    // 为Twitter手动存储access token到authorizedClientService
                    // 注意：这里无法直接存储，因为没有Authentication对象
                    // Twitter token验证暂时无法工作，除非使用其他方法

                    return xUser;
                } catch (Exception e) {
                    throw new RuntimeException("Failed to load Twitter user", e);
                }
            } else {
                // 对于其他提供商使用默认服务
                DefaultOAuth2UserService delegate = new DefaultOAuth2UserService();
                OAuth2User oauth2User = delegate.loadUser(userRequest);

                if ("github".equals(registrationId)) {
                    return processGitHubUser(oauth2User, userRequest.getAccessToken());
                } else if ("google".equals(registrationId)) {
                    return processGoogleUser(oauth2User);
                }

                return oauth2User;
            }
        };
    }

    private OAuth2User loadXUser(OAuth2UserRequest userRequest) throws Exception {  // ✅ X API v2：方法名更新
        // 手动调用Twitter API获取用户信息
        String authorizationHeader = "Bearer " + userRequest.getAccessToken().getTokenValue();

        HttpHeaders headers = new HttpHeaders();
        headers.set("Authorization", authorizationHeader);

        HttpEntity<?> entity = new HttpEntity<>(headers);

        // 调用Twitter API v2
        ResponseEntity<Map<String, Object>> response = restTemplate().exchange(
            "https://api.x.com/2/users/me?user.fields=created_at,description,entities,id,location,name,pinned_tweet_id,profile_image_url,protected,public_metrics,url,username,verified,verified_type,withheld",
            HttpMethod.GET,
            entity,
            new ParameterizedTypeReference<Map<String, Object>>() {}
        );

        if (response.getBody() != null && response.getBody().containsKey("data")) {
            @SuppressWarnings("unchecked")
            Map<String, Object> userData = (Map<String, Object>) response.getBody().get("data");

            // 创建扁平化的属性映射
            Map<String, Object> attributes = new HashMap<>();
            attributes.putAll(userData);

            // 确保username属性存在
            if (!attributes.containsKey("username")) {
                throw new IllegalArgumentException("Twitter API response missing 'username' field");
            }

            return new DefaultOAuth2User(
                Collections.singleton(new SimpleGrantedAuthority("ROLE_USER")),
                attributes,
                "username"  // 使用username作为name属性
            );
        } else {
            throw new IllegalArgumentException("Invalid Twitter API response structure");
        }
    }

    private OAuth2User processGitHubUser(OAuth2User oauth2User, OAuth2AccessToken accessToken) {
        Map<String, Object> attributes = new HashMap<>(oauth2User.getAttributes());

        // GitHub邮箱获取：如果主用户信息中没有邮箱，尝试获取用户的邮箱列表
        if (attributes.get("email") == null && accessToken.getScopes().contains("user:email")) {
            try {
                String email = getGitHubUserEmail(accessToken.getTokenValue());
                if (email != null) {
                    attributes.put("email", email);
                    System.out.println("Successfully retrieved GitHub user email: " + email);
                } else {
                    System.out.println("No verified primary email found for GitHub user: " + attributes.get("login"));
                }
            } catch (Exception e) {
                System.err.println("Failed to fetch GitHub user email: " + e.getMessage());
                // 不要因为邮箱获取失败而影响整个登录流程
                // 用户仍可以使用其他信息登录
            }
        }

        return new DefaultOAuth2User(
            oauth2User.getAuthorities(),
            attributes,
            "login"  // GitHub的用户名字段是"login"
        );
    }

    // 新增：获取GitHub用户邮箱的方法
    private String getGitHubUserEmail(String accessToken) throws Exception {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);
        headers.setAccept(Collections.singletonList(MediaType.APPLICATION_JSON));

        HttpEntity<?> entity = new HttpEntity<>(headers);

        ResponseEntity<List<Map<String, Object>>> response = restTemplate().exchange(
            "https://api.github.com/user/emails",
            HttpMethod.GET,
            entity,
            new ParameterizedTypeReference<List<Map<String, Object>>>() {}
        );

        if (response.getBody() != null) {
            // 查找主要且已验证的邮箱
            return response.getBody().stream()
                .filter(email -> Boolean.TRUE.equals(email.get("primary")) &&
                               Boolean.TRUE.equals(email.get("verified")))
                .findFirst()
                .map(email -> (String) email.get("email"))
                .orElse(null);
        }

        return null;
    }

    private OAuth2User processGoogleUser(OAuth2User oauth2User) {
        // Google用户处理保持现有逻辑
        return oauth2User;
    }


    // 创建OAuth2授权请求解析器 - 支持PKCE和保留前端传入的state参数
    @Bean
    public OAuth2AuthorizationRequestResolver authorizationRequestResolver(ClientRegistrationRepository clientRegistrationRepository) {
        DefaultOAuth2AuthorizationRequestResolver defaultResolver = 
            new DefaultOAuth2AuthorizationRequestResolver(
                clientRegistrationRepository, "/oauth2/authorization");

        // 配置自定义的授权请求参数 - 先启用PKCE
        defaultResolver.setAuthorizationRequestCustomizer(OAuth2AuthorizationRequestCustomizers.withPkce());

        // 创建自定义解析器，保留前端传入的state参数（但不要覆盖Spring Security生成的state）
        // ✅ 关键修复：Spring Security使用state作为session key，不能直接覆盖
        // 前端state信息会在回调时从URL参数中获取，不需要在这里处理
        return defaultResolver;
    }

    /**
     * 辅助方法：确定OAuth2提供商（后备方案，当无法从 Authentication 获取 registrationId 时使用）
     * 返回小写字符串（如 "github", "x"），与前端和 ApiAuthController 保持一致
     */
    private String determineProvider(OAuth2User oauth2User) {
        if (oauth2User.getAttribute("login") != null) {
            return "github";
        } else if (oauth2User.getAttribute("username") != null) {
            return "x";  // ✅ 返回注册ID 'x'，与前端和 ApiAuthController 保持一致
        }
        return "unknown";
    }

    /**
     * 辅助方法：获取提供商用户ID
     */
    private String getProviderUserId(OAuth2User oauth2User, String provider) {
        switch (provider.toLowerCase()) {
            case "github": return oauth2User.getAttribute("id").toString();
            case "twitter":
            case "x": return oauth2User.getAttribute("id");  // ✅ 支持 "twitter" 和 "x"
            default: return null;
        }
    }

    /**
     * 辅助方法：获取提供商邮箱
     */
    private String getProviderEmail(OAuth2User oauth2User, String provider) {
        switch (provider.toLowerCase()) {
            case "github": return oauth2User.getAttribute("email");
            case "twitter":
            case "x": return null; // Twitter/X不提供邮箱
            default: return null;
        }
    }

    /**
     * 辅助方法：获取提供商用户名
     */
    private String getProviderName(OAuth2User oauth2User, String provider) {
        switch (provider.toLowerCase()) {
            case "github": return (String) oauth2User.getAttribute("login");
            case "twitter":
            case "x": return (String) oauth2User.getAttribute("username");  // ✅ 支持 "twitter" 和 "x"
            default: return oauth2User.getName();
        }
    }

    /**
     * 辅助方法：获取提供商头像
     */
    private String getProviderPicture(OAuth2User oauth2User, String provider) {
        switch (provider.toLowerCase()) {
            case "github": return (String) oauth2User.getAttribute("avatar_url");
            case "twitter":
            case "x": return (String) oauth2User.getAttribute("profile_image_url");  // ✅ 支持 "twitter" 和 "x"
            default: return null;
        }
    }

}
