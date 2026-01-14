package com.example.oauth2demo.config;

import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.util.matcher.AntPathRequestMatcher;
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
import org.springframework.web.client.RestTemplate;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.AuthenticationSuccessHandler;
import org.springframework.security.web.csrf.CookieCsrfTokenRepository;
import org.springframework.beans.factory.annotation.Value;

import java.io.IOException;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Value("${app.frontend.type:thymeleaf}")
    private String frontendType;

    @Bean
    public RestTemplate restTemplate() {
        return new RestTemplate();
    }

    @Autowired
    private OAuth2AuthorizedClientService authorizedClientService;

    @Autowired
    private ClientRegistrationRepository clientRegistrationRepository;

    @Bean
    public AuthenticationSuccessHandler oauth2SuccessHandler() {
        return new AuthenticationSuccessHandler() {
            @Override
            public void onAuthenticationSuccess(HttpServletRequest request, HttpServletResponse response,
                                              Authentication authentication) throws IOException {
                System.out.println("=== OAuth2 Authentication Success ===");

                // 处理Google用户（OpenID Connect）
                if (authentication.getPrincipal() instanceof OidcUser oidcUser) {
                    String idToken = oidcUser.getIdToken().getTokenValue();

                    // 创建HTTP Only Cookie存储Google ID Token
                    Cookie idTokenCookie = new Cookie("id_token", idToken);
                    idTokenCookie.setHttpOnly(true);
                    idTokenCookie.setSecure(true); // HTTPS环境下设置为true
                    idTokenCookie.setPath("/");
                    idTokenCookie.setMaxAge(3600); // 1小时过期

                    response.addCookie(idTokenCookie);

                    System.out.println("Provider: Google");
                    System.out.println("User: " + oidcUser.getFullName());
                    System.out.println("Email: " + oidcUser.getEmail());
                    System.out.println("ID Token stored in cookie");
                }
                // 处理GitHub用户（OAuth2）
                else if (authentication.getPrincipal() instanceof OAuth2User oauth2User) {
                    // 尝试获取OAuth2AuthorizedClient来判断提供商类型
                    OAuth2AuthorizedClient githubClient = authorizedClientService
                        .loadAuthorizedClient("github", authentication.getName());
                    OAuth2AuthorizedClient twitterClient = authorizedClientService
                        .loadAuthorizedClient("twitter", authentication.getName());

                    // 处理GitHub用户
                    if (githubClient != null && githubClient.getAccessToken() != null) {
                        String accessToken = githubClient.getAccessToken().getTokenValue();

                        // 创建HTTP Only Cookie存储GitHub访问令牌
                        Cookie accessTokenCookie = new Cookie("github_access_token", accessToken);
                        accessTokenCookie.setHttpOnly(true);
                        accessTokenCookie.setSecure(true); // HTTPS环境下设置为true
                        accessTokenCookie.setPath("/");
                        accessTokenCookie.setMaxAge(3600); // 1小时过期

                        response.addCookie(accessTokenCookie);

                        System.out.println("Provider: GitHub");
                        System.out.println("User: " + oauth2User.getAttribute("login"));
                        System.out.println("Name: " + oauth2User.getAttribute("name"));
                        System.out.println("GitHub access token stored in cookie");
                    }
                    // 处理Twitter用户
                    else if (twitterClient != null && twitterClient.getAccessToken() != null) {
                        String accessToken = twitterClient.getAccessToken().getTokenValue();

                        // 创建HTTP Only Cookie存储Twitter访问令牌
                        Cookie accessTokenCookie = new Cookie("twitter_access_token", accessToken);
                        accessTokenCookie.setHttpOnly(true);
                        accessTokenCookie.setSecure(true); // HTTPS环境下设置为true
                        accessTokenCookie.setPath("/");
                        accessTokenCookie.setMaxAge(3600); // 1小时过期

                        response.addCookie(accessTokenCookie);

                        System.out.println("Provider: Twitter");
                        System.out.println("User: " + oauth2User.getAttribute("username"));
                        System.out.println("Name: " + oauth2User.getAttribute("name"));
                        System.out.println("Twitter access token stored in cookie");
                    }
                }

                // 重定向到测试页面
                response.sendRedirect("/test");
            }
        };
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            /*
             * === CSRF（跨站请求伪造）保护配置 ===
             * 
             * 什么是CSRF攻击？
             * - CSRF (Cross-Site Request Forgery) 是一种恶意攻击方式
             * - 攻击者诱导用户在已登录的网站上执行非预期的操作
             * - 例如：用户登录了银行网站，然后访问了恶意网站，恶意网站可能会
             *   发送转账请求到银行网站，由于用户已登录，请求会被执行
             * 
             * CSRF保护原理：
             * 1. 服务器为每个用户会话生成一个随机的CSRF Token
             * 2. 用户发送POST请求时，必须携带这个Token
             * 3. 服务器验证Token是否正确，不正确则拒绝请求
             * 4. 恶意网站无法获取到用户的CSRF Token，因此无法伪造请求
             * 
             * CookieCsrfTokenRepository.withHttpOnlyFalse() 配置说明：
             * - 将CSRF Token存储在Cookie中
             * - withHttpOnlyFalse() 允许JavaScript读取Cookie中的CSRF Token
             * - 这样前端JavaScript可以获取Token并在AJAX请求中使用
             */
            .csrf(csrf -> csrf
                .csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
                .ignoringRequestMatchers("/api/logout", "/api/validate-google-token", "/api/validate-github-token", "/api/validate-twitter-token")
            )
            .authorizeHttpRequests(authz -> authz
                .requestMatchers("/", "/login/**", "/oauth2/**", "/css/**", "/js/**", "/images/**", "/static/**", "/index.html", "/assets/**", "/favicon.ico", "/error", "/api/user").permitAll()
                .anyRequest().authenticated()
            )
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
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED)
            )
            .logout(logout -> logout
                .logoutRequestMatcher(new AntPathRequestMatcher("/logout", "GET"))
                .logoutSuccessUrl("/")
                .invalidateHttpSession(true)
                .clearAuthentication(true)
                .deleteCookies("id_token", "github_access_token", "twitter_access_token", "JSESSIONID")
                .permitAll()
            );

        return http.build();
    }

    // 新增：自定义OAuth2用户服务
    @Bean
    public OAuth2UserService<OAuth2UserRequest, OAuth2User> oauth2UserService() {
        return userRequest -> {
            String registrationId = userRequest.getClientRegistration().getRegistrationId();

            if ("twitter".equals(registrationId)) {
                // 自定义Twitter用户信息获取
                try {
                    return loadTwitterUser(userRequest);
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

    private OAuth2User loadTwitterUser(OAuth2UserRequest userRequest) throws Exception {
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


}
