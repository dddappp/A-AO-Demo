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

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Value("${app.frontend.type:react}")
    private String frontendType;

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
     * OAuth2登录成功处理器
     * 处理用户认证成功后的逻辑
     */
    @Bean
    public AuthenticationSuccessHandler oauth2SuccessHandler() {
        return new AuthenticationSuccessHandler() {
            @Override
            public void onAuthenticationSuccess(HttpServletRequest request, HttpServletResponse response,
                                              Authentication authentication) throws IOException {
                System.out.println("=== OAuth2 Authentication Success ===");

                try {
                    UserDto userDto = null;

                    // 处理Google用户（OpenID Connect）
                    if (authentication.getPrincipal() instanceof OidcUser oidcUser) {
                        String providerUserId = oidcUser.getSubject();
                        String email = oidcUser.getEmail();
                        String name = oidcUser.getFullName();
                        String picture = oidcUser.getPicture();

                        // 获取或创建用户
                        userDto = userService.getOrCreateOAuthUser(UserEntity.AuthProvider.GOOGLE,
                                                                  providerUserId, email, name, picture);

                        System.out.println("Provider: Google");
                        System.out.println("User: " + name);
                        System.out.println("Email: " + email);
                    }
                    // 处理GitHub和Twitter用户（OAuth2）
                    else if (authentication.getPrincipal() instanceof OAuth2User oauth2User) {
                        String provider = determineProvider(oauth2User);
                        String providerUserId = getProviderUserId(oauth2User, provider);
                        String email = getProviderEmail(oauth2User, provider);
                        String name = getProviderName(oauth2User, provider);
                        String picture = getProviderPicture(oauth2User, provider);

                        // 获取或创建用户
                        UserEntity.AuthProvider authProvider = UserEntity.AuthProvider.valueOf(provider.toUpperCase());
                        userDto = userService.getOrCreateOAuthUser(authProvider, providerUserId, email, name, picture);

                        System.out.println("Provider: " + provider);
                        System.out.println("User: " + name);
                        System.out.println("Email: " + email);
                    }

                    // 生成我们自己的JWT Token并存储在HttpOnly Cookie中
                    if (userDto != null) {
                        String accessToken = jwtTokenService.generateAccessToken(
                            userDto.getUsername(),
                            userDto.getEmail(),
                            userDto.getId()
                        );

                        String refreshToken = jwtTokenService.generateRefreshToken(
                            userDto.getUsername(),
                            userDto.getId()
                        );

                        // 存储Access Token到HttpOnly Cookie
                        Cookie accessTokenCookie = new Cookie("accessToken", accessToken);
                        accessTokenCookie.setHttpOnly(true);
                        accessTokenCookie.setPath("/");
                        accessTokenCookie.setMaxAge(3600); // 1小时
                        accessTokenCookie.setSecure(false); // 开发环境设为false
                        accessTokenCookie.setAttribute("SameSite", "Lax");
                        response.addCookie(accessTokenCookie);

                        // 存储Refresh Token到HttpOnly Cookie
                        Cookie refreshTokenCookie = new Cookie("refreshToken", refreshToken);
                        refreshTokenCookie.setHttpOnly(true);
                        refreshTokenCookie.setPath("/");
                        refreshTokenCookie.setMaxAge(604800); // 7天
                        refreshTokenCookie.setSecure(false); // 开发环境设为false
                        refreshTokenCookie.setAttribute("SameSite", "Lax");
                        response.addCookie(refreshTokenCookie);
                    }

                    // 根据前端类型重定向
                    if ("react".equals(frontendType)) {
                        response.sendRedirect("/");  // React SPA
                    } else {
                        response.sendRedirect("/test");  // Thymeleaf页面
                    }

                } catch (Exception e) {
                    System.err.println("Error processing OAuth2 login: " + e.getMessage());
                    e.printStackTrace();
                    response.sendRedirect("/login?error=oauth2_processing_failed");
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
                .anyRequest().authenticated()
            )
            // OAuth2登录配置
            .oauth2Login(oauth2 -> oauth2
                .loginPage("/login")
                .successHandler(oauth2SuccessHandler())
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


    // 创建OAuth2授权请求解析器 - 支持PKCE和强制账户选择
    @Bean
    public OAuth2AuthorizationRequestResolver authorizationRequestResolver(ClientRegistrationRepository clientRegistrationRepository) {
        DefaultOAuth2AuthorizationRequestResolver resolver =
            new DefaultOAuth2AuthorizationRequestResolver(
                clientRegistrationRepository, "/oauth2/authorization");

        // 配置自定义的授权请求参数 - 先启用PKCE
        resolver.setAuthorizationRequestCustomizer(OAuth2AuthorizationRequestCustomizers.withPkce());

        return resolver;
    }

    /**
     * 辅助方法：确定OAuth2提供商
     */
    private String determineProvider(OAuth2User oauth2User) {
        if (oauth2User.getAttribute("login") != null) {
            return "github";
        } else if (oauth2User.getAttribute("username") != null) {
            return "twitter";
        }
        return "unknown";
    }

    /**
     * 辅助方法：获取提供商用户ID
     */
    private String getProviderUserId(OAuth2User oauth2User, String provider) {
        switch (provider) {
            case "github": return oauth2User.getAttribute("id").toString();
            case "twitter": return oauth2User.getAttribute("id");
            default: return null;
        }
    }

    /**
     * 辅助方法：获取提供商邮箱
     */
    private String getProviderEmail(OAuth2User oauth2User, String provider) {
        switch (provider) {
            case "github": return oauth2User.getAttribute("email");
            case "twitter": return null; // Twitter不提供邮箱
            default: return null;
        }
    }

    /**
     * 辅助方法：获取提供商用户名
     */
    private String getProviderName(OAuth2User oauth2User, String provider) {
        switch (provider) {
            case "github": return (String) oauth2User.getAttribute("login");
            case "twitter": return (String) oauth2User.getAttribute("username");
            default: return oauth2User.getName();
        }
    }

    /**
     * 辅助方法：获取提供商头像
     */
    private String getProviderPicture(OAuth2User oauth2User, String provider) {
        switch (provider) {
            case "github": return (String) oauth2User.getAttribute("avatar_url");
            case "twitter": return (String) oauth2User.getAttribute("profile_image_url");
            default: return null;
        }
    }

}
